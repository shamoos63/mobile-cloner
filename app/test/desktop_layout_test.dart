import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_cloner/src/ui/desktop/views/desktop_view.dart';

import 'l10n_helpers.dart';

/// Every desktop panel, in Arabic (right to left) and English, at window
/// sizes from small to large, with the real fonts so text measures like in
/// the app: no RenderFlex may overflow.
void main() {
  setUpAll(loadAppFonts);

  const backups = [
    BackupCardData(
      alias: 'Samsung SM-X230',
      subtitle: 'Android API 35 · SM-X230',
      lastBackup: '2026-10-21 12:05',
      bytesByCategory: {
        ContentCategory.photos: 150000000,
        ContentCategory.videos: 36000000,
        ContentCategory.contacts: 20000,
      },
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
    AdbDeviceData(
      serial: 'R5GYB1VDTJA',
      name: 'SM-X230',
      connected: true,
      status: 'Opened on the phone. Choose what to back up there.',
    ),
    AdbDeviceData(serial: 'emulator-5554', connected: false, status: 'Setup failed: device offline'),
  ];

  for (final lang in ['ar', 'en']) {
    for (final size in const [Size(720, 560), Size(800, 600), Size(1024, 700), Size(1280, 800), Size(1600, 1000)]) {
      for (final section in DesktopSection.values) {
        for (final live in [false, true]) {
          testWidgets('$lang ${section.name} at ${size.width.toInt()}x${size.height.toInt()}${live ? ' (live)' : ''}', (
            tester,
          ) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              localized(
                lang: lang,
                DesktopHomeView(
                  hostName: 'Hishams-MacBook-Pro.local',
                  addresses: const ['192.168.1.2'],
                  pairing: null,
                  backupFolder: '/Users/shamoo/Documents/Mobile Cloner Backups',
                  backups: backups,
                  adbDevices: adb,
                  section: section,
                  nearby: const [NearbyDeviceData(name: 'Galaxy S24', address: '192.168.1.20')],
                  history: const [
                    HistoryEntry(title: 'Photos from SM-X230', detail: '812 files · 150 MB', when: '2026-10-21 12:05'),
                  ],
                  appVersion: '0.1.0 (1)',
                  language: lang,
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
              ),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }

  testWidgets('the sidebar is on the right in Arabic and on the left in English', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final (lang, overview) in [('ar', 'نظرة عامة'), ('en', 'Overview')]) {
      await tester.pumpWidget(
        localized(
          lang: lang,
          DesktopHomeView(
            hostName: 'mac',
            addresses: const [],
            pairing: null,
            backupFolder: '/tmp/backups',
            backups: const [],
            adbDevices: const [],
            language: lang,
          ),
        ),
      );
      final x = tester.getCenter(find.text(overview)).dx;
      expect(lang == 'ar' ? x > 1000 : x < 280, isTrue, reason: '$lang sidebar item at x=$x');
    }
  });
}
