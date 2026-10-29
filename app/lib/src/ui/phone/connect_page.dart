import 'dart:async';

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../platform/usb_link.dart';
import '../../services/cloner_service.dart';
import '../theme.dart';
import '../widgets/discovery_access.dart';
import '../widgets/labels.dart';
import '../widgets/usb_cable_status.dart';
import '../widgets/visuals.dart';
import 'scan_page.dart';

/// Picks the device to send to. Returns the connected [Device].
class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key, this.desktopOnly = false, this.mustMatch});

  final bool desktopOnly;

  /// When resuming: only this fingerprint is acceptable.
  final String? mustMatch;

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final service = ClonerService.instance;
  bool _busy = false;
  String? _error;
  Timer? _rescan;

  @override
  void initState() {
    super.initState();
    service.startLooking();
    _start();
    // A cable or hotspot link can come up after this screen opens: keep
    // scanning while nothing has been found.
    _rescan = Timer.periodic(const Duration(seconds: 10), (_) {
      if (service.peers.isEmpty && !_busy) service.refresh(scan: true);
    });
  }

  Future<void> _start() async {
    // A phone on the USB cable needs no permission and no network.
    unawaited(service.startUsbCable());
    await service.ensureDiscoveryAccess();
    service.refresh(scan: true);
  }

  @override
  void dispose() {
    _rescan?.cancel();
    service.stopLooking();
    super.dispose();
  }

  Future<void> _pick(Future<Device> Function() connect) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final differentDevice = S.of(context).differentDevice;
    try {
      final device = await connect();
      if (widget.mustMatch != null && device.fingerprint != widget.mustMatch) {
        throw StateError(differentDevice);
      }
      if (mounted) Navigator.pop(context, device);
    } catch (e) {
      setState(() => _error = e is StateError ? e.message : tr.connectFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.push<PairingCode>(context, MaterialPageRoute(builder: (_) => const ScanPage()));
    if (code != null) await _pick(() => service.connectWithCode(code));
  }

  Future<void> _manual() async {
    final controller = TextEditingController();
    final host = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).connectByAddress),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(hintText: '192.168.1.20'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(S.of(context).cancel)),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(S.of(context).connect),
          ),
        ],
      ),
    );
    if (host != null && host.isNotEmpty) await _pick(() => service.connectManual(host));
  }

  /// Cable progress worth showing here; null while nothing is plugged in.
  String? _usbNotice() {
    final link = UsbLink.instance;
    return switch (link.state) {
      UsbLinkState.idle || UsbLinkState.noDevice || UsbLinkState.connected => null,
      _ => usbCableMessage(link.state, detail: link.detail).text,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.desktopOnly ? s.chooseComputer : s.chooseNewPhone),
        actions: [
          IconButton(onPressed: () => service.refresh(scan: true), tooltip: s.refresh, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([service, UsbLink.instance]),
        builder: (context, _) {
          final peers = service.peers.values
              .where((d) => !widget.desktopOnly || d.info.cloner?.platform.isDesktop == true || d.info.deviceType == DeviceType.desktop)
              .toList()
            // The phone on the USB cable first.
            ..sort((a, b) => (service.isUsbCable(b) ? 1 : 0) - (service.isUsbCable(a) ? 1 : 0));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const DiscoveryAccessCard(),
              if (_usbNotice() case final text?)
                Card(
                  child: ListTile(
                    leading: const IconBadge(Icons.usb_rounded, size: 40, color: AppColors.violet),
                    title: Text(s.usbCable),
                    subtitle: Text(text),
                  ),
                ),
              SectionLabel(s.sectionNearby),
              if (peers.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(children: [
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 16),
                      Expanded(child: Text(s.lookingForDevices,
                          style: t.bodyMedium)),
                    ]),
                  ),
                )
              else
                Card(
                  child: Column(children: [
                    for (final d in peers)
                      ListTile(
                        enabled: !_busy,
                        onTap: () => _pick(() async => d),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: IconBadge(deviceIcon(d), size: 44),
                        title: Text(d.info.alias, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        subtitle: Text([
                          if (d.info.cloner?.sdkInt != null) s.androidApi(d.info.cloner!.sdkInt!),
                          if (!d.info.isCloner) 'LocalSend',
                          service.isUsbCable(d) ? s.usbCable : ltr(d.ip),
                        ].join(' · ')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                  ]),
                ),
              SectionLabel(s.sectionOtherWays),
              Card(
                child: Column(children: [
                  ListTile(
                    onTap: _busy ? null : _scan,
                    leading: const IconBadge(Icons.qr_code_scanner_rounded, size: 44, color: AppColors.indigo),
                    title: Text(s.scanQrCode),
                    subtitle: Text(s.scanQrCodeSubtitle),
                  ),
                  ListTile(
                    onTap: _busy
                        ? null
                        : () => _pick(() => service.connectManual('127.0.0.1', port: AdbBridge.phoneToPcPort)),
                    leading: const IconBadge(Icons.usb_rounded, size: 44, color: AppColors.violet),
                    title: Text(s.computerOverUsb),
                    subtitle: Text(s.computerOverUsbSubtitle),
                  ),
                  ListTile(
                    onTap: _busy ? null : _manual,
                    leading: const IconBadge(Icons.keyboard_rounded, size: 44, color: AppColors.teal),
                    title: Text(s.enterAddress),
                    subtitle: Text(s.enterAddressSubtitle),
                  ),
                ]),
              ),
              if (peers.isEmpty && !widget.desktopOnly) ...[
                SectionLabel(s.sectionNotFinding),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(s.notFindingHelp, style: t.bodyMedium),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
