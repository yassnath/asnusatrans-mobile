import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../security/app_security.dart';

class AppErrorReporter {
  const AppErrorReporter._();

  static const _recentEventsPrefsKey = 'app_error_events_recent_v1';
  static const _maxRecentEvents = 20;

  static bool _initialized = false;

  static Future<void> initialize() async {
    _initialized = true;
  }

  static void reportFlutterError(
    FlutterErrorDetails details, {
    required String context,
    bool fatal = false,
  }) {
    report(
      details.exception,
      details.stack,
      context: context,
      fatal: fatal,
    );
  }

  static void report(
    Object error,
    StackTrace? stackTrace, {
    required String context,
    bool fatal = false,
  }) {
    final message = AppSecurity.sanitizeUserFacingError(
      error.toString(),
      fallback: 'Unexpected application error.',
    );
    final stack = stackTrace?.toString() ?? '';
    final event = _AppErrorEvent(
      context: sanitizeContext(context),
      message: message,
      fingerprint: fingerprintFor(message, stack),
      platform: defaultTargetPlatform.name,
      fatal: fatal,
      createdAt: DateTime.now().toUtc(),
    );

    unawaited(_persistAndUpload(event));
  }

  @visibleForTesting
  static String sanitizeContext(String value) {
    final sanitized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.:-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    if (sanitized.isEmpty) return 'unknown';
    return sanitized.length <= 80 ? sanitized : sanitized.substring(0, 80);
  }

  @visibleForTesting
  static String fingerprintFor(String message, String stackTrace) {
    final topFrames = stackTrace
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(4)
        .join('|');
    final seed = '$message|$topFrames';
    var hash = 0x811c9dc5;
    for (final codeUnit in seed.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Future<void> _persistAndUpload(_AppErrorEvent event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current =
          prefs.getStringList(_recentEventsPrefsKey) ?? const <String>[];
      final next = <String>[
        jsonEncode(event.toLocalJson()),
        ...current,
      ].take(_maxRecentEvents).toList(growable: false);
      await prefs.setStringList(_recentEventsPrefsKey, next);
    } catch (_) {
      // Error reporting must never make the original failure worse.
    }

    if (!_initialized || kDebugMode) return;

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if ((userId ?? '').isEmpty) return;
      await client.from('app_error_events').insert(event.toRemoteJson(userId));
    } catch (_) {
      // Remote monitoring is best-effort; local recent events stay available.
    }
  }
}

class _AppErrorEvent {
  const _AppErrorEvent({
    required this.context,
    required this.message,
    required this.fingerprint,
    required this.platform,
    required this.fatal,
    required this.createdAt,
  });

  final String context;
  final String message;
  final String fingerprint;
  final String platform;
  final bool fatal;
  final DateTime createdAt;

  Map<String, dynamic> toLocalJson() {
    return <String, dynamic>{
      'context': context,
      'message': message,
      'fingerprint': fingerprint,
      'platform': platform,
      'fatal': fatal,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toRemoteJson(String? userId) {
    return <String, dynamic>{
      'user_id': userId,
      'event_context': context,
      'message': message,
      'fingerprint': fingerprint,
      'platform': platform,
      'fatal': fatal,
      'metadata': <String, dynamic>{},
      'created_at': createdAt.toIso8601String(),
    };
  }
}
