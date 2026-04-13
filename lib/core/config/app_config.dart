import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class AppConfig {
  const AppConfig._();

  static const _defaultSupabaseUrl = 'https://msziutqvkrbwwohcdoou.supabase.co';
  static const _defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zeml1dHF2a3Jid3dvaGNkb291Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE2ODUxOTEsImV4cCI6MjA4NzI2MTE5MX0.zsjHAtY2OAR1CwXWMep45qeU3YyHbw7-RX-aPyChC5Y';
  static const _envSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _envSupabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _envInvoiceRenderServiceUrl =
      String.fromEnvironment('INVOICE_RENDER_SERVICE_URL');
  static const _envFirebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _envFirebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _envFirebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _envFirebaseStorageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _envFirebaseAndroidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _envFirebaseIosAppId =
      String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _envFirebaseIosBundleId =
      String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  // Empty --dart-define values should not disable the built-in fallback config.
  static String get supabaseUrl {
    final value = _envSupabaseUrl.trim();
    return value.isNotEmpty ? value : _defaultSupabaseUrl;
  }

  static String get supabaseAnonKey {
    final value = _envSupabaseAnonKey.trim();
    return value.isNotEmpty ? value : _defaultSupabaseAnonKey;
  }

  static bool get hasSupabase =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static String get invoiceRenderServiceUrl =>
      _envInvoiceRenderServiceUrl.trim();

  static bool get hasInvoiceRenderService => invoiceRenderServiceUrl.isNotEmpty;

  static String get firebaseApiKey => _envFirebaseApiKey.trim();

  static String get firebaseProjectId => _envFirebaseProjectId.trim();

  static String get firebaseMessagingSenderId =>
      _envFirebaseMessagingSenderId.trim();

  static String get firebaseStorageBucket => _envFirebaseStorageBucket.trim();

  static String get firebaseAndroidAppId => _envFirebaseAndroidAppId.trim();

  static String get firebaseIosAppId => _envFirebaseIosAppId.trim();

  static String get firebaseIosBundleId => _envFirebaseIosBundleId.trim();

  static FirebaseOptions? get firebaseOptionsForCurrentPlatform {
    if (!kIsWeb) {
      try {
        return DefaultFirebaseOptions.currentPlatform;
      } on UnsupportedError {
        // Fall back to manual dart-define Firebase options below.
      }
    }

    if (kIsWeb) return null;

    final apiKey = firebaseApiKey;
    final projectId = firebaseProjectId;
    final senderId = firebaseMessagingSenderId;
    if (apiKey.isEmpty || projectId.isEmpty || senderId.isEmpty) {
      return null;
    }

    final storageBucket = firebaseStorageBucket;
    final normalizedStorageBucket =
        storageBucket.isEmpty ? null : storageBucket;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final appId = firebaseAndroidAppId;
        if (appId.isEmpty) return null;
        return FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: projectId,
          storageBucket: normalizedStorageBucket,
        );
      case TargetPlatform.iOS:
        final appId = firebaseIosAppId;
        if (appId.isEmpty) return null;
        final bundleId = firebaseIosBundleId;
        return FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: projectId,
          storageBucket: normalizedStorageBucket,
          iosBundleId: bundleId.isEmpty ? null : bundleId,
        );
      default:
        return null;
    }
  }

  static bool get hasFirebaseManualOptions =>
      firebaseOptionsForCurrentPlatform != null;
}
