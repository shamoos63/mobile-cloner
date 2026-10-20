import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart' hide AndroidPermission;

import '../platform/android_bridge.dart';

/// Photos and videos from MediaStore, sent at full original quality with
/// their folder (e.g. `DCIM/Camera`) and capture date.
class MediaSource {
  MediaSource(this.bridge);

  final AndroidBridge bridge;

  Future<bool> requestAccess() async {
    final info = await bridge.deviceInfo();
    final granted = await bridge.requestPermissions(AndroidPermission.media(info.sdkInt));
    if (granted.values.every((g) => g)) return true;
    final state = await PhotoManager.requestPermissionExtend();
    return state.hasAccess;
  }

  Future<int> count(ContentCategory category) => PhotoManager.getAssetCount(type: _type(category));

  RequestType _type(ContentCategory c) => c == ContentCategory.videos ? RequestType.video : RequestType.image;

  /// Builds the outgoing list. [onProgress] reports how many assets were
  /// scanned, since big libraries take a while.
  Future<List<OutgoingFile>> files(ContentCategory category, {void Function(int scanned, int total)? onProgress}) async {
    final info = await bridge.deviceInfo();
    final type = _type(category);
    final total = await PhotoManager.getAssetCount(type: type);
    final result = <OutgoingFile>[];
    const page = 500;
    for (var start = 0; start < total; start += page) {
      final assets = await PhotoManager.getAssetListRange(start: start, end: start + page, type: type);
      for (final asset in assets) {
        final file = await _fileFor(asset, info.storageRoot);
        if (file == null) continue;
        final relDir = (asset.relativePath ?? '').replaceAll(RegExp(r'/+$'), '');
        final name = asset.title ?? p.basename(file.path);
        result.add(OutgoingFile.fromFile(
          file,
          category: category,
          relPath: relDir.isEmpty ? name : '$relDir/$name',
          takenAt: asset.createDateTime,
        ));
      }
      onProgress?.call(start + assets.length, total);
    }
    return result;
  }

  /// Reads the original file in place when the path is readable (all
  /// supported Android versions with media permission), so large videos
  /// are not copied to the cache first.
  Future<File?> _fileFor(AssetEntity asset, String root) async {
    final rel = asset.relativePath, title = asset.title;
    if (rel != null && title != null) {
      final direct = File(p.join(root, rel, title));
      if (await direct.exists()) return direct;
    }
    return asset.originFile;
  }
}
