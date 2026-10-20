import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

import '../protocol/constants.dart';
import '../protocol/device_info.dart';
import '../protocol/file_dto.dart';
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

/// HTTP(S) server implementing the receiving half of LocalSend v2 plus the
/// Cloner `finish` extension. Only one session runs at a time.
class ClonerServer {
  ClonerServer({
    required this.identity,
    required this.info,
    required this.delegate,
    this.pin,
  });

  final DeviceIdentity identity;
  DeviceInfo info;
  final ReceiveDelegate delegate;

  /// Optional PIN a sender has to supply on prepare-upload.
  String? pin;

  HttpServer? _server;
  ReceiveSession? _session;
  final _events = StreamController<ServerEvent>.broadcast();

  Stream<ServerEvent> get events => _events.stream;
  ReceiveSession? get currentSession => _session;
  int? get port => _server?.port;

  Future<void> start({int port = defaultPort, InternetAddress? address}) async {
    final bind = address ?? InternetAddress.anyIPv4;
    _server = info.protocol == ProtocolType.https
        ? await HttpServer.bindSecure(bind, port, identity.toSecurityContext())
        : await HttpServer.bind(bind, port);
    _server!.listen(_handle, onError: (_) {});
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
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
    final active = _session;
    if (active != null && active.state == SessionState.active) {
      return _status(req.response, HttpStatus.conflict, 'Blocked by another session');
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
    _events.add(SessionStarted(session));
    await _json(req.response, {
      'sessionId': session.id,
      'files': {for (final e in session.files.entries) e.key: e.value.token},
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

    status
      ..state = FileState.receiving
      ..received = 0;
    final writer = await delegate.openFile(session, status.file);
    final hashSink = _DigestSink();
    final hasher = status.file.sha256 != null ? crypto.sha256.startChunkedConversion(hashSink) : null;
    var lastEmit = DateTime.now();
    try {
      await writer.addStream(req.map((chunk) {
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
      if (hasher != null && hashSink.value.toString() != status.file.sha256!.toLowerCase()) {
        await writer.abort();
        status.state = FileState.failed;
        _events.add(FileProgress(session, status));
        return _status(req.response, 422, 'Checksum mismatch (sha256)');
      }
      await writer.commit();
      status.state = FileState.done;
    } catch (e) {
      await writer.abort();
      status
        ..state = FileState.failed
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
    await _endSession(session);
    req.response.statusCode = HttpStatus.ok;
    await req.response.close();
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

  Future<void> _status(HttpResponse res, int code, String message) async {
    res
      ..statusCode = code
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'message': message}));
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
