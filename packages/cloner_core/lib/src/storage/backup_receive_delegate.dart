import 'dart:async';

import '../protocol/device_info.dart';
import '../protocol/file_dto.dart';
import '../server/receive_delegate.dart';
import '../server/receive_session.dart';
import 'backup_store.dart';
import 'file_writer.dart';

/// Receive delegate for a computer acting as backup station: every file is
/// stored in a [BackupStore], nothing is restored.
class BackupReceiveDelegate implements ReceiveDelegate {
  BackupReceiveDelegate(
    this.store, {
    this.approve,
    this.onSeen,
    this.onFinished,
    this.incremental = true,
  });

  final BackupStore store;

  /// Asks the user to accept; null means auto-accept.
  final Future<bool> Function(Device sender, List<FileDto> files)? approve;
  final void Function(Device device)? onSeen;
  final FutureOr<void> Function(ReceiveSession session)? onFinished;
  final bool incremental;

  @override
  void onDeviceSeen(Device device) => onSeen?.call(device);

  @override
  Future<Set<String>?> onPrepare(Device sender, List<FileDto> files) async {
    if (approve != null && !await approve!(sender, files)) return null;
    return {
      for (final f in files)
        if (!incremental || !store.hasFile(sender.info, f)) f.id,
    };
  }

  @override
  Future<IncomingFileWriter> openFile(ReceiveSession session, FileDto file) async =>
      FileSystemWriter(store.pathFor(session.sender.info, file), modified: file.modified);

  @override
  Future<void> onSessionFinished(ReceiveSession session) async {
    await store.writeManifest(session.sender.info, session.summary);
    await onFinished?.call(session);
  }

  @override
  void onSessionCanceled(ReceiveSession session) {}
}
