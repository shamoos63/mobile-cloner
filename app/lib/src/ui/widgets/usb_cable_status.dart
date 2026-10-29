import '../../l10n.dart';
import '../../platform/usb_link.dart';

/// What to tell the user about the phone-to-phone cable. [waitedLong] is
/// true once nothing has happened for a while after choosing the cable.
({String text, bool suggestHotspot}) usbCableMessage(UsbLinkState state, {String? detail, bool waitedLong = false}) =>
    switch (state) {
      UsbLinkState.connected => (
        text: tr.usbConnected,
        suggestHotspot: false,
      ),
      UsbLinkState.permission => (text: tr.usbPermission, suggestHotspot: false),
      UsbLinkState.switching => (
        text: tr.usbSwitching,
        suggestHotspot: false,
      ),
      UsbLinkState.denied => (
        text: tr.usbDenied,
        suggestHotspot: false,
      ),
      UsbLinkState.unsupported => (
        // The platform's detail is English; the message is in the app's language.
        text: tr.usbUnsupported,
        suggestHotspot: true,
      ),
      UsbLinkState.detached => (
        text: tr.usbDetached,
        suggestHotspot: false,
      ),
      UsbLinkState.error => (text: tr.usbError, suggestHotspot: true),
      UsbLinkState.idle || UsbLinkState.noDevice when waitedLong => (
        text: tr.usbNoLink,
        suggestHotspot: true,
      ),
      UsbLinkState.idle || UsbLinkState.noDevice => (
        text: tr.usbConnectHint,
        suggestHotspot: false,
      ),
    };
