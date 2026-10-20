import 'dart:convert';

import '../protocol/constants.dart';
import '../protocol/device_info.dart';

/// How two devices reach each other. All modes end up as a TCP/IP link, so
/// the transfer code is the same; the mode only changes the setup steps the
/// UI walks the user through and how the peer is found.
enum ConnectionMode {
  /// Both on the same Wi-Fi. Multicast discovery.
  wifi,

  /// No router: the old phone opens a hotspot, the new phone joins it from a
  /// QR code.
  hotspot,

  /// USB-C to USB-C (or OTG) cable between two phones with USB tethering
  /// enabled on one of them. Multicast is unreliable here, so the QR code or
  /// a subnet scan connects the pair.
  usbTethering,

  /// Phone plugged into a computer with USB debugging on. The desktop runs
  /// `adb forward tcp:<port> tcp:<port>` and talks to 127.0.0.1.
  adb,
}

/// Payload of the pairing QR code shown by the receiver. Carries everything
/// needed to connect without discovery, plus the certificate fingerprint so
/// the TLS connection is pinned from the first byte.
class PairingCode {
  const PairingCode({
    required this.addresses,
    required this.port,
    required this.fingerprint,
    required this.alias,
    this.https = true,
    this.pin,
    this.wifiSsid,
    this.wifiPassword,
  });

  /// Every IPv4 address of the receiver; the scanner tries each.
  final List<String> addresses;
  final int port;
  final String fingerprint;
  final String alias;
  final bool https;
  final String? pin;

  /// Hotspot credentials, so the scanner can join the network first.
  final String? wifiSsid;
  final String? wifiPassword;

  static const scheme = 'mobilecloner';

  String encode() => Uri(
    scheme: scheme,
    host: 'pair',
    queryParameters: {
      'v': '1',
      'a': addresses.join(','),
      'p': '$port',
      'f': fingerprint,
      'n': alias,
      if (!https) 's': 'http',
      'pin': ?pin,
      'ssid': ?wifiSsid,
      'pw': ?wifiPassword,
    },
  ).toString();

  static PairingCode? tryDecode(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != scheme || uri.host != 'pair') return null;
    final q = uri.queryParameters;
    final addresses = (q['a'] ?? '').split(',').where((a) => a.isNotEmpty).toList();
    if (addresses.isEmpty || q['f'] == null) return null;
    return PairingCode(
      addresses: addresses,
      port: int.tryParse(q['p'] ?? '') ?? defaultPort,
      fingerprint: q['f']!,
      alias: q['n'] ?? 'Device',
      https: q['s'] != 'http',
      pin: q['pin'],
      wifiSsid: q['ssid'],
      wifiPassword: q['pw'],
    );
  }

  /// Placeholder device for an address; the real info comes from `register`.
  Device deviceFor(String ip) => Device(
    ip: ip,
    info: DeviceInfo(
      alias: alias,
      fingerprint: fingerprint,
      port: port,
      protocol: https ? ProtocolType.https : ProtocolType.http,
    ),
  );

  @override
  String toString() => jsonEncode({'addresses': addresses, 'port': port, 'alias': alias});
}
