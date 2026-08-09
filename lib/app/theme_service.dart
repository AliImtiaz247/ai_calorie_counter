import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const _themeModeKey = 'settings_theme_mode';
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
    ThemeMode.light,
  );

  static ThemeMode get current => themeModeNotifier.value;

  static ThemeMode themeModeFromString(String? value) {
    if (value == 'dark') {
      return ThemeMode.dark;
    }
    if (value == 'system') {
      return ThemeMode.system;
    }
    return ThemeMode.light;
  }

  static String themeModeToString(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeModeKey);
    themeModeNotifier.value = themeModeFromString(savedMode);
  }

  static Future<void> setThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, themeModeToString(themeMode));
    themeModeNotifier.value = themeMode;
  }
}
