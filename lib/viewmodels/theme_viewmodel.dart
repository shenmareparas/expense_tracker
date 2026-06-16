import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ViewModel for theme mode persistence and notification.
///
/// Caches the [SharedPreferences] instance so subsequent writes
/// don't await [SharedPreferences.getInstance] again.
class ThemeViewModel extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _hapticEnabled = true;
  String _defaultAnalyticsTab = 'net';
  List<String> _analyticsTabOrder = ['net', 'expense', 'income'];
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  bool get hapticEnabled => _hapticEnabled;
  String get defaultAnalyticsTab => _defaultAnalyticsTab;
  List<String> get analyticsTabOrder => _analyticsTabOrder;

  ThemeViewModel() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    final themeString = _prefs!.getString('theme_mode') ?? 'system';
    _hapticEnabled = _prefs!.getBool('haptic_enabled') ?? true;
    _defaultAnalyticsTab = _prefs!.getString('default_analytics_tab') ?? 'expense';
    _analyticsTabOrder = _prefs!.getStringList('analytics_tab_order') ?? ['expense', 'income', 'net'];

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

  Future<void> setDefaultAnalyticsTab(String tab) async {
    _defaultAnalyticsTab = tab;
    notifyListeners();

    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('default_analytics_tab', tab);
  }

  Future<void> setAnalyticsTabOrder(List<String> order) async {
    _analyticsTabOrder = List.from(order);
    notifyListeners();

    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setStringList('analytics_tab_order', order);
  }
}
