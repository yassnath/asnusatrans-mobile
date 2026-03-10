import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/i18n/language_controller.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.hasSupabase) {
    throw StateError(
      'SUPABASE_URL dan SUPABASE_ANON_KEY wajib diisi via --dart-define.',
    );
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  await ThemeController.init();
  await LanguageController.init();

  runApp(const CvantApp());
}
