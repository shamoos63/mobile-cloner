import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../l10n.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../platform/android_bridge.dart';

/// Scans a HK Cloner pairing QR code and returns it.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    AndroidBridge.instance.requestPermissions([AndroidPermission.camera]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(foregroundColor: Colors.white, title: Text(S.of(context).scanTheCode, style: const TextStyle(color: Colors.white))),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_done) return;
              for (final b in capture.barcodes) {
                final code = PairingCode.tryDecode(b.rawValue ?? '');
                if (code != null) {
                  _done = true;
                  Navigator.pop(context, code);
                  return;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
