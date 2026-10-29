import 'package:cloner_core/cloner_core.dart';
import 'package:test/test.dart';

void main() {
  test('classifies Android, Linux and Windows interface names', () {
    expect(
      {
        for (final n in [
          'wlan0',
          'swlan0',
          'ap0',
          'rndis0',
          'usb0',
          'ncm0',
          'eth0',
          'rmnet_data0',
          'ccmni1',
          'v4-rmnet_data2',
          'tun0',
          'wlp2s0',
          'Wi-Fi',
          'Ethernet',
          'en0',
          'lo',
        ])
          n: LinkKind.of(n),
      },
      {
        'wlan0': LinkKind.wifi,
        'swlan0': LinkKind.hotspot,
        'ap0': LinkKind.hotspot,
        'rndis0': LinkKind.usbTether,
        'usb0': LinkKind.usbTether,
        'ncm0': LinkKind.usbTether,
        'eth0': LinkKind.ethernet,
        'rmnet_data0': LinkKind.cellular,
        'ccmni1': LinkKind.cellular,
        'v4-rmnet_data2': LinkKind.cellular,
        'tun0': LinkKind.tunnel,
        'wlp2s0': LinkKind.wifi,
        'Wi-Fi': LinkKind.wifi,
        'Ethernet': LinkKind.ethernet,
        'en0': LinkKind.other,
        'lo': LinkKind.other,
      },
    );
    expect(LinkKind.cellular.local, isFalse);
    expect(LinkKind.usbTether.cable && LinkKind.ethernet.cable, isTrue);
  });

  test('scans every local link, cable links first, each /24 once', () {
    final targets = Discovery.scanTargets(const [
      LocalLink('wlan0', '192.168.1.23', LinkKind.wifi),
      LocalLink('rndis0', '192.168.42.129', LinkKind.usbTether),
      LocalLink('swlan0', '192.168.1.99', LinkKind.hotspot),
    ]);
    expect(targets.length, 2 * 254);
    expect(targets.first, '192.168.42.1');
    expect(targets[254], '192.168.1.1');
    expect(targets.last, '192.168.1.254');
  });
}
