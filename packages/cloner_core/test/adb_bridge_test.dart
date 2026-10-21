@TestOn('linux || mac-os')
library;

import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Fake adb: logs every call, answers `devices` and `dumpsys package` from
/// files the test writes.
Future<(AdbBridge, File)> fakeAdb(Directory dir, {String? dumpsys}) async {
  final log = File(p.join(dir.path, 'calls.log'));
  final dump = File(p.join(dir.path, 'dumpsys.txt'))..writeAsStringSync(dumpsys ?? '');
  final script = File(p.join(dir.path, 'adb'))
    ..writeAsStringSync('''#!/bin/sh
echo "\$*" >> ${log.path}
case "\$*" in
  "devices -l") printf 'List of devices attached\\nRZCT1 device usb:1-1 product:a53x model:SM_A536E device:a53x\\nR5GY2 unauthorized usb:1-2\\n' ;;
  *"dumpsys package"*) cat ${dump.path} ;;
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

  test('installs when missing, then maps ports and opens linked', () async {
    final (adb, log) = await fakeAdb(tmp);
    final apk = File(p.join(tmp.path, 'mobile-cloner.apk'))..writeAsStringSync('apk');
    final r = await adb.ensureAppRunning('RZCT1',
        package: 'com.mobilecloner.app', activity: '.MainActivity', versionCode: 3, apkPath: apk.path);
    expect(r, AppSetupResult.installed);
    final calls = log.readAsLinesSync();
    expect(calls, contains('-s RZCT1 install -r ${apk.path}'));
    expect(calls, contains('-s RZCT1 reverse tcp:53319 tcp:53320'));
    expect(calls.last, '-s RZCT1 shell am start -n com.mobilecloner.app/.MainActivity --es cloner_link adb');
  });

  test('opens without installing when up to date; updates when older', () async {
    var (adb, log) = await fakeAdb(tmp, dumpsys: '    versionCode=3 minSdk=23 targetSdk=35\n');
    final apk = File(p.join(tmp.path, 'mobile-cloner.apk'))..writeAsStringSync('apk');
    expect(
      await adb.ensureAppRunning('RZCT1', package: 'x', activity: '.A', versionCode: 3, apkPath: apk.path),
      AppSetupResult.alreadyInstalled,
    );
    expect(log.readAsLinesSync().where((c) => c.contains('install')), isEmpty);
    expect(
      await adb.ensureAppRunning('RZCT1', package: 'x', activity: '.A', versionCode: 4, apkPath: apk.path),
      AppSetupResult.updated,
    );
  });

  test('missing app and no APK: reports it and does not launch', () async {
    final (adb, log) = await fakeAdb(tmp);
    expect(await adb.ensureAppRunning('RZCT1', package: 'x', activity: '.A', versionCode: 1), AppSetupResult.missingApk);
    expect(log.readAsLinesSync().where((c) => c.contains('am start')), isEmpty);
  });
}
