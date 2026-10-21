import 'dart:async';

import 'package:flutter/services.dart';

class AndroidDeviceInfo {
  const AndroidDeviceInfo({
    required this.sdkInt,
    required this.release,
    required this.manufacturer,
    required this.model,
    required this.storageRoot,
  });

  final int sdkInt;
  final String release;
  final String manufacturer;
  final String model;

  /// `/storage/emulated/0` on most phones.
  final String storageRoot;
}

class SafTree {
  const SafTree({required this.uri, required this.basePath, this.writable = true});

  final String uri;

  /// Folder the grant covers, relative to shared storage (`Android/media`).
  final String basePath;
  final bool writable;

  /// Whether [path] (relative to shared storage) is inside this tree.
  bool covers(String path) => basePath.isEmpty || path == basePath || path.startsWith('$basePath/');

  /// [path] relative to the tree root.
  String relative(String path) => basePath.isEmpty ? path : path.substring(basePath.length).replaceFirst(RegExp('^/'), '');
}

class SafEntry {
  const SafEntry(this.rel, this.size, this.modified, this.uri);
  final String rel;
  final int size;
  final DateTime modified;
  final String uri;
}

/// Dart side of `AndroidBridge.kt`.
class AndroidBridge {
  AndroidBridge._();
  static final instance = AndroidBridge._();

  static const _ch = MethodChannel('mobile_cloner/android');

  AndroidDeviceInfo? _info;

  /// `cloner_link` extra of the launch intent, read once (`adb` when the
  /// computer opened us over USB).
  Future<String?> takeLaunchLink() => _ch.invokeMethod<String>('takeLaunchLink');

  Future<AndroidDeviceInfo> deviceInfo() async {
    if (_info != null) return _info!;
    final m = (await _ch.invokeMapMethod<String, Object?>('deviceInfo'))!;
    return _info = AndroidDeviceInfo(
      sdkInt: m['sdkInt'] as int,
      release: m['release'] as String,
      manufacturer: m['manufacturer'] as String,
      model: m['model'] as String,
      storageRoot: m['storageRoot'] as String,
    );
  }

  Future<({int? level, bool charging})> battery() async {
    final m = (await _ch.invokeMapMethod<String, Object?>('battery'))!;
    return (level: m['level'] as int?, charging: m['charging'] as bool? ?? false);
  }

  Future<int> freeBytes() async => (await _ch.invokeMethod<int>('freeBytes'))!;

  /// Requests runtime permissions; returns name -> granted.
  Future<Map<String, bool>> requestPermissions(List<String> names) async =>
      (await _ch.invokeMapMethod<String, bool>('requestPermissions', {'permissions': names}))!;

  Future<bool> hasAllFilesAccess() async => (await _ch.invokeMethod<bool>('hasAllFilesAccess'))!;
  Future<void> requestAllFilesAccess() => _ch.invokeMethod('requestAllFilesAccess');

  Future<bool> isPackageInstalled(String pkg) async =>
      (await _ch.invokeMethod<bool>('isPackageInstalled', {'package': pkg}))!;
  Future<bool> launchPackage(String pkg) async =>
      (await _ch.invokeMethod<bool>('launchPackage', {'package': pkg}))!;

  Future<void> openTetherSettings() => _ch.invokeMethod('openTetherSettings');
  Future<void> openWifiSettings() => _ch.invokeMethod('openWifiSettings');


  /// Local-only hotspot (Android 8+). Null on older versions.
  Future<({String ssid, String? password})?> startLocalHotspot() async {
    final m = await _ch.invokeMapMethod<String, Object?>('startLocalHotspot');
    if (m == null || m['ssid'] == null) return null;
    return (ssid: (m['ssid'] as String).replaceAll('"', ''), password: (m['password'] as String?)?.replaceAll('"', ''));
  }

  Future<void> stopLocalHotspot() => _ch.invokeMethod('stopLocalHotspot');

  Future<bool> joinWifi(String ssid, String? password) async =>
      (await _ch.invokeMethod<bool>('joinWifi', {'ssid': ssid, 'password': password})) ?? false;

  Future<void> keepScreenOn(bool on) => _ch.invokeMethod('keepScreenOn', {'on': on});

  Future<void> serviceUpdate({required String title, required String text, int progress = -1}) =>
      _ch.invokeMethod('serviceUpdate', {'title': title, 'text': text, 'progress': progress});
  Future<void> serviceStop() => _ch.invokeMethod('serviceStop');
  Future<void> alert(String title, String text) => _ch.invokeMethod('alert', {'title': title, 'text': text});

  Future<void> scanMedia(List<String> paths) => _ch.invokeMethod('scanMedia', {'paths': paths});
  Future<int> exportContacts(String path) async => (await _ch.invokeMethod<int>('exportContacts', {'path': path}))!;
  Future<bool> importVcf(String path) async => (await _ch.invokeMethod<bool>('importVcf', {'path': path}))!;

  // --- Storage Access Framework ---

  Future<SafTree?> pickTree({String? initialPath}) async {
    final m = await _ch.invokeMapMethod<String, Object?>('safPickTree', {'initialPath': initialPath});
    if (m == null) return null;
    return SafTree(uri: m['uri'] as String, basePath: m['basePath'] as String);
  }

  Future<List<SafTree>> trees() async {
    final list = await _ch.invokeListMethod<Map>('safTrees') ?? const [];
    return [
      for (final m in list)
        SafTree(uri: m['uri'] as String, basePath: m['basePath'] as String, writable: m['writable'] as bool? ?? false),
    ];
  }

  Future<SafTree?> treeCovering(String path) async {
    final all = await trees();
    SafTree? best;
    for (final t in all) {
      if (t.covers(path) && (best == null || t.basePath.length > best.basePath.length)) best = t;
    }
    return best;
  }

  Future<List<SafEntry>> list(SafTree tree, {String? sub}) async {
    final list = await _ch.invokeListMethod<Map>('safList', {'tree': tree.uri, 'sub': sub}) ?? const [];
    return [
      for (final m in list)
        SafEntry(
          m['rel'] as String,
          (m['size'] as num).toInt(),
          DateTime.fromMillisecondsSinceEpoch((m['modified'] as num).toInt()),
          m['uri'] as String,
        ),
    ];
  }

  /// Streams a document in 1 MB chunks starting at [offset].
  Stream<List<int>> read(String uri, {int offset = 0, int chunk = 1 << 20}) async* {
    final handle = (await _ch.invokeMethod<int>('safOpenRead', {'uri': uri, 'offset': offset}))!;
    try {
      while (true) {
        final bytes = await _ch.invokeMethod<Uint8List>('safRead', {'handle': handle, 'max': chunk});
        if (bytes == null) break;
        yield bytes;
      }
    } finally {
      await _ch.invokeMethod('safCloseRead', {'handle': handle});
    }
  }

  Future<int> partialSize(SafTree tree, String rel) async =>
      (await _ch.invokeMethod<int>('safPartialSize', {'tree': tree.uri, 'rel': rel})) ?? 0;

  Future<int> openWrite(SafTree tree, String rel, {required bool append}) async =>
      (await _ch.invokeMethod<int>('safOpenWrite', {'tree': tree.uri, 'rel': rel, 'append': append}))!;

  Future<void> write(int handle, Uint8List bytes) => _ch.invokeMethod('safWrite', {'handle': handle, 'bytes': bytes});
  Future<void> closeWrite(int handle) => _ch.invokeMethod('safCloseWrite', {'handle': handle});
  Future<void> commit(SafTree tree, String rel) => _ch.invokeMethod('safCommit', {'tree': tree.uri, 'rel': rel});
}

/// Android permission names used by the app.
abstract final class AndroidPermission {
  static const readExternal = 'android.permission.READ_EXTERNAL_STORAGE';
  static const writeExternal = 'android.permission.WRITE_EXTERNAL_STORAGE';
  static const readImages = 'android.permission.READ_MEDIA_IMAGES';
  static const readVideo = 'android.permission.READ_MEDIA_VIDEO';
  static const readContacts = 'android.permission.READ_CONTACTS';
  static const writeContacts = 'android.permission.WRITE_CONTACTS';
  static const camera = 'android.permission.CAMERA';
  static const fineLocation = 'android.permission.ACCESS_FINE_LOCATION';
  static const nearbyWifi = 'android.permission.NEARBY_WIFI_DEVICES';
  static const notifications = 'android.permission.POST_NOTIFICATIONS';

  static List<String> media(int sdkInt) => sdkInt >= 33
      ? [readImages, readVideo]
      : [readExternal, if (sdkInt <= 29) writeExternal];

  static List<String> hotspot(int sdkInt) => [fineLocation, if (sdkInt >= 33) nearbyWifi];
}
