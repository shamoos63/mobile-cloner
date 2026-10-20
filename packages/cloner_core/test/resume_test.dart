import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  final receiverId = DeviceIdentity.generate();
  final senderId = DeviceIdentity.generate();

  setUp(() async => tmp = await Directory.systemTemp.createTemp('cloner_resume'));
  tearDown(() async => tmp.delete(recursive: true));

  DeviceInfo info(DeviceIdentity id, String alias) => DeviceInfo(
    alias: alias,
    fingerprint: id.fingerprint,
    cloner: const ClonerPeerInfo(platform: ClonerPlatform.android, sdkInt: 33),
  );

  test('interrupted transfer resumes mid-file from the checkpoint, over a new connection', () async {
    final store = BackupStore(p.join(tmp.path, 'backups'));
    final server = ClonerServer(identity: receiverId, info: info(receiverId, 'PC'), delegate: BackupReceiveDelegate(store));
    await server.start(port: 0, address: InternetAddress.loopbackIPv4);

    final bytes = List.generate(8 * 1024 * 1024, (i) => Random(i).nextInt(256));
    final src = File(p.join(tmp.path, 'video.mp4'))..writeAsBytesSync(bytes);
    final file = OutgoingFile.fromFile(src, category: ContentCategory.videos, relPath: 'DCIM/Camera/video.mp4');

    // Throttled source so we can interrupt half way.
    OutgoingFile slow(OutgoingFile f) => OutgoingFile(
      dto: f.dto,
      open: (offset) => f.open(offset).asyncMap((chunk) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return chunk;
      }),
    );

    final cpStore = CheckpointStore(p.join(tmp.path, 'checkpoint.json'));
    TransferCheckpoint newCheckpoint() => TransferCheckpoint(
      transferId: 't1',
      peerFingerprint: receiverId.fingerprint,
      peerAlias: 'PC',
      role: 'send',
      categories: {ContentCategory.videos},
      totalFiles: 1,
      totalBytes: bytes.length,
    );

    final client = ClonerClient(self: info(senderId, 'Phone'));
    final target = await client.probe('127.0.0.1', port: server.port!);
    final job1 = SendJob(client: client, target: target, files: [slow(file)], checkpoint: newCheckpoint(), checkpointStore: cpStore);
    var sawSpeed = false;
    job1.progress.listen((pr) {
      if (pr.bytesPerSecond > 0) sawSpeed = true;
      if (pr.sentBytes > bytes.length ~/ 3) job1.interrupt(InterruptReason.lowBatterySelf);
    });
    final r1 = await job1.run();
    expect(r1.outcome, SendOutcome.interrupted);
    expect(r1.interruptReason, InterruptReason.lowBatterySelf);
    expect(sawSpeed, isTrue);

    // The checkpoint survived and records why we stopped.
    final cp = (await cpStore.load())!;
    expect(cp.interruptReason, InterruptReason.lowBatterySelf);
    expect(cp.doneFileIds, isEmpty);
    expect(cp.lastAddress, '127.0.0.1');

    final partFile = File('${store.pathFor(client.self, file.dto)}.part');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final kept = partFile.lengthSync();
    expect(kept, greaterThan(0));
    expect(kept, lessThan(bytes.length));

    // Resume with a fresh client (as after a reboot or a switch to cable).
    final client2 = ClonerClient(self: info(senderId, 'Phone'));
    final target2 = await client2.probe('127.0.0.1', port: server.port!);
    var firstSent = -1;
    final job2 = SendJob(client: client2, target: target2, files: [file], checkpoint: cp, checkpointStore: cpStore);
    job2.progress.listen((pr) => firstSent = firstSent < 0 ? pr.sentBytes : firstSent);
    final r2 = await job2.run();
    expect(r2.outcome, SendOutcome.completed, reason: '${r2.error}');
    expect(firstSent, greaterThanOrEqualTo(kept), reason: 'resumed, not restarted');
    expect(File(store.pathFor(client.self, file.dto)).readAsBytesSync(), bytes);
    expect(await cpStore.load(), isNull, reason: 'checkpoint cleared when done');

    client.close();
    client2.close();
    await server.stop();
  });

  test('heartbeat reports peer battery and stops on critical battery', () async {
    final server = ClonerServer(
      identity: receiverId,
      info: info(receiverId, 'New phone'),
      delegate: BackupReceiveDelegate(BackupStore(p.join(tmp.path, 'b'))),
      localStatus: () => const PeerStatus(batteryLevel: 3, charging: false),
    );
    await server.start(port: 0, address: InternetAddress.loopbackIPv4);
    final events = <ServerEvent>[];
    server.events.listen(events.add);
    final client = ClonerClient(self: info(senderId, 'Old phone'));
    final target = await client.probe('127.0.0.1', port: server.port!);
    final src = File(p.join(tmp.path, 'big.bin'))..writeAsBytesSync(List.filled(4 * 1024 * 1024, 7));
    final f = OutgoingFile.fromFile(src, category: ContentCategory.files, relPath: 'big.bin');
    final slow = OutgoingFile(
      dto: f.dto,
      open: (o) => f.open(o).asyncMap((c) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return c;
      }),
    );
    final job = SendJob(
      client: client,
      target: target,
      files: [slow],
      localStatus: () => const PeerStatus(batteryLevel: 80, charging: true),
      heartbeatInterval: const Duration(milliseconds: 100),
    );
    final r = await job.run();
    expect(r.outcome, SendOutcome.interrupted);
    expect(r.interruptReason, InterruptReason.lowBatteryPeer);
    expect(events.whereType<PeerStatusReceived>().first.status.batteryLevel, 80);
    client.close();
    await server.stop();
  });

  test('speed meter uses a sliding window', () {
    var now = DateTime(2026);
    final m = SpeedMeter(clock: () => now);
    m.add(0);
    for (var i = 0; i < 10; i++) {
      now = now.add(const Duration(seconds: 1));
      m.add(1000);
    }
    expect(m.bytesPerSecond, closeTo(1000, 1));
    expect(m.eta(5000), const Duration(seconds: 5));
  });
}
