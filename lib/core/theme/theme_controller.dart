import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._();

  static const _prefKey = 'cvant_theme_mode';
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey) ?? 'dark';
    mode.value = raw == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  static Future<void> setMode(ThemeMode next) async {
    if (mode.value == next) return;
    mode.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, next == ThemeMode.light ? 'light' : 'dark');
  }

  static Future<void> toggle() async {
    await setMode(mode.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }
}
