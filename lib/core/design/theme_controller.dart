import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the persisted light/dark/system appearance preference.
class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;

  static const _key = 'leadx_theme_mode';

  Future<void> setMode(ThemeMode next) async {
    mode = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (next == ThemeMode.system) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, next.name);
    }
  }

  static Future<ThemeController> init() async {
    final c = ThemeController();
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_key)) {
      case 'light':
        c.mode = ThemeMode.light;
      case 'dark':
        c.mode = ThemeMode.dark;
      default:
        c.mode = ThemeMode.system;
    }
    return c;
  }
}
