import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/i18n/language_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/auth_gate.dart';

class CvantApp extends StatelessWidget {
  const CvantApp({super.key, this.startupError});

  final Object? startupError;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: LanguageController.language,
          builder: (context, language, __) {
            return MaterialApp(
              title: 'AS Nusa Trans',
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              locale: Locale(language.code),
              supportedLocales: const [
                Locale('id'),
                Locale('en'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: startupError == null
                  ? const AuthGate()
                  : _StartupErrorScreen(error: startupError!),
            );
          },
        );
      },
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aplikasi gagal dibuka',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Terjadi masalah saat inisialisasi aplikasi. Tutup aplikasi lalu buka lagi. Jika masih sama, kirimkan error ini ke tim pengembang.',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SelectableText(
                      error.toString(),
                      style: const TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
