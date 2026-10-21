import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_cloner/src/ui/desktop/views/desktop_view.dart';
import 'package:mobile_cloner/src/ui/theme.dart';

/// Every desktop panel, at window sizes from small to large, with the real
/// font so text measures like in the app: no RenderFlex may overflow.
void main() {
  setUpAll(() async {
    final loader = FontLoader('Manrope');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final bytes = File('assets/fonts/Manrope-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  });

  const backups = [
    BackupCardData(
      alias: 'Samsung SM-X230',
      subtitle: 'Android API 35 · SM-X230',
      lastBackup: '2026-10-21 12:05',
      bytesByCategory: {ContentCategory.photos: 150000000, ContentCategory.videos: 36000000, ContentCategory.contacts: 20000},
      path: '/tmp/a',
    ),
    BackupCardData(
      alias: 'Pixel 7 Pro with a rather long name',
      subtitle: 'Android API 34 · Pixel 7 Pro',
      lastBackup: '2026-10-20 09:41',
      bytesByCategory: {ContentCategory.whatsapp: 2000000000},
      path: '/tmp/b',
    ),
  ];
  const adb = [
    AdbDeviceData(serial: 'R5GYB1VDTJA', name: 'SM-X230', connected: true, status: 'Opened on the phone. Choose what to back up there.'),
    AdbDeviceData(serial: 'emulator-5554', connected: false, status: 'Setup failed: device offline'),
  ];

  for (final size in const [Size(720, 560), Size(800, 600), Size(1024, 700), Size(1280, 800), Size(1600, 1000)]) {
    for (final section in DesktopSection.values) {
      for (final live in [false, true]) {
        testWidgets('${section.name} at ${size.width.toInt()}x${size.height.toInt()}${live ? ' (live)' : ''}', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(MaterialApp(
            theme: buildTheme(Brightness.light),
            home: DesktopHomeView(
              hostName: 'Hishams-MacBook-Pro.local',
              addresses: const ['192.168.1.2'],
              pairing: null,
              backupFolder: '/Users/shamoo/Documents/Mobile Cloner Backups',
              backups: backups,
              adbDevices: adb,
              section: section,
              nearby: const [NearbyDeviceData(name: 'Galaxy S24', address: '192.168.1.20')],
              history: const [HistoryEntry(title: 'Photos from SM-X230', detail: '812 files · 150 MB', when: '2026-10-21 12:05')],
              appVersion: '0.1.0 (1)',
              live: live
                  ? const LiveTransferData(
                      peer: 'SM-X230',
                      fraction: 0.42,
                      bytesPerSecond: 31000000,
                      doneBytes: 80000000,
                      totalBytes: 186000000,
                      doneFiles: 300,
                      totalFiles: 812,
                      eta: Duration(seconds: 7),
                    )
                  : null,
            ),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
