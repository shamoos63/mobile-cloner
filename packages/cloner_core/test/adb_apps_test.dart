import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Output captured from a Xiaomi MI 9T Pro on Android 15.
const pmListF = '''
package:/data/app/~~eevrspRT7UAKbw83u6QE8g==/com.google.android.contactkeys-Nu3i4x6LLhGH8840SFue4w==/base.apk=com.google.android.contactkeys\r
package:/data/app/~~nQNPYPoWrM5in3wPK_JAzg==/com.whatsapp-UcwFntB2q-qKRVWBXUCCLA==/base.apk=com.whatsapp\r
package:/data/app/~~8RmRIJ0GWMYy6gMXBndkEQ==/com.instagram.android-7_tQNqII2uq6TFv6dOrdiw==/base.apk=com.instagram.android
''';

const pmPathWhatsApp = '''
package:/data/app/~~nQNPYPoWrM5in3wPK_JAzg==/com.whatsapp-UcwFntB2q-qKRVWBXUCCLA==/split_config.arm64_v8a.apk
package:/data/app/~~nQNPYPoWrM5in3wPK_JAzg==/com.whatsapp-UcwFntB2q-qKRVWBXUCCLA==/base.apk
package:/data/app/~~nQNPYPoWrM5in3wPK_JAzg==/com.whatsapp-UcwFntB2q-qKRVWBXUCCLA==/split_config.xxhdpi.apk
''';

const launchers = '''
33 activities found:
  Activity #0:
    priority=0 preferredOrder=0 match=0x108000 specificIndex=-1 isDefault=true
    com.android.contacts/.activities.PeopleActivity
  Activity #1:
    priority=0 preferredOrder=0 match=0x108000 specificIndex=-1 isDefault=true
    com.whatsapp/.Main
  Activity #2:
    priority=0 preferredOrder=0 match=0x108000 specificIndex=-1 isDefault=true
    com.instagram.android/com.instagram.mainactivity.LauncherActivity
''';

void main() {
  test('pm list packages, with -f paths that contain = signs', () {
    expect(PmOutput.packages(pmListF), ['com.google.android.contactkeys', 'com.whatsapp', 'com.instagram.android']);
    expect(PmOutput.packages('package:com.foo\npackage:com.bar\n'), ['com.foo', 'com.bar']);
  });

  test('pm path puts the base APK first', () {
    final paths = PmOutput.paths(pmPathWhatsApp);
    expect(paths.map(p.posix.basename), ['base.apk', 'split_config.arm64_v8a.apk', 'split_config.xxhdpi.apk']);
  });

  test('launcher query: indented long form; unsupported command gives null', () {
    expect(PmOutput.launcherPackages(launchers), {'com.android.contacts', 'com.whatsapp', 'com.instagram.android'});
    expect(PmOutput.launcherPackages('Unknown command: query-activities'), isNull);
    expect(PmOutput.launcherPackages(''), isNull);
  });

  test('sizes and versions', () {
    expect(PmOutput.totalSize('141712207\n5567963\n'), 147280170);
    expect(PmOutput.versionName('    versionCode=231 minSdk=24\n    versionName=2.26.35.75\n'), '2.26.35.75');
  });

  group('over a fake adb', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('adbapps'));
    tearDown(() => tmp.delete(recursive: true));

    test('third-party apps: launchable only, HK Cloner and background packages left out', () async {
      final script = File(p.join(tmp.path, 'adb'))
        ..writeAsStringSync('''#!/bin/sh
case "\$*" in
  *"pm list packages -3"*) printf '$pmListF' ; printf 'package:/data/app/x/com.mobilecloner.app-1/base.apk=com.mobilecloner.app\\n' ;;
  *"query-activities"*) cat <<'Q'
$launchers    com.mobilecloner.app/.MainActivity
Q
;;
  *"pm path com.whatsapp"*) printf '$pmPathWhatsApp' ;;
  *"pm path com.instagram.android"*) printf 'package:/data/app/i/base.apk\\n' ;;
  *"stat -c"*) printf '1000\\n24\\n' ;;
  *"dumpsys package com.whatsapp"*) printf '    versionCode=231 minSdk=24\\n    versionName=2.26.35.75\\n' ;;
  *"dumpsys package"*) printf '    versionCode=5\\n    versionName=446.0\\n' ;;
esac
''');
      await Process.run('chmod', ['+x', script.path]);
      final apps = await AdbBridge(adbPath: script.path).thirdPartyApps('X', exclude: 'com.mobilecloner.app');
      expect(apps.map((a) => a.packageName), ['com.instagram.android', 'com.whatsapp']);
      final wa = apps.last;
      expect((wa.apks.length, p.posix.basename(wa.apks.first), wa.sizeBytes, wa.versionName, wa.versionCode),
          (3, 'base.apk', 1024, '2.26.35.75', 231));
    });
  });

  test('an apps backup made by the computer shows up in the backup list', () async {
    final tmp = await Directory.systemTemp.createTemp('rec');
    addTearDown(() => tmp.delete(recursive: true));
    final store = BackupStore(tmp.path);
    const phone = DeviceInfo(alias: 'MI 9T Pro', fingerprint: 'ABCDEF1234', deviceModel: 'MI 9T Pro');
    await store.recordCategory(phone, ContentCategory.apps, files: 3, bytes: 31000000);
    final list = await store.listBackups();
    expect(list.length, 1);
    expect((list.single.$2.categories['apps'] as Map)['files'], 3);
    expect(list.single.$2.alias, 'MI 9T Pro');
  });
}
