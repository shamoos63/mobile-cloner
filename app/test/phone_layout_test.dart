import 'dart:convert';
import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_cloner/src/platform/android_bridge.dart';
import 'package:mobile_cloner/src/services/app_installer.dart';
import 'package:mobile_cloner/src/ui/phone/views/app_install_list.dart';
import 'package:mobile_cloner/src/ui/phone/views/app_picker_view.dart';
import 'package:mobile_cloner/src/ui/phone/views/home_view.dart';
import 'package:mobile_cloner/src/ui/phone/views/receive_view.dart';
import 'package:mobile_cloner/src/ui/phone/views/select_view.dart';
import 'package:mobile_cloner/src/ui/phone/views/settings_view.dart';
import 'package:mobile_cloner/src/ui/phone/views/transfer_view.dart';

import 'l10n_helpers.dart';

/// Every phone screen on a small phone (360x640), in Arabic and English,
/// with the real fonts: nothing may overflow. Screens scroll, so each is
/// also dragged to the end.
void main() {
  setUpAll(loadAppFonts);

  final screens = <String, Widget>{
    'home': PhoneHomeView(
      deviceName: 'Samsung SM-A536E',
      osLabel: 'Android 14',
      myStatus: const PeerStatus(batteryLevel: 64, charging: false),
      nearby: const [NearbyPeer(name: 'Galaxy Tab S9 FE', isDesktop: false, subtitle: 'Android API 34')],
      resume: const ResumeInfo(peer: 'Galaxy Tab S9 FE', doneFiles: 312, totalFiles: 1840, reason: 'Connection lost'),
      onSend: () {},
      onReceive: () {},
      onBackup: () {},
      onRestore: () {},
      onResume: () {},
      onDiscardResume: () {},
      onSettings: () {},
    ),
    'receive': ReceiveView(
      deviceName: 'Samsung SM-A536E',
      pairing: null,
      mode: ConnectionMode.usbTethering,
      onMode: (_) {},
      needsWhatsAppAccess: true,
      onGrantWhatsApp: () {},
      modeHint: 'x' * 240,
      modeActionLabel: 'Use another way',
      onModeAction: () {},
    ),
    'select': SelectContentView(
      targetName: 'Galaxy Tab S9 FE',
      targetIsDesktop: false,
      items: const [
        SelectableItem(category: ContentCategory.photos, selected: true, count: 1840, bytes: 7400000000),
        SelectableItem(category: ContentCategory.contacts, selected: true, count: 312),
        SelectableItem(
          category: ContentCategory.whatsapp,
          selected: true,
          count: 9120,
          bytes: 2100000000,
          warning: 'Android 11+ needs your OK to read this folder.',
          actionLabel: 'Allow',
        ),
        SelectableItem(category: ContentCategory.wallpaper, selected: false, loading: true),
      ],
      onToggle: (_, _) {},
      onStart: () {},
      onWhatsAppScope: (_) {},
    ),
    'transfer': const TransferView(
      title: 'Sending to Galaxy Tab S9 FE',
      peerName: 'Galaxy Tab S9 FE',
      fraction: 0.42,
      doneBytes: 3100000000,
      totalBytes: 7400000000,
      bytesPerSecond: 31000000,
      doneFiles: 780,
      totalFiles: 1840,
      eta: Duration(minutes: 3, seconds: 12),
      currentFile: 'DCIM/Camera/IMG_20261021_120501.jpg',
      categories: [CategoryProgress(ContentCategory.photos, 780, 1840), CategoryProgress(ContentCategory.contacts, 0, 1)],
      myStatus: PeerStatus(batteryLevel: 64, charging: true),
      peerStatus: PeerStatus(batteryLevel: 12, charging: false),
    ),
    'transfer interrupted': const TransferView(
      title: 'Sending to Galaxy Tab S9 FE',
      peerName: 'Galaxy Tab S9 FE',
      fraction: 0.42,
      doneBytes: 3100000000,
      totalBytes: 7400000000,
      bytesPerSecond: 0,
      doneFiles: 780,
      totalFiles: 1840,
      interruptedReason: 'Connection lost. Reconnect and tap Resume.',
    ),
    'settings': PhoneSettingsView(
      deviceName: 'Samsung SM-A536E',
      defaultDeviceName: 'Samsung SM-A536E',
      themeMode: ThemeMode.system,
      language: 'ar',
      keepScreenOn: true,
      permissions: const [
        PermissionItem(icon: Icons.radar, title: 'Nearby devices', purpose: 'Find the other phone', state: PermissionState.denied),
        PermissionItem(icon: Icons.photo, title: 'Photos and videos', purpose: 'Your gallery', state: PermissionState.granted),
        PermissionItem(icon: Icons.camera, title: 'Camera', purpose: 'Scan the QR code', state: PermissionState.blocked),
      ],
      version: '0.1.0 (1)',
      onRename: (_) {},
      onThemeMode: (_) {},
      onLanguage: (_) {},
      onKeepScreenOn: (_) {},
      onGrant: (_) {},
      onOpenAppSettings: () {},
    ),
  };

  screens['app picker'] = AppPickerView(
    apps: [
      for (final (i, name) in ['Telegram', 'A very long application name that keeps going', 'Maps'].indexed)
        InstalledApp(
          packageName: 'com.example.app$i',
          label: name,
          versionName: '11.140.0.1234567-release',
          versionCode: 1,
          apks: const ['/data/app/base.apk'],
          sizeBytes: 98000000,
          readable: i != 2,
        ),
    ],
    initial: const {'com.example.app0'},
    iconFor: (_) async => null,
    onDone: (_) {},
  );
  screens['app install list'] = Scaffold(
    body: ListView(padding: const EdgeInsets.all(20), children: [
      AppInstallList(
        queue: AppInstallQueue(
          install: (_) async => (result: AppInstallResult.installed, detail: null),
          installedVersion: (_) async => null,
          sdkInt: 34,
          bundles: [
            for (final name in ['Telegram', 'A very long application name that keeps going'])
              AppBundle(
                dir: '/r',
                manifest: AppManifest(
                  packageName: name,
                  label: name,
                  versionName: '11.140.0',
                  versionCode: 1,
                  apks: const ['base.apk'],
                  sizeBytes: 98000000,
                  minSdk: 40,
                ),
                apkPaths: const ['/r/base.apk'],
              ),
          ],
        ),
        beforeInstall: () async => true,
      ),
    ]),
  );

  for (final lang in ['ar', 'en']) {
    for (final e in screens.entries) {
      testWidgets('$lang ${e.key} at 360x640', (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(localized(lang: lang, e.value));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -3000));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        expect(Directionality.of(tester.element(find.byWidget(e.value))),
            lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      });
    }
  }

  test('every string exists in Arabic and English, with the same placeholders', () {
    Map<String, Object?> arb(String name) => (jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map).cast();
    final ar = arb('app_ar.arb'), en = arb('app_en.arb');
    Set<String> keys(Map<String, Object?> m) => {for (final k in m.keys) if (!k.startsWith('@')) k};
    expect(keys(en), keys(ar));
    final placeholder = RegExp(r'\{(\w+)[},]');
    for (final k in keys(ar)) {
      Set<String> names(Object? v) => {for (final m in placeholder.allMatches('$v')) m.group(1)!};
      expect(names(ar[k]), names(en[k]), reason: k);
      expect('${ar[k]}'.trim(), isNotEmpty, reason: k);
    }
  });
}
