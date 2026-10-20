import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

import '../protocol/constants.dart';
import '../protocol/device_info.dart';
import '../protocol/file_dto.dart';
import '../protocol/peer_status.dart';
import '../security/identity.dart';
import '../transfer/session_summary.dart';
import 'receive_delegate.dart';
import 'receive_session.dart';

sealed class ServerEvent {
  const ServerEvent();
}

class SessionStarted extends ServerEvent {
  const SessionStarted(this.session);
  final ReceiveSession session;
}

class FileProgress extends ServerEvent {
  const FileProgress(this.session, this.status);
  final ReceiveSession session;
  final IncomingFileStatus status;
}

class SessionEnded extends ServerEvent {
  const SessionEnded(this.session);
  final ReceiveSession session;
}

/// The sender reported its health (battery, pause state).
class PeerStatusReceived extends ServerEvent {
  const PeerStatusReceived(this.session, this.status);
  final ReceiveSession? session;
  final PeerStatus status;
}

/// HTTP(S) server implementing the receiving half of LocalSend v2 plus the
/// Cloner `finish` extension. Only one session runs at a time.
class ClonerServer {
  ClonerServer({
    required this.identity,
    required this.info,
    required this.delegate,
    this.pin,
    PeerStatus Function()? localStatus,
  }) : localStatus = localStatus ?? (() => const PeerStatus());

  final DeviceIdentity identity;
  DeviceInfo info;
  final ReceiveDelegate delegate;

  /// Optional PIN a sender has to supply on prepare-upload.
  String? pin;

  /// Our own health, returned on every status heartbeat.
  final PeerStatus Function() localStatus;

  HttpServer? _server;
  HttpServer? _loopback;
  ReceiveSession? _session;
  final _events = StreamController<ServerEvent>.broadcast();

  Stream<ServerEvent> get events => _events.stream;
  ReceiveSession? get currentSession => _session;
  int? get port => _server?.port;

  /// Port of the plain-HTTP loopback listener, if it started.
  int? get cablePort => _loopback?.port;

  /// Starts the network server, plus a plain-HTTP loopback listener on
  /// [loopback] for ADB cable transfers (null disables it).
  Future<void> start({int port = defaultPort, InternetAddress? address, int? loopback = loopbackPort}) async {
    final bind = address ?? InternetAddress.anyIPv4;
    _server = info.protocol == ProtocolType.https
        ? await HttpServer.bindSecure(bind, port, identity.toSecurityContext())
        : await HttpServer.bind(bind, port);
    _server!.listen(_handle, onError: (_) {});
    if (loopback != null) {
      try {
        _loopback = await HttpServer.bind(InternetAddress.loopbackIPv4, loopback);
        _loopback!.listen(_handle, onError: (_) {});
      } on SocketException {
        // Port taken (another instance); cable mode falls back to HTTPS.
      }
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    await _loopback?.close(force: true);
    _server = null;
    _loopback = null;
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final path = req.uri.path;
      switch ((req.method, path)) {
        case ('POST', ApiRoute.register):
          await _register(req);
        case ('GET', ApiRoute.info):
          await _json(req.response, info.toJson());
        case ('POST', ApiRoute.prepareUpload):
          await _prepareUpload(req);
        case ('POST', ApiRoute.upload):
          await _upload(req);
        case ('POST', ApiRoute.cancel):
          await _cancel(req);
        case ('POST', ApiRoute.finish):
          await _finish(req);
        case ('POST', ApiRoute.status):
          await _peerStatus(req);
        default:
          await _status(req.response, HttpStatus.notFound, 'Not found');
      }
    } catch (e) {
      try {
        await _status(req.response, HttpStatus.internalServerError, '$e');
      } catch (_) {}
    }
  }

  String _remoteIp(HttpRequest req) => req.connectionInfo?.remoteAddress.address ?? '';

  Future<void> _register(HttpRequest req) async {
    final body = await _readJson(req);
    if (body == null) return _status(req.response, HttpStatus.badRequest, 'Invalid body');
    final peer = DeviceInfo.fromJson(body);
    if (peer.fingerprint != info.fingerprint) {
      delegate.onDeviceSeen(Device(ip: _remoteIp(req), info: peer));
    }
    await _json(req.response, info.toJson());
  }

  Future<void> _prepareUpload(HttpRequest req) async {
    if (pin != null && req.uri.queryParameters['pin'] != pin) {
      return _status(req.response, HttpStatus.unauthorized, 'PIN required');
    }
    final body = await _readJson(req);
    if (body == null || body['info'] is! Map || body['files'] is! Map) {
      return _status(req.response, HttpStatus.badRequest, 'Invalid body');
    }
    final List<FileDto> files;
    final DeviceInfo senderInfo;
    try {
      senderInfo = DeviceInfo.fromJson((body['info'] as Map).cast());
      files = [
        for (final f in (body['files'] as Map).values) FileDto.fromJson((f as Map).cast()),
      ];
    } catch (_) {
      return _status(req.response, HttpStatus.badRequest, 'Invalid body');
    }
    final sender = Device(ip: _remoteIp(req), info: senderInfo);
    final active = _session;
    if (active != null && active.state == SessionState.active) {
      // The same sender coming back (new IP after switching from Wi-Fi to
      // cable, or after a crash) replaces its own stale session.
      if (active.sender.fingerprint == senderInfo.fingerprint && senderInfo.fingerprint.isNotEmpty) {
        active.state = SessionState.canceled;
        _events.add(SessionEnded(active));
      } else {
        return _status(req.response, HttpStatus.conflict, 'Blocked by another session');
      }
    }
    final accepted = await delegate.onPrepare(sender, files);
    if (accepted == null) {
      return _status(req.response, HttpStatus.forbidden, 'Rejected');
    }
    if (accepted.isEmpty) {
      req.response.statusCode = HttpStatus.noContent;
      return req.response.close();
    }
    final session = ReceiveSession(
      sender: sender,
      accepted: {for (final f in files) if (accepted.contains(f.id)) f.id: f},
    );
    _session = session;

    // Cloner extension: tell the sender how much of each file we already
    // hold so it resumes mid-file instead of starting over.
    final offsets = <String, int>{};
    if (senderInfo.isCloner) {
      for (final status in session.files.values) {
        final writer = await delegate.openFile(sender, status.file);
        final have = await writer.partialBytes();
        if (have > 0 && have < status.file.size) {
          offsets[status.file.id] = have;
          status.received = have;
        }
      }
    }
    _events.add(SessionStarted(session));
    await _json(req.response, {
      'sessionId': session.id,
      'files': {for (final e in session.files.entries) e.key: e.value.token},
      if (offsets.isNotEmpty) 'cloner': {'offsets': offsets},
    });
  }

  Future<void> _upload(HttpRequest req) async {
    final q = req.uri.queryParameters;
    final sessionId = q['sessionId'], fileId = q['fileId'], token = q['token'];
    if (sessionId == null || fileId == null || token == null) {
      return _status(req.response, HttpStatus.badRequest, 'Missing parameters');
    }
    final session = _session;
    if (session == null || session.id != sessionId || session.state != SessionState.active) {
      return _status(req.response, HttpStatus.conflict, 'Blocked by another session');
    }
    final status = session.files[fileId];
    if (status == null || status.token != token || session.sender.ip != _remoteIp(req)) {
      return _status(req.response, HttpStatus.forbidden, 'Invalid token or IP address');
    }

    final offset = int.tryParse(q['offset'] ?? '') ?? 0;
    final writer = await delegate.openFile(session.sender, status.file);
    final have = await writer.partialBytes();
    if (offset > 0 && offset != have) {
      // Tell the sender where we really are; it retries from there.
      return _status(req.response, HttpStatus.requestedRangeNotSatisfiable, 'Offset mismatch', {'offset': have});
    }
    status
      ..state = FileState.receiving
      ..received = offset;
    final hashSink = _DigestSink();
    // A resumed file can't be hashed without re-reading the prefix; the
    // size check below still catches truncation.
    final hasher = status.file.sha256 != null && offset == 0
        ? crypto.sha256.startChunkedConversion(hashSink)
        : null;
    var lastEmit = DateTime.now();
    try {
      await writer.addStream(append: offset > 0, req.map((chunk) {
        status.received += chunk.length;
        hasher?.add(chunk);
        final now = DateTime.now();
        if (now.difference(lastEmit).inMilliseconds > 200) {
          lastEmit = now;
          _events.add(FileProgress(session, status));
        }
        return chunk;
      }));
      hasher?.close();
      if (status.received != status.file.size) {
        // Connection dropped mid-file: keep the partial data for resume.
        await writer.abort();
        status.state = FileState.pending;
        _events.add(FileProgress(session, status));
        return _status(req.response, HttpStatus.badRequest, 'Incomplete body');
      }
      if (hasher != null && hashSink.value.toString() != status.file.sha256!.toLowerCase()) {
        await writer.abort();
        status.state = FileState.failed;
        _events.add(FileProgress(session, status));
        return _status(req.response, 422, 'Checksum mismatch (sha256)');
      }
      await writer.commit();
      status.state = FileState.done;
    } catch (e) {
      // Usually the link dropped. Keep the partial file and let the sender
      // resume; the file stays pending.
      await writer.abort();
      status
        ..state = FileState.pending
        ..error = e;
      _events.add(FileProgress(session, status));
      rethrow;
    }
    _events.add(FileProgress(session, status));
    req.response.statusCode = HttpStatus.ok;
    await req.response.close();

    // Plain LocalSend senders never call /finish.
    if (!session.sender.info.isCloner && session.allSettled) {
      await _endSession(session);
    }
  }

  Future<void> _peerStatus(HttpRequest req) async {
    final body = await _readJson(req);
    if (body != null) {
      final session = _session;
      _events.add(PeerStatusReceived(
        session != null && session.sender.ip == _remoteIp(req) ? session : null,
        PeerStatus.fromJson(body),
      ));
    }
    await _json(req.response, localStatus().toJson());
  }

  Future<void> _finish(HttpRequest req) async {
    final session = _session;
    if (session == null || session.id != req.uri.queryParameters['sessionId']) {
      return _status(req.response, HttpStatus.notFound, 'Unknown session');
    }
    final body = await _readJson(req);
    session.summary = body == null ? null : SessionSummary.fromJson(body);
    for (final f in session.files.values) {
      if (f.state == FileState.pending) f.state = FileState.skipped;
    }
    // Answer first: post-processing (contacts import, media scan) can take
    // longer than the sender waits, and a CLI receiver may exit right after.
    req.response.statusCode = HttpStatus.ok;
    await req.response.close();
    await _endSession(session);
  }

  Future<void> _endSession(ReceiveSession session) async {
    if (session.state != SessionState.active) return;
    session.state = SessionState.finished;
    await delegate.onSessionFinished(session);
    _events.add(SessionEnded(session));
  }

  Future<void> _cancel(HttpRequest req) async {
    final session = _session;
    if (session != null && session.id == req.uri.queryParameters['sessionId']) {
      cancelSession();
    }
    req.response.statusCode = HttpStatus.ok;
    await req.response.close();
  }

  /// Cancels the running session (from either side).
  void cancelSession() {
    final session = _session;
    if (session == null || session.state != SessionState.active) return;
    session.state = SessionState.canceled;
    delegate.onSessionCanceled(session);
    _events.add(SessionEnded(session));
  }

  Future<Map<String, Object?>?> _readJson(HttpRequest req) async {
    try {
      final decoded = jsonDecode(await utf8.decodeStream(req));
      return decoded is Map ? decoded.cast<String, Object?>() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _json(HttpResponse res, Object body) async {
    res
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await res.close();
  }

  Future<void> _status(HttpResponse res, int code, String message, [Map<String, Object?>? extra]) async {
    res
      ..statusCode = code
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'message': message, ...?extra}));
    await res.close();
  }
}

class _DigestSink implements Sink<crypto.Digest> {
  late crypto.Digest value;
  @override
  void add(crypto.Digest data) => value = data;
  @override
  void close() {}
}
