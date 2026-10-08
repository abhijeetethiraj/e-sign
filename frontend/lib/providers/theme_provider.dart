import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central state manager for application theme (Light, Dark, System).
/// Persists user preference in SharedPreferences across app restarts.
class ThemeProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Restores saved theme preference from local storage
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString(_keyThemeMode);
      if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (saved == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.light;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[ThemeProvider] Error loading theme mode: $e');
    }
  }

  /// Toggles between Light and Dark mode
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  /// Sets specific ThemeMode and persists to storage
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String value = mode == ThemeMode.dark
          ? 'dark'
          : (mode == ThemeMode.system ? 'system' : 'light');
      await prefs.setString(_keyThemeMode, value);
    } catch (e) {
      debugPrint('[ThemeProvider] Error saving theme mode: $e');
    }
  }
}
