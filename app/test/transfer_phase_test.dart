import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_cloner/src/ui/phone/views/transfer_view.dart';

import 'l10n_helpers.dart';

/// The buttons always match the phase: a finished send never offers Pause
/// or Cancel, an unfinished one never shows Done.
void main() {
  Widget view(TransferPhase phase, {bool stuck = false, List<String>? taps}) => localized(TransferView(
    title: 'Sending to Mac',
    peerName: 'Mac',
    fraction: phase == TransferPhase.sending ? 0.62 : 1,
    doneBytes: 100,
    totalBytes: 100,
    bytesPerSecond: 1000000,
    doneFiles: phase == TransferPhase.sending ? 5 : 7,
    totalFiles: 7,
    currentFile: 'com.STSelfCare.STApp/base.apk',
    categories: const [CategoryProgress(ContentCategory.apps, 6, 6)],
    phase: phase,
    finishingStuck: stuck,
    interruptedReason: phase == TransferPhase.interrupted ? 'Connection lost.' : null,
    onPause: () => taps?.add('pause'),
    onCancel: () => taps?.add('cancel'),
    onResume: () => taps?.add('resume'),
    onDone: () => taps?.add('done'),
  ));

  setUpAll(loadAppFonts);

  testWidgets('sending: Pause and Cancel, never Done', (tester) async {
    await tester.pumpWidget(view(TransferPhase.sending));
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
    expect(find.text('All done'), findsNothing);
    expect(find.textContaining('STApp/base.apk'), findsOneWidget);
  });

  testWidgets('finishing: no Pause or Cancel; Resume only once it is stuck', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(view(TransferPhase.finishing));
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Done'), findsNothing);
    expect(find.text('Finishing up...'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);

    final taps = <String>[];
    await tester.pumpWidget(view(TransferPhase.finishing, stuck: true, taps: taps));
    expect(find.textContaining('has not confirmed yet'), findsOneWidget);
    await tester.ensureVisible(find.text('Resume'));
    await tester.tap(find.text('Resume'));
    expect(taps, ['resume']);
  });

  testWidgets('done: only Done, no speed, no current file', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final taps = <String>[];
    await tester.pumpWidget(view(TransferPhase.done, taps: taps));
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('All done'), findsOneWidget);
    expect(find.textContaining('MB/s'), findsNothing);
    expect(find.textContaining('STApp/base.apk'), findsNothing);
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    expect(taps, ['done']);
  });

  testWidgets('interrupted: the resume card, no Pause', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(view(TransferPhase.interrupted));
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Continue another way'), findsOneWidget);
  });
}
