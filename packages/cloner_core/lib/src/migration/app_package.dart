import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One installed app as it travels between devices: its APKs (the base
/// plus any split APKs) under `apps/<package>/`, an [AppManifest] in
/// `app.json` and the launcher icon in `icon.png`. Only the app moves; its
/// private data stays on the old phone (Android keeps it out of reach).
class AppManifest {
  const AppManifest({
    required this.packageName,
    required this.label,
    required this.versionName,
    required this.versionCode,
    required this.apks,
    required this.sizeBytes,
    this.minSdk,
  });

  static const fileName = 'app.json';
  static const iconFileName = 'icon.png';
  static const baseApk = 'base.apk';

  final String packageName;
  final String label;
  final String versionName;
  final int versionCode;

  /// APK file names, `base.apk` first, then the splits.
  final List<String> apks;
  final int sizeBytes;

  /// Oldest Android API level the app runs on, when the sender knew it.
  final int? minSdk;

  bool get hasSplits => apks.length > 1;

  Map<String, Object?> toJson() => {
    'package': packageName,
    'label': label,
    'versionName': versionName,
    'versionCode': versionCode,
    'apks': apks,
    'size': sizeBytes,
    'minSdk': ?minSdk,
  };

  factory AppManifest.fromJson(Map<String, Object?> j) => AppManifest(
    packageName: j['package'] as String,
    label: j['label'] as String? ?? j['package'] as String,
    versionName: j['versionName'] as String? ?? '',
    versionCode: (j['versionCode'] as num?)?.toInt() ?? 0,
    apks: [for (final a in (j['apks'] as List? ?? const [])) '$a'],
    sizeBytes: (j['size'] as num?)?.toInt() ?? 0,
    minSdk: (j['minSdk'] as num?)?.toInt(),
  );

  /// Base APK first, splits after it in a stable order.
  static List<String> orderApks(Iterable<String> names) {
    final list = [...names]..sort();
    if (list.remove(baseApk)) list.insert(0, baseApk);
    return list;
  }
}

/// A received or backed-up app on disk: `<dir>/app.json`, the APKs and the
/// icon. [complete] is false while some APK named in the manifest is
/// missing (an interrupted transfer); such an app must not be installed.
class AppBundle {
  const AppBundle({required this.dir, required this.manifest, required this.apkPaths, this.iconPath});

  final String dir;
  final AppManifest manifest;

  /// Absolute paths, base APK first.
  final List<String> apkPaths;
  final String? iconPath;

  String get packageName => manifest.packageName;
  bool get complete => apkPaths.length == manifest.apks.length && apkPaths.isNotEmpty;

  /// Package of a file in the `apps` category (`com.foo/base.apk` -> `com.foo`).
  static String? packageOf(String relPath) {
    final parts = relPath.split('/');
    return parts.length >= 2 && parts.first.isNotEmpty ? parts.first : null;
  }

  /// Every app in [appsDir] (`<appsDir>/<package>/...`), by label. Folders
  /// without a readable manifest are skipped.
  static Future<List<AppBundle>> scan(String appsDir) async {
    final root = Directory(appsDir);
    if (!await root.exists()) return const [];
    final bundles = <AppBundle>[];
    await for (final e in root.list(followLinks: false)) {
      if (e is! Directory) continue;
      final b = await load(e.path);
      if (b != null) bundles.add(b);
    }
    bundles.sort((a, b) => a.manifest.label.toLowerCase().compareTo(b.manifest.label.toLowerCase()));
    return bundles;
  }

  static Future<AppBundle?> load(String dir) async {
    final json = File(p.join(dir, AppManifest.fileName));
    if (!await json.exists()) return null;
    final AppManifest manifest;
    try {
      manifest = AppManifest.fromJson((jsonDecode(await json.readAsString()) as Map).cast());
    } catch (_) {
      return null;
    }
    final apks = [
      for (final name in AppManifest.orderApks(manifest.apks))
        if (await File(p.join(dir, name)).exists()) p.join(dir, name),
    ];
    final icon = File(p.join(dir, AppManifest.iconFileName));
    return AppBundle(dir: dir, manifest: manifest, apkPaths: apks, iconPath: await icon.exists() ? icon.path : null);
  }
}
