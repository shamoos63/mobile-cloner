import 'dart:io';

/// What a network interface is, judged by its name. Android and desktop
/// kernels name them consistently enough for the UI to say "cable link is
/// up" and for discovery to skip links that can't reach a nearby device.
enum LinkKind {
  /// Joined to a Wi-Fi network (`wlan0`, `en0` on macOS is [other]).
  wifi,

  /// This phone's own hotspot (`swlan0` on Samsung, `ap0`, `softap0`, `wlan1`).
  hotspot,

  /// USB tethering on the phone that shares its network (`rndis0`, `usb0`,
  /// `ncm0`): the cable link as seen from the tethering phone.
  usbTether,

  /// Wired Ethernet, including a USB Ethernet link (`eth0`): the cable link
  /// as seen from a phone or computer on the other end of USB tethering.
  ethernet,

  /// Mobile data (`rmnet*`, `ccmni*`, `pdp*`). Never leads to a nearby device.
  cellular,

  /// VPN and other tunnels (`tun*`, `ppp*`, `ipsec*`, `wg*`).
  tunnel,

  other;

  /// Worth scanning and putting in the pairing code.
  bool get local => this != cellular && this != tunnel;

  /// Created by a USB cable between two devices.
  bool get cable => this == usbTether || this == ethernet;

  static LinkKind of(String name) {
    final n = name.toLowerCase();
    bool starts(List<String> p) => p.any(n.startsWith);
    if (starts(['rmnet', 'ccmni', 'pdp', 'v4-rmnet', 'clat', 'seth_', 'wwan'])) return cellular;
    if (starts(['tun', 'ppp', 'ipsec', 'wg', 'utun'])) return tunnel;
    if (starts(['rndis', 'usb', 'ncm'])) return usbTether;
    if (starts(['swlan', 'ap', 'softap', 'wlan1', 'p2p'])) return hotspot;
    if (starts(['wlan', 'wifi', 'wi-fi', 'wl'])) return wifi;
    if (starts(['eth', 'enx', 'eno', 'enp'])) return ethernet;
    return other;
  }
}

/// One IPv4 address of this device and the kind of link it is on.
class LocalLink {
  const LocalLink(this.interface, this.address, this.kind);

  final String interface;
  final String address;
  final LinkKind kind;

  /// Every usable IPv4 address: no loopback, link-local, mobile data or VPN.
  static Future<List<LocalLink>> list() async =>
      fromInterfaces(await NetworkInterface.list(type: InternetAddressType.IPv4));

  static List<LocalLink> fromInterfaces(Iterable<NetworkInterface> interfaces) => [
    for (final iface in interfaces)
      for (final a in iface.addresses)
        if (a.type == InternetAddressType.IPv4 && !a.isLoopback && !a.isLinkLocal && LinkKind.of(iface.name).local)
          LocalLink(iface.name, a.address, LinkKind.of(iface.name)),
  ];

  @override
  String toString() => '$interface $address (${kind.name})';
}
