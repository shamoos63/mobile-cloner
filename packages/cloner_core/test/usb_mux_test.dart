import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// One end of an in-memory USB link. Bytes arrive at the other end cut
/// into 16 KiB pieces like bulk reads; every write size is recorded.
class FakeLink implements MuxTransport {
  FakeLink._();

  static (FakeLink, FakeLink) pair() {
    final a = FakeLink._(), b = FakeLink._();
    a._peer = b;
    b._peer = a;
    return (a, b);
  }

  late FakeLink _peer;
  final _in = StreamController<Uint8List>();
  final writes = <int>[];
  var _unplugged = false;

  @override
  Stream<Uint8List> get incoming => _in.stream;

  @override
  Future<void> write(Uint8List bytes) async {
    if (_unplugged) throw const SocketException('detached');
    writes.add(bytes.length);
    for (var o = 0; o < bytes.length; o += 16384) {
      _peer._in.add(Uint8List.fromList(bytes.sublist(o, min(o + 16384, bytes.length))));
    }
    await Future<void>.delayed(Duration.zero);
  }

  /// Pulls the cable: both ends see the link end.
  void unplug() {
    for (final l in [this, _peer]) {
      l._unplugged = true;
      l._in.addError(const SocketException('detached'));
      l._in.close();
    }
  }
}

Uint8List randomBytes(int n, int seed) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
}

/// Reads [ch] to the end, acknowledging as it goes.
Future<Uint8List> drain(MuxChannel ch) async {
  final b = BytesBuilder();
  await for (final chunk in ch.data) {
    b.add(chunk);
    ch.ack(chunk.length);
  }
  return b.takeBytes();
}

void main() {
  test('many channels in both directions keep their bytes intact', () async {
    final (la, lb) = FakeLink.pair();
    final a = UsbMux(la)..start();
    final b = UsbMux(lb)..start();

    // Every incoming channel echoes what it got, reversed in order of chunks.
    for (final m in [a, b]) {
      m.incomingChannels.listen((ch) async {
        final got = await drain(ch);
        await ch.write(got);
        ch.close();
      });
    }

    Future<void> roundTrip(UsbMux from, int size, int seed) async {
      final payload = randomBytes(size, seed);
      final ch = from.open();
      final echoed = drain(ch);
      await ch.write(payload);
      ch.close();
      expect(await echoed, payload);
    }

    await Future.wait([
      roundTrip(a, 3 * 1024 * 1024 + 11, 1),
      roundTrip(a, 1, 2),
      roundTrip(b, 2 * 1024 * 1024, 3),
      roundTrip(b, 64 * 1024, 4),
      roundTrip(a, 0, 5),
    ]);
  });

  test('no USB write is a multiple of the packet size', () async {
    final (la, lb) = FakeLink.pair();
    final a = UsbMux(la)..start();
    final b = UsbMux(lb)..start();
    b.incomingChannels.listen(drain);
    final ch = a.open();
    // Payload sizes that would land on 64/512/1024 multiples with headers.
    for (final n in [55, 503, 1015, 16375, 65536]) {
      await ch.write(randomBytes(n, n));
    }
    ch.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(la.writes.where((w) => w % 64 == 0), isEmpty, reason: '${la.writes}');
    expect(lb.writes.where((w) => w % 64 == 0), isEmpty, reason: '${lb.writes}');
  });

  test('a reader that does not acknowledge stops the writer at the window', () async {
    final (la, lb) = FakeLink.pair();
    final a = UsbMux(la, window: 64 * 1024)..start();
    final b = UsbMux(lb, window: 64 * 1024)..start();
    final received = <Uint8List>[];
    final remote = Completer<MuxChannel>();
    b.incomingChannels.listen((ch) {
      remote.complete(ch);
      ch.data.listen(received.add); // never acks
    });
    final ch = a.open();
    var done = false;
    unawaited(ch.write(randomBytes(256 * 1024, 9)).then((_) => done = true));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(done, isFalse);
    expect(received.fold<int>(0, (s, c) => s + c.length), 64 * 1024);

    (await remote.future).ack(256 * 1024);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(done, isTrue);
  });

  test('pulling the cable ends every channel with an error', () async {
    final (la, lb) = FakeLink.pair();
    final a = UsbMux(la)..start();
    final b = UsbMux(lb)..start();
    b.incomingChannels.listen((_) {});
    final ch = a.open();
    final ended = ch.data.toList();
    la.unplug();
    await expectLater(ended, throwsA(isA<SocketException>()));
    await a.closed;
    await b.closed;
    expect(() => a.open(), throwsA(isA<SocketException>()));
    await expectLater(ch.write(Uint8List(10)), throwsA(isA<SocketException>()));
  });

  test('a restarted peer resets the channels from before', () async {
    final (la, lb) = FakeLink.pair();
    final a = UsbMux(la)..start();
    UsbMux(lb).start();
    final ch = a.open();
    final ended = expectLater(ch.data.toList(), throwsA(isA<SocketException>()));
    // The other app restarts on the same link and says hello again:
    // type 1, stream 0, length 1, version 1.
    await lb.write(Uint8List.fromList([1, 0, 0, 0, 0, 0, 0, 0, 1, 1]));
    await ended;
  });

  group('UsbTunnel', () {
    late HttpServer server;
    late UsbTunnel tunnel;
    late FakeLink link;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final body = await req.fold<BytesBuilder>(BytesBuilder(), (b, c) => b..add(c));
        req.response.headers.contentType = ContentType.binary;
        req.response.add(body.takeBytes().reversed.toList());
        await req.response.close();
      });
      final (la, lb) = FakeLink.pair();
      link = la;
      final phoneA = UsbMux(la)..start();
      final phoneB = UsbMux(lb)..start();
      tunnel = UsbTunnel(phoneA, listenPort: 0, targetPort: 0);
      await tunnel.start();
      await UsbTunnel(phoneB, listenPort: 0, targetPort: server.port).start();
    });

    tearDown(() => server.close(force: true));

    test('HTTP requests reach the other phone, several at once', () async {
      final client = HttpClient();
      Future<void> post(int size, int seed) async {
        final body = randomBytes(size, seed);
        final req = await client.post('127.0.0.1', tunnel.port!, '/echo');
        req.add(body);
        final res = await req.close();
        final got = await res.fold<BytesBuilder>(BytesBuilder(), (b, c) => b..add(c));
        expect(got.takeBytes(), body.reversed.toList());
      }

      await Future.wait([post(5 * 1024 * 1024, 1), post(10, 2), post(700 * 1024, 3)]);
      client.close();
    });

    test('unplugging fails the request instead of hanging', () async {
      final client = HttpClient();
      final req = await client.post('127.0.0.1', tunnel.port!, '/echo');
      req.add(randomBytes(1024, 1));
      link.unplug();
      await expectLater(() async => (await req.close()).drain<void>(), throwsA(anything));
      client.close(force: true);
    });
  });

  test('a whole transfer runs over the USB tunnel', () async {
    final tmp = await Directory.systemTemp.createTemp('usb_e2e');
    addTearDown(() => tmp.delete(recursive: true));
    final receiverId = DeviceIdentity.generate(), senderId = DeviceIdentity.generate();
    final store = BackupStore(p.join(tmp.path, 'backups'));
    final receiver = ClonerServer(
      identity: receiverId,
      info: DeviceInfo(alias: 'New phone', fingerprint: receiverId.fingerprint, port: 0),
      delegate: BackupReceiveDelegate(store),
    );
    await receiver.start(port: 0, address: InternetAddress.loopbackIPv4, loopback: 0);
    addTearDown(receiver.stop);

    final (la, lb) = FakeLink.pair();
    final sender = UsbTunnel(UsbMux(la)..start(), listenPort: 0, targetPort: 0);
    await sender.start();
    await UsbTunnel(UsbMux(lb)..start(), listenPort: 0, targetPort: receiver.cablePort!).start();

    final src = File(p.join(tmp.path, 'IMG_0001.jpg'))..writeAsBytesSync(randomBytes(3 * 1024 * 1024 + 5, 7));
    final client = ClonerClient(self: DeviceInfo(alias: 'Old phone', fingerprint: senderId.fingerprint, port: 53317));
    final target = await client.probe('127.0.0.1', port: sender.port!, https: false);
    expect(target.fingerprint, receiverId.fingerprint);
    final result = await SendJob(
      client: client,
      target: target,
      files: [OutgoingFile.fromFile(src, category: ContentCategory.photos, relPath: 'DCIM/Camera/IMG_0001.jpg')],
    ).run();
    expect(result.outcome, SendOutcome.completed, reason: '${result.error}');
    final dir = store.deviceDir(client.self);
    expect(File(p.join(dir, 'photos', 'DCIM', 'Camera', 'IMG_0001.jpg')).readAsBytesSync(), src.readAsBytesSync());
  });
}
