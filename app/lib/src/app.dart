import 'dart:io';

import 'package:flutter/material.dart';

import 'services/cloner_service.dart';
import 'ui/desktop/desktop_home.dart';
import 'ui/phone/phone_home.dart';
import 'ui/theme.dart';
import 'ui/widgets/incoming_request_listener.dart';
import 'ui/widgets/usb_link_listener.dart';

class MobileClonerApp extends StatelessWidget {
  const MobileClonerApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HK Cloner',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      builder: (context, child) => IncomingRequestListener(navigatorKey: navigatorKey, child: child!),
      home: ListenableBuilder(
        listenable: ClonerService.instance,
        builder: (context, _) {
          final s = ClonerService.instance;
          if (s.startupError != null) {
            return Scaffold(body: Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not start: ${s.startupError}', textAlign: TextAlign.center),
            )));
          }
          if (!s.ready) {
            return const Scaffold(body: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Preparing secure connection...')],
            )));
          }
          return Platform.isAndroid ? const UsbLinkListener(child: PhoneHome()) : const DesktopHome();
        },
      ),
    );
  }
}
