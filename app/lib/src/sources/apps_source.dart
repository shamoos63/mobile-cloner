import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/android_bridge.dart';

/// Installed apps as files to send: per app its APKs (base + splits, read
/// straight from where Android installed them), `app.json` and `icon.png`,
/// all under `apps/<package>/`. App data is not included: Android keeps it
/// private to each app.
class AppsSource {
  AppsSource(this.bridge);

  final AndroidBridge bridge;
  static final _icons = <String, Uint8List?>{};

  /// User apps by name. Slow on phones with many apps: called when Apps is ticked.
  Future<List<InstalledApp>> list() async =>
      (await bridge.listApps())..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  /// Launcher icon, cached for the session.
  Future<Uint8List?> icon(String package) async {
    if (_icons.containsKey(package)) return _icons[package];
    return _icons[package] = await bridge.appIcon(package);
  }

  Future<List<OutgoingFile>> files(Iterable<InstalledApp> apps) async {
    final staging = p.join((await getTemporaryDirectory()).path, 'apps');
    final files = <OutgoingFile>[];
    for (final app in apps.where((a) => a.readable)) {
      final names = <String>[];
      final apks = <OutgoingFile>[];
      for (final (i, path) in app.apks.indexed) {
        // Android names the base APK base.apk; keep that name for the receiver.
        final name = i == 0 ? AppManifest.baseApk : p.basename(path);
        names.add(name);
        apks.add(OutgoingFile.fromFile(File(path), category: ContentCategory.apps, relPath: '${app.packageName}/$name'));
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
    }
    return files;
  }

  /// After a restart: the files for the packages a checkpoint recorded.
  Future<List<OutgoingFile>> filesFor(Iterable<String> packages) async {
    final wanted = packages.toSet();
    return files((await list()).where((a) => wanted.contains(a.packageName)));
  }
}
