import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_cloner/src/platform/android_bridge.dart';
import 'package:mobile_cloner/src/services/app_settings.dart';
import 'package:mobile_cloner/src/ui/phone/views/home_view.dart';
import 'package:mobile_cloner/src/ui/phone/views/settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppSettings', () {
    test('loads saved values and defaults', () async {
      SharedPreferences.setMockInitialValues({});
      await AppSettings.instance.load();
      expect((AppSettings.instance.deviceName, AppSettings.instance.themeMode, AppSettings.instance.keepScreenOn),
          (null, ThemeMode.system, true));

      SharedPreferences.setMockInitialValues({'deviceName': 'Old phone', 'themeMode': 'dark', 'keepScreenOn': false});
      await AppSettings.instance.load();
      expect((AppSettings.instance.deviceName, AppSettings.instance.themeMode, AppSettings.instance.keepScreenOn),
          ('Old phone', ThemeMode.dark, false));
    });

    test('every setter saves, and a blank name resets to the model', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings.instance;
      await s.load();
      await s.setDeviceName('  Kitchen tablet ');
      await s.setThemeMode(ThemeMode.light);
      await s.setKeepScreenOn(false);
      final prefs = await SharedPreferences.getInstance();
      expect((prefs.getString('deviceName'), prefs.getString('themeMode'), prefs.getBool('keepScreenOn')),
          ('Kitchen tablet', 'light', false));

      await s.setDeviceName('   ');
      expect(s.deviceName, isNull);
      expect(prefs.containsKey('deviceName'), isFalse);
    });
  });

  testWidgets('home settings button opens settings', (tester) async {
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      home: PhoneHomeView(
        deviceName: 'Galaxy A53',
        osLabel: 'Android 14',
        myStatus: null,
        nearby: const [],
        onSend: () {},
        onReceive: () {},
        onBackup: () {},
        onRestore: () {},
        onSettings: () => opened++,
      ),
    ));
    await tester.tap(find.byTooltip('Settings'));
    expect(opened, 1);
  });

  testWidgets('every setting reports its change', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final events = <String>[];
    const nearby = PermissionItem(icon: Icons.radar, title: 'Nearby devices', purpose: 'p', state: PermissionState.denied);
    const camera = PermissionItem(icon: Icons.camera, title: 'Camera', purpose: 'p', state: PermissionState.blocked);
    const photos = PermissionItem(icon: Icons.photo, title: 'Photos and videos', purpose: 'p', state: PermissionState.granted);
    await tester.pumpWidget(MaterialApp(
      home: PhoneSettingsView(
        deviceName: 'Samsung SM-A536E',
        defaultDeviceName: 'Samsung SM-A536E',
        themeMode: ThemeMode.system,
        keepScreenOn: true,
        permissions: const [nearby, camera, photos],
        version: '0.1.0 (1)',
        onRename: (n) => events.add('rename $n'),
        onThemeMode: (m) => events.add('theme ${m.name}'),
        onKeepScreenOn: (on) => events.add('screen $on'),
        onGrant: (p) => events.add('grant ${p.title}'),
        onOpenAppSettings: () => events.add('app settings'),
      ),
    ));

    await tester.tap(find.text('Device name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Old phone');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Allow'));
    await tester.tap(find.widgetWithText(FilledButton, 'Settings'));
    await tester.tap(find.text('Open Android app settings'));
    await tester.pump();

    expect(events, [
      'rename Old phone',
      'theme dark',
      'screen false',
      'grant Nearby devices',
      'grant Camera',
      'app settings',
    ]);
    // Granted permissions show a check instead of a button.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('Version 0.1.0 (1)'), findsOneWidget);
  });
}
