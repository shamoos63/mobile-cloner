import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../platform/android_bridge.dart';
import '../../services/cloner_service.dart';
import '../phone/select_page.dart';

/// When the computer opens the app over USB (`cloner_link=adb`), links to
/// it through the ADB tunnel and goes straight to choosing what to back up.
class UsbLinkListener extends StatefulWidget {
  const UsbLinkListener({super.key, required this.child});
  final Widget child;

  @override
  State<UsbLinkListener> createState() => _UsbLinkListenerState();
}

class _UsbLinkListenerState extends State<UsbLinkListener> with WidgetsBindingObserver {
  bool _linking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_linking) return;
    final link = await AndroidBridge.instance.takeLaunchLink();
    if (link != 'adb' || !mounted) return;
    _linking = true;
    try {
      Device? computer;
      // The tunnel is set up just before launch; give it a moment.
      for (var i = 0; i < 5 && computer == null; i++) {
        try {
          computer = await ClonerService.instance.connectManual('127.0.0.1', port: AdbBridge.phoneToPcPort);
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        }
      }
      if (!mounted) return;
      if (computer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).usbComputerUnreachable)),
        );
        return;
      }
      final nav = Navigator.of(context);
      nav.popUntil((r) => r.isFirst);
      await nav.push(MaterialPageRoute(builder: (_) => SelectPage(target: computer!)));
    } finally {
      _linking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
