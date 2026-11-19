import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Owns the persisted light/dark/system preference and the liquid-glass
/// navigation toggle.
class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;
  bool glassEnabled = true;

  Future<void> setMode(ThemeMode next) async {
    mode = next;
    notifyListeners();
    await ThemeService.save(next);
  }

  Future<void> setGlassEnabled(bool on) async {
    glassEnabled = on;
    notifyListeners();
    await ThemeService.setGlassEnabled(on);
  }

  static Future<ThemeController> init() async {
    final c = ThemeController();
    c.mode = await ThemeService.load();
    c.glassEnabled = await ThemeService.glassEnabled();
    return c;
  }
}
