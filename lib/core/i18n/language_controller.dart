import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  id,
  en,
}

extension AppLanguageX on AppLanguage {
  String get code => this == AppLanguage.en ? 'en' : 'id';

  String get label => this == AppLanguage.en ? 'English' : 'Bahasa Indonesia';

  static AppLanguage fromCode(String value) {
    if (value.toLowerCase().trim() == 'en') {
      return AppLanguage.en;
    }
    return AppLanguage.id;
  }
}

class LanguageController {
  LanguageController._();

  static const _prefKey = 'cvant_language_code';

  static final ValueNotifier<AppLanguage> language =
      ValueNotifier<AppLanguage>(AppLanguage.id);

  static Locale get locale => Locale(language.value.code);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey) ?? 'id';
    language.value = AppLanguageX.fromCode(raw);
  }

  static Future<void> setLanguage(AppLanguage next) async {
    if (language.value == next) return;
    language.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, next.code);
  }

  static Future<void> toggle() async {
    await setLanguage(
      language.value == AppLanguage.id ? AppLanguage.en : AppLanguage.id,
    );
  }
}
