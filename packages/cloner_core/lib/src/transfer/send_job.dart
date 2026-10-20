import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../client/cloner_client.dart';
import '../migration/content_category.dart';
import '../protocol/device_info.dart';
import '../protocol/file_dto.dart';
import '../protocol/peer_status.dart';
import 'checkpoint.dart';
import 'session_summary.dart';
import 'speed_meter.dart';

/// A file ready to send: its metadata and a way to (re)open its bytes.
class OutgoingFile {
  OutgoingFile({required this.dto, required this.open});

  final FileDto dto;

  /// Opens a fresh byte stream starting at the given offset. Called again
  /// on retry and on resume.
  final Stream<List<int>> Function(int offset) open;

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
        id: stableId(category, relPath, stat.size, stat.modified),
        fileName: p.posix.basename(relPath),
        size: stat.size,
        fileType: lookupMimeType(file.path) ?? 'application/octet-stream',
        modified: stat.modified,
        accessed: stat.accessed,
        cloner: ClonerFileMeta(category: category, relPath: relPath, takenAt: takenAt, mediaAlbum: album),
      ),
      open: (offset) => readChunked(file, offset),
    );
  }

  /// Same file -> same id across sessions and app restarts, which is what
  /// lets a checkpoint and the receiver's partial data line up on resume.
  static String stableId(ContentCategory category, String relPath, int size, DateTime? modified) {
    final key = '${category.wireName}|$relPath|$size|${modified?.millisecondsSinceEpoch ?? 0}';
    return crypto.sha1.convert(utf8.encode(key)).toString().substring(0, 24);
  }
}

/// Reads [file] from [offset] in 1 MB blocks. Much faster over HTTP than
/// `File.openRead`'s 64 KB chunks, which cost a socket write each.
Stream<List<int>> readChunked(File file, int offset, {int chunkSize = 1 << 20}) async* {
  final raf = await file.open();
  try {
    await raf.setPosition(offset);
    while (true) {
      final bytes = await raf.read(chunkSize);
      if (bytes.isEmpty) break;
      yield bytes;
    }
  } finally {
    await raf.close();
  }
}

class SendProgress {
  const SendProgress({
    required this.totalBytes,
    required this.sentBytes,
    required this.totalFiles,
    required this.doneFiles,
    required this.failedFiles,
    required this.bytesPerSecond,
    this.eta,
    this.currentFile,
    this.peerStatus,
    this.stalled = false,
  });

  final int totalBytes;
  final int sentBytes;
  final int totalFiles;
  final int doneFiles;
  final int failedFiles;

  /// Live speed over the last few seconds.
  final double bytesPerSecond;
  final Duration? eta;
  final String? currentFile;

  /// Latest heartbeat from the receiver (battery, free space).
  final PeerStatus? peerStatus;

  /// No bytes moved for a while and the peer stopped answering heartbeats.
  final bool stalled;

  double get fraction => totalBytes == 0 ? 1 : sentBytes / totalBytes;
}

enum SendOutcome {
  completed,
  rejected,
  canceled,

  /// Stopped part way (connection lost, battery, paused). The checkpoint
  /// holds what's needed to resume, over the same or another connection.
  interrupted,
  failed,
}

class SendResult {
  const SendResult(this.outcome, this.summary, {this.error, this.interruptReason});
  final SendOutcome outcome;
  final SessionSummary summary;
  final Object? error;
  final InterruptReason? interruptReason;
}

/// Sends a batch of files to one peer: prepare-upload, parallel uploads with
/// retries and byte-level resume, live speed, heartbeats, checkpointing,
/// then the Cloner `finish` call.
class SendJob {
  SendJob({
    required this.client,
    required this.target,
    required this.files,
    this.pin,
    this.parallel = 5,
    this.maxLargeInFlight = 2,
    this.largeFileBytes = 8 << 20,
    this.retries = 3,
    this.sourceSdkInt,
    this.checkpoint,
    this.checkpointStore,
    this.localStatus,
    this.heartbeatInterval = const Duration(seconds: 5),
    this.stallTimeout = const Duration(seconds: 20),
  });

  final ClonerClient client;
  final Device target;
  final List<OutgoingFile> files;
  final String? pin;
  /// Upload lanes. Small files are latency bound (one request each), so
  /// several in flight keep the link busy between them.
  final int parallel;

  /// Large files are bandwidth bound; more than a couple at once only
  /// splits the link and fragments the receiver's disk writes.
  final int maxLargeInFlight;
  final int largeFileBytes;
  final int retries;
  final int? sourceSdkInt;

  /// Progress record; files listed as done are skipped.
  final TransferCheckpoint? checkpoint;
  final CheckpointStore? checkpointStore;

  /// Our battery etc., sent with each heartbeat. Null disables heartbeats.
  final PeerStatus Function()? localStatus;
  final Duration heartbeatInterval;

  /// No progress and no heartbeat answer for this long = connection lost.
  final Duration stallTimeout;

  final _progress = StreamController<SendProgress>.broadcast();
  Stream<SendProgress> get progress => _progress.stream;

  final _peerStatus = StreamController<PeerStatus>.broadcast();
  Stream<PeerStatus> get peerStatus => _peerStatus.stream;

  String? _sessionId;
  bool _canceled = false;
  InterruptReason? _interrupt;
  final _stop = Completer<void>();
  final List<StreamSubscription<List<int>>> _active = [];

  /// Stops after flushing the checkpoint; resume later with a new job.
  void interrupt(InterruptReason reason) {
    _interrupt ??= reason;
    if (!_stop.isCompleted) _stop.complete();
  }

  Future<void> cancel() async {
    _canceled = true;
    if (!_stop.isCompleted) _stop.complete();
    final id = _sessionId;
    if (id != null) {
      try {
        await client.cancel(target, id);
      } catch (_) {}
    }
  }

  bool get _stopped => _canceled || _interrupt != null;

  Future<SendResult> run() async {
    final summary = SessionSummary(sourceSdkInt: sourceSdkInt);
    Timer? heartbeat;
    try {
      final pending = [
        for (final f in files)
          if (!(checkpoint?.doneFileIds.contains(f.dto.id) ?? false)) f,
      ];
      final prepared = await client.prepareUpload(target, [for (final f in pending) f.dto], pin: pin);
      if (prepared.nothingToSend) {
        await _markAllDone(pending);
        return SendResult(SendOutcome.completed, summary);
      }
      _sessionId = prepared.sessionId;

      // Files the receiver already has (incremental) count as done.
      await _markAllDone(pending.where((f) => !prepared.tokens.containsKey(f.dto.id)));
      final queue = pending.where((f) => prepared.tokens.containsKey(f.dto.id)).toList();
      final totalBytes = queue.fold(0, (a, f) => a + f.dto.size);
      final sentPerFile = <String, int>{
        for (final f in queue) f.dto.id: prepared.offsets[f.dto.id] ?? 0,
      };
      final meter = SpeedMeter();
      var done = 0, failed = 0;
      String? current;
      PeerStatus? lastPeer;
      var lastActivity = DateTime.now();
      var stalled = false;

      void emit() {
        final sent = sentPerFile.values.fold(0, (a, b) => a + b);
        if (_progress.isClosed) return;
        _progress.add(SendProgress(
          totalBytes: totalBytes,
          sentBytes: sent,
          totalFiles: queue.length,
          doneFiles: done,
          failedFiles: failed,
          bytesPerSecond: meter.bytesPerSecond,
          eta: meter.eta(totalBytes - sent),
          currentFile: current,
          peerStatus: lastPeer,
          stalled: stalled,
        ));
      }

      if (localStatus != null && target.info.isCloner) {
        heartbeat = Timer.periodic(heartbeatInterval, (_) async {
          try {
            final peer = await client.status(target, localStatus!());
            lastPeer = peer;
            lastActivity = DateTime.now();
            stalled = false;
            _peerStatus.add(peer);
            if (peer.isCritical) interrupt(InterruptReason.lowBatteryPeer);
          } catch (_) {
            if (DateTime.now().difference(lastActivity) > stallTimeout) {
              stalled = true;
              interrupt(InterruptReason.connectionLost);
            }
          }
          final mine = localStatus!();
          if (mine.isCritical) interrupt(InterruptReason.lowBatterySelf);
          emit();
        });
      }

      // Two queues, each in the caller's order (e.g. WhatsApp databases
      // first). Free lanes take large files while fewer than
      // [maxLargeInFlight] are moving, otherwise small ones.
      final large = Queue.of(queue.where((f) => f.dto.size >= largeFileBytes));
      final small = Queue.of(queue.where((f) => f.dto.size < largeFileBytes));
      var largeInFlight = 0;
      OutgoingFile? take() {
        if (large.isNotEmpty && (largeInFlight < maxLargeInFlight || small.isEmpty)) {
          largeInFlight++;
          return large.removeFirst();
        }
        return small.isNotEmpty ? small.removeFirst() : null;
      }

      Future<void> worker() async {
        while (!_stopped) {
          final file = take();
          if (file == null) break;
          final isLarge = file.dto.size >= largeFileBytes;
          final id = file.dto.id;
          final stats = summary.of(file.dto.category);
          current = file.dto.relPath;
          var ok = false;
          var offset = prepared.offsets[id] ?? 0;
          for (var attempt = 0; attempt <= retries && !ok && !_stopped; attempt++) {
            final base = offset;
            try {
              await client.upload(
                target,
                sessionId: prepared.sessionId,
                fileId: id,
                token: prepared.tokens[id]!,
                offset: base,
                length: file.dto.size - base,
                data: _cancellable(file.open(base)),
                onProgress: (sent) {
                  final delta = base + sent - sentPerFile[id]!;
                  sentPerFile[id] = base + sent;
                  meter.add(delta);
                  lastActivity = DateTime.now();
                  checkpoint?.partialBytes[id] = base + sent;
                  emit();
                },
              );
              ok = true;
            } on ClonerHttpException catch (e) {
              // Token / session errors won't fix themselves.
              if (e.statusCode == 403 || e.statusCode == 409) break;
              if (e.statusCode == 416) {
                offset = (e.receiverOffset ?? 0).clamp(0, file.dto.size);
                sentPerFile[id] = offset;
              }
            } catch (_) {
              if (_stopped) break;
              // Bytes sent are not always bytes stored; try where we think
              // we were, and the receiver corrects us with a 416 if needed.
              offset = sentPerFile[id]!.clamp(0, file.dto.size);
              await Future<void>.delayed(Duration(milliseconds: 700 * (attempt + 1)));
            }
          }
          if (ok) {
            done++;
            stats
              ..files += 1
              ..bytes += file.dto.size;
            checkpoint?.doneFileIds.add(id);
            checkpoint?.partialBytes.remove(id);
          } else if (!_stopped) {
            failed++;
            stats.failed += 1;
          }
          if (isLarge) largeInFlight--;
          if (checkpoint != null) await checkpointStore?.save(checkpoint!, force: ok && done % 20 == 0);
          emit();
        }
      }

      await Future.wait(List.generate(min(parallel, max(queue.length, 1)), (_) => worker()));
      heartbeat?.cancel();
      if (_canceled) return SendResult(SendOutcome.canceled, summary);
      if (_interrupt != null || (failed > 0 && !await _reachable())) {
        final reason = _interrupt ?? InterruptReason.connectionLost;
        await _saveInterrupted(reason);
        return SendResult(SendOutcome.interrupted, summary, interruptReason: reason);
      }
      await client.finish(target, prepared.sessionId, summary);
      await checkpointStore?.clear();
      return SendResult(SendOutcome.completed, summary);
    } on ClonerHttpException catch (e) {
      if (e.rejected) return SendResult(SendOutcome.rejected, summary, error: e);
      return SendResult(SendOutcome.failed, summary, error: e);
    } catch (e) {
      if (_canceled) return SendResult(SendOutcome.canceled, summary, error: e);
      final reason = _interrupt ?? InterruptReason.connectionLost;
      await _saveInterrupted(reason);
      return SendResult(SendOutcome.interrupted, summary, error: e, interruptReason: reason);
    } finally {
      heartbeat?.cancel();
      await _progress.close();
      await _peerStatus.close();
    }
  }

  /// Wraps a file stream so [interrupt] / [cancel] stops it promptly.
  Stream<List<int>> _cancellable(Stream<List<int>> source) {
    late StreamController<List<int>> controller;
    StreamSubscription<List<int>>? sub;
    controller = StreamController<List<int>>(
      onListen: () {
        sub = source.listen(controller.add, onError: controller.addError, onDone: controller.close);
        _active.add(sub!);
        _stop.future.then((_) {
          sub?.cancel();
          if (!controller.isClosed) {
            controller.addError(const SocketException('Transfer interrupted'));
            controller.close();
          }
        });
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () {
        _active.remove(sub);
        return sub?.cancel();
      },
    );
    return controller.stream;
  }

  Future<bool> _reachable() async {
    try {
      await client.register(target, timeout: const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markAllDone(Iterable<OutgoingFile> files) async {
    final cp = checkpoint;
    if (cp == null) return;
    for (final f in files) {
      cp.doneFileIds.add(f.dto.id);
    }
    await checkpointStore?.save(cp, force: true);
  }

  Future<void> _saveInterrupted(InterruptReason reason) async {
    final cp = checkpoint;
    if (cp == null) return;
    cp
      ..interruptReason = reason
      ..lastAddress = target.ip
      ..lastPort = target.port;
    await checkpointStore?.save(cp, force: true);
  }
}
