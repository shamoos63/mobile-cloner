import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../platform/android_bridge.dart';

/// How we can read a WhatsApp folder on this phone.
enum WhatsAppAccess {
  /// Plain file access (Android 10 and older, or All-files access granted).
  direct,

  /// Through a folder the user granted in the system picker.
  saf,

  /// Needs the user to grant access first.
  needsGrant,

  /// No WhatsApp folder found.
  notFound,
}

class WhatsAppScan {
  const WhatsAppScan({
    required this.variant,
    required this.access,
    this.root,
    this.files = const [],
    this.newestBackup,
  });

  final WhatsAppVariant variant;
  final WhatsAppAccess access;

  /// Root relative to shared storage, e.g. `Android/media/com.whatsapp/WhatsApp`.
  final String? root;
  final List<OutgoingFile> files;

  /// Modification time of the newest `msgstore*` database: tells the user
  /// whether they need to run a fresh WhatsApp backup first.
  final DateTime? newestBackup;

  int get totalBytes => files.fold(0, (a, f) => a + f.dto.size);
}

/// Finds and lists the WhatsApp / WhatsApp Business folder for sending.
class WhatsAppSource {
  WhatsAppSource(this.bridge);

  final AndroidBridge bridge;

  Future<bool> isInstalled(WhatsAppVariant v) => bridge.isPackageInstalled(v.packageName);

  /// Opens WhatsApp so the user can run Settings > Chats > Chat backup >
  /// Back up. WhatsApp has no public intent to start a backup directly.
  Future<bool> openForBackup(WhatsAppVariant v) => bridge.launchPackage(v.packageName);

  /// Asks for access to the WhatsApp folder via the system picker, starting
  /// in `Android/media/<package>`.
  Future<SafTree?> grantFolder(WhatsAppVariant v) =>
      bridge.pickTree(initialPath: 'Android/media/${v.packageName}');

  Future<WhatsAppScan> scan(WhatsAppVariant v, WhatsAppScope scope) async {
    final info = await bridge.deviceInfo();
    final allFiles = await bridge.hasAllFilesAccess();
    var sawProtected = false;

    for (final root in WhatsAppLayout.sourceCandidates(v, info.sdkInt)) {
      final protected = root.startsWith('Android/media') && WhatsAppLayout.needsSpecialAccess(info.sdkInt);
      if (!protected || allFiles) {
        final dir = Directory(p.join(info.storageRoot, root));
        if (await dir.exists()) {
          return _scanDirect(v, scope, root, dir);
        }
        continue;
      }
      sawProtected = true;
      final tree = await bridge.treeCovering(root);
      if (tree != null) {
        final scan = await _scanSaf(v, scope, root, tree);
        if (scan.files.isNotEmpty) return scan;
      }
    }
    return WhatsAppScan(variant: v, access: sawProtected ? WhatsAppAccess.needsGrant : WhatsAppAccess.notFound);
  }

  Future<WhatsAppScan> _scanDirect(WhatsAppVariant v, WhatsAppScope scope, String root, Directory dir) async {
    final files = <OutgoingFile>[];
    DateTime? newest;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      final rel = p.relative(e.path, from: dir.path).replaceAll(r'\', '/');
      if (rel.endsWith('.part') || !WhatsAppLayout.includes(scope, rel)) continue;
      final f = OutgoingFile.fromFile(e, category: v.category, relPath: rel);
      files.add(f);
      if (rel.toLowerCase().startsWith('databases/msgstore')) {
        final m = f.dto.modified;
        if (m != null && (newest == null || m.isAfter(newest))) newest = m;
      }
    }
    return WhatsAppScan(variant: v, access: WhatsAppAccess.direct, root: root, files: _dbFirst(files), newestBackup: newest);
  }

  Future<WhatsAppScan> _scanSaf(WhatsAppVariant v, WhatsAppScope scope, String root, SafTree tree) async {
    final sub = tree.relative(root);
    final entries = await bridge.list(tree, sub: sub.isEmpty ? null : sub);
    final files = <OutgoingFile>[];
    DateTime? newest;
    for (final e in entries) {
      final rel = sub.isEmpty ? e.rel : e.rel.substring(sub.length + 1);
      if (rel.endsWith('.part') || !WhatsAppLayout.includes(scope, rel)) continue;
      files.add(OutgoingFile(
        dto: FileDto(
          id: OutgoingFile.stableId(v.category, rel, e.size, e.modified),
          fileName: p.posix.basename(rel),
          size: e.size,
          fileType: lookupMimeType(rel) ?? 'application/octet-stream',
          modified: e.modified,
          cloner: ClonerFileMeta(category: v.category, relPath: rel),
        ),
        open: (offset) => bridge.read(e.uri, offset: offset),
      ));
      if (rel.toLowerCase().startsWith('databases/msgstore') && (newest == null || e.modified.isAfter(newest))) {
        newest = e.modified;
      }
    }
    return WhatsAppScan(variant: v, access: WhatsAppAccess.saf, root: root, files: _dbFirst(files), newestBackup: newest);
  }

  /// Chat databases go first so an interrupted transfer still moves chats.
  List<OutgoingFile> _dbFirst(List<OutgoingFile> files) {
    files.sort((a, b) {
      final ai = WhatsAppLayout.isChatDatabase(a.dto.relPath) ? 0 : 1;
      final bi = WhatsAppLayout.isChatDatabase(b.dto.relPath) ? 0 : 1;
      return ai.compareTo(bi);
    });
    return files;
  }
}
