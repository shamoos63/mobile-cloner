// Renders the main screens with sample data to PNGs for docs and review.
// Run: flutter test screenshots/screenshots_test.dart --update-goldens
import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_cloner/src/ui/desktop/views/desktop_view.dart';
import 'package:mobile_cloner/src/ui/phone/views/home_view.dart';
import 'package:mobile_cloner/src/ui/phone/views/receive_view.dart';
import 'package:mobile_cloner/src/ui/phone/views/select_view.dart';
import 'package:mobile_cloner/src/ui/phone/views/transfer_view.dart';
import 'package:mobile_cloner/src/ui/theme.dart';

Future<void> _loadFonts() async {
  final manrope = FontLoader('Manrope');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    manrope.addFont(Future.value(ByteData.sublistView(File('assets/fonts/Manrope-$w.ttf').readAsBytesSync())));
  }
  await manrope.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(
        File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

const _pairing = PairingCode(
  addresses: ['192.168.1.42', '192.168.42.129'],
  port: 53317,
  fingerprint: '3F2A9C0B7E5D41A8B6C2F09E1D7A4C3B5E8F0A2D6C9B1E4F7A0D3C6B9E2F5A8C',
  alias: 'Galaxy S24',
);

const _batteryLow = PeerStatus(batteryLevel: 14, charging: false);
const _batteryOk = PeerStatus(batteryLevel: 82, charging: true);

Widget _frame(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildTheme(brightness),
  home: child,
);

void main() {
  setUpAll(_loadFonts);

  Future<void> shoot(WidgetTester tester, String name, Widget view, Size logical, double dpr,
      {Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = logical * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_frame(view, brightness: brightness));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
  }

  const phone = Size(412, 915);
  const desktop = Size(1440, 900);

  testWidgets('phone home', (t) => shoot(t, 'phone_home', PhoneHomeView(
    deviceName: 'Galaxy S10',
    osLabel: 'Android 12',
    myStatus: _batteryOk,
    resume: const ResumeInfo(peer: 'Galaxy S24', doneFiles: 1840, totalFiles: 2650, reason: 'Connection lost'),
    nearby: const [
      NearbyPeer(name: 'Galaxy S24', isDesktop: false, subtitle: 'Android 15 · Wi-Fi'),
      NearbyPeer(name: 'Hisham-MacBook', isDesktop: true, subtitle: 'Backup station · USB'),
    ],
    onSend: () {}, onReceive: () {}, onBackup: () {}, onRestore: () {}, onResume: () {},
  ), phone, 3));

  testWidgets('phone select', (t) => shoot(t, 'phone_select', SelectContentView(
    targetName: 'Galaxy S24',
    targetIsDesktop: false,
    items: [
      const SelectableItem(category: ContentCategory.photos, selected: true, count: 8412, bytes: 21400000000),
      const SelectableItem(category: ContentCategory.videos, selected: true, count: 612, bytes: 38900000000),
      const SelectableItem(category: ContentCategory.contacts, selected: true, count: 1186),
      SelectableItem(
        category: ContentCategory.whatsapp, selected: true, count: 23841, bytes: 9600000000,
        warning: 'Last chat backup: 3 days ago', actionLabel: 'Back up now', onAction: () {},
      ),
      const SelectableItem(category: ContentCategory.whatsappBusiness, selected: false, count: 2210, bytes: 1100000000),
    ],
    onToggle: (_, _) {},
    onStart: () {},
    onWhatsAppScope: (_) {},
  ), phone, 3));

  testWidgets('phone transfer', (t) => shoot(t, 'phone_transfer', TransferView(
    title: 'Sending to Galaxy S24',
    peerName: 'S24',
    fraction: 0.64,
    doneBytes: 45100000000,
    totalBytes: 71000000000,
    bytesPerSecond: 48600000,
    eta: const Duration(minutes: 9),
    doneFiles: 21780,
    totalFiles: 34061,
    currentFile: 'DCIM/Camera/VID_20250814_193201.mp4',
    onPause: () {},
    onCancel: () {},
    myStatus: _batteryOk,
    peerStatus: _batteryLow,
    categories: const [
      CategoryProgress(ContentCategory.contacts, 1, 1),
      CategoryProgress(ContentCategory.whatsapp, 23841, 23841),
      CategoryProgress(ContentCategory.photos, 5120, 8412),
      CategoryProgress(ContentCategory.videos, 0, 612),
    ],
  ), phone, 3));

  testWidgets('phone interrupted', (t) => shoot(t, 'phone_interrupted', TransferView(
    title: 'Sending to Galaxy S24',
    peerName: 'S24',
    fraction: 0.71,
    doneBytes: 50400000000,
    totalBytes: 71000000000,
    bytesPerSecond: 0,
    doneFiles: 24310,
    totalFiles: 34061,
    myStatus: _batteryOk,
    peerStatus: const PeerStatus(batteryLevel: 4, charging: false),
    interruptedReason: 'Battery critical on Galaxy S24',
    onResume: () {},
    onReconnect: () {},
    categories: const [
      CategoryProgress(ContentCategory.whatsapp, 23841, 23841),
      CategoryProgress(ContentCategory.photos, 7650, 8412),
    ],
  ), phone, 3, brightness: Brightness.dark));

  testWidgets('phone receive', (t) => shoot(t, 'phone_receive', ReceiveView(
    deviceName: 'Galaxy S24',
    pairing: _pairing,
    mode: ConnectionMode.usbTethering,
    onMode: (_) {},
    needsWhatsAppAccess: true,
    onGrantWhatsApp: () {},
  ), phone, 3));

  testWidgets('desktop', (t) => shoot(t, 'desktop_home', const DesktopHomeView(
    hostName: 'Hisham-MacBook',
    addresses: ['192.168.1.20'],
    pairing: _pairing,
    backupFolder: '/Users/hisham/Documents/Mobile Cloner Backups',
    adbDevices: [AdbDeviceData(serial: 'R58N12ABCDE · Galaxy S10', connected: true), AdbDeviceData(serial: 'RFCW3XYZ987 · Galaxy A54', connected: false)],
    live: LiveTransferData(
      peer: 'Galaxy S10',
      fraction: 0.42,
      bytesPerSecond: 112400000,
      doneBytes: 29800000000,
      totalBytes: 71000000000,
      doneFiles: 14302,
      totalFiles: 34061,
      eta: Duration(minutes: 6),
      peerStatus: PeerStatus(batteryLevel: 67, charging: true),
    ),
    backups: [
      BackupCardData(alias: 'Galaxy S10', subtitle: 'Android 12 · SM-G973F', lastBackup: 'Today, 09:41', bytesByCategory: {
        ContentCategory.videos: 38900000000, ContentCategory.photos: 21400000000,
        ContentCategory.whatsapp: 9600000000, ContentCategory.contacts: 2400000,
      }),
      BackupCardData(alias: 'Pixel 6a', subtitle: 'Android 14 · bluejay', lastBackup: 'Oct 12, 21:05', bytesByCategory: {
        ContentCategory.photos: 12100000000, ContentCategory.whatsapp: 4300000000,
        ContentCategory.whatsappBusiness: 1200000000, ContentCategory.contacts: 900000,
      }),
      BackupCardData(alias: 'Galaxy A12', subtitle: 'Android 6.0 · SM-A125F', lastBackup: 'Sep 30, 18:22', bytesByCategory: {
        ContentCategory.photos: 6400000000, ContentCategory.videos: 3100000000, ContentCategory.whatsapp: 2200000000,
      }),
    ],
  ), desktop, 2));
}
