import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/i18n/language_controller.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/security/app_security.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installFrameworkErrorFilters();
  ErrorWidget.builder = AppSecurity.buildReleaseErrorWidget;

  Object? startupError;

  try {
    if (!AppConfig.hasSupabase) {
      throw StateError(
        'SUPABASE_URL dan SUPABASE_ANON_KEY wajib diisi via --dart-define.',
      );
    }
    AppSecurity.validateRuntimeConfigOrThrow();

    final disableWindowsDeepLinkObserver =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        detectSessionInUri: !disableWindowsDeepLinkObserver,
      ),
    );
    await _ensureBundledIconFontsReady();
    await ThemeController.init();
    await LanguageController.init();
    await PushNotificationService.instance.initialize();
  } catch (error, stackTrace) {
    startupError = AppSecurity.sanitizeUserFacingError(
      error.toString(),
      fallback: 'Inisialisasi aplikasi gagal. Coba buka ulang aplikasi.',
    );
    AppSecurity.debugLog(
      'App startup failed',
      error: error,
      stackTrace: stackTrace,
    );
  }

  runApp(CvantApp(startupError: startupError));
}

Future<void> _ensureBundledIconFontsReady() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
    return;
  }

  Future<ByteData?> loadFontData(String assetPath) async {
    final normalizedPath = assetPath.replaceAll('/', Platform.pathSeparator);
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final currentDir = Directory.current.path;
    final fileCandidates = <String>[
      [executableDir, 'data', 'flutter_assets', normalizedPath]
          .join(Platform.pathSeparator),
      [currentDir, 'data', 'flutter_assets', normalizedPath]
          .join(Platform.pathSeparator),
      [currentDir, normalizedPath].join(Platform.pathSeparator),
    ];

    for (final candidate in fileCandidates) {
      final file = File(candidate);
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        return ByteData.sublistView(bytes);
      }
    }

    try {
      return await rootBundle.load(assetPath);
    } catch (error, stackTrace) {
      AppSecurity.debugLog(
        'Failed to load icon font asset $assetPath',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> loadFont(String family, String assetPath) async {
    try {
      final fontData = await loadFontData(assetPath);
      if (fontData == null) return;
      final loader = FontLoader(family);
      loader.addFont(Future<ByteData>.value(fontData));
      await loader.load();
    } catch (error, stackTrace) {
      AppSecurity.debugLog(
        'Failed to eagerly load bundled font $family',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  await Future.wait<void>([
    loadFont('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    loadFont(
      'CupertinoIcons',
      'packages/cupertino_icons/assets/CupertinoIcons.ttf',
    ),
  ]);
}

void _installFrameworkErrorFilters() {
  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (_isIgnorableWindowsKeyboardAssertion(
      details.exception,
      details.stack,
    )) {
      AppSecurity.debugLog(
        'Ignored Windows keyboard synchronization assertion',
        error: details.exceptionAsString(),
      );
      return;
    }

    if (previousFlutterError != null) {
      previousFlutterError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    if (_isIgnorableWindowsKeyboardAssertion(error, stack)) {
      AppSecurity.debugLog(
        'Ignored Windows platform keyboard synchronization assertion',
        error: error,
      );
      return true;
    }

    if (previousPlatformError != null) {
      return previousPlatformError(error, stack);
    }
    return false;
  };
}

bool _isIgnorableWindowsKeyboardAssertion(
  Object error,
  StackTrace? stackTrace,
) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
    return false;
  }

  final message = error.toString();
  final stack = stackTrace?.toString() ?? '';
  const knownKeyboardSyncMarkers = <String>[
    'Attempted to send a key down event when no keys are in keysPressed',
    'A KeyUpEvent is dispatched, but the state shows that the physical key is not pressed',
    'A KeyDownEvent is dispatched, but the state shows that the physical key is already pressed',
  ];

  final matchesKnownMessage = knownKeyboardSyncMarkers.any(
    (marker) => message.contains(marker),
  );
  if (!matchesKnownMessage) return false;

  return stack.contains('raw_keyboard.dart') ||
      stack.contains('hardware_keyboard.dart') ||
      message.contains('keysPressed') ||
      message.contains('_pressedKeys');
}
