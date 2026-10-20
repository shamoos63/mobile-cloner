import 'dart:io';

import '../server/receive_delegate.dart';

/// Writes to `<target>.part`, then renames into place on commit. The
/// `.part` file survives an interrupted transfer, so the next attempt
/// appends to it instead of starting over.
class FileSystemWriter implements IncomingFileWriter {
  FileSystemWriter(this.targetPath, {this.modified});

  final String targetPath;
  final DateTime? modified;
  late final File _part = File('$targetPath.part');

  @override
  Future<int> partialBytes() async => await _part.exists() ? await _part.length() : 0;

  @override
  Future<void> addStream(Stream<List<int>> data, {bool append = false}) async {
    await _part.parent.create(recursive: true);
    final sink = _part.openWrite(mode: append ? FileMode.append : FileMode.write);
    try {
      await sink.addStream(data);
      await sink.flush();
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

  /// Keeps the partial data for a later resume; use [discard] to drop it.
  @override
  Future<void> abort() async {}

  Future<void> discard() async {
    if (await _part.exists()) await _part.delete();
  }
}
