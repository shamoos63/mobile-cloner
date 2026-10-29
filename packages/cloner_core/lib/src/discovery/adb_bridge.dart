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

  /// Whether [package] is on the phone at [versionCode] or newer.
  Future<PhoneApp> appState(String serial, String package, {required int versionCode}) async {
    final installed = await installedVersion(serial, package);
    return PhoneApp(installed, versionCode);
  }

  /// `adb install -r` (replace, keep data). Android 6 has no `-g`, so
  /// permissions are still asked in the app. Throws [AdbInstallException]
  /// with the reason Android gave.
  Future<void> install(String serial, String apkPath) => installApp(serial, [apkPath]);

  /// Installs one app from its base APK plus split APKs (base first), with
  /// `install-multiple` when there are splits. Replaces an older version
  /// and keeps its data.
  Future<void> installApp(String serial, List<String> apks) async {
    if (apks.isEmpty) throw ArgumentError('No APKs');
    final args = apks.length == 1
        ? ['-s', serial, 'install', '-r', apks.first]
        : ['-s', serial, 'install-multiple', '-r', ...apks];
    final r = await Process.run(adbPath, args);
    final out = '${r.stdout}\n${r.stderr}';
    if (r.exitCode != 0 || out.contains('Failure [')) throw AdbInstallException.parse(out);
  }

  /// Removes [package] and its data from the phone.
  Future<void> uninstall(String serial, String package) => _run(['-s', serial, 'uninstall', package]);

  /// Opens the app's launcher activity; [extras] become string intent extras
  /// (the app reads `cloner_link=adb` to link to this computer by itself).
  Future<void> launch(String serial, String component, {Map<String, String> extras = const {}}) => _run([
    '-s', serial, 'shell', 'am', 'start', '-n', component, //
    for (final e in extras.entries) ...['--es', e.key, e.value],
  ]);

  /// Maps the ports and opens [package] linked to this computer.
  Future<void> openLinked(String serial, {required String package, required String activity}) async {
    await connect(serial);
    await launch(serial, '$package/$activity', extras: const {'cloner_link': 'adb'});
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

/// HK Cloner on a phone, compared with the version this computer ships.
class PhoneApp {
  const PhoneApp(this.installedVersion, this.wantedVersion);

  /// Installed versionCode; null when the app isn't on the phone.
  final int? installedVersion;
  final int wantedVersion;

  bool get missing => installedVersion == null;
  bool get outdated => installedVersion != null && installedVersion! < wantedVersion;
  bool get ready => !missing && !outdated;
}

/// The phone APK shipped with a desktop build.
///
/// One location on every platform, filled by `tool/bundle_apk.sh` (or
/// `tool/bundle_apk.ps1`) locally and by CI:
/// - macOS: `HK Cloner.app/Contents/Resources/data/hk-cloner.apk`
/// - Windows and Linux: `<folder of the exe>/data/hk-cloner.apk`
abstract final class PhoneApk {
  static const fileName = 'hk-cloner.apk';
  static const folder = 'data';

  /// Overrides every other location (development).
  static const envVar = 'HK_CLONER_APK';

  /// `flutter build apk` output, found from a development build of the
  /// desktop app inside the same checkout.
  static const devBuild = 'build/app/outputs/flutter-apk/app-release.apk';

  /// The APK to install: [envVar], then the bundled copy in [bundleDir]
  /// (the app's resources folder), then the copy older builds put next to
  /// the exe, then the Android build output of a checkout [bundleDir] is in.
  static String? locate(String bundleDir, {Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final sep = Platform.pathSeparator;
    final candidates = [
      env[envVar],
      '$bundleDir$sep$folder$sep$fileName',
      '$bundleDir${sep}mobile-cloner.apk',
      ..._devCandidates(bundleDir),
    ];
    for (final c in candidates) {
      if (c != null && c.isNotEmpty && File(c).existsSync()) return c;
    }
    return null;
  }

  /// `<dir>/build/app/outputs/...` for [bundleDir] and each parent: a desktop
  /// build lives under `app/build/`, so one parent holds the Android output.
  static Iterable<String> _devCandidates(String bundleDir) sync* {
    var dir = Directory(bundleDir).absolute;
    for (var i = 0; i < 10; i++) {
      yield '${dir.path}${Platform.pathSeparator}${devBuild.replaceAll('/', Platform.pathSeparator)}';
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  }
}

/// Why `adb install` failed, from the `Failure [CODE: ...]` line.
enum InstallFailure {
  /// A copy signed with a different key is installed (e.g. a Play or debug
  /// build). Only uninstalling first helps, which deletes the app's data.
  updateIncompatible,

  /// The phone has a newer version than this APK.
  downgrade,

  /// The phone refused installs over USB (Xiaomi "Install via USB", work
  /// profiles, or the user tapped Block on the phone's prompt).
  blocked,

  /// The phone is still asking "Allow USB debugging?" or went offline.
  notAuthorized,

  noSpace,
  invalidApk,
  other,
}

class AdbInstallException implements Exception {
  AdbInstallException(this.failure, this.detail);

  factory AdbInstallException.parse(String output) {
    final code = RegExp(r'(INSTALL_[A-Z_]+)').firstMatch(output)?.group(1) ?? '';
    final failure = switch (code) {
      'INSTALL_FAILED_UPDATE_INCOMPATIBLE' ||
      'INSTALL_FAILED_SHARED_USER_INCOMPATIBLE' => InstallFailure.updateIncompatible,
      'INSTALL_FAILED_VERSION_DOWNGRADE' => InstallFailure.downgrade,
      'INSTALL_FAILED_USER_RESTRICTED' ||
      'INSTALL_FAILED_ABORTED' ||
      'INSTALL_FAILED_VERIFICATION_FAILURE' => InstallFailure.blocked,
      'INSTALL_FAILED_INSUFFICIENT_STORAGE' => InstallFailure.noSpace,
      'INSTALL_PARSE_FAILED_NOT_APK' ||
      'INSTALL_FAILED_INVALID_APK' ||
      'INSTALL_PARSE_FAILED_NO_CERTIFICATES' => InstallFailure.invalidApk,
      _ when RegExp('unauthorized|offline|no devices', caseSensitive: false).hasMatch(output) =>
        InstallFailure.notAuthorized,
      _ => InstallFailure.other,
    };
    final line = output
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.contains('Failure') || l.contains('error'), orElse: () => output.trim());
    return AdbInstallException(failure, line);
  }

  final InstallFailure failure;
  final String detail;

  @override
  String toString() => 'AdbInstallException(${failure.name}): $detail';
}

class AdbException implements Exception {
  AdbException(this.message);
  final String message;
  @override
  String toString() => 'AdbException: $message';
}
