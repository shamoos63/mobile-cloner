import 'dart:async';

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../platform/android_bridge.dart';
import '../../platform/usb_link.dart';
import '../../restore/phone_receive_delegate.dart';
import '../../services/cloner_service.dart';
import '../theme.dart';
import '../widgets/discovery_access.dart';
import '../widgets/usb_cable_status.dart';
import '../widgets/visuals.dart';
import 'views/receive_view.dart';
import 'views/transfer_view.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  final service = ClonerService.instance;
  ConnectionMode _mode = ConnectionMode.wifi;
  PairingCode? _pairing;
  String? _hint;

  /// The cable is not working: offer "No Wi-Fi around" instead.
  bool _suggestHotspot = false;
  bool _needsWhatsApp = false;

  /// When Cable mode was chosen; after a while without a link we say so.
  DateTime? _cableSince;
  Timer? _cableTick;

  @override
  void initState() {
    super.initState();
    service.startLooking();
    UsbLink.instance.addListener(_onUsb);
    _refreshPairing();
    _checkWhatsAppAccess();
    _askPermissions();
  }

  /// One after the other: Android shows one permission dialog at a time.
  Future<void> _askPermissions() async {
    if (await service.ensureDiscoveryAccess()) service.refresh();
    try {
      await service.bridge.requestPermissions(
          [...AndroidPermission.media(service.android!.sdkInt), AndroidPermission.writeContacts, AndroidPermission.notifications]);
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
  }

  @override
  void dispose() {
    if (_mode == ConnectionMode.hotspot) service.bridge.stopLocalHotspot();
    service.stopLooking();
    UsbLink.instance.removeListener(_onUsb);
    _cableTick?.cancel();
    super.dispose();
  }

  Future<void> _refreshPairing({String? ssid, String? password}) async {
    final code = await service.pairingCode(ssid: ssid, password: password);
    if (mounted) setState(() => _pairing = code);
  }

  Future<void> _checkWhatsAppAccess() async {
    final sdk = service.android!.sdkInt;
    if (!WhatsAppLayout.needsSpecialAccess(sdk) || await service.bridge.hasAllFilesAccess()) {
      setState(() => _needsWhatsApp = false);
      return;
    }
    final tree = await service.bridge.treeCovering(WhatsAppLayout.scopedRoot(WhatsAppVariant.messenger));
    setState(() => _needsWhatsApp = tree == null);
  }

  Future<void> _grantWhatsApp() async {
    // Android/media covers both WhatsApp and WhatsApp Business.
    await service.bridge.pickTree(initialPath: 'Android/media');
    await _checkWhatsAppAccess();
  }

  Future<void> _setMode(ConnectionMode mode) async {
    if (_mode == ConnectionMode.hotspot && mode != ConnectionMode.hotspot) await service.bridge.stopLocalHotspot();
    _cableTick?.cancel();
    setState(() {
      _mode = mode;
      _hint = null;
      _suggestHotspot = false;
      _cableSince = null;
    });
    if (mode != ConnectionMode.adb) await service.ensureDiscoveryAccess();
    switch (mode) {
      case ConnectionMode.wifi:
        await _refreshPairing();
        service.refresh();
      case ConnectionMode.hotspot:
        await service.bridge.requestPermissions(AndroidPermission.hotspot(service.android!.sdkInt));
        try {
          final hs = await service.bridge.startLocalHotspot();
          if (hs == null) {
            setState(() => _hint = S.of(context).hotspotUseSettings);
            await service.bridge.openTetherSettings();
          } else {
            setState(() => _hint = S.of(context).hotspotOn(hs.ssid));
          }
          await Future<void>.delayed(const Duration(seconds: 1));
          await _refreshPairing(ssid: hs?.ssid, password: hs?.password);
        } catch (e) {
          setState(() => _hint = S.of(context).hotspotFailed('$e'));
        }
      case ConnectionMode.usbTethering:
        await _cableMode();
      case ConnectionMode.adb:
        break;
    }
  }

  /// Phone to phone over a USB cable with Android Open Accessory: no
  /// tethering, no network. Whichever phone the cable makes USB host asks
  /// for access and switches the other one over; the hint follows the link.
  Future<void> _cableMode() async {
    _cableSince = DateTime.now();
    _cableTick = Timer.periodic(const Duration(seconds: 5), (_) => _onUsb());
    _onUsb();
    await service.startUsbCable();
  }

  void _onUsb() {
    if (!mounted || _mode != ConnectionMode.usbTethering) return;
    final link = UsbLink.instance;
    final since = _cableSince;
    final m = usbCableMessage(
      link.state,
      detail: link.detail,
      waitedLong: since != null && DateTime.now().difference(since) > const Duration(seconds: 25),
    );
    setState(() {
      _hint = m.text;
      _suggestHotspot = m.suggestHotspot;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final report = service.lastReport;
        if (report != null) return _ReportView(report: report);
        final s = service.receiveSession;
        if (s != null && s.state == SessionState.active) {
          final done = s.files.values.where((f) => f.state == FileState.done).length;
          return TransferView(
            title: S.of(context).receivingFrom(s.sender.info.alias),
            peerName: s.sender.info.alias,
            fraction: s.totalBytes == 0 ? 0 : s.receivedBytes / s.totalBytes,
            doneBytes: s.receivedBytes,
            totalBytes: s.totalBytes,
            bytesPerSecond: service.receiveMeter.bytesPerSecond,
            eta: service.receiveMeter.eta(s.totalBytes - s.receivedBytes),
            doneFiles: done,
            totalFiles: s.files.length,
            myStatus: service.localStatus,
            peerStatus: service.senderStatus,
            categories: _categories(s),
            onPause: null,
            onCancel: service.server.cancelSession,
          );
        }
        return ReceiveView(
          deviceName: service.self.alias,
          pairing: _pairing,
          mode: _mode,
          onMode: _setMode,
          modeHint: _hint,
          notice: const DiscoveryAccessCard(),
          modeActionLabel: _suggestHotspot ? S.of(context).useNoWifiMode : null,
          onModeAction: _suggestHotspot ? () => _setMode(ConnectionMode.hotspot) : null,
          needsWhatsAppAccess: _needsWhatsApp,
          onGrantWhatsApp: _grantWhatsApp,
        );
      },
    );
  }

  List<CategoryProgress> _categories(ReceiveSession s) {
    final total = <ContentCategory, int>{}, done = <ContentCategory, int>{};
    for (final f in s.files.values) {
      total[f.file.category] = (total[f.file.category] ?? 0) + 1;
      if (f.state == FileState.done) done[f.file.category] = (done[f.file.category] ?? 0) + 1;
    }
    return [for (final e in total.entries) CategoryProgress(e.key, done[e.key] ?? 0, e.value)];
  }
}

/// End of a receive: what arrived and what the user still has to do.
class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});
  final RestoreReport report;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = report.session;
    final ok = s.files.values.where((f) => f.state == FileState.done).length;
    final service = ClonerService.instance;
    final l = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.transferComplete)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          HeroSurface(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check_circle_rounded, size: 40),
              const SizedBox(height: 12),
              Text(l.itemsMoved(ok, s.files.length), style: t.headlineSmall?.copyWith(color: Colors.white)),
              Text(l.fromName(s.sender.info.alias), style: t.bodyMedium?.copyWith(color: Colors.white70)),
            ]),
          ),
          if (report.whatsApp.isNotEmpty) ...[
            SectionLabel(l.finishWhatsapp),
            for (final v in report.whatsApp)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const IconBadge(Icons.chat_outlined, color: AppColors.teal, size: 40),
                      const SizedBox(width: 12),
                      Text(v.folderName, style: t.titleMedium),
                    ]),
                    const SizedBox(height: 12),
                    Text(l.whatsappRestoreSteps),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => service.bridge.launchPackage(v.packageName),
                      child: Text(l.openWhatsapp),
                    ),
                  ]),
                ),
              ),
          ],
          if (report.contactsFiles > 0) ...[
            SectionLabel(l.categoryContacts),
            Card(
              child: ListTile(
                leading: const IconBadge(Icons.contacts_outlined, size: 40),
                title: Text(report.contactsImportOpened ? l.confirmContactsImport : l.contactsReceived),
                subtitle: Text(l.contactsImportHint),
              ),
            ),
          ],
          if (report.wallpaperSet) ...[
            SectionLabel(l.categoryWallpaper),
            Card(
              child: ListTile(
                leading: const IconBadge(Icons.wallpaper_outlined, size: 40),
                title: Text(l.wallpaperSet),
                subtitle: Text(l.wallpaperSetHint),
              ),
            ),
          ],
          for (final p in report.problems)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(p, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              service.lastReport = null;
              Navigator.pop(context);
            },
            child: Text(l.done),
          ),
        ],
      ),
    );
  }
}
