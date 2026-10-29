import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_cloner/src/ui/desktop/install_app_dialog.dart';

void main() {
  late Directory tmp;
  late String bundled;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('apk');
    bundled = (File('${tmp.path}/hk-cloner.apk')..writeAsBytesSync(List.filled(2048, 0))).path;
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Opens the dialog; the returned list gets what it popped.
  Future<List<bool?>> open(
    WidgetTester tester, {
    PhoneApp app = const PhoneApp(null, 1),
    String? apkPath,
    required List<String> calls,
    Object? installError,
    String? picked,
  }) async {
    final result = <bool?>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result.add(await showDialog<bool>(
            context: context,
            builder: (_) => InstallAppDialog(
              deviceName: 'Galaxy A53',
              app: app,
              apkPath: apkPath,
              bundledVersion: '0.1.0 (1)',
              install: (apk) async {
                calls.add('install $apk');
                if (installError != null && !calls.contains('uninstall')) throw installError;
              },
              uninstall: () async => calls.add('uninstall'),
              pickApk: () async => picked,
            ),
          )),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('missing app: installs the bundled APK and closes', (tester) async {
    final calls = <String>[];
    final result = await open(tester, apkPath: bundled, calls: calls);
    expect(find.text("HK Cloner isn't on Galaxy A53"), findsOneWidget);
    expect(find.textContaining('HK Cloner 0.1.0 (1) · 2.0 KB'), findsOneWidget);
    await tester.tap(find.text('Install on phone'));
    await tester.pumpAndSettle();
    expect(calls, ['install $bundled']);
    expect(result, [true]);
  });

  testWidgets('older app: offers an update', (tester) async {
    await open(tester, app: const PhoneApp(1, 2), apkPath: bundled, calls: []);
    expect(find.text('HK Cloner on Galaxy A53 is out of date'), findsOneWidget);
    expect(find.text('Update on phone'), findsOneWidget);
  });

  testWidgets('no bundled APK: choose one, then install it', (tester) async {
    final calls = <String>[];
    final other = (File('${tmp.path}/picked.apk')..writeAsStringSync('apk')).path;
    await open(tester, calls: calls, picked: other);
    expect(find.textContaining('No phone app was found'), findsOneWidget);
    expect(find.text('Install on phone'), findsNothing);
    await tester.tap(find.text('Choose APK...'));
    await tester.pumpAndSettle();
    expect(find.textContaining('picked.apk'), findsOneWidget);
    await tester.tap(find.text('Install on phone'));
    await tester.pumpAndSettle();
    expect(calls, ['install $other']);
  });

  testWidgets('different signature: uninstalls only after the user confirms', (tester) async {
    final calls = <String>[];
    final result = await open(
      tester,
      apkPath: bundled,
      calls: calls,
      installError: AdbInstallException(InstallFailure.updateIncompatible, 'Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE]'),
    );
    await tester.tap(find.text('Install on phone'));
    await tester.pumpAndSettle();
    expect(find.textContaining("deletes HK Cloner's data on the phone"), findsOneWidget);
    expect(calls, ['install $bundled']);
    await tester.tap(find.text('Uninstall and install'));
    await tester.pumpAndSettle();
    expect(calls, ['install $bundled', 'uninstall', 'install $bundled']);
    expect(result, [true]);
  });

  testWidgets('blocked install: explains what to do on the phone and can retry', (tester) async {
    final calls = <String>[];
    final result = await open(
      tester,
      apkPath: bundled,
      calls: calls,
      installError: AdbInstallException(InstallFailure.blocked, 'Failure [INSTALL_FAILED_USER_RESTRICTED]'),
    );
    await tester.tap(find.text('Install on phone'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The phone refused the install'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Uninstall and install'), findsNothing);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(result, [null]);
    expect(calls.where((c) => c == 'uninstall'), isEmpty);
  });
}
