import 'dart:convert';
import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/android_bridge.dart';

/// Installed apps as files to send: per app its APKs (base + splits, read
/// straight from where Android installed them), `app.json` and `icon.png`,
/// all under `apps/<package>/`. App data is not included: Android keeps it
/// private to each app.
class AppsSource {
  AppsSource(this.bridge, {this.stagingDir});

  final AndroidBridge bridge;

  /// Where app.json and icon.png are written; the app's temp folder if null.
  final String? stagingDir;
  static final _icons = <String, Uint8List?>{};

  static void _log(String message) => debugPrint('HKCloner.apps: $message');

  /// User apps by name. Slow on phones with many apps: called when Apps is ticked.
  Future<List<InstalledApp>> list() async =>
      (await bridge.listApps())..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  /// Launcher icon, cached for the session. Never fails or hangs: an app
  /// without an icon still moves.
  Future<Uint8List?> icon(String package) async {
    if (_icons.containsKey(package)) return _icons[package];
    try {
      return _icons[package] = await bridge.appIcon(package).timeout(const Duration(seconds: 3));
    } catch (e) {
      _log('no icon for $package: $e');
      return _icons[package] = null;
    }
  }

  Future<List<OutgoingFile>> files(Iterable<InstalledApp> apps) async => (await prepare(apps)).files;

  /// The files to send for [apps], plus the labels of apps whose APKs could
  /// not be read (they are left out, and the user is told).
  Future<({List<OutgoingFile> files, List<String> skipped})> prepare(Iterable<InstalledApp> apps) async {
    final staging = p.join(stagingDir ?? (await getTemporaryDirectory()).path, 'apps');
    final files = <OutgoingFile>[];
    final skipped = <String>[];
    for (final app in apps) {
      final names = <String>[];
      final apks = <OutgoingFile>[];
      try {
        if (!app.readable || app.apks.isEmpty) throw const FileSystemException('APK not readable');
        for (final (i, path) in app.apks.indexed) {
          // Android names the base APK base.apk; keep that name for the receiver.
          final name = i == 0 ? AppManifest.baseApk : p.basename(path);
          final file = File(path);
          // Opening it proves Dart may read it (stat alone doesn't).
          (await file.open()).closeSync();
          names.add(name);
          apks.add(OutgoingFile.fromFile(file, category: ContentCategory.apps, relPath: '${app.packageName}/$name'));
        }
      } catch (e) {
        _log('skipping ${app.packageName}: $e');
        skipped.add(app.label);
        continue;
      }
      final dir = Directory(p.join(staging, app.packageName))..createSync(recursive: true);
      // Same timestamps as the base APK: stable file ids across restarts.
      final stamp = File(app.apks.first).lastModifiedSync();
      final manifest = File(p.join(dir.path, AppManifest.fileName))
        ..writeAsStringSync(jsonEncode(AppManifest(
          packageName: app.packageName,
          label: app.label,
          versionName: app.versionName,
          versionCode: app.versionCode,
          apks: names,
          sizeBytes: app.sizeBytes,
          minSdk: app.minSdk,
        ).toJson()))
        ..setLastModifiedSync(stamp);
      files.add(OutgoingFile.fromFile(manifest, category: ContentCategory.apps, relPath: '${app.packageName}/${AppManifest.fileName}'));
      final png = await icon(app.packageName);
      if (png != null) {
        final iconFile = File(p.join(dir.path, AppManifest.iconFileName))
          ..writeAsBytesSync(png)
          ..setLastModifiedSync(stamp);
        files.add(OutgoingFile.fromFile(iconFile,
            category: ContentCategory.apps, relPath: '${app.packageName}/${AppManifest.iconFileName}'));
      }
      files.addAll(apks);
      _log('${app.packageName}: ${apks.length} APK(s), ${app.sizeBytes} bytes');
    }
    _log('prepared ${files.length} files for ${apps.length - skipped.length} apps, skipped ${skipped.length}');
    return (files: files, skipped: skipped);
  }

  /// After a restart: the files for the packages a checkpoint recorded.
  Future<List<OutgoingFile>> filesFor(Iterable<String> packages) async {
    final wanted = packages.toSet();
    return files((await list()).where((a) => wanted.contains(a.packageName)));
  }
}
