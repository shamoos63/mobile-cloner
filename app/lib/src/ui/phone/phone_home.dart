import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../services/cloner_service.dart';
import 'connect_page.dart';
import 'receive_page.dart';
import 'select_page.dart';
import 'transfer_page.dart';
import 'views/home_view.dart';

class PhoneHome extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final service = ClonerService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final a = service.android!;
        final cp = service.checkpoint;
        return PhoneHomeView(
          deviceName: a.model,
          osLabel: 'Android ${a.release}',
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
                subtitle: d.info.cloner?.sdkInt != null ? 'Android API ${d.info.cloner!.sdkInt}' : d.ip,
              ),
          ],
          onSend: () => startSend(context),
          onReceive: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceivePage())),
          onBackup: () => startSend(context, toComputer: true),
          onRestore: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceivePage())),
          onResume: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferPage(resumeOnOpen: true))),
          onDiscardResume: service.discardCheckpoint,
        );
      },
    );
  }
}
