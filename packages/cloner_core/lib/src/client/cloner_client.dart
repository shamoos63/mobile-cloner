import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../protocol/constants.dart';
import '../protocol/device_info.dart';
import '../protocol/file_dto.dart';
import '../protocol/peer_status.dart';
import '../security/identity.dart';
import '../transfer/session_summary.dart';

class PrepareUploadResult {
  const PrepareUploadResult({required this.sessionId, required this.tokens, this.offsets = const {}});

  final String sessionId;

  /// fileId -> token. Files the receiver declined are missing.
  final Map<String, String> tokens;

  /// fileId -> bytes the receiver already holds (Cloner resume extension).
  final Map<String, int> offsets;

  /// Receiver already has everything (HTTP 204).
  bool get nothingToSend => tokens.isEmpty;
}

class ClonerHttpException implements Exception {
  ClonerHttpException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  bool get pinRequired => statusCode == 401;
  bool get rejected => statusCode == 403;
  bool get busy => statusCode == 409;

  /// For 416 on a resumed upload: how many bytes the receiver really has.
  int? get receiverOffset {
    try {
      return ((jsonDecode(message) as Map)['offset'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'ClonerHttpException($statusCode): $message';
}

/// HTTP client side of the protocol.
///
/// Peers use self-signed certificates, so instead of a CA chain we pin the
/// certificate hash to the fingerprint the peer announced during discovery.
class ClonerClient {
  ClonerClient({
    required this.self,
    Duration connectTimeout = const Duration(seconds: 5),
  }) : _http = HttpClient()
         ..connectionTimeout = connectTimeout
         ..idleTimeout = const Duration(seconds: 30) {
    _http.badCertificateCallback = _checkCertificate;
  }

  /// Our own info, sent with register / prepare-upload.
  DeviceInfo self;
  final HttpClient _http;

  /// host:port -> expected fingerprint.
  final Map<String, String> _pins = {};

  bool _checkCertificate(X509Certificate cert, String host, int port) {
    final expected = _pins['$host:$port'];
    // Unknown peer (manual IP entry): accept and pin on first use.
    if (expected == null || expected.isEmpty) {
      _pins['$host:$port'] = DeviceIdentity.fingerprintOfDer(cert.der);
      return true;
    }
    return DeviceIdentity.fingerprintOfDer(cert.der) == expected.toUpperCase();
  }

  void pin(Device device) {
    if (device.https && device.fingerprint.isNotEmpty) {
      _pins['${device.ip}:${device.port}'] = device.fingerprint;
    }
  }

  /// POST /register. Returns the peer's info.
  Future<DeviceInfo> register(Device target, {Duration? timeout}) async {
    pin(target);
    final res = await _postJson(target.uri(ApiRoute.register), self.toJson())
        .timeout(timeout ?? const Duration(seconds: 5));
    return DeviceInfo.fromJson(_decodeObject(res.body));
  }

  /// Contacts a peer by address only (manual connect / legacy subnet scan).
  Future<Device> probe(String ip, {int port = defaultPort, bool https = true, Duration? timeout}) async {
    final uri = Uri(scheme: https ? 'https' : 'http', host: ip, port: port, path: ApiRoute.register);
    final res = await _postJson(uri, self.toJson()).timeout(timeout ?? const Duration(seconds: 3));
    final info = DeviceInfo.fromJson(_decodeObject(res.body));
    return Device(
      ip: ip,
      info: DeviceInfo(
        alias: info.alias,
        version: info.version,
        deviceModel: info.deviceModel,
        deviceType: info.deviceType,
        // In HTTPS mode the certificate is the source of truth.
        fingerprint: https ? (_pins['$ip:$port'] ?? info.fingerprint) : info.fingerprint,
        port: port,
        protocol: https ? ProtocolType.https : ProtocolType.http,
        download: info.download,
        cloner: info.cloner,
      ),
    );
  }

  /// [probe] that picks the scheme: loopback addresses (ADB cable) try the
  /// plain-HTTP listener first, everything else is HTTPS.
  Future<Device> probeAuto(String ip, {int port = defaultPort, Duration? timeout}) async {
    if (InternetAddress.tryParse(ip)?.isLoopback ?? false) {
      try {
        return await probe(ip, port: port, https: false, timeout: timeout);
      } catch (_) {}
    }
    return probe(ip, port: port, timeout: timeout);
  }

  Future<PrepareUploadResult> prepareUpload(
    Device target,
    List<FileDto> files, {
    String? pin,
  }) async {
    this.pin(target);
    final res = await _postJson(
      target.uri(ApiRoute.prepareUpload, {'pin': ?pin}),
      {
        'info': self.toJson(),
        'files': {for (final f in files) f.id: f.toJson()},
      },
      // The receiver may wait for the user to tap Accept.
    ).timeout(const Duration(minutes: 5));
    if (res.statusCode == HttpStatus.noContent) {
      return const PrepareUploadResult(sessionId: '', tokens: {});
    }
    final json = _decodeObject(res.body);
    final cloner = json['cloner'] as Map?;
    return PrepareUploadResult(
      sessionId: json['sessionId'] as String,
      tokens: (json['files'] as Map).cast<String, String>(),
      offsets: ((cloner?['offsets'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      ),
    );
  }

  /// Streams one file. [data] must start at [offset]; [length] is the
  /// number of bytes still to send. [onProgress] gets bytes sent so far in
  /// this call.
  Future<void> upload(
    Device target, {
    required String sessionId,
    required String fileId,
    required String token,
    required int length,
    required Stream<List<int>> data,
    int offset = 0,
    void Function(int sent)? onProgress,
  }) async {
    final req = await _http.postUrl(
      target.uri(ApiRoute.upload, {
        'sessionId': sessionId,
        'fileId': fileId,
        'token': token,
        if (offset > 0) 'offset': '$offset',
      }),
    );
    req.headers.contentType = ContentType.binary;
    req.contentLength = length;
    var sent = 0;
    await req.addStream(data.map((chunk) {
      sent += chunk.length;
      onProgress?.call(sent);
      return chunk;
    }));
    final res = await req.close();
    await _ensureOk(res);
  }

  Future<void> cancel(Device target, String sessionId) async {
    await _postJson(target.uri(ApiRoute.cancel, {'sessionId': sessionId}), null)
        .timeout(const Duration(seconds: 5));
  }

  /// Cloner extension: tells the receiver the session is complete.
  /// Ignored (404) by plain LocalSend peers.
  Future<void> finish(Device target, String sessionId, SessionSummary summary) async {
    if (!target.info.isCloner) return;
    await _postJson(
      target.uri(ApiRoute.finish, {'sessionId': sessionId}),
      summary.toJson(),
    ).timeout(const Duration(seconds: 30));
  }

  /// Heartbeat: sends our status, returns the peer's.
  Future<PeerStatus> status(Device target, PeerStatus mine) async {
    final res = await _postJson(target.uri(ApiRoute.status), mine.toJson())
        .timeout(const Duration(seconds: 4));
    return PeerStatus.fromJson(_decodeObject(res.body));
  }

  void close() => _http.close(force: true);

  Future<({int statusCode, String body})> _postJson(Uri uri, Object? body) async {
    final req = await _http.postUrl(uri);
    if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      req.headers.contentType = ContentType.json;
      req.contentLength = bytes.length;
      req.add(bytes);
    }
    final res = await req.close();
    return _ensureOk(res);
  }

  Future<({int statusCode, String body})> _ensureOk(HttpClientResponse res) async {
    final body = await utf8.decodeStream(res);
    if (res.statusCode >= 300) {
      throw ClonerHttpException(res.statusCode, body);
    }
    return (statusCode: res.statusCode, body: body);
  }

  Map<String, Object?> _decodeObject(String body) =>
      (jsonDecode(body) as Map).cast<String, Object?>();
}
