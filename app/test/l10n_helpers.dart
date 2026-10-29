import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_cloner/src/l10n.dart';
import 'package:mobile_cloner/src/services/app_settings.dart';
import 'package:mobile_cloner/src/ui/theme.dart';

/// [home] in [lang] (`ar` or `en`) the way the app shows it: locale,
/// delegates, text direction and the language's font. Also sets the app's
/// language for code that reads `tr`.
Widget localized(Widget home, {String lang = 'en'}) {
  AppSettings.instance.language = lang;
  return MaterialApp(
    locale: Locale(lang),
    supportedLocales: S.supportedLocales,
    localizationsDelegates: S.localizationsDelegates,
    theme: buildTheme(Brightness.light, arabic: lang == 'ar'),
    home: home,
  );
}

/// The bundled fonts, so text measures like in the app.
Future<void> loadAppFonts() async {
  for (final (family, weights) in [
    ('Manrope', ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']),
    ('Tajawal', ['Regular', 'Medium', 'Bold', 'ExtraBold']),
  ]) {
    final loader = FontLoader(family);
    for (final w in weights) {
      final bytes = File('assets/fonts/$family-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}
