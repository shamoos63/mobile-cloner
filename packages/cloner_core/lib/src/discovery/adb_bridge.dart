import 'dart:io';

import '../protocol/constants.dart';

/// Phone-to-computer over USB using ADB port mapping (USB debugging on).
///
/// - `adb reverse`: the phone reaches the computer's server at
///   `127.0.0.1:[phoneToPcPort]` (used for backups, phone sends).
/// - `adb forward`: the computer reaches the phone's server at
///   `127.0.0.1:[pcToPhonePort]` (used for restores, computer sends).
///
/// Separate ports avoid clashing with each side's own server on 53317.
/// Both map onto the plain-HTTP [loopbackPort] listener: the cable needs no
/// TLS, and skipping it roughly doubles throughput on phone CPUs. Connect
/// with `https: false`.
class AdbBridge {
  AdbBridge({this.adbPath = 'adb', this.devicePort = loopbackPort, this.desktopPort = loopbackPort});

  final String adbPath;

  /// Finds adb: next to [besides] (a bundled copy), the Android SDK, then
  /// Homebrew and PATH. GUI apps on macOS don't inherit the shell's PATH,
  /// so plain `adb` is not enough there.
  static String locate({String? besides}) {
    final env = Platform.environment;
    final exe = Platform.isWindows ? 'adb.exe' : 'adb';
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
    final candidates = [
      if (besides != null) '$besides/$exe',
      if (besides != null) '$besides/platform-tools/$exe',
      for (final v in ['ANDROID_HOME', 'ANDROID_SDK_ROOT'])
        if (env[v] != null) '${env[v]}/platform-tools/$exe',
      if (Platform.isMacOS) '$home/Library/Android/sdk/platform-tools/adb',
      if (Platform.isWindows) '${env['LOCALAPPDATA']}\\Android\\Sdk\\platform-tools\\adb.exe',
      if (Platform.isLinux) '$home/Android/Sdk/platform-tools/adb',
      '/opt/homebrew/bin/adb',
      '/usr/local/bin/adb',
      '/usr/bin/adb',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return exe;
  }

  final int devicePort;
  final int desktopPort;

  static const phoneToPcPort = 53319;
  static const pcToPhonePort = 53318;

  /// Serial numbers of attached devices in `device` state.
  Future<List<String>> devices() async {
    final r = await Process.run(adbPath, ['devices']);
    if (r.exitCode != 0) throw AdbException('${r.stderr}');
    return [
      for (final line in (r.stdout as String).split('\n').skip(1))
        if (line.trim().endsWith('\tdevice')) line.split('\t').first.trim(),
    ];
  }

  /// Every attached device with its state: `device`, `unauthorized` (the
  /// phone still shows the "Allow USB debugging?" prompt) or `offline`.
  Future<List<AdbDevice>> list() async {
    final r = await Process.run(adbPath, ['devices', '-l']);
    if (r.exitCode != 0) throw AdbException('${r.stderr}');
    return [
      for (final line in (r.stdout as String).split('\n').skip(1))
        if (line.trim().isNotEmpty && !line.startsWith('*')) AdbDevice.parse(line),
    ];
  }

  /// Installed versionCode of [package], or null when it isn't installed.
  Future<int?> installedVersion(String serial, String package) async {
    final r = await Process.run(adbPath, ['-s', serial, 'shell', 'dumpsys', 'package', package]);
    final m = RegExp(r'versionCode=(\d+)').firstMatch('${r.stdout}');
    return m == null ? null : int.parse(m.group(1)!);
  }

  /// `adb install -r` (replace, keep data). Android 6 has no `-g`, so
  /// permissions are still asked in the app.
  Future<void> install(String serial, String apkPath) => _run(['-s', serial, 'install', '-r', apkPath]);

  /// Opens the app's launcher activity; [extras] become string intent extras
  /// (the app reads `cloner_link=adb` to link to this computer by itself).
  Future<void> launch(String serial, String component, {Map<String, String> extras = const {}}) => _run([
    '-s', serial, 'shell', 'am', 'start', '-n', component, //
    for (final e in extras.entries) ...['--es', e.key, e.value],
  ]);

  /// Makes sure [package] is on the phone at [versionCode] or newer
  /// (installing [apkPath] otherwise), then opens it linked to us.
  Future<AppSetupResult> ensureAppRunning(
    String serial, {
    required String package,
    required String activity,
    required int versionCode,
    String? apkPath,
  }) async {
    final installed = await installedVersion(serial, package);
    var result = AppSetupResult.alreadyInstalled;
    if (installed == null || installed < versionCode) {
      if (apkPath == null || !File(apkPath).existsSync()) {
        return installed == null ? AppSetupResult.missingApk : AppSetupResult.outdatedNoApk;
      }
      await install(serial, apkPath);
      result = installed == null ? AppSetupResult.installed : AppSetupResult.updated;
    }
    await connect(serial);
    await launch(serial, '$package/$activity', extras: const {'cloner_link': 'adb'});
    return result;
  }

  Future<void> connect(String serial) async {
    await _run(['-s', serial, 'reverse', 'tcp:$phoneToPcPort', 'tcp:$desktopPort']);
    await _run(['-s', serial, 'forward', 'tcp:$pcToPhonePort', 'tcp:$devicePort']);
  }

  Future<void> disconnect(String serial) async {
    await Process.run(adbPath, ['-s', serial, 'reverse', '--remove', 'tcp:$phoneToPcPort']);
    await Process.run(adbPath, ['-s', serial, 'forward', '--remove', 'tcp:$pcToPhonePort']);
  }

  Future<void> _run(List<String> args) async {
    final r = await Process.run(adbPath, args);
    if (r.exitCode != 0) throw AdbException('adb ${args.join(' ')}: ${r.stderr}');
  }
}

class AdbDevice {
  const AdbDevice(this.serial, this.state, {this.model});

  /// One line of `adb devices -l`.
  factory AdbDevice.parse(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
    final model = RegExp(r'model:(\S+)').firstMatch(line)?.group(1)?.replaceAll('_', ' ');
    return AdbDevice(parts.first, parts.length > 1 ? parts[1] : 'unknown', model: model);
  }

  final String serial;
  final String state;
  final String? model;

  bool get ready => state == 'device';
  bool get unauthorized => state == 'unauthorized';
}

enum AppSetupResult {
  alreadyInstalled,
  installed,
  updated,

  /// Not installed and no APK ships with this desktop build.
  missingApk,

  /// Installed but older, and no APK to update with; it was still opened.
  outdatedNoApk;

  bool get ok => this != missingApk;
}

class AdbException implements Exception {
  AdbException(this.message);
  final String message;
  @override
  String toString() => 'AdbException: $message';
}
