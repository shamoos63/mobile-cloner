import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_cloner/src/platform/usb_link.dart';
import 'package:mobile_cloner/src/ui/widgets/usb_cable_status.dart';

void main() {
  test('every cable state has a message; dead ends offer the hotspot', () {
    for (final s in UsbLinkState.values) {
      expect(usbCableMessage(s).text, isNotEmpty, reason: s.name);
    }
    expect(usbCableMessage(UsbLinkState.noDevice).suggestHotspot, isFalse);
    expect(usbCableMessage(UsbLinkState.noDevice, waitedLong: true).suggestHotspot, isTrue);
    expect(usbCableMessage(UsbLinkState.noDevice, waitedLong: true).text, contains('OTG'));
    expect(usbCableMessage(UsbLinkState.unsupported).suggestHotspot, isTrue);
    expect(usbCableMessage(UsbLinkState.connected).suggestHotspot, isFalse);
    expect(usbCableMessage(UsbLinkState.permission).text, contains('Allow'));
  });
}
