import 'package:flutter/material.dart';

/// Visual language: calm off-white (or deep navy) canvas, white cards with
/// soft shadows, and one indigo-to-teal gradient reserved for the hero
/// surfaces and the main progress ring.
abstract final class AppColors {
  static const indigo = Color(0xFF4F46E5);
  static const violet = Color(0xFF7C3AED);
  static const teal = Color(0xFF14B8A6);
  static const amber = Color(0xFFF59E0B);
  static const rose = Color(0xFFE11D48);

  static const canvasLight = Color(0xFFF5F6FB);
  static const canvasDark = Color(0xFF0B1020);
  static const cardDark = Color(0xFF141A2E);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF312E81), indigo, Color(0xFF0F766E)],
    stops: [0, 0.55, 1],
  );

  static const ringGradient = SweepGradient(colors: [indigo, violet, teal, indigo]);
}

/// [arabic] uses Tajawal (Manrope has no Arabic letters); each font falls
/// back to the other, so Arabic names show in English and Latin in Arabic.
ThemeData buildTheme(Brightness brightness, {bool arabic = false}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.indigo,
    brightness: brightness,
    surface: dark ? AppColors.cardDark : Colors.white,
  ).copyWith(
    primary: dark ? const Color(0xFF818CF8) : AppColors.indigo,
    onPrimary: Colors.white,
    secondaryContainer: dark ? const Color(0xFF312E81) : const Color(0xFFE0E7FF),
    onSecondaryContainer: dark ? Colors.white : const Color(0xFF312E81),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: arabic ? 'Tajawal' : 'Manrope',
    fontFamilyFallback: arabic ? const ['Manrope'] : const ['Tajawal'],
  );
  final text = base.textTheme.copyWith(
    displayMedium: base.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.5),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );
  return base.copyWith(
    scaffoldBackgroundColor: dark ? AppColors.canvasDark : AppColors.canvasLight,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 4,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: dark ? Colors.white10 : const Color(0xFFE7E9F2)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: text.labelLarge?.copyWith(fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: text.labelLarge,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: BorderSide(color: dark ? Colors.white12 : const Color(0xFFE7E9F2)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        side: BorderSide(color: dark ? Colors.white12 : const Color(0xFFE0E3EE)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: const Size.fromHeight(48),
      ),
    ),
    checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
  );
}
