import 'dart:async';

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../services/cloner_service.dart';
import '../theme.dart';
import '../widgets/discovery_access.dart';
import '../widgets/labels.dart';
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
    try {
      final device = await connect();
      if (widget.mustMatch != null && device.fingerprint != widget.mustMatch) {
        throw StateError('That is a different device than the one you were sending to.');
      }
      if (mounted) Navigator.pop(context, device);
    } catch (e) {
      setState(() => _error = '$e');
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
        title: const Text('Connect by address'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: '192.168.1.20'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    if (host != null && host.isNotEmpty) await _pick(() => service.connectManual(host));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.desktopOnly ? 'Choose a computer' : 'Choose the new phone'),
        actions: [IconButton(onPressed: () => service.refresh(scan: true), icon: const Icon(Icons.refresh_rounded))],
      ),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final peers = service.peers.values
              .where((d) => !widget.desktopOnly || d.info.cloner?.platform.isDesktop == true || d.info.deviceType == DeviceType.desktop)
              .toList();
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
              const SectionLabel('Nearby'),
              if (peers.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(children: [
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 16),
                      Expanded(child: Text('Looking for devices. On the other device, open HK Cloner and tap Receive.',
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
                          if (d.info.cloner?.sdkInt != null) 'Android API ${d.info.cloner!.sdkInt}',
                          if (!d.info.isCloner) 'LocalSend',
                          d.ip,
                        ].join(' · ')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                  ]),
                ),
              const SectionLabel('Other ways to connect'),
              Card(
                child: Column(children: [
                  ListTile(
                    onTap: _busy ? null : _scan,
                    leading: const IconBadge(Icons.qr_code_scanner_rounded, size: 44, color: AppColors.indigo),
                    title: const Text('Scan QR code'),
                    subtitle: const Text('Works on hotspot and USB cable too'),
                  ),
                  ListTile(
                    onTap: _busy
                        ? null
                        : () => _pick(() => service.connectManual('127.0.0.1', port: AdbBridge.phoneToPcPort)),
                    leading: const IconBadge(Icons.usb_rounded, size: 44, color: AppColors.violet),
                    title: const Text('Computer over USB'),
                    subtitle: const Text('Click "Link" in HK Cloner on the computer first'),
                  ),
                  ListTile(
                    onTap: _busy ? null : _manual,
                    leading: const IconBadge(Icons.keyboard_rounded, size: 44, color: AppColors.teal),
                    title: const Text('Enter address'),
                    subtitle: const Text('Shown under the QR code on the other device'),
                  ),
                ]),
              ),
              if (peers.isEmpty && !widget.desktopOnly) ...[
                const SectionLabel('Not finding it?'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'Same Wi-Fi: both phones must be on the same network, and some routers (guest networks) '
                      'keep devices apart.\n\n'
                      'USB cable: only the phone being charged by the other can turn on USB tethering, and the '
                      'other phone must support a USB network, which many phones do not. If nothing shows up '
                      'within a minute, unplug the cable and choose "No Wi-Fi around" on the new phone. It needs '
                      'no router and is almost as fast.',
                      style: t.bodyMedium,
                    ),
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
