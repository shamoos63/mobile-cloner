import 'dart:async';
import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Where the phone-to-phone USB cable link is (`UsbLink.kt`).
enum UsbLinkState {
  idle,

  /// Looking, but no phone on the cable (or this phone can't be USB host).
  noDevice,

  /// Android's "Allow HK Cloner to access ..." dialog is up.
  permission,

  /// The other phone was asked to switch to accessory mode.
  switching,
  connected,

  /// The thing on the cable is not a phone that can do accessory mode.
  unsupported,
  denied,
  detached,
  error,
}

/// Dart side of the Android Open Accessory cable link. [connections] gives
/// a fresh [MuxTransport] each time the link comes up; it ends (with an
/// error) when the cable is pulled.
class UsbLink extends ChangeNotifier {
  UsbLink._();
  static final instance = UsbLink._();

  static const _ctl = MethodChannel('mobile_cloner/usb_ctl');
  static const _events = EventChannel('mobile_cloner/usb');

  UsbLinkState state = UsbLinkState.idle;

  /// `host` (this phone drives the cable) or `accessory`.
  String? role;
  String? detail;

  StreamSubscription<Object?>? _sub;
  StreamController<Uint8List>? _incoming;
  final _connections = StreamController<MuxTransport>.broadcast();

  Stream<MuxTransport> get connections => _connections.stream;

  void init() {
    _sub ??= _events.receiveBroadcastStream().listen(_onEvent, onError: (Object e) => debugPrint('USB events: $e'));
  }

  /// Finds the other phone and sets up the link (asks for USB access and
  /// switches the other phone to accessory mode when this one is host).
  Future<void> start() async {
    init();
    try {
      _apply(await _ctl.invokeMapMethod<String, Object?>('start'));
    } on PlatformException catch (e) {
      _apply({'state': 'error', 'detail': e.message});
    }
  }

  Future<void> stop() => _ctl.invokeMethod('stop');

  /// The other phone plugged in and made this one its accessory.
  Future<bool> accessoryPresent() async {
    try {
      return await _ctl.invokeMethod<bool>('accessoryPresent') ?? false;
    } on PlatformException {
      return false;
    }
  }

  void _onEvent(Object? e) {
    if (e is Uint8List) {
      _incoming?.add(e);
    } else if (e is Map) {
      _apply(e.cast<String, Object?>());
    }
  }

  void _apply(Map<String, Object?>? m) {
    if (m == null) return;
    final next = UsbLinkState.values.asNameMap()['${m['state']}'] ?? UsbLinkState.error;
    role = m['role'] as String?;
    detail = m['detail'] as String?;
    if (next == UsbLinkState.connected && _incoming == null) {
      final incoming = _incoming = StreamController<Uint8List>();
      _connections.add(_Transport(incoming.stream));
    } else if (next != UsbLinkState.connected && _incoming != null) {
      _incoming!
        ..addError(SocketException(detail ?? 'USB cable link lost'))
        ..close();
      _incoming = null;
    }
    state = next;
    notifyListeners();
  }

  static Future<void> _write(Uint8List bytes) async {
    try {
      await _ctl.invokeMethod<void>('write', bytes);
    } on PlatformException catch (e) {
      throw SocketException(e.message ?? 'USB write failed');
    }
  }
}

class _Transport implements MuxTransport {
  _Transport(this.incoming);

  @override
  final Stream<Uint8List> incoming;

  @override
  Future<void> write(Uint8List bytes) => UsbLink._write(bytes);
}
