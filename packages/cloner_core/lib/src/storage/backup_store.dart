import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../migration/content_category.dart';
import '../migration/safe_path.dart';
import '../protocol/device_info.dart';
import '../protocol/file_dto.dart';
import '../transfer/send_job.dart';
import '../transfer/session_summary.dart';

/// Metadata kept next to a device backup (`backup.json`).
class BackupManifest {
  BackupManifest({
    required this.alias,
    required this.fingerprint,
    this.deviceModel,
    this.platform,
    this.sdkInt,
    required this.lastBackup,
    Map<String, Object?>? categories,
  }) : categories = categories ?? {};

  final String alias;
  final String fingerprint;
  final String? deviceModel;
  final String? platform;
  final int? sdkInt;
  final DateTime lastBackup;
  final Map<String, Object?> categories;

  factory BackupManifest.fromJson(Map<String, Object?> json) => BackupManifest(
    alias: json['alias'] as String? ?? 'Device',
    fingerprint: json['fingerprint'] as String? ?? '',
    deviceModel: json['deviceModel'] as String?,
    platform: json['platform'] as String?,
    sdkInt: (json['sdkInt'] as num?)?.toInt(),
    lastBackup: DateTime.tryParse(json['lastBackup'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    categories: (json['categories'] as Map?)?.cast(),
  );

  Map<String, Object?> toJson() => {
    'formatVersion': 1,
    'alias': alias,
    'fingerprint': fingerprint,
    'deviceModel': deviceModel,
    'platform': platform,
    'sdkInt': sdkInt,
    'lastBackup': lastBackup.toUtc().toIso8601String(),
    'categories': categories,
  };
}

/// One folder per device under [root], laid out as `<category>/<relPath>`.
/// Backups are incremental: a file already present with the same size is
/// skipped at prepare time.
class BackupStore {
  BackupStore(this.root);

  final String root;

  static const manifestName = 'backup.json';

  String deviceDir(DeviceInfo device) {
    final model = device.deviceModel == null ? '' : ' (${device.deviceModel})';
    final shortFp = device.fingerprint.length >= 8 ? device.fingerprint.substring(0, 8) : device.fingerprint;
    final name = '${device.alias}$model $shortFp'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return p.join(root, name);
  }

  String pathFor(DeviceInfo device, FileDto file) =>
      SafePath.resolveUnder(p.join(deviceDir(device), file.category.wireName), file.relPath);

  /// Whether [file] is already backed up (same size).
  bool hasFile(DeviceInfo device, FileDto file) {
    final f = File(pathFor(device, file));
    return f.existsSync() && f.lengthSync() == file.size;
  }

  Future<void> writeManifest(DeviceInfo device, SessionSummary? summary) async {
    final dir = deviceDir(device);
    final file = File(p.join(dir, manifestName));
    final previous = await readManifest(dir);
    final categories = <String, Object?>{...?previous?.categories};
    for (final e in (summary?.categories ?? const <ContentCategory, CategoryStats>{}).entries) {
      categories[e.key.wireName] = {
        ...e.value.toJson(),
        'at': DateTime.now().toUtc().toIso8601String(),
      };
    }
    final manifest = BackupManifest(
      alias: device.alias,
      fingerprint: device.fingerprint,
      deviceModel: device.deviceModel,
      platform: device.cloner?.platform.name,
      sdkInt: device.cloner?.sdkInt ?? summary?.sourceSdkInt,
      lastBackup: DateTime.now(),
      categories: categories,
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(manifest.toJson()));
  }

  static Future<BackupManifest?> readManifest(String deviceDir) async {
    final f = File(p.join(deviceDir, manifestName));
    if (!await f.exists()) return null;
    try {
      return BackupManifest.fromJson((jsonDecode(await f.readAsString()) as Map).cast());
    } catch (_) {
      return null;
    }
  }

  /// Device backups found under [root].
  Future<List<(String dir, BackupManifest manifest)>> listBackups() async {
    final rootDir = Directory(root);
    if (!await rootDir.exists()) return [];
    final result = <(String, BackupManifest)>[];
    await for (final entity in rootDir.list()) {
      if (entity is! Directory) continue;
      final m = await readManifest(entity.path);
      if (m != null) result.add((entity.path, m));
    }
    result.sort((a, b) => b.$2.lastBackup.compareTo(a.$2.lastBackup));
    return result;
  }

  /// Removes one device backup. Refuses anything that is not a backup
  /// folder directly under [root].
  Future<void> deleteBackup(String deviceDir) async {
    final dir = Directory(p.normalize(deviceDir));
    if (!p.equals(dir.parent.path, p.normalize(root))) {
      throw ArgumentError.value(deviceDir, 'deviceDir', 'not a backup under $root');
    }
    if (await readManifest(dir.path) == null) {
      throw ArgumentError.value(deviceDir, 'deviceDir', 'no $manifestName here');
    }
    await dir.delete(recursive: true);
  }

  /// Builds the outgoing file list to restore a backup onto a phone.
  static Future<List<OutgoingFile>> filesToRestore(
    String deviceDir, {
    Set<ContentCategory>? only,
  }) async {
    final files = <OutgoingFile>[];
    for (final category in ContentCategory.values) {
      if (only != null && !only.contains(category)) continue;
      final dir = Directory(p.join(deviceDir, category.wireName));
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File || entity.path.endsWith('.part')) continue;
        final rel = p.relative(entity.path, from: dir.path).replaceAll(r'\', '/');
        files.add(OutgoingFile.fromFile(entity, category: category, relPath: rel));
      }
    }
    return files;
  }
}
