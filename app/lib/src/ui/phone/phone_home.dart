import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../services/cloner_service.dart';
import 'connect_page.dart';
import 'receive_page.dart';
import 'select_page.dart';
import 'settings_page.dart';
import 'transfer_page.dart';
import 'views/home_view.dart';

class PhoneHome extends StatefulWidget {
  const PhoneHome({super.key});

  static Future<void> startSend(BuildContext context, {bool toComputer = false}) async {
    final device = await Navigator.push<Device>(
      context,
      MaterialPageRoute(builder: (_) => ConnectPage(desktopOnly: toComputer)),
    );
    if (device == null || !context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SelectPage(target: device)));
  }

  @override
  State<PhoneHome> createState() => _PhoneHomeState();
}

class _PhoneHomeState extends State<PhoneHome> {
  @override
  void initState() {
    super.initState();
    // First launch: ask for "Nearby devices" (Location before Android 13)
    // up front, so the home screen's nearby list and every mode can work.
    ClonerService.instance.ensureDiscoveryAccess().then((ok) {
      if (ok) ClonerService.instance.refresh(scan: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ClonerService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final a = service.android!;
        final cp = service.checkpoint;
        return PhoneHomeView(
          deviceName: service.self.alias,
          osLabel: S.of(context).androidVersion(a.release),
          myStatus: service.localStatus,
          resume: cp == null
              ? null
              : ResumeInfo(
                  peer: cp.peerAlias,
                  doneFiles: cp.doneFiles,
                  totalFiles: cp.totalFiles,
                  reason: service.interruptText(cp.interruptReason).split('.').first,
                ),
          nearby: [
            for (final d in service.peers.values)
              NearbyPeer(
                name: d.info.alias,
                isDesktop: d.info.deviceType == DeviceType.desktop,
                subtitle: d.info.cloner?.sdkInt != null ? S.of(context).androidApi(d.info.cloner!.sdkInt!) : d.ip,
              ),
          ],
          onSend: () => PhoneHome.startSend(context),
          onReceive: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceivePage())),
          onBackup: () => PhoneHome.startSend(context, toComputer: true),
          onRestore: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceivePage())),
          onResume: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferPage(resumeOnOpen: true))),
          onDiscardResume: service.discardCheckpoint,
          onSettings: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
        );
      },
    );
  }
}
