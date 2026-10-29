import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/foundation.dart';

import '../platform/android_bridge.dart';

enum AppInstallState {
  waiting,
  installing,
  installed,

  /// The same or a newer version is already on this phone: skipped.
  alreadyInstalled,
  canceled,
  failed,

  /// The app needs a newer Android than this phone has.
  needsNewerAndroid,

  /// Some APK didn't arrive (interrupted transfer): not installable.
  incomplete,
}

class AppInstallItem {
  AppInstallItem(this.bundle);
  final AppBundle bundle;
  AppInstallState state = AppInstallState.waiting;

  /// Android's reason when [state] is failed.
  String? detail;

  bool get installable => state == AppInstallState.waiting || state == AppInstallState.canceled || state == AppInstallState.failed;
}

/// Received apps waiting to be installed. Nothing installs by itself: the
/// user taps Install (one) or Install all, and Android asks to confirm each.
class AppInstallQueue extends ChangeNotifier {
  AppInstallQueue({required this.install, required this.installedVersion, required this.sdkInt, required List<AppBundle> bundles})
    : items = [for (final b in bundles) AppInstallItem(b)];

  factory AppInstallQueue.forPhone(AndroidBridge bridge, int sdkInt, List<AppBundle> bundles) => AppInstallQueue(
    install: bridge.installApp,
    installedVersion: bridge.installedAppVersion,
    sdkInt: sdkInt,
    bundles: bundles,
  );

  final Future<({AppInstallResult result, String? detail})> Function(List<String> apks, {String? package, int versionCode})
  install;
  final Future<int?> Function(String package) installedVersion;
  final int sdkInt;
  final List<AppInstallItem> items;
  bool running = false;

  /// Marks what can't or needn't be installed, before the list is shown.
  Future<void> check() async {
    for (final item in items) {
      final m = item.bundle.manifest;
      if (!item.bundle.complete) {
        item.state = AppInstallState.incomplete;
      } else if (m.minSdk != null && m.minSdk! > sdkInt) {
        item.state = AppInstallState.needsNewerAndroid;
      } else {
        final have = await installedVersion(m.packageName);
        if (have != null && have >= m.versionCode) item.state = AppInstallState.alreadyInstalled;
      }
    }
    notifyListeners();
  }

  Future<void> installOne(AppInstallItem item) async {
    if (!item.installable || running) return;
    running = true;
    try {
      await _install(item);
    } finally {
      running = false;
      notifyListeners();
    }
  }

  /// One after another; Android shows its confirm screen for each.
  Future<void> installAll() async {
    if (running) return;
    running = true;
    try {
      for (final item in items.where((i) => i.state == AppInstallState.waiting).toList()) {
        await _install(item);
      }
    } finally {
      running = false;
      notifyListeners();
    }
  }

  Future<void> _install(AppInstallItem item) async {
    item
      ..state = AppInstallState.installing
      ..detail = null;
    notifyListeners();
    try {
      final m = item.bundle.manifest;
      final r = await install(item.bundle.apkPaths, package: m.packageName, versionCode: m.versionCode);
      item.state = switch (r.result) {
        AppInstallResult.installed => AppInstallState.installed,
        AppInstallResult.canceled => AppInstallState.canceled,
        AppInstallResult.failed => AppInstallState.failed,
      };
      item.detail = r.detail;
    } catch (e) {
      item
        ..state = AppInstallState.failed
        ..detail = '$e';
    }
    notifyListeners();
  }
}
