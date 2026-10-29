import 'dart:async';
import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;

import '../l10n.dart';
import '../platform/android_bridge.dart';
import 'receive_journal.dart';
import 'writers.dart';

/// What happened after a session, for the summary screen.
class RestoreReport {
  RestoreReport(this.session);

  final ReceiveSession session;
  int contactsFiles = 0;
  bool contactsImportOpened = false;
  bool wallpaperSet = false;
  final Set<WhatsAppVariant> whatsApp = {};
  final List<String> problems = [];
}

/// Receiving side on a phone: puts each file where it belongs (gallery,
/// WhatsApp folder for this Android version, contacts import...).
class PhoneReceiveDelegate implements ReceiveDelegate {
  PhoneReceiveDelegate({
    required this.bridge,
    required this.info,
    required this.stagingDir,
    required this.journal,
    required this.approve,
    required this.onSeen,
    required this.onReport,
  }) : planner = AndroidRestorePlanner(sdkInt: info.sdkInt);

  final AndroidBridge bridge;
  final AndroidDeviceInfo info;
  final AndroidRestorePlanner planner;

  /// App-private folder for staging media and deferred items.
  final String stagingDir;
  final ReceiveJournal journal;
  final Future<bool> Function(Device sender, List<FileDto> files) approve;
  final void Function(Device device) onSeen;
  final void Function(RestoreReport report) onReport;

  bool? _allFiles;

  @override
  void onDeviceSeen(Device device) => onSeen(device);

  @override
  Future<Set<String>?> onPrepare(Device sender, List<FileDto> files) async {
    if (!await approve(sender, files)) return null;
    _allFiles = await bridge.hasAllFilesAccess();
    final done = await journal.doneFor(sender.fingerprint);
    return {for (final f in files) if (!done.contains(f.id)) f.id};
  }

  @override
  Future<IncomingFileWriter> openFile(Device sender, FileDto file) async {
    final writer = await _writerFor(file);
    return _JournalingWriter(writer, () => journal.markDone(sender.fingerprint, file.id));
  }

  Future<IncomingFileWriter> _writerFor(FileDto file) async {
    final target = planner.targetFor(file);
    switch (target) {
      case MediaStoreTarget():
        return MediaStoreWriter(p.join(stagingDir, 'media', file.id), target);
      case SharedStorageTarget(:final path, :final needsSpecialAccess):
        if (!needsSpecialAccess || (_allFiles ??= await bridge.hasAllFilesAccess())) {
          return FileSystemWriter(SafePath.resolveUnder(info.storageRoot, path), modified: file.modified);
        }
        final tree = await bridge.treeCovering(path);
        if (tree == null) {
          throw StateError(tr.noFolderAccess(path));
        }
        return SafWriter(bridge, tree, tree.relative(path));
      case DeferredTarget(:final category, :final relPath):
        return FileSystemWriter(SafePath.resolveUnder(p.join(stagingDir, category.wireName), relPath));
    }
  }

  @override
  Future<void> onSessionFinished(ReceiveSession session) async {
    await journal.flush();
    final report = RestoreReport(session);
    final scanPaths = <String>[];
    final wallpapers = <String, String>{};
    for (final status in session.files.values) {
      if (status.state != FileState.done) continue;
      final file = status.file;
      final target = planner.targetFor(file);
      switch (target) {
        case SharedStorageTarget(:final path, :final whatsApp):
          if (whatsApp != null) report.whatsApp.add(whatsApp);
          if (whatsApp == null) scanPaths.add(p.join(info.storageRoot, path));
        case DeferredTarget(category: ContentCategory.contacts):
          report.contactsFiles++;
        case DeferredTarget(category: ContentCategory.wallpaper, :final relPath):
          wallpapers[p.basenameWithoutExtension(relPath)] = p.join(stagingDir, ContentCategory.wallpaper.wireName, relPath);
        default:
          break;
      }
    }
    if (scanPaths.isNotEmpty) await bridge.scanMedia(scanPaths);
    if (report.contactsFiles > 0) {
      final vcf = p.join(stagingDir, ContentCategory.contacts.wireName, 'contacts.vcf');
      if (await File(vcf).exists()) {
        report.contactsImportOpened = await bridge.importVcf(vcf);
        if (!report.contactsImportOpened) report.problems.add('No Contacts app found to import contacts.vcf.');
      }
    }
    if (wallpapers.isNotEmpty) {
      try {
        report.wallpaperSet = await bridge.applyWallpapers(home: wallpapers['home'], lock: wallpapers['lock']);
      } catch (e) {
        report.problems.add(tr.wallpaperFailed('$e'));
      }
    }
    onReport(report);
  }

  @override
  void onSessionCanceled(ReceiveSession session) {
    unawaited(journal.flush());
  }
}

class _JournalingWriter implements IncomingFileWriter {
  _JournalingWriter(this.inner, this.onCommitted);

  final IncomingFileWriter inner;
  final Future<void> Function() onCommitted;

  @override
  Future<int> partialBytes() => inner.partialBytes();

  @override
  Future<void> addStream(Stream<List<int>> data, {bool append = false}) => inner.addStream(data, append: append);

  @override
  Future<void> commit() async {
    await inner.commit();
    await onCommitted();
  }

  @override
  Future<void> abort() => inner.abort();
}
