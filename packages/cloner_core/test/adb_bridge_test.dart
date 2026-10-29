@TestOn('linux || mac-os')
library;

import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Fake adb: logs every call, answers `devices` and `dumpsys package` from
/// files the test writes; `install` prints [installOutput] and exits with
/// [installExit].
Future<(AdbBridge, File)> fakeAdb(
  Directory dir, {
  String? dumpsys,
  String installOutput = 'Success',
  int installExit = 0,
}) async {
  final log = File(p.join(dir.path, 'calls.log'));
  final dump = File(p.join(dir.path, 'dumpsys.txt'))..writeAsStringSync(dumpsys ?? '');
  final install = File(p.join(dir.path, 'install.txt'))..writeAsStringSync(installOutput);
  final script = File(p.join(dir.path, 'adb'))
    ..writeAsStringSync('''#!/bin/sh
echo "\$*" >> ${log.path}
case "\$*" in
  "devices -l") printf 'List of devices attached\\nRZCT1 device usb:1-1 product:a53x model:SM_A536E device:a53x\\nR5GY2 unauthorized usb:1-2\\n' ;;
  *"dumpsys package"*) cat ${dump.path} ;;
  *" install "*) cat ${install.path}; exit $installExit ;;
esac
''');
  await Process.run('chmod', ['+x', script.path]);
  return (AdbBridge(adbPath: script.path), log);
}

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('adb'));
  tearDown(() => tmp.delete(recursive: true));

  test('lists devices with state and model', () async {
    final (adb, _) = await fakeAdb(tmp);
    final list = await adb.list();
    expect(list.map((d) => (d.serial, d.ready, d.unauthorized, d.model)), [
      ('RZCT1', true, false, 'SM A536E'),
      ('R5GY2', false, true, null),
    ]);
  });

  test('app state: missing, outdated, ready', () async {
    var (adb, _) = await fakeAdb(tmp);
    var app = await adb.appState('RZCT1', 'com.mobilecloner.app', versionCode: 3);
    expect((app.missing, app.outdated, app.ready), (true, false, false));

    (adb, _) = await fakeAdb(tmp, dumpsys: '    versionCode=2 minSdk=23 targetSdk=35\n');
    app = await adb.appState('RZCT1', 'com.mobilecloner.app', versionCode: 3);
    expect((app.missing, app.outdated, app.ready, app.installedVersion), (false, true, false, 2));

    (adb, _) = await fakeAdb(tmp, dumpsys: '    versionCode=3 minSdk=23 targetSdk=35\n');
    app = await adb.appState('RZCT1', 'com.mobilecloner.app', versionCode: 3);
    expect(app.ready, isTrue);
  });

  test('installs with -r, then maps ports and opens linked', () async {
    final (adb, log) = await fakeAdb(tmp);
    final apk = File(p.join(tmp.path, 'hk-cloner.apk'))..writeAsStringSync('apk');
    await adb.install('RZCT1', apk.path);
    await adb.openLinked('RZCT1', package: 'com.mobilecloner.app', activity: '.MainActivity');
    final calls = log.readAsLinesSync();
    expect(calls, contains('-s RZCT1 install -r ${apk.path}'));
    expect(calls, contains('-s RZCT1 reverse tcp:53319 tcp:53320'));
    expect(calls.last, '-s RZCT1 shell am start -n com.mobilecloner.app/.MainActivity --es cloner_link adb');
  });

  test('install failures carry the reason Android gave', () async {
    Future<InstallFailure> failure(String output, {int exit = 1}) async {
      final (adb, _) = await fakeAdb(tmp, installOutput: output, installExit: exit);
      try {
        await adb.install('RZCT1', 'x.apk');
      } on AdbInstallException catch (e) {
        return e.failure;
      }
      fail('install did not throw for: $output');
    }

    expect(
      await failure(
        'Performing Streamed Install\nadb: failed to install x.apk: Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE: '
        'Existing package com.mobilecloner.app signatures do not match newer version; ignoring!]',
      ),
      InstallFailure.updateIncompatible,
    );
    expect(await failure('Failure [INSTALL_FAILED_USER_RESTRICTED: Install canceled by user]'), InstallFailure.blocked);
    expect(await failure('Failure [INSTALL_FAILED_VERSION_DOWNGRADE]'), InstallFailure.downgrade);
    expect(await failure('Failure [INSTALL_FAILED_INSUFFICIENT_STORAGE]'), InstallFailure.noSpace);
    expect(
      await failure("adb: device unauthorized.\nThis adb server's \$ADB_VENDOR_KEYS is not set"),
      InstallFailure.notAuthorized,
    );
    // Old adb versions exit 0 even when Android refused.
    expect(
      await failure('Failure [INSTALL_PARSE_FAILED_NOT_APK: Failed to parse]', exit: 0),
      InstallFailure.invalidApk,
    );
  });

  test('uninstall removes the package', () async {
    final (adb, log) = await fakeAdb(tmp);
    await adb.uninstall('RZCT1', 'com.mobilecloner.app');
    expect(log.readAsLinesSync(), contains('-s RZCT1 uninstall com.mobilecloner.app'));
  });

  group('PhoneApk.locate', () {
    test('prefers the env override, then data/hk-cloner.apk, then the legacy name', () {
      final bundle = Directory(p.join(tmp.path, 'Release'))..createSync();
      expect(PhoneApk.locate(bundle.path, environment: {}), isNull);

      final legacy = File(p.join(bundle.path, 'mobile-cloner.apk'))..writeAsStringSync('old');
      expect(PhoneApk.locate(bundle.path, environment: {}), legacy.path);

      final bundled = File(p.join(bundle.path, 'data', 'hk-cloner.apk'))
        ..createSync(recursive: true)
        ..writeAsStringSync('apk');
      expect(PhoneApk.locate(bundle.path, environment: {}), bundled.path);

      final dev = File(p.join(tmp.path, 'dev.apk'))..writeAsStringSync('dev');
      expect(PhoneApk.locate(bundle.path, environment: {PhoneApk.envVar: dev.path}), dev.path);
      // A missing override falls through.
      expect(PhoneApk.locate(bundle.path, environment: {PhoneApk.envVar: p.join(tmp.path, 'nope.apk')}), bundled.path);
    });

    test('finds the Android build output from a desktop build in the same checkout', () {
      // app/build/macos/Build/Products/Debug/HK Cloner.app/Contents/Resources
      final resources = Directory(
        p.join(
          tmp.path,
          'app',
          'build',
          'macos',
          'Build',
          'Products',
          'Debug',
          'HK Cloner.app',
          'Contents',
          'Resources',
        ),
      )..createSync(recursive: true);
      expect(PhoneApk.locate(resources.path, environment: {}), isNull);
      final out = File(p.join(tmp.path, 'app', 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk'))
        ..createSync(recursive: true);
      expect(PhoneApk.locate(resources.path, environment: {}), out.path);
    });
  });
}
