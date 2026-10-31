import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:test/test.dart';

class _NoopDelegate implements ReceiveDelegate {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a taken port falls back to a free one instead of failing', () async {
    final squatter = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    addTearDown(squatter.close);
    final id = DeviceIdentity.generate();
    ClonerServer server() => ClonerServer(
      identity: id,
      info: DeviceInfo(alias: 'Mac', fingerprint: id.fingerprint, port: squatter.port),
      delegate: _NoopDelegate(),
    );

    await expectLater(server().start(port: squatter.port, loopback: null), throwsA(isA<SocketException>()));

    final s = server();
    await s.start(port: squatter.port, loopback: null, fallbackToFreePort: true);
    addTearDown(s.stop);
    expect(s.port, isNot(squatter.port));
    expect(s.port, greaterThan(0));
  });
}
