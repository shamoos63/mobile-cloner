import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../client/cloner_client.dart';
import '../protocol/constants.dart';
import '../protocol/device_info.dart';

/// LocalSend-style discovery: UDP multicast announcements, answered with an
/// HTTP `register` call (or a UDP reply as fallback), plus a legacy subnet
/// scan for networks that drop multicast (common on hotspots and USB
/// tethering).
class Discovery {
  Discovery({
    required this.client,
    required DeviceInfo Function() self,
    this.port = defaultPort,
    this.group = defaultMulticastGroup,
  }) : _self = self;

  final ClonerClient client;
  final DeviceInfo Function() _self;
  final int port;
  final String group;

  final _devices = StreamController<Device>.broadcast();
  final List<RawDatagramSocket> _sockets = [];

  Stream<Device> get devices => _devices.stream;

  /// Reports a device found some other way (incoming `register`, QR code).
  void report(Device device) => _devices.add(device);

  Future<void> start() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
      reusePort: !Platform.isWindows && !Platform.isAndroid,
    );
    for (final iface in interfaces) {
      try {
        socket.joinMulticast(InternetAddress(group), iface);
      } catch (_) {
        // Interface without multicast support.
      }
    }
    socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket.receive();
        if (dg != null) _onDatagram(socket, dg);
      },
      // Send failures (e.g. EPERM when the network blocks multicast) arrive
      // here asynchronously; the subnet scan still finds peers.
      onError: (Object _) {},
    );
    _sockets.add(socket);
    announce();
  }

  /// Sends our announcement. Call again when the user pulls to refresh.
  void announce() {
    final payload = utf8.encode(jsonEncode(_self().toJson(withAnnounce: true, announce: true)));
    for (final s in _sockets) {
      try {
        s.send(payload, InternetAddress(group), port);
      } on SocketException {
        // Multicast blocked on this network.
      }
    }
  }

  void _onDatagram(RawDatagramSocket socket, Datagram dg) {
    final Map<String, Object?> json;
    try {
      json = (jsonDecode(utf8.decode(dg.data)) as Map).cast();
    } catch (_) {
      return;
    }
    final info = DeviceInfo.fromJson(json);
    final self = _self();
    if (info.fingerprint == self.fingerprint) return;
    final device = Device(ip: dg.address.address, info: info);
    _devices.add(device);
    if (json['announce'] == true) {
      client.register(device).catchError((_) {
        final reply = utf8.encode(jsonEncode(self.toJson(withAnnounce: true, announce: false)));
        socket.send(reply, InternetAddress(group), port);
        return self;
      });
    }
  }

  /// Tries `register` on every host of each local /24 network. Needed on
  /// USB tethering and some hotspots where multicast is dropped.
  Future<void> scanSubnets({int concurrency = 50}) async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    final own = <String>{};
    final targets = <String>[];
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (addr.isLoopback || addr.isLinkLocal) continue;
        own.add(addr.address);
        final prefix = addr.address.substring(0, addr.address.lastIndexOf('.'));
        for (var i = 1; i < 255; i++) {
          targets.add('$prefix.$i');
        }
      }
    }
    targets.removeWhere(own.contains);
    var index = 0;
    Future<void> worker() async {
      while (index < targets.length) {
        final ip = targets[index++];
        try {
          _devices.add(await client.probe(ip, port: port, timeout: const Duration(milliseconds: 800)));
        } catch (_) {}
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));
  }

  void stop() {
    for (final s in _sockets) {
      s.close();
    }
    _sockets.clear();
  }

  Future<void> dispose() async {
    stop();
    await _devices.close();
  }
}
