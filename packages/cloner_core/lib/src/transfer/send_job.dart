import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../client/cloner_client.dart';
import '../migration/content_category.dart';
import '../protocol/device_info.dart';
import '../protocol/file_dto.dart';
import 'session_summary.dart';

/// A file ready to send: its metadata and a way to (re)open its bytes.
class OutgoingFile {
  OutgoingFile({required this.dto, required this.open});

  final FileDto dto;

  /// Opens a fresh byte stream. Called again on retry.
  final Stream<List<int>> Function() open;

  /// Convenience for a file on disk.
  factory OutgoingFile.fromFile(
    File file, {
    required ContentCategory category,
    required String relPath,
    DateTime? takenAt,
    String? album,
  }) {
    final stat = file.statSync();
    return OutgoingFile(
      dto: FileDto(
        id: _newId(),
        fileName: p.posix.basename(relPath),
        size: stat.size,
        fileType: lookupMimeType(file.path) ?? 'application/octet-stream',
        modified: stat.modified,
        accessed: stat.accessed,
        cloner: ClonerFileMeta(category: category, relPath: relPath, takenAt: takenAt, mediaAlbum: album),
      ),
      open: file.openRead,
    );
  }

  static final _random = Random.secure();
  static int _counter = 0;
  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${(_counter++).toRadixString(36)}${_random.nextInt(1 << 32).toRadixString(36)}';
}

class SendProgress {
  const SendProgress({
    required this.totalBytes,
    required this.sentBytes,
    required this.totalFiles,
    required this.doneFiles,
    required this.failedFiles,
    this.currentFile,
  });

  final int totalBytes;
  final int sentBytes;
  final int totalFiles;
  final int doneFiles;
  final int failedFiles;
  final String? currentFile;

  double get fraction => totalBytes == 0 ? 1 : sentBytes / totalBytes;
}

enum SendOutcome { completed, rejected, canceled, failed }

class SendResult {
  const SendResult(this.outcome, this.summary, [this.error]);
  final SendOutcome outcome;
  final SessionSummary summary;
  final Object? error;
}

/// Sends a batch of files to one peer: prepare-upload, parallel uploads with
/// retries, then the Cloner `finish` call.
class SendJob {
  SendJob({
    required this.client,
    required this.target,
    required this.files,
    this.pin,
    this.parallel = 3,
    this.retries = 2,
    this.sourceSdkInt,
  });

  final ClonerClient client;
  final Device target;
  final List<OutgoingFile> files;
  final String? pin;
  final int parallel;
  final int retries;
  final int? sourceSdkInt;

  final _progress = StreamController<SendProgress>.broadcast();
  Stream<SendProgress> get progress => _progress.stream;

  String? _sessionId;
  bool _canceled = false;

  Future<void> cancel() async {
    _canceled = true;
    final id = _sessionId;
    if (id != null) {
      try {
        await client.cancel(target, id);
      } catch (_) {}
    }
  }

  Future<SendResult> run() async {
    final summary = SessionSummary(sourceSdkInt: sourceSdkInt);
    try {
      final prepared = await client.prepareUpload(target, [for (final f in files) f.dto], pin: pin);
      if (prepared.nothingToSend) {
        return SendResult(SendOutcome.completed, summary);
      }
      _sessionId = prepared.sessionId;

      final queue = files.where((f) => prepared.tokens.containsKey(f.dto.id)).toList();
      final totalBytes = queue.fold(0, (a, f) => a + f.dto.size);
      final sentPerFile = <String, int>{};
      var done = 0, failed = 0;
      String? current;

      void emit() => _progress.add(SendProgress(
        totalBytes: totalBytes,
        sentBytes: sentPerFile.values.fold(0, (a, b) => a + b),
        totalFiles: queue.length,
        doneFiles: done,
        failedFiles: failed,
        currentFile: current,
      ));

      var next = 0;
      Future<void> worker() async {
        while (!_canceled && next < queue.length) {
          final file = queue[next++];
          final stats = summary.of(file.dto.category);
          current = file.dto.relPath;
          var ok = false;
          for (var attempt = 0; attempt <= retries && !ok && !_canceled; attempt++) {
            try {
              sentPerFile[file.dto.id] = 0;
              await client.upload(
                target,
                sessionId: prepared.sessionId,
                fileId: file.dto.id,
                token: prepared.tokens[file.dto.id]!,
                length: file.dto.size,
                data: file.open(),
                onProgress: (sent) {
                  sentPerFile[file.dto.id] = sent;
                  emit();
                },
              );
              ok = true;
            } on ClonerHttpException catch (e) {
              // Token / session errors won't fix themselves.
              if (e.statusCode == 403 || e.statusCode == 409) break;
            } catch (_) {
              await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
            }
          }
          if (ok) {
            done++;
            stats
              ..files += 1
              ..bytes += file.dto.size;
          } else {
            failed++;
            stats.failed += 1;
          }
          emit();
        }
      }

      await Future.wait(List.generate(min(parallel, queue.length), (_) => worker()));
      if (_canceled) return SendResult(SendOutcome.canceled, summary);
      await client.finish(target, prepared.sessionId, summary);
      return SendResult(SendOutcome.completed, summary);
    } on ClonerHttpException catch (e) {
      if (e.rejected) return SendResult(SendOutcome.rejected, summary, e);
      return SendResult(SendOutcome.failed, summary, e);
    } catch (e) {
      return SendResult(_canceled ? SendOutcome.canceled : SendOutcome.failed, summary, e);
    } finally {
      await _progress.close();
    }
  }
}
