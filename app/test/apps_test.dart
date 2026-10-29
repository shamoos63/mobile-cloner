import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_cloner/src/l10n.dart' show ltr;
import 'package:mobile_cloner/src/platform/android_bridge.dart';
import 'package:mobile_cloner/src/services/app_installer.dart';
import 'package:mobile_cloner/src/ui/phone/views/app_picker_view.dart';

import 'l10n_helpers.dart';

InstalledApp app(String pkg, String label, int size, {bool readable = true}) => InstalledApp(
  packageName: pkg,
  label: label,
  versionName: '1.0',
  versionCode: 1,
  apks: ['/data/app/$pkg/base.apk'],
  sizeBytes: size,
  readable: readable,
);

AppBundle bundle(String pkg, {int versionCode = 5, int? minSdk, int present = 2}) => AppBundle(
  dir: '/r/$pkg',
  manifest: AppManifest(
    packageName: pkg,
    label: pkg,
    versionName: '1',
    versionCode: versionCode,
    apks: const ['base.apk', 'split_config.arm64_v8a.apk'],
    sizeBytes: 100,
    minSdk: minSdk,
  ),
  apkPaths: ['/r/$pkg/base.apk', '/r/$pkg/split_config.arm64_v8a.apk'].take(present).toList(),
);

void main() {
  final apps = [
    app('org.telegram.messenger', 'Telegram', 80 * 1024 * 1024),
    app('com.google.android.apps.maps', 'Maps', 120 * 1024 * 1024),
    app('com.whatsapp', 'WhatsApp', 60 * 1024 * 1024),
    app('com.bank.secure', 'Bank', 40 * 1024 * 1024, readable: false),
  ];

  testWidgets('picker: search, select all / none, sort, count and size, unreadable apps disabled', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Set<String>? done;
    await tester.pumpWidget(localized(AppPickerView(
      apps: apps,
      initial: const {'com.whatsapp'},
      iconFor: (_) async => null,
      onDone: (s) => done = s,
    )));
    await tester.pump();
    expect(find.text('1 app · ${ltr('60.0 MB')}'), findsOneWidget);
    expect(find.text('Only the app is copied. App data and sign-ins stay on the old phone.'), findsOneWidget);
    expect(find.text("Android doesn't let HK Cloner read this app."), findsOneWidget);

    // Name order by default, size order on request.
    List<String> order() => [for (final t in tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile))) (t.title as Text).data!];
    expect(order(), ['Bank', 'Maps', 'Telegram', 'WhatsApp']);
    await tester.tap(find.text('Size'));
    await tester.pump();
    expect(order(), ['Maps', 'Telegram', 'WhatsApp', 'Bank']);

    // Select all skips the unreadable app.
    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(find.text('3 apps · ${ltr('260 MB')}'), findsOneWidget);
    await tester.tap(find.text('Bank'));
    await tester.pump();
    expect(find.text('3 apps · ${ltr('260 MB')}'), findsOneWidget);

    // Search narrows the list; Select none clears only what is shown.
    await tester.enterText(find.byType(TextField), 'tele');
    await tester.pump();
    expect(order(), ['Telegram']);
    await tester.tap(find.text('Select none'));
    await tester.pump();
    expect(find.text('2 apps · ${ltr('180 MB')}'), findsOneWidget);

    await tester.tap(find.text('Done'));
    expect(done, {'com.google.android.apps.maps', 'com.whatsapp'});
  });

  testWidgets('picker: Back keeps what was ticked', (tester) async {
    Set<String>? done;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(localized(Navigator(
      key: nav,
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const SizedBox()),
    )));
    nav.currentState!.push(MaterialPageRoute(
      builder: (context) => AppPickerView(
        apps: apps,
        initial: const {},
        iconFor: (_) async => null,
        onDone: (s) {
          done = s;
          Navigator.pop(context, s);
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maps'));
    await tester.pump();
    // The system Back button / gesture.
    await nav.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(done, {'com.google.android.apps.maps'});
    expect(find.byType(AppPickerView), findsNothing);
  });

  group('AppInstallQueue', () {
    test('checks first: incomplete, needs newer Android, already installed', () async {
      final q = AppInstallQueue(
        install: (_, {package, versionCode = 0}) async => (result: AppInstallResult.installed, detail: null),
        installedVersion: (pkg) async => pkg == 'have.same' ? 5 : (pkg == 'have.older' ? 4 : null),
        sdkInt: 30,
        bundles: [
          bundle('half', present: 1),
          bundle('needs.u', minSdk: 34),
          bundle('have.same'),
          bundle('have.older'),
          bundle('fresh'),
        ],
      );
      await q.check();
      expect([for (final i in q.items) i.state], [
        AppInstallState.incomplete,
        AppInstallState.needsNewerAndroid,
        AppInstallState.alreadyInstalled,
        AppInstallState.waiting,
        AppInstallState.waiting,
      ]);
    });

    test('Install all goes one by one, base APK first; a canceled one can be retried', () async {
      final calls = <List<String>>[];
      var answers = [AppInstallResult.installed, AppInstallResult.canceled];
      final q = AppInstallQueue(
        install: (apks, {package, versionCode = 0}) async {
          calls.add(apks);
          final r = answers.first;
          answers = answers.skip(1).toList();
          return (result: r, detail: null);
        },
        installedVersion: (_) async => null,
        sdkInt: 34,
        bundles: [bundle('a'), bundle('b')],
      );
      await q.check();
      await q.installAll();
      expect(calls, [
        ['/r/a/base.apk', '/r/a/split_config.arm64_v8a.apk'],
        ['/r/b/base.apk', '/r/b/split_config.arm64_v8a.apk'],
      ]);
      expect([for (final i in q.items) i.state], [AppInstallState.installed, AppInstallState.canceled]);

      answers = [AppInstallResult.failed];
      await q.installOne(q.items[1]);
      expect(q.items[1].state, AppInstallState.failed);
      await q.installOne(q.items[0]); // installed: nothing to do
      expect(calls.length, 3);
    });
  });
}
