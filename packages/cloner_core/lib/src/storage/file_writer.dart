import 'dart:io';

import '../server/receive_delegate.dart';

/// Writes to `<target>.part`, then renames into place on commit.
class FileSystemWriter implements IncomingFileWriter {
  FileSystemWriter(this.targetPath, {this.modified});

  final String targetPath;
  final DateTime? modified;
  late final File _part = File('$targetPath.part');

  @override
  Future<void> addStream(Stream<List<int>> data) async {
    await _part.parent.create(recursive: true);
    final sink = _part.openWrite();
    try {
      await sink.addStream(data);
    } finally {
      await sink.close();
    }
  }

  @override
  Future<void> commit() async {
    final target = File(targetPath);
    if (await target.exists()) await target.delete();
    await _part.rename(targetPath);
    if (modified != null) {
      try {
        await target.setLastModified(modified!);
      } catch (_) {}
    }
  }

  @override
  Future<void> abort() async {
    if (await _part.exists()) await _part.delete();
  }
}
