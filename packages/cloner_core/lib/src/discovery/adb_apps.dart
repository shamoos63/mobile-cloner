import 'dart:io';

import 'adb_bridge.dart';

/// A third-party app on a phone, as `adb` sees it: no label or icon (only
/// the phone app knows those), but enough to pull and reinstall it.
class AdbApp {
  const AdbApp({required this.packageName, required this.apks, required this.sizeBytes, this.versionName = '', this.versionCode = 0});

  final String packageName;

  /// Paths on the phone, base APK first.
  final List<String> apks;
  final int sizeBytes;
  final String versionName;
  final int versionCode;
}

/// Parsers for `pm` / `cmd package` output. Kept separate so tests can
/// feed them real output from different Android versions.
abstract final class PmOutput {
  /// `pm list packages -3` (with or without `-f`): package names.
  static List<String> packages(String out) => [
    for (final line in out.split('\n'))
      if (line.trim().startsWith('package:'))
        // -f prints package:/data/app/.../base.apk=com.foo; the name is after the last '='.
        line.trim().substring('package:'.length).split('=').last.trim(),
  ]..removeWhere((p) => p.isEmpty);

  /// `pm path <package>`: APK paths, base first.
  static List<String> paths(String out) {
    final list = [
      for (final line in out.split('\n'))
        if (line.trim().startsWith('package:')) line.trim().substring('package:'.length),
    ];
    final base = list.indexWhere((p) => p.endsWith('/base.apk'));
    if (base > 0) list.insert(0, list.removeAt(base));
    return list;
  }

  /// `cmd package query-activities ... LAUNCHER`: packages with a launcher
  /// icon. Brief output is `com.foo/.Main`; the long form has
  /// `packageName=com.foo` lines. Null when the command isn't supported.
  static Set<String>? launcherPackages(String out) {
    if (out.contains('Unknown command') || out.contains('Error')) return null;
    final found = <String>{
      for (final m in RegExp(r'^\s*([A-Za-z][\w.]*)/[\w.$]+\s*$', multiLine: true).allMatches(out)) m.group(1)!,
      for (final m in RegExp(r'packageName=([A-Za-z][\w.]*)').allMatches(out)) m.group(1)!,
    };
    return found.isEmpty ? null : found;
  }

  /// `stat -c %s <paths...>`: total bytes.
  static int totalSize(String out) =>
      out.split('\n').map((l) => int.tryParse(l.trim()) ?? 0).fold(0, (a, b) => a + b);

  /// versionName from `dumpsys package <package>`.
  static String versionName(String dumpsys) => RegExp(r'versionName=(\S+)').firstMatch(dumpsys)?.group(1) ?? '';
}

extension AdbApps on AdbBridge {
  /// User-installed apps that have a launcher icon (the same rule as the
  /// phone app), without HK Cloner itself.
  Future<List<AdbApp>> thirdPartyApps(String serial, {String? exclude}) async {
    final listed = await _shell(serial, ['pm', 'list', 'packages', '-3', '--user', '0']);
    var packages = PmOutput.packages(listed);
    if (packages.isEmpty) packages = PmOutput.packages(await _shell(serial, ['pm', 'list', 'packages', '-3']));
    final launchers = PmOutput.launcherPackages(await _shell(serial, [
      'cmd', 'package', 'query-activities', '--brief', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', //
    ]));
    final apps = <AdbApp>[];
    for (final pkg in packages) {
      if (pkg == exclude || (launchers != null && !launchers.contains(pkg))) continue;
      final paths = PmOutput.paths(await _shell(serial, ['pm', 'path', pkg]));
      if (paths.isEmpty) continue;
      final size = PmOutput.totalSize(await _shell(serial, ['stat', '-c', '%s', ...paths]));
      final dump = await _shell(serial, ['dumpsys', 'package', pkg]);
      apps.add(AdbApp(
        packageName: pkg,
        apks: paths,
        sizeBytes: size,
        versionName: PmOutput.versionName(dump),
        versionCode: int.tryParse(RegExp(r'versionCode=(\d+)').firstMatch(dump)?.group(1) ?? '') ?? 0,
      ));
    }
    apps.sort((a, b) => a.packageName.compareTo(b.packageName));
    return apps;
  }

  /// Copies [remote] from the phone to [local].
  Future<void> pull(String serial, String remote, String local) async {
    final r = await Process.run(adbPath, ['-s', serial, 'pull', remote, local]);
    if (r.exitCode != 0) throw AdbException('adb pull $remote: ${r.stderr}');
  }

  Future<String> _shell(String serial, List<String> args) async {
    final r = await Process.run(adbPath, ['-s', serial, 'shell', ...args]);
    return '${r.stdout}';
  }
}
