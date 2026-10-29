import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_cloner/src/ui/desktop/views/desktop_view.dart';

import 'l10n_helpers.dart';

void main() {
  testWidgets('sidebar items switch the main panel', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The test font is much wider than Manrope; ignore the overflows it causes.
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!'${d.exception}'.contains('overflowed')) onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);

    var section = DesktopSection.overview;
    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setState) => localized(
        DesktopHomeView(
          hostName: 'mac',
          addresses: const [],
          pairing: null,
          backupFolder: '/tmp/backups',
          backups: const [],
          adbDevices: const [],
          section: section,
          onSection: (s) => setState(() => section = s),
        ),
      ),
    ));

    expect(find.text('Backup station'), findsOneWidget);
    final expected = {
      'Backups': 'Every phone backed up to this computer.',
      'Devices': 'Nearby on Wi-Fi',
      'History': 'Recent backups, newest first.',
      'Settings': 'Backup folder',
      'Overview': 'Backup station',
    };
    for (final e in expected.entries) {
      await tester.tap(find.descendant(of: find.byType(InkWell), matching: find.text(e.key)).first);
      await tester.pumpAndSettle();
      expect(find.text(e.value), findsOneWidget, reason: e.key);
    }
  });
}
