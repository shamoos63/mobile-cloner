import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloner_core/cloner_core.dart';
import 'package:photo_manager/photo_manager.dart';

import '../platform/android_bridge.dart';

/// Stages the file in app storage (deterministic name, so a resumed
/// transfer appends), then inserts it into MediaStore on commit with the
/// original folder and capture date.
class MediaStoreWriter implements IncomingFileWriter {
  MediaStoreWriter(this.stagingPath, this.target);

  final String stagingPath;
  final MediaStoreTarget target;
  late final _staging = FileSystemWriter(stagingPath);

  @override
  Future<int> partialBytes() => _staging.partialBytes();

  @override
  Future<void> addStream(Stream<List<int>> data, {bool append = false}) => _staging.addStream(data, append: append);

  @override
  Future<void> commit() async {
    await _staging.commit();
    final file = File(stagingPath);
    try {
      final relativePath = '${target.relativeDir}/';
      if (target.isVideo) {
        await PhotoManager.editor.saveVideo(file,
            title: target.displayName, relativePath: relativePath, creationDate: target.takenAt);
      } else {
        await PhotoManager.editor.saveImageWithPath(stagingPath,
            title: target.displayName, relativePath: relativePath, creationDate: target.takenAt);
      }
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> abort() => _staging.abort();
}

/// Writes through a Storage Access Framework grant (WhatsApp folder on
/// Android 11+ without All-files access). Data goes to `<name>.part` and is
/// renamed on commit.
class SafWriter implements IncomingFileWriter {
  SafWriter(this.bridge, this.tree, this.rel);

  final AndroidBridge bridge;
  final SafTree tree;
  final String rel;

  @override
  Future<int> partialBytes() => bridge.partialSize(tree, rel);

  @override
  Future<void> addStream(Stream<List<int>> data, {bool append = false}) async {
    final handle = await bridge.openWrite(tree, rel, append: append);
    final buffer = BytesBuilder(copy: false);
    try {
      await for (final chunk in data) {
        buffer.add(chunk);
        // Batch platform-channel calls to ~1 MB.
        if (buffer.length >= 1 << 20) await bridge.write(handle, buffer.takeBytes());
      }
      if (buffer.isNotEmpty) await bridge.write(handle, buffer.takeBytes());
    } finally {
      await bridge.closeWrite(handle);
    }
  }

  @override
  Future<void> commit() => bridge.commit(tree, rel);

  @override
  Future<void> abort() async {}
}
