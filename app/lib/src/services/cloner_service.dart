import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/android_bridge.dart';
import '../platform/usb_link.dart';
import '../restore/phone_receive_delegate.dart';
import '../restore/receive_journal.dart';
import '../l10n.dart';
import '../version.dart';
import 'app_settings.dart';
import 'format.dart';

/// A request from a sender waiting for the user to tap Accept.
class IncomingRequest {
  IncomingRequest(this.sender, this.files);
  final Device sender;
  final List<FileDto> files;
  final _answer = Completer<bool>();
  Future<bool> get answer => _answer.future;
  void respond(bool accept) {
    if (!_answer.isCompleted) _answer.complete(accept);
  }

  int get totalBytes => files.fold(0, (a, f) => a + f.size);
  Map<ContentCategory, int> get countByCategory {
    final m = <ContentCategory, int>{};
    for (final f in files) {
      m[f.category] = (m[f.category] ?? 0) + 1;
    }
    return m;
  }
}

enum SendState { idle, preparing, sending, interrupted, done, failed }

/// App-wide state: identity, server, discovery, peers, the current send or
/// receive, battery watch and the resume checkpoint.
class ClonerService extends ChangeNotifier {
  ClonerService._();
  static final instance = ClonerService._();

  final bridge = AndroidBridge.instance;
  late DeviceIdentity identity;
  late DeviceInfo self;
  AndroidDeviceInfo? android;
  late ClonerServer server;
  late ClonerClient client;
  late Discovery discovery;
  late String dataDir;
  late CheckpointStore checkpointStore;
  BackupStore? backupStore;
  bool ready = false;
  String? startupError;

  bool get isAndroid => Platform.isAndroid;
  bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  // Discovery
  final Map<String, Device> peers = {};

  // Own health
  PeerStatus localStatus = const PeerStatus();
  bool _warnedLowBattery = false;
  Timer? _batteryTimer;

  // Receiving
  IncomingRequest? pendingRequest;
  ReceiveSession? receiveSession;
  final SpeedMeter receiveMeter = SpeedMeter();
  int _lastReceived = 0;
  PeerStatus? senderStatus;
  RestoreReport? lastReport;
  ReceiveSession? lastBackupSession;

  // Sending
  SendState sendState = SendState.idle;
  SendJob? _job;
  Device? sendTarget;
  SendProgress? sendProgress;
  SendResult? sendResult;
  List<OutgoingFile> _lastFiles = const [];
  List<OutgoingFile> get lastFiles => _lastFiles;
  TransferCheckpoint? checkpoint;

  Future<void> init() async {
    try {
      final support = await getApplicationSupportDirectory();
      dataDir = support.path;
      checkpointStore = CheckpointStore(p.join(dataDir, 'transfer_checkpoint.json'));
      identity = await _loadIdentity();
      await AppSettings.instance.load();
      if (isAndroid) android = await bridge.deviceInfo();
      self = _buildSelf();
      client = ClonerClient(self: self);
      server = ClonerServer(
        identity: identity,
        info: self,
        delegate: await _buildDelegate(),
        localStatus: () => localStatus,
        apps: isAndroid ? _PhoneAppCatalog(bridge) : null,
      );
      await server.start();
      server.events.listen(_onServerEvent);
      discovery = Discovery(client: client, self: () => self);
      discovery.devices.listen(_onPeer);
      try {
        await discovery.start();
      } catch (e) {
        debugPrint('Multicast unavailable: $e');
      }
      checkpoint = await checkpointStore.load();
      _startBatteryWatch();
      _initUsbCable();
      ready = true;
    } catch (e, st) {
      startupError = '$e';
      debugPrint('$e\n$st');
    }
    notifyListeners();
  }

  Future<DeviceIdentity> _loadIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('identity');
    if (stored != null) return DeviceIdentity.fromJson((jsonDecode(stored) as Map).cast());
    // RSA key generation takes a few seconds on a phone; keep the UI smooth.
    final id = await Isolate.run(DeviceIdentity.generate);
    await prefs.setString('identity', jsonEncode(id.toJson()));
    return id;
  }

  DeviceInfo _buildSelf() {
    final a = android;
    final platform = isAndroid ? ClonerPlatform.android : ClonerPlatform.parse(Platform.operatingSystem);
    return DeviceInfo(
      alias: AppSettings.instance.deviceName ?? defaultDeviceName,
      fingerprint: identity.fingerprint,
      deviceModel: a?.model ?? Platform.operatingSystem,
      deviceType: isAndroid ? DeviceType.mobile : DeviceType.desktop,
      cloner: ClonerPeerInfo(
        platform: platform,
        sdkInt: a?.sdkInt,
        osVersion: a?.release ?? Platform.operatingSystemVersion,
        appVersion: appVersionName,
        capabilities: isAndroid ? const {'media', 'contacts', 'whatsapp', 'files'} : const {'backup'},
      ),
    );
  }

  /// The phone's own name ("Samsung SM-A536E"), used unless renamed.
  String get defaultDeviceName {
    final a = android;
    return a != null ? '${_titleCase(a.manufacturer)} ${a.model}' : Platform.localHostname;
  }

  /// Renames this device for everyone who finds it from now on.
  Future<void> rename(String? name) async {
    await AppSettings.instance.setDeviceName(name);
    self = _buildSelf();
    server.info = self;
    client.self = self;
    discovery.announce();
    notifyListeners();
  }

  Future<ReceiveDelegate> _buildDelegate() async {
    if (isAndroid) {
      return PhoneReceiveDelegate(
        bridge: bridge,
        info: android!,
        stagingDir: p.join(dataDir, 'incoming'),
        journal: ReceiveJournal(p.join(dataDir, 'receive_journal.json')),
        approve: _askUser,
        onSeen: _onPeer,
        onReport: (r) {
          lastReport = r;
          notifyListeners();
        },
      );
    }
    backupStore = BackupStore(await backupRoot());
    return BackupReceiveDelegate(
      backupStore!,
      approve: _askUser,
      onSeen: _onPeer,
      onFinished: (s) {
        lastBackupSession = s;
        notifyListeners();
      },
    );
  }

  Future<String> backupRoot() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('backupRoot');
    if (saved != null) return saved;
    String base;
    try {
      base = (await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      // No XDG documents dir (minimal Linux installs): use the home folder.
      base = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? dataDir;
    }
    return p.join(base, 'Mobile Cloner Backups');
  }

  /// Changes where desktop backups go. Takes effect for the next session.
  Future<void> setBackupRoot(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backupRoot', path);
    await server.stop();
    server = ClonerServer(
      identity: identity,
      info: self,
      delegate: await _buildDelegate(),
      localStatus: () => localStatus,
      apps: isAndroid ? _PhoneAppCatalog(bridge) : null,
    );
    await server.start();
    server.events.listen(_onServerEvent);
    notifyListeners();
  }

  Future<bool> _askUser(Device sender, List<FileDto> files) async {
    // A sender we were already receiving from is resuming: no second prompt.
    final last = receiveSession;
    if (last != null && last.sender.fingerprint == sender.fingerprint) return true;
    final request = IncomingRequest(sender, files);
    pendingRequest = request;
    notifyListeners();
    final ok = await request.answer.timeout(const Duration(minutes: 4), onTimeout: () => false);
    pendingRequest = null;
    notifyListeners();
    return ok;
  }

  void _onPeer(Device device) {
    if (device.fingerprint == identity.fingerprint) return;
    // The cable is faster and steadier than Wi-Fi: keep it while it's up.
    final known = peers[device.fingerprint];
    if (known != null && isUsbCable(known) && !isUsbCable(device) && _usbTunnel != null) return;
    peers[device.fingerprint] = device;
    notifyListeners();
  }

  // --- USB cable (Android Open Accessory) -------------------------------------

  UsbTunnel? _usbTunnel;

  /// The phone on the other end of the USB cable, once it answered.
  Device? usbPeer;

  bool isUsbCable(Device d) => d.ip == '127.0.0.1' && d.port == usbTunnelPort;

  void _initUsbCable() {
    if (!isAndroid) return;
    final link = UsbLink.instance..init();
    link.connections.listen(_onUsbCable);
    // Opened because the other phone plugged in and made this one its accessory.
    unawaited(link.accessoryPresent().then((present) {
      if (present) unawaited(link.start());
    }));
  }

  /// Looks for the other phone on the cable (Send, Receive > USB cable).
  Future<void> startUsbCable() async {
    if (isAndroid) await UsbLink.instance.start();
  }

  Future<void> _onUsbCable(MuxTransport transport) async {
    await _usbTunnel?.stop();
    final mux = UsbMux(transport)..start();
    final tunnel = UsbTunnel(mux);
    try {
      await tunnel.start();
    } catch (e) {
      debugPrint('USB tunnel: $e');
      await mux.close();
      return;
    }
    _usbTunnel = tunnel;
    unawaited(mux.closed.then((_) {
      if (_usbTunnel != tunnel) return;
      _usbTunnel = null;
      final gone = usbPeer;
      usbPeer = null;
      if (gone != null && peers[gone.fingerprint] == gone) peers.remove(gone.fingerprint);
      notifyListeners();
    }));
    // The other phone's app may still be starting its end of the tunnel.
    for (var i = 0; i < 20 && !mux.isClosed; i++) {
      try {
        final d = await client.probe('127.0.0.1', port: usbTunnelPort, https: false, timeout: const Duration(seconds: 2));
        usbPeer = d;
        _onPeer(d);
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  void _onServerEvent(ServerEvent e) {
    switch (e) {
      case SessionStarted(:final session):
        receiveSession = session;
        _lastReceived = session.receivedBytes;
        lastReport = null;
        _foreground(tr.receivingFrom(session.sender.info.alias), tr.notifStarting, 0);
      case FileProgress(:final session):
        final now = session.receivedBytes;
        receiveMeter.add(now - _lastReceived);
        _lastReceived = now;
        final pct = session.totalBytes == 0 ? 100 : (now * 100 ~/ session.totalBytes);
        _foreground(tr.receivingFrom(session.sender.info.alias),
            tr.notifReceiving(formatBytes(now), formatBytes(session.totalBytes), formatSpeed(receiveMeter.bytesPerSecond)), pct);
      case SessionEnded():
        _stopForeground();
      case PeerStatusReceived(:final status):
        senderStatus = status;
        if (status.isLow) {
          _alert(tr.peerBatteryLowTitle(status.batteryLevel!), tr.peerBatteryLowBody);
        }
    }
    notifyListeners();
  }

  // --- Battery -------------------------------------------------------------

  void _startBatteryWatch() {
    if (!isAndroid) return;
    Future<void> poll() async {
      try {
        final b = await bridge.battery();
        final free = await bridge.freeBytes();
        localStatus = PeerStatus(batteryLevel: b.level, charging: b.charging, freeBytes: free);
        if (localStatus.isLow && !_warnedLowBattery && _busy) {
          _warnedLowBattery = true;
          _alert(tr.selfBatteryLowTitle(b.level!), tr.selfBatteryLowBody);
        }
        if (!localStatus.isLow) _warnedLowBattery = false;
        if (localStatus.isCritical && _job != null) {
          _job!.interrupt(InterruptReason.lowBatterySelf);
        }
        notifyListeners();
      } catch (_) {}
    }

    poll();
    _batteryTimer = Timer.periodic(const Duration(seconds: 15), (_) => poll());
  }

  bool get _busy => sendState == SendState.sending || receiveSession?.state == SessionState.active;

  void _alert(String title, String text) {
    if (isAndroid) unawaited(bridge.alert(title, text));
  }

  void _foreground(String title, String text, int pct) {
    if (!isAndroid) return;
    unawaited(bridge.serviceUpdate(title: title, text: text, progress: pct));
    unawaited(bridge.keepScreenOn(AppSettings.instance.keepScreenOn));
  }

  void _stopForeground() {
    if (!isAndroid) return;
    unawaited(bridge.serviceStop());
    unawaited(bridge.keepScreenOn(false));
  }

  // --- Connecting ------------------------------------------------------------

  /// Whether this phone may look for nearby devices. Android 13+ asks for
  /// "Nearby devices", older versions for "Location"; without it Wi-Fi and
  /// cable discovery quietly find nothing on some phones (Samsung).
  PermissionState discoveryAccess = PermissionState.granted;

  /// The one permission step every way of connecting runs first: on the
  /// home screen, before sending, before receiving and on every mode
  /// switch. Asks when Android still can; with [ask] false only re-reads
  /// the state (back from Settings).
  Future<bool> ensureDiscoveryAccess({bool ask = true}) async {
    if (!isAndroid) return true;
    final names = AndroidPermission.discovery(android!.sdkInt);
    try {
      var states = await bridge.permissionState(names);
      if (ask && states.values.any((s) => s == PermissionState.denied)) {
        await bridge.requestPermissions(names);
        states = await bridge.permissionState(names);
      }
      final next = states.values.contains(PermissionState.blocked)
          ? PermissionState.blocked
          : states.values.contains(PermissionState.denied)
          ? PermissionState.denied
          : PermissionState.granted;
      if (next != discoveryAccess) {
        discoveryAccess = next;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Discovery permission check failed: $e');
    }
    return discoveryAccess == PermissionState.granted;
  }

  int _looking = 0;

  /// A screen starts looking for devices: holds the Wi-Fi multicast lock
  /// (Android drops discovery packets without it) until [stopLooking].
  void startLooking() {
    if (_looking++ == 0 && isAndroid) unawaited(bridge.multicastLock(true).catchError((Object _) {}));
  }

  void stopLooking() {
    if (_looking == 0) return;
    if (--_looking == 0 && isAndroid) unawaited(bridge.multicastLock(false).catchError((Object _) {}));
  }

  void refresh({bool scan = false}) {
    unawaited(() async {
      await discovery.joinNewInterfaces();
      discovery.announce();
      if (scan) await discovery.scanSubnets();
    }());
  }

  /// Connects from a scanned pairing QR code. Tries every address in it.
  Future<Device> connectWithCode(PairingCode code) async {
    if (code.wifiSsid != null && isAndroid) {
      await bridge.joinWifi(code.wifiSsid!, code.wifiPassword);
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    Object? lastError;
    for (final ip in code.addresses) {
      try {
        client.pin(code.deviceFor(ip));
        final device = await client.probe(ip, port: code.port, https: code.https, timeout: const Duration(seconds: 4));
        if (device.fingerprint.toUpperCase() != code.fingerprint.toUpperCase()) {
          throw HandshakeException(tr.codeWrongDevice);
        }
        _onPeer(device);
        return device;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError(tr.noAddressReachable);
  }

  Future<Device> connectManual(String host, {int port = defaultPort}) async {
    final device = await client.probeAuto(host, port: port, timeout: const Duration(seconds: 4));
    _onPeer(device);
    return device;
  }

  /// Pairing code for this device (shown as QR on the receiver).
  Future<PairingCode> pairingCode({String? ssid, String? password}) async {
    // No mobile data or VPN addresses: they never reach a nearby device and
    // each one costs the scanner a 4 s timeout.
    final addresses = [for (final l in await LocalLink.list()) l.address];
    // Hotspot / tethering gateways first: they're the likely link in those modes.
    addresses.sort((a, b) => (_isGateway(b) ? 1 : 0) - (_isGateway(a) ? 1 : 0));
    return PairingCode(
      addresses: addresses,
      port: server.port ?? defaultPort,
      fingerprint: identity.fingerprint,
      alias: self.alias,
      pin: server.pin,
      wifiSsid: ssid,
      wifiPassword: password,
    );
  }

  bool _isGateway(String ip) => ip.endsWith('.1');

  // --- Sending ---------------------------------------------------------------

  Future<void> send(Device target, List<OutgoingFile> files, {Map<String, Object?> options = const {}}) async {
    final cp = TransferCheckpoint(
      transferId: DateTime.now().millisecondsSinceEpoch.toString(),
      peerFingerprint: target.fingerprint,
      peerAlias: target.info.alias,
      role: 'send',
      categories: {for (final f in files) f.dto.category},
      totalFiles: files.length,
      totalBytes: files.fold(0, (a, f) => a + f.dto.size),
      options: options,
    );
    await checkpointStore.save(cp, force: true);
    await _run(target, files, cp);
  }

  /// Continues the interrupted transfer, optionally over another
  /// connection ([target] must be the same device: same fingerprint).
  Future<void> resume({Device? target, List<OutgoingFile>? files}) async {
    final cp = checkpoint;
    if (cp == null) return;
    final t = target ?? sendTarget ?? peers[cp.peerFingerprint];
    if (t == null) throw StateError(tr.reconnectFirst(cp.peerAlias));
    if (t.fingerprint != cp.peerFingerprint) throw StateError(tr.differentDeviceThan(cp.peerAlias));
    await _run(t, files ?? _lastFiles, cp);
  }

  Future<void> discardCheckpoint() async {
    await checkpointStore.clear();
    checkpoint = null;
    sendState = SendState.idle;
    notifyListeners();
  }

  Future<void> _run(Device target, List<OutgoingFile> files, TransferCheckpoint cp) async {
    sendTarget = target;
    _lastFiles = files;
    checkpoint = cp;
    sendState = SendState.preparing;
    sendResult = null;
    sendProgress = null;
    notifyListeners();
    final job = SendJob(
      client: client,
      target: target,
      files: files,
      sourceSdkInt: android?.sdkInt,
      checkpoint: cp,
      checkpointStore: checkpointStore,
      localStatus: () => localStatus,
    );
    _job = job;
    job.progress.listen((pr) {
      sendState = SendState.sending;
      sendProgress = pr;
      _foreground(tr.sendingTo(target.info.alias),
          '${tr.notifSending(pr.doneFiles, pr.totalFiles, formatSpeed(pr.bytesPerSecond))}'
              '${pr.eta == null ? '' : ' · ${tr.notifTimeLeft(formatDuration(pr.eta!))}'}',
          (pr.fraction * 100).round());
      notifyListeners();
    });
    final result = await job.run();
    _job = null;
    sendResult = result;
    sendState = switch (result.outcome) {
      SendOutcome.completed => SendState.done,
      SendOutcome.interrupted => SendState.interrupted,
      SendOutcome.canceled => SendState.idle,
      _ => SendState.failed,
    };
    if (result.outcome == SendOutcome.completed) checkpoint = null;
    if (result.outcome == SendOutcome.interrupted) {
      _alert(tr.transferPaused, _interruptText(result.interruptReason));
    }
    _stopForeground();
    notifyListeners();
  }

  void pauseSend() => _job?.interrupt(InterruptReason.paused);
  Future<void> cancelSend() async {
    await _job?.cancel();
    await discardCheckpoint();
  }

  static String _interruptText(InterruptReason? r) => switch (r) {
    InterruptReason.connectionLost => tr.interruptConnectionLost,
    InterruptReason.lowBatterySelf => tr.interruptLowBatterySelf,
    InterruptReason.lowBatteryPeer => tr.interruptLowBatteryPeer,
    InterruptReason.paused => tr.interruptPaused,
    _ => tr.interruptStopped,
  };

  String interruptText(InterruptReason? r) => _interruptText(r);

  static String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  void dispose() {
    _batteryTimer?.cancel();
    super.dispose();
  }
}

/// This phone's apps for a computer linked over USB: the same third-party
/// list the app picker shows, with the APK paths `adb pull` copies.
class _PhoneAppCatalog implements AppCatalog {
  _PhoneAppCatalog(this.bridge);
  final AndroidBridge bridge;

  @override
  Future<List<Map<String, Object?>>> list() async => [
    for (final a in await bridge.listApps())
      {
        'package': a.packageName,
        'label': a.label,
        'versionName': a.versionName,
        'versionCode': a.versionCode,
        'apks': a.apks,
        'size': a.sizeBytes,
        'readable': a.readable,
        'minSdk': ?a.minSdk,
      },
  ];

  @override
  Future<List<int>?> icon(String package) => bridge.appIcon(package);
}

