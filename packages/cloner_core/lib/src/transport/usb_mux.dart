import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../protocol/constants.dart';

/// Local port that leads through a USB cable link to the other phone's
/// plain-HTTP [loopbackPort] listener. Connect with `https: false`.
const usbTunnelPort = 53321;

/// A byte pipe to one other device, e.g. an Android Open Accessory link
/// over a USB cable. No message boundaries; [UsbMux] adds them.
abstract interface class MuxTransport {
  /// Bytes from the other side. Ends (or errors) when the link drops.
  Stream<Uint8List> get incoming;

  /// Completes once [bytes] are handed to the link, which gives backpressure.
  Future<void> write(Uint8List bytes);
}

/// Many TCP-like channels over one [MuxTransport], so the HTTP transfer
/// code (several upload lanes at once) runs over a single USB link.
///
/// Frame: `type u8 | stream u32 | length u32 | payload`. Bit 31 of `stream`
/// is set when the frame's sender opened the channel, so both sides number
/// their own channels without clashing. Each channel has a credit window:
/// the sender may have at most [window] unacknowledged bytes in flight, the
/// receiver returns credit once it has handed the bytes on. A link that
/// drops ends every channel with an error, which the transfer code treats
/// like any lost connection (and resumes).
class UsbMux {
  UsbMux(this.transport, {this.window = 1 << 20, this.maxFrame = 64 * 1024, this.batch = 256 * 1024});

  final MuxTransport transport;

  /// Bytes a channel may send before the other side acknowledges them.
  final int window;

  /// Largest DATA payload.
  final int maxFrame;

  /// Frames are gathered into writes of up to this many bytes.
  final int batch;

  static const version = 1;
  static const _headerSize = 9;
  static const _openedBySender = 0x80000000;

  final _channels = <int, MuxChannel>{};
  final _incoming = StreamController<MuxChannel>();
  final _closed = Completer<void>();
  var _nextId = 1;
  StreamSubscription<Uint8List>? _sub;

  /// Channels the other side opened.
  Stream<MuxChannel> get incomingChannels => _incoming.stream;

  /// Completes when the link is gone.
  Future<void> get closed => _closed.future;
  bool get isClosed => _closed.isCompleted;

  void start() {
    _sub = transport.incoming.listen(_onBytes, onError: (Object e) => _drop(e), onDone: () => _drop('USB link closed'));
    _send(_Frame.hello, 0, Uint8List.fromList([version]));
  }

  /// Opens a channel to the other side.
  MuxChannel open() {
    if (isClosed) throw const SocketException('USB link closed');
    final ch = MuxChannel._(this, _nextId++, openedByMe: true);
    _channels[ch._key] = ch;
    _send(_Frame.open, ch._wire, Uint8List(0));
    return ch;
  }

  /// Ends every channel and stops reading.
  Future<void> close() async {
    await _sub?.cancel();
    _drop('USB link closed');
  }

  // --- Sending -----------------------------------------------------------

  final _queue = ListQueue<Uint8List>();
  var _queued = 0;
  var _pumping = false;
  final _drainWaiters = <Completer<void>>[];

  /// Queues a frame; [_drained] waits for the queue to empty.
  void _send(int type, int wire, Uint8List payload) {
    if (isClosed) return;
    final frame = Uint8List(_headerSize + payload.length);
    ByteData.sublistView(frame)
      ..setUint8(0, type)
      ..setUint32(1, wire)
      ..setUint32(5, payload.length);
    frame.setRange(_headerSize, frame.length, payload);
    _queue.add(frame);
    _queued += frame.length;
    if (!_pumping) unawaited(_pump());
  }

  /// Waits while more than [window] bytes are queued for the link.
  Future<void> _drained() async {
    while (_queued > window && !isClosed) {
      final c = Completer<void>();
      _drainWaiters.add(c);
      await c.future;
    }
    if (isClosed) throw const SocketException('USB link closed');
  }

  Future<void> _pump() async {
    _pumping = true;
    try {
      while (_queue.isNotEmpty && !isClosed) {
        final out = BytesBuilder(copy: false);
        while (_queue.isNotEmpty && (out.isEmpty || out.length + _queue.first.length <= batch)) {
          out.add(_queue.removeFirst());
        }
        final sent = out.length;
        // A USB bulk transfer that is an exact multiple of the packet size
        // (64/512/1024) and shorter than the reader's buffer never completes
        // on the other side. A pad frame makes the length odd.
        if (out.length % 64 == 0) out.add(Uint8List(_headerSize)..[0] = _Frame.pad);
        try {
          await transport.write(out.takeBytes());
        } catch (e) {
          _drop(e);
          return;
        }
        _queued -= sent;
        if (_queued <= window) {
          for (final w in _drainWaiters) {
            w.complete();
          }
          _drainWaiters.clear();
        }
      }
    } finally {
      _pumping = false;
    }
  }

  // --- Receiving ---------------------------------------------------------

  Uint8List _buf = Uint8List(0);
  var _gotHello = false;

  void _onBytes(Uint8List chunk) {
    _buf = _buf.isEmpty ? chunk : (BytesBuilder(copy: false)..add(_buf)..add(chunk)).takeBytes();
    var offset = 0;
    while (_buf.length - offset >= _headerSize) {
      final h = ByteData.sublistView(_buf, offset, offset + _headerSize);
      final length = h.getUint32(5);
      if (_buf.length - offset < _headerSize + length) break;
      final payload = Uint8List.sublistView(_buf, offset + _headerSize, offset + _headerSize + length);
      _onFrame(h.getUint8(0), h.getUint32(1), payload);
      offset += _headerSize + length;
      if (isClosed) return;
    }
    _buf = offset == _buf.length ? Uint8List(0) : Uint8List.fromList(Uint8List.sublistView(_buf, offset));
  }

  void _onFrame(int type, int wire, Uint8List payload) {
    final openedByMe = wire & _openedBySender == 0;
    final id = wire & ~_openedBySender;
    final key = MuxChannel._keyOf(id, openedByMe: openedByMe);
    switch (type) {
      case _Frame.hello:
        // The other side (re)started: channels from before are dead.
        if (_gotHello) _resetChannels();
        _gotHello = true;
      case _Frame.open:
        final ch = MuxChannel._(this, id, openedByMe: false);
        _channels[key] = ch;
        _incoming.add(ch);
      case _Frame.data:
        _channels[key]?._deliver(Uint8List.fromList(payload));
      case _Frame.close:
        _channels[key]?._remoteClosed();
      case _Frame.credit:
        _channels[key]?._addCredit(ByteData.sublistView(payload).getUint32(0));
      case _Frame.pad:
        break;
    }
  }

  void _resetChannels() {
    for (final ch in [..._channels.values]) {
      ch._fail(const SocketException('USB link restarted'));
    }
    _channels.clear();
  }

  void _drop(Object reason) {
    if (isClosed) return;
    _closed.complete();
    final error = reason is SocketException ? reason : SocketException('USB link lost: $reason');
    for (final ch in [..._channels.values]) {
      ch._fail(error);
    }
    _channels.clear();
    _queue.clear();
    for (final w in _drainWaiters) {
      w.complete();
    }
    _drainWaiters.clear();
    unawaited(_incoming.close());
  }
}

abstract final class _Frame {
  static const hello = 1;
  static const open = 2;
  static const data = 3;
  static const close = 4;
  static const credit = 5;
  static const pad = 6;
}

/// One bidirectional byte channel inside a [UsbMux].
class MuxChannel {
  MuxChannel._(this._mux, this._id, {required this.openedByMe}) : _credit = _mux.window;

  final UsbMux _mux;
  final int _id;
  final bool openedByMe;
  int _credit;
  Completer<void>? _creditWaiter;
  final _data = StreamController<Uint8List>();
  var _localClosed = false;
  var _remoteDone = false;

  static int _keyOf(int id, {required bool openedByMe}) => openedByMe ? id : id | UsbMux._openedBySender;
  int get _key => _keyOf(_id, openedByMe: openedByMe);

  /// Our side of the wire: bit 31 says "the sender of this frame opened it".
  int get _wire => openedByMe ? _id | UsbMux._openedBySender : _id;

  /// Bytes from the other side. Call [ack] once each chunk is handed on.
  Stream<Uint8List> get data => _data.stream;

  /// Sends [bytes], waiting for credit and for the link to drain.
  Future<void> write(Uint8List bytes) async {
    var offset = 0;
    while (offset < bytes.length) {
      if (_localClosed) throw const SocketException('Channel closed');
      while (_credit <= 0) {
        if (_mux.isClosed) throw const SocketException('USB link closed');
        final c = _creditWaiter = Completer<void>();
        await c.future;
      }
      final n = min(min(_credit, _mux.maxFrame), bytes.length - offset);
      _credit -= n;
      _mux._send(_Frame.data, _wire, Uint8List.sublistView(bytes, offset, offset + n));
      offset += n;
      await _mux._drained();
    }
  }

  /// Returns [bytes] of credit to the sender.
  void ack(int bytes) {
    // Still acknowledged after our own close(): the other direction lives on.
    if (bytes <= 0 || _mux.isClosed) return;
    _mux._send(_Frame.credit, _wire, Uint8List(4)..buffer.asByteData().setUint32(0, bytes));
  }

  /// No more data from this side.
  void close() {
    if (_localClosed) return;
    _localClosed = true;
    _mux._send(_Frame.close, _wire, Uint8List(0));
    _wakeWriter();
    _forgetIfDone();
  }

  void _deliver(Uint8List bytes) {
    if (!_data.isClosed) _data.add(bytes);
  }

  void _remoteClosed() {
    _remoteDone = true;
    unawaited(_data.close());
    _wakeWriter();
    _forgetIfDone();
  }

  void _addCredit(int bytes) {
    _credit += bytes;
    _wakeWriter();
  }

  void _fail(Object error) {
    _localClosed = _remoteDone = true;
    if (!_data.isClosed) {
      _data.addError(error);
      unawaited(_data.close());
    }
    _wakeWriter();
  }

  void _wakeWriter() {
    final w = _creditWaiter;
    _creditWaiter = null;
    if (w != null && !w.isCompleted) w.complete();
  }

  void _forgetIfDone() {
    if (_localClosed && _remoteDone) _mux._channels.remove(_key);
  }
}

/// Makes a [UsbMux] look like `adb forward` in both directions: a local
/// connection to 127.0.0.1:[listenPort] comes out on the other device at
/// 127.0.0.1:[targetPort] (its plain-HTTP transfer listener).
class UsbTunnel {
  UsbTunnel(this.mux, {this.listenPort = usbTunnelPort, this.targetPort = loopbackPort});

  final UsbMux mux;
  final int listenPort;
  final int targetPort;
  ServerSocket? _server;
  final _sockets = <Socket>{};

  /// Port actually listened on (useful when [listenPort] is 0).
  int? get port => _server?.port;

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, listenPort);
    _server!.listen((socket) {
      try {
        _pipe(socket, mux.open());
      } catch (_) {
        socket.destroy();
      }
    });
    mux.incomingChannels.listen((ch) async {
      try {
        _pipe(await Socket.connect(InternetAddress.loopbackIPv4, targetPort), ch);
      } catch (_) {
        ch.close();
      }
    });
    unawaited(mux.closed.then((_) => stop()));
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    for (final s in [..._sockets]) {
      s.destroy();
    }
    _sockets.clear();
  }

  void _pipe(Socket socket, MuxChannel ch) {
    _sockets.add(socket);
    socket.setOption(SocketOption.tcpNoDelay, true);
    late final StreamSubscription<Uint8List> sub;
    sub = socket.listen(
      (bytes) => sub.pause(ch.write(bytes).catchError((Object _) => socket.destroy())),
      onDone: ch.close,
      onError: (Object _) => ch.close(),
      cancelOnError: true,
    );
    () async {
      try {
        await for (final chunk in ch.data) {
          socket.add(chunk);
          await socket.flush();
          ch.ack(chunk.length);
        }
        await socket.close();
      } catch (_) {
        socket.destroy();
      } finally {
        _sockets.remove(socket);
      }
    }();
  }
}
