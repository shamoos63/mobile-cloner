// Simulates an Android phone backing up to a Mobile Cloner desktop, for
// trying the desktop app without a phone:
//   dart run example/fake_phone.dart <desktop-ip> [port]
import 'dart:io';
import 'dart:math';

import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final ip = args.isEmpty ? '127.0.0.1' : args[0];
  final port = args.length > 1 ? int.parse(args[1]) : defaultPort;
  final root = await Directory.systemTemp.createTemp('fake_phone');
  final rnd = Random(7);
  final files = <OutgoingFile>[];

  void add(ContentCategory c, String rel, int size) {
    final f = File(p.join(root.path, c.wireName, rel))..createSync(recursive: true);
    final raf = f.openSync(mode: FileMode.write);
    final chunk = List.generate(64 * 1024, (_) => rnd.nextInt(256));
    for (var w = 0; w < size; w += chunk.length) {
      raf.writeFromSync(chunk, 0, min(chunk.length, size - w));
    }
    raf.closeSync();
    files.add(OutgoingFile.fromFile(f, category: c, relPath: rel));
  }

  add(ContentCategory.contacts, 'contacts.vcf', 180 * 1024);
  add(ContentCategory.whatsapp, 'Databases/msgstore.db.crypt14', 24 * 1024 * 1024);
  add(ContentCategory.whatsapp, 'Backups/chatsettingsbackup.db.crypt14', 64 * 1024);
  for (var i = 0; i < 40; i++) {
    add(ContentCategory.whatsapp, 'Media/WhatsApp Images/IMG-20251018-WA00${i.toString().padLeft(2, '0')}.jpg', 900 * 1024);
  }
  for (var i = 0; i < 60; i++) {
    add(ContentCategory.photos, 'DCIM/Camera/IMG_20251019_1${i.toString().padLeft(5, '0')}.jpg', 3 * 1024 * 1024);
  }
  for (var i = 0; i < 6; i++) {
    add(ContentCategory.videos, 'DCIM/Camera/VID_20251019_$i.mp4', 60 * 1024 * 1024);
  }

  final identity = DeviceIdentity.generate();
  final client = ClonerClient(
    self: DeviceInfo(
      alias: 'Galaxy S10',
      fingerprint: identity.fingerprint,
      deviceModel: 'SM-G973F',
      deviceType: DeviceType.mobile,
      cloner: const ClonerPeerInfo(platform: ClonerPlatform.android, sdkInt: 31, osVersion: '12'),
    ),
  );
  final target = await client.probe(ip, port: port);
  stdout.writeln('Backing up ${files.length} files to ${target.info.alias}...');
  final job = SendJob(
    client: client,
    target: target,
    files: files,
    sourceSdkInt: 31,
    localStatus: () => const PeerStatus(batteryLevel: 67, charging: true),
  );
  job.progress.listen((pr) => stdout.write('\r${(pr.fraction * 100).toStringAsFixed(1)}%  '
      '${(pr.bytesPerSecond / 1e6).toStringAsFixed(1)} MB/s   '));
  final r = await job.run();
  stdout.writeln('\n${r.outcome.name} ${r.error ?? ''}');
  client.close();
  await root.delete(recursive: true);
}
