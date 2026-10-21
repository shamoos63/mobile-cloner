import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/services/cloner_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) await _setUpWindow();
  ClonerService.instance.init();
  runApp(const MobileClonerApp());
}

/// Desktop: no OS title bar; the app draws its own (see DesktopTitleBar).
Future<void> _setUpWindow() async {
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    // Smallest window the desktop layout is tested at.
    minimumSize: Size(720, 560),
    titleBarStyle: TitleBarStyle.hidden,
    // macOS: hide the traffic lights, the custom bar has its own buttons.
    windowButtonVisibility: false,
    title: 'HK Cloner',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
