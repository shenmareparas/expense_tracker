import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ViewModel for theme mode persistence and notification.
///
/// Caches the [SharedPreferences] instance so subsequent writes
/// don't await [SharedPreferences.getInstance] again.
class ThemeViewModel extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _hapticEnabled = true;
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  bool get hapticEnabled => _hapticEnabled;

  ThemeViewModel() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    final themeString = _prefs!.getString('theme_mode') ?? 'system';
    _hapticEnabled = _prefs!.getBool('haptic_enabled') ?? true;

    _themeMode = ThemeMode.values.firstWhere(
      (e) => e.name == themeString,
      orElse: () => ThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('theme_mode', mode.name);
  }

  Future<void> setHapticEnabled(bool enabled) async {
    _hapticEnabled = enabled;
    notifyListeners();

    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('haptic_enabled', enabled);
  }
}
