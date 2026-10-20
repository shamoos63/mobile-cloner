import 'dart:io';
import 'dart:math';

import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late DeviceIdentity receiverId;
  late DeviceIdentity senderId;

  setUpAll(() {
    receiverId = DeviceIdentity.generate();
    senderId = DeviceIdentity.generate();
  });

  setUp(() async => tmp = await Directory.systemTemp.createTemp('cloner_e2e'));
  tearDown(() async => tmp.delete(recursive: true));

  DeviceInfo info(DeviceIdentity id, String alias, int port, {ClonerPlatform platform = ClonerPlatform.android, int? sdk}) =>
      DeviceInfo(
        alias: alias,
        fingerprint: id.fingerprint,
        port: port,
        cloner: ClonerPeerInfo(platform: platform, sdkInt: sdk),
      );

  test('phone backs up WhatsApp + photos to a desktop over pinned HTTPS, incrementally', () async {
    final store = BackupStore(p.join(tmp.path, 'backups'));
    final serverInfo = info(receiverId, 'PC', 0, platform: ClonerPlatform.linux);
    final server = ClonerServer(
      identity: receiverId,
      info: serverInfo,
      delegate: BackupReceiveDelegate(store),
    );
    await server.start(port: 0, address: InternetAddress.loopbackIPv4);
    final port = server.port!;

    final src = Directory(p.join(tmp.path, 'src'))..createSync();
    final rnd = Random(1);
    File mk(String rel, int size) {
      final f = File(p.join(src.path, rel))..createSync(recursive: true);
      f.writeAsBytesSync(List.generate(size, (_) => rnd.nextInt(256)));
      return f;
    }

    final db = mk('Databases/msgstore.db.crypt14', 300 * 1024);
    final img = mk('DCIM/Camera/IMG_0001.jpg', 2 * 1024 * 1024 + 7);

    final client = ClonerClient(self: info(senderId, 'Old phone', 53317, sdk: 28));
    final target = Device(
      ip: '127.0.0.1',
      info: DeviceInfo(alias: 'PC', fingerprint: receiverId.fingerprint, port: port, cloner: serverInfo.cloner),
    );
    final files = [
      OutgoingFile.fromFile(db, category: ContentCategory.whatsapp, relPath: 'Databases/msgstore.db.crypt14'),
      OutgoingFile.fromFile(img, category: ContentCategory.photos, relPath: 'DCIM/Camera/IMG_0001.jpg'),
    ];
    final result = await SendJob(client: client, target: target, files: files, sourceSdkInt: 28).run();
    expect(result.outcome, SendOutcome.completed, reason: '${result.error}');

    final dir = store.deviceDir(client.self);
    expect(File(p.join(dir, 'whatsapp', 'Databases', 'msgstore.db.crypt14')).readAsBytesSync(), db.readAsBytesSync());
    expect(File(p.join(dir, 'photos', 'DCIM', 'Camera', 'IMG_0001.jpg')).lengthSync(), img.lengthSync());
    final manifest = (await BackupStore.readManifest(dir))!;
    expect(manifest.sdkInt, 28);
    expect((manifest.categories['whatsapp'] as Map)['files'], 1);

    // Second run: nothing new, receiver answers 204.
    final again = await SendJob(
      client: client,
      target: target,
      files: [
        OutgoingFile.fromFile(db, category: ContentCategory.whatsapp, relPath: 'Databases/msgstore.db.crypt14'),
      ],
    ).run();
    expect(again.outcome, SendOutcome.completed);

    // Restore listing reconstructs categories and relative paths.
    final restore = await BackupStore.filesToRestore(dir);
    expect(restore.map((f) => '${f.dto.category.wireName}:${f.dto.relPath}').toSet(), {
      'whatsapp:Databases/msgstore.db.crypt14',
      'photos:DCIM/Camera/IMG_0001.jpg',
    });

    client.close();
    await server.stop();
  });

  test('wrong certificate fingerprint is refused', () async {
    final server = ClonerServer(
      identity: receiverId,
      info: info(receiverId, 'PC', 0),
      delegate: BackupReceiveDelegate(BackupStore(tmp.path)),
    );
    await server.start(port: 0, address: InternetAddress.loopbackIPv4);
    final client = ClonerClient(self: info(senderId, 'Phone', 53317));
    final impostor = Device(ip: '127.0.0.1', info: DeviceInfo(alias: 'PC', fingerprint: 'DEADBEEF', port: server.port!));
    await expectLater(client.register(impostor), throwsA(isA<HandshakeException>()));
    client.close();
    await server.stop();
  });

  test('PIN and rejection', () async {
    final server = ClonerServer(
      identity: receiverId,
      info: info(receiverId, 'PC', 0),
      pin: '4242',
      delegate: BackupReceiveDelegate(BackupStore(tmp.path), approve: (_, _) async => false),
    );
    await server.start(port: 0, address: InternetAddress.loopbackIPv4);
    final client = ClonerClient(self: info(senderId, 'Phone', 53317));
    final target = await client.probe('127.0.0.1', port: server.port!);
    expect(target.fingerprint, receiverId.fingerprint);
    final f = File(p.join(tmp.path, 'a.txt'))..writeAsStringSync('hi');
    final file = OutgoingFile.fromFile(f, category: ContentCategory.files, relPath: 'a.txt');

    final noPin = await SendJob(client: client, target: target, files: [file]).run();
    expect((noPin.error as ClonerHttpException).pinRequired, isTrue);
    final rejected = await SendJob(client: client, target: target, files: [file], pin: '4242').run();
    expect(rejected.outcome, SendOutcome.rejected);
    client.close();
    await server.stop();
  });

  test('malicious relative path never escapes the backup folder', () async {
    final server = ClonerServer(
      identity: receiverId,
      info: info(receiverId, 'PC', 0),
      delegate: BackupReceiveDelegate(BackupStore(p.join(tmp.path, 'b'))),
    );
    await server.start(port: 0, address: InternetAddress.loopbackIPv4);
    final client = ClonerClient(self: info(senderId, 'Phone', 53317));
    final target = await client.probe('127.0.0.1', port: server.port!);
    final evil = OutgoingFile(
      dto: const FileDto(id: 'x', fileName: '../../escape.txt', size: 2, fileType: 'text/plain'),
      open: () => Stream.value([1, 2]),
    );
    final r = await SendJob(client: client, target: target, files: [evil]).run();
    expect(r.outcome, isNot(SendOutcome.completed));
    expect(File(p.join(tmp.path, 'escape.txt')).existsSync(), isFalse);
    client.close();
    await server.stop();
  });
}
