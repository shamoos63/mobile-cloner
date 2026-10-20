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

class AdbException implements Exception {
  AdbException(this.message);
  final String message;
  @override
  String toString() => 'AdbException: $message';
}
