import 'dart:math';

import '../protocol/device_info.dart';
import '../protocol/file_dto.dart';
import '../transfer/session_summary.dart';

enum FileState { pending, receiving, done, failed, skipped }

class IncomingFileStatus {
  IncomingFileStatus(this.file, this.token);

  final FileDto file;
  final String token;
  FileState state = FileState.pending;
  int received = 0;
  Object? error;
}

enum SessionState { active, finished, canceled }

class ReceiveSession {
  ReceiveSession({required this.sender, required Map<String, FileDto> accepted})
    : id = _randomToken(),
      files = {
        for (final e in accepted.entries) e.key: IncomingFileStatus(e.value, _randomToken()),
      };

  final String id;
  final Device sender;
  final Map<String, IncomingFileStatus> files;
  final DateTime startedAt = DateTime.now();
  SessionState state = SessionState.active;
  SessionSummary? summary;

  int get totalBytes => files.values.fold(0, (a, f) => a + f.file.size);
  int get receivedBytes => files.values.fold(0, (a, f) => a + f.received);

  bool get allSettled => files.values.every(
    (f) => f.state == FileState.done || f.state == FileState.failed || f.state == FileState.skipped,
  );

  static final _random = Random.secure();
  static String _randomToken() =>
      List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
