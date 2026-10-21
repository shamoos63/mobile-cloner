import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/android_bridge.dart';

/// Home and lock screen wallpapers as image files (`home.jpg`, `lock.jpg`).
class WallpaperSource {
  WallpaperSource(this.bridge);

  final AndroidBridge bridge;

  /// No files and [denied] set when Android needs All-files access to
  /// hand the wallpaper out (API 33+).
  Future<({List<OutgoingFile> files, bool denied})> export() async {
    final dir = p.join((await getTemporaryDirectory()).path, 'wallpaper');
    final r = await bridge.exportWallpapers(dir);
    return (
      files: [
        for (final path in [r.home, r.lock])
          if (path != null)
            OutgoingFile.fromFile(File(path), category: ContentCategory.wallpaper, relPath: p.basename(path)),
      ],
      denied: r.denied,
    );
  }
}
