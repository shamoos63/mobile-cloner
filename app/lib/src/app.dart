import 'dart:io';

import 'package:flutter/material.dart';

import 'l10n.dart';

import 'services/app_settings.dart';
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
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => _app(AppSettings.instance),
    );
  }

  Widget _app(AppSettings settings) {
    return MaterialApp(
      // A new language rebuilds every screen (back to home), so no widget
      // keeps text in the old one.
      key: ValueKey(settings.language),
      title: 'HK Cloner',
      themeMode: settings.themeMode,
      locale: Locale(settings.language),
      supportedLocales: S.supportedLocales,
      localizationsDelegates: S.localizationsDelegates,
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, arabic: settings.rtl),
      darkTheme: buildTheme(Brightness.dark, arabic: settings.rtl),
      builder: (context, child) => IncomingRequestListener(navigatorKey: navigatorKey, child: child!),
      home: ListenableBuilder(
        listenable: ClonerService.instance,
        builder: (context, _) {
          final s = ClonerService.instance;
          if (s.startupError != null) {
            return Scaffold(body: Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(S.of(context).startupFailed(s.startupError!), textAlign: TextAlign.center),
            )));
          }
          if (!s.ready) {
            return Scaffold(body: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(S.of(context).startupPreparing),
              ],
            )));
          }
          return Platform.isAndroid ? const UsbLinkListener(child: PhoneHome()) : const DesktopHome();
        },
      ),
    );
  }
}
