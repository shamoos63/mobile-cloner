import 'dart:convert';
import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('apps'));
  tearDown(() => tmp.delete(recursive: true));

  const maps = AppManifest(
    packageName: 'com.google.android.apps.maps',
    label: 'Maps',
    versionName: '11.140.0',
    versionCode: 1140000,
    apks: ['split_config.xxhdpi.apk', 'base.apk', 'split_config.arm64_v8a.apk'],
    sizeBytes: 98000000,
    minSdk: 26,
  );

  test('manifest survives JSON, and old manifests without minSdk load', () {
    final back = AppManifest.fromJson(jsonDecode(jsonEncode(maps.toJson())) as Map<String, Object?>);
    expect((back.packageName, back.label, back.versionCode, back.minSdk, back.hasSplits),
        (maps.packageName, 'Maps', 1140000, 26, true));
    expect(back.apks, maps.apks);
    final bare = AppManifest.fromJson({'package': 'com.x', 'apks': ['base.apk']});
    expect((bare.label, bare.minSdk, bare.hasSplits), ('com.x', null, false));
  });

  test('base APK first, splits after it in a stable order', () {
    expect(AppManifest.orderApks(maps.apks), ['base.apk', 'split_config.arm64_v8a.apk', 'split_config.xxhdpi.apk']);
  });

  test('files group by their package folder', () {
    expect(AppBundle.packageOf('com.foo/base.apk'), 'com.foo');
    expect(AppBundle.packageOf('com.foo/split_config.en.apk'), 'com.foo');
    expect(AppBundle.packageOf('loose.apk'), isNull);
  });

  Future<void> write(String pkg, AppManifest m, {List<String>? present, bool icon = true}) async {
    final dir = Directory(p.join(tmp.path, pkg))..createSync();
    File(p.join(dir.path, AppManifest.fileName)).writeAsStringSync(jsonEncode(m.toJson()));
    for (final a in present ?? m.apks) {
      File(p.join(dir.path, a)).writeAsStringSync('apk');
    }
    if (icon) File(p.join(dir.path, AppManifest.iconFileName)).writeAsBytesSync([1, 2, 3]);
  }

  test('scans a folder of apps: sorted by name, splits grouped, incomplete ones flagged', () async {
    await write('com.google.android.apps.maps', maps);
    await write(
      'org.telegram',
      const AppManifest(
        packageName: 'org.telegram',
        label: 'aTelegram',
        versionName: '11',
        versionCode: 5,
        apks: ['base.apk', 'split_config.ar.apk'],
        sizeBytes: 80,
      ),
      present: ['base.apk'],
      icon: false,
    );
    Directory(p.join(tmp.path, 'not.an.app')).createSync(); // no manifest: skipped

    final apps = await AppBundle.scan(tmp.path);
    expect([for (final a in apps) a.manifest.label], ['aTelegram', 'Maps']);
    final m = apps[1];
    expect(m.complete, isTrue);
    expect([for (final a in m.apkPaths) p.basename(a)], ['base.apk', 'split_config.arm64_v8a.apk', 'split_config.xxhdpi.apk']);
    expect(m.iconPath, isNotNull);
    expect((apps[0].complete, apps[0].iconPath), (false, null));
    expect(await AppBundle.scan(p.join(tmp.path, 'missing')), isEmpty);
  });
}
