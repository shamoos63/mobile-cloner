import '../../platform/usb_link.dart';

/// What to tell the user about the phone-to-phone cable. [waitedLong] is
/// true once nothing has happened for a while after choosing the cable.
({String text, bool suggestHotspot}) usbCableMessage(UsbLinkState state, {String? detail, bool waitedLong = false}) =>
    switch (state) {
      UsbLinkState.connected => (
        text: 'Connected by cable. On the old phone, tap Send: this phone is at the top of the list.',
        suggestHotspot: false,
      ),
      UsbLinkState.permission => (text: 'Tap Allow on this phone so HK Cloner can use the cable.', suggestHotspot: false),
      UsbLinkState.switching => (
        text: 'Almost there. On the other phone, tap OK to open HK Cloner, then Allow.',
        suggestHotspot: false,
      ),
      UsbLinkState.denied => (
        text: 'USB access was not allowed. Unplug the cable, plug it back in and tap Allow.',
        suggestHotspot: false,
      ),
      UsbLinkState.unsupported => (
        text: '${detail ?? 'The device on the cable cannot do phone-to-phone transfers'}. '
            '"No Wi-Fi around" works without a cable or a router.',
        suggestHotspot: true,
      ),
      UsbLinkState.detached => (
        text: 'The cable was unplugged. Plug it back in: the transfer continues where it stopped.',
        suggestHotspot: false,
      ),
      UsbLinkState.error => (text: detail ?? 'The cable link failed. Unplug it and plug it back in.', suggestHotspot: true),
      UsbLinkState.idle || UsbLinkState.noDevice when waitedLong => (
        text: 'The phones have not found each other over the cable. One of them must act as USB host (OTG): try '
            'turning the cable around, another USB-C cable, or an OTG adapter on the new phone. Or use "No Wi-Fi '
            'around".',
        suggestHotspot: true,
      ),
      UsbLinkState.idle || UsbLinkState.noDevice => (
        text: 'Connect the phones with a USB-C cable (or an OTG adapter) and open HK Cloner on both. '
            'Then tap Allow on both phones.',
        suggestHotspot: false,
      ),
    };
