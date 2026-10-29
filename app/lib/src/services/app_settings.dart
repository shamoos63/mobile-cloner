import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User settings, saved across restarts. Starts with defaults so the app
/// can build before [load] finishes.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final instance = AppSettings._();

  static const _deviceNameKey = 'deviceName';
  static const _themeKey = 'themeMode';
  static const _keepScreenOnKey = 'keepScreenOn';

  /// Name other devices see; null uses the phone's model.
  String? deviceName;
  ThemeMode themeMode = ThemeMode.system;

  /// Keep the screen on while a transfer runs (it is faster with the
  /// screen on, and some phones pause Wi-Fi when it goes off).
  bool keepScreenOn = true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    deviceName = prefs.getString(_deviceNameKey);
    themeMode = ThemeMode.values.asNameMap()[prefs.getString(_themeKey)] ?? ThemeMode.system;
    keepScreenOn = prefs.getBool(_keepScreenOnKey) ?? true;
    notifyListeners();
  }

  /// Blank resets to the phone's model name.
  Future<void> setDeviceName(String? name) async {
    final trimmed = name?.trim();
    deviceName = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (deviceName == null) {
      await prefs.remove(_deviceNameKey);
    } else {
      await prefs.setString(_deviceNameKey, deviceName!);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await (await SharedPreferences.getInstance()).setString(_themeKey, mode.name);
    notifyListeners();
  }

  Future<void> setKeepScreenOn(bool on) async {
    keepScreenOn = on;
    await (await SharedPreferences.getInstance()).setBool(_keepScreenOnKey, on);
    notifyListeners();
  }
}
