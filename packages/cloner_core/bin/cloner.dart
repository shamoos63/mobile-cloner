import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;

/// Headless Mobile Cloner: back up a phone to a folder, restore it, or send
/// files. Usable on servers and handy for testing the protocol.
Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>('cloner', 'Mobile Cloner command line client.')
    ..addCommand(ReceiveCommand())
    ..addCommand(SendCommand())
    ..addCommand(RestoreCommand())
    ..addCommand(DiscoverCommand());
  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exitCode = 64;
  }
}

Future<DeviceIdentity> loadIdentity() async {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
  final file = File(p.join(home, '.mobile_cloner', 'identity.json'));
  if (await file.exists()) {
    return DeviceIdentity.fromJson((jsonDecode(await file.readAsString()) as Map).cast());
  }
  final identity = DeviceIdentity.generate();
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(identity.toJson()));
  return identity;
}

DeviceInfo selfInfo(DeviceIdentity id, String alias, int port) => DeviceInfo(
  alias: alias,
  fingerprint: id.fingerprint,
  deviceModel: Platform.operatingSystem,
  deviceType: DeviceType.headless,
  port: port,
  cloner: ClonerPeerInfo(
    platform: ClonerPlatform.parse(Platform.operatingSystem),
    osVersion: Platform.operatingSystemVersion,
    capabilities: const {'backup'},
  ),
);

String fmtBytes(int b) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = b.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}

/// Upload lanes; CLONER_PARALLEL overrides for benchmarking.
final _parallel = int.tryParse(Platform.environment['CLONER_PARALLEL'] ?? '') ?? 5;

Future<Device> resolveTarget(ClonerClient client, String to) async {
  final parts = to.split(':');
  final port = parts.length > 1 ? int.parse(parts[1]) : defaultPort;
  return client.probeAuto(parts[0], port: port);
}

class ReceiveCommand extends Command<void> {
  ReceiveCommand() {
    argParser
      ..addOption('dir', abbr: 'd', help: 'Backup folder.', defaultsTo: 'MobileClonerBackups')
      ..addOption('alias', defaultsTo: 'Cloner CLI')
      ..addOption('port', defaultsTo: '$defaultPort')
      ..addOption('pin', help: 'Require this PIN from senders.')
      ..addFlag('once', help: 'Exit after the first finished session.')
      ..addFlag('full', help: 'Re-copy files that already exist (default is incremental).');
  }

  @override
  String get name => 'receive';
  @override
  String get description => 'Act as a backup station: store everything phones send.';

  @override
  Future<void> run() async {
    final a = argResults!;
    final identity = await loadIdentity();
    final port = int.parse(a['port'] as String);
    final info = selfInfo(identity, a['alias'] as String, port);
    final done = Completer<void>();
    final store = BackupStore(a['dir'] as String);
    final server = ClonerServer(
      identity: identity,
      info: info,
      pin: a['pin'] as String?,
      delegate: BackupReceiveDelegate(
        store,
        incremental: !(a['full'] as bool),
        onSeen: (d) => stdout.writeln('Seen ${d.info.alias} at ${d.ip}'),
        onFinished: (s) {
          final ok = s.files.values.where((f) => f.state == FileState.done).length;
          stdout.writeln('Session finished: $ok/${s.files.length} files, '
              '${fmtBytes(s.receivedBytes)} -> ${store.deviceDir(s.sender.info)}');
          if (a['once'] as bool && !done.isCompleted) done.complete();
        },
      ),
    );
    await server.start(port: port);
    server.events.listen((e) {
      if (e is SessionStarted) {
        stdout.writeln('Receiving ${e.session.files.length} files '
            '(${fmtBytes(e.session.totalBytes)}) from ${e.session.sender.info.alias}');
      }
    });
    final client = ClonerClient(self: info);
    final discovery = Discovery(client: client, self: () => info, port: port);
    try {
      await discovery.start();
    } catch (e) {
      stderr.writeln('Multicast unavailable ($e); peers can still connect by IP.');
    }
    stdout.writeln('Listening on port $port, fingerprint ${identity.fingerprint.substring(0, 16)}...');
    stdout.writeln('Backups go to ${p.absolute(store.root)}');
    await done.future;
    discovery.stop();
    await server.stop();
    client.close();
  }
}

class SendCommand extends Command<void> {
  SendCommand() {
    argParser
      ..addOption('to', mandatory: true, help: 'Receiver ip[:port].')
      ..addOption('category', defaultsTo: 'files', allowed: [for (final c in ContentCategory.values) c.wireName])
      ..addOption('pin');
  }

  @override
  String get name => 'send';
  @override
  String get description => 'Send files or folders to a receiver.';

  @override
  Future<void> run() async {
    final a = argResults!;
    final identity = await loadIdentity();
    final client = ClonerClient(self: selfInfo(identity, 'Cloner CLI', defaultPort));
    final target = await resolveTarget(client, a['to'] as String);
    final category = ContentCategory.parse(a['category']);
    final files = <OutgoingFile>[];
    for (final path in a.rest) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        await for (final e in Directory(path).list(recursive: true)) {
          if (e is File) {
            final rel = p.relative(e.path, from: path).replaceAll(r'\', '/');
            files.add(OutgoingFile.fromFile(e, category: category, relPath: rel));
          }
        }
      } else if (type == FileSystemEntityType.file) {
        files.add(OutgoingFile.fromFile(File(path), category: category, relPath: p.basename(path)));
      }
    }
    await _sendAndReport(client, target, files, a['pin'] as String?);
  }
}

class RestoreCommand extends Command<void> {
  RestoreCommand() {
    argParser
      ..addOption('to', mandatory: true, help: 'Phone ip[:port] (127.0.0.1:${AdbBridge.pcToPhonePort} over ADB).')
      ..addOption('backup', mandatory: true, help: 'Device folder inside the backup root.')
      ..addMultiOption('only', allowed: [for (final c in ContentCategory.values) c.wireName])
      ..addOption('pin');
  }

  @override
  String get name => 'restore';
  @override
  String get description => 'Send a device backup back to a phone.';

  @override
  Future<void> run() async {
    final a = argResults!;
    final identity = await loadIdentity();
    final client = ClonerClient(self: selfInfo(identity, 'Cloner CLI', defaultPort));
    final target = await resolveTarget(client, a['to'] as String);
    final only = (a['only'] as List<String>).map(ContentCategory.parse).toSet();
    final files = await BackupStore.filesToRestore(a['backup'] as String, only: only.isEmpty ? null : only);
    await _sendAndReport(client, target, files, a['pin'] as String?);
  }
}

Future<void> _sendAndReport(ClonerClient client, Device target, List<OutgoingFile> files, String? pin) async {
  stdout.writeln('Sending ${files.length} files to ${target.info.alias}...');
  final job = SendJob(client: client, target: target, files: files, pin: pin, parallel: _parallel);
  var lastPct = -1;
  job.progress.listen((pr) {
    final pct = (pr.fraction * 100).floor();
    if (pct != lastPct) {
      lastPct = pct;
      stdout.write('\r$pct%  ${pr.doneFiles}/${pr.totalFiles} files  ${fmtBytes(pr.sentBytes)}   ');
    }
  });
  final result = await job.run();
  stdout.writeln('\n${result.outcome.name}${result.error == null ? '' : ': ${result.error}'}');
  client.close();
  if (result.outcome != SendOutcome.completed) exitCode = 1;
}

class DiscoverCommand extends Command<void> {
  DiscoverCommand() {
    argParser
      ..addOption('seconds', defaultsTo: '5')
      ..addFlag('scan', help: 'Also scan local /24 subnets (for hotspot / USB tethering).');
  }

  @override
  String get name => 'discover';
  @override
  String get description => 'List Cloner and LocalSend devices nearby.';

  @override
  Future<void> run() async {
    final identity = await loadIdentity();
    final info = selfInfo(identity, 'Cloner CLI', defaultPort);
    final client = ClonerClient(self: info);
    final discovery = Discovery(client: client, self: () => info);
    final seen = <String>{};
    discovery.devices.listen((d) {
      if (seen.add(d.fingerprint)) {
        final kind = d.info.isCloner ? 'cloner/${d.info.cloner!.platform.name}' : 'localsend';
        stdout.writeln('${d.info.alias.padRight(24)} ${d.ip}:${d.port}  $kind');
      }
    });
    await discovery.start();
    if (argResults!['scan'] as bool) await discovery.scanSubnets();
    await Future<void>.delayed(Duration(seconds: int.parse(argResults!['seconds'] as String)));
    await discovery.dispose();
    client.close();
  }
}
