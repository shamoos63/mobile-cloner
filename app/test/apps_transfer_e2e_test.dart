import 'dart:io';
import 'dart:math';

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_cloner/src/platform/android_bridge.dart';
import 'package:mobile_cloner/src/sources/apps_source.dart';
import 'package:path/path.dart' as p;

/// Chosen apps really travel: the app source builds the files from the
/// installed APKs (one app with splits), a real sender sends them to a real
/// receiver, and the received folder groups back into installable apps.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding answers every HttpClient request with 400; this test
  // needs the real network stack (loopback sockets).
  setUp(() => HttpOverrides.global = null);

  test('two apps, one with splits, arrive complete and byte-identical', () async {
    final tmp = await Directory.systemTemp.createTemp('apps_e2e');
    addTearDown(() => tmp.delete(recursive: true));
    final rnd = Random(3);
    String apk(String dir, String name, int size) {
      final f = File(p.join(tmp.path, 'data', 'app', dir, name))..createSync(recursive: true);
      f.writeAsBytesSync(List.generate(size, (_) => rnd.nextInt(256)));
      return f.path;
    }

    final apps = [
      InstalledApp(
        packageName: 'com.whatsapp',
        label: 'WhatsApp',
        versionName: '2.26.35.75',
        versionCode: 231,
        apks: [apk('wa', 'base.apk', 900000), apk('wa', 'split_config.arm64_v8a.apk', 300000), apk('wa', 'split_config.xxhdpi.apk', 70000)],
        sizeBytes: 1270000,
        readable: true,
        minSdk: 24,
      ),
      InstalledApp(
        packageName: 'com.STSelfCare.STApp',
        label: 'ST Selfcare',
        versionName: '2.0.0.4',
        versionCode: 2004,
        // Android calls it base.apk; the receiver must too, whatever it was named.
        apks: [apk('st', 'something.apk', 500000)],
        sizeBytes: 500000,
        readable: true,
      ),
      InstalledApp(
        packageName: 'com.gone',
        label: 'Gone',
        versionName: '1',
        versionCode: 1,
        apks: [p.join(tmp.path, 'missing', 'base.apk')],
        sizeBytes: 10,
        readable: true,
      ),
    ];

    final prepared = await AppsSource(AndroidBridge.instance, stagingDir: p.join(tmp.path, 'staging')).prepare(apps);
    expect(prepared.skipped, ['Gone'], reason: 'an unreadable app is reported, not silently dropped');
    expect(prepared.files.where((f) => f.dto.fileName.endsWith('.apk')).length, 4);

    final receiverId = DeviceIdentity.generate();
    final store = BackupStore(p.join(tmp.path, 'backups'));
    final receiver = ClonerServer(
      identity: receiverId,
      info: DeviceInfo(alias: 'Mac', fingerprint: receiverId.fingerprint, port: 0),
      delegate: BackupReceiveDelegate(store),
    );
    await receiver.start(port: 0, address: InternetAddress.loopbackIPv4, loopback: 0);
    addTearDown(receiver.stop);

    final sender = ClonerClient(
      self: DeviceInfo(alias: 'MI 9T Pro', fingerprint: DeviceIdentity.generate().fingerprint, port: 53317),
    );
    final target = await sender.probe('127.0.0.1', port: receiver.cablePort!, https: false);
    final result = await SendJob(client: sender, target: target, files: prepared.files).run();
    expect(result.outcome, SendOutcome.completed, reason: '${result.error}');

    final bundles = await AppBundle.scan(p.join(store.deviceDir(sender.self), ContentCategory.apps.wireName));
    expect(bundles.map((b) => b.manifest.label), ['ST Selfcare', 'WhatsApp']);
    expect(bundles.every((b) => b.complete), isTrue);
    final wa = bundles.last;
    expect(wa.apkPaths.map(p.basename), ['base.apk', 'split_config.arm64_v8a.apk', 'split_config.xxhdpi.apk']);
    for (final (i, path) in apps.first.apks.indexed) {
      expect(File(wa.apkPaths[i]).readAsBytesSync(), File(path).readAsBytesSync());
    }
    expect(p.basename(bundles.first.apkPaths.single), 'base.apk');
    expect(wa.manifest.minSdk, 24);
  });
}
