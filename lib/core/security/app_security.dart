import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';

class AppSecurity {
  const AppSecurity._();

  static const _allowedExternalHosts = <String>{
    'wa.me',
    'api.whatsapp.com',
  };

  static void validateRuntimeConfigOrThrow() {
    if (!_isAllowedRemoteUrl(AppConfig.supabaseUrl,
        allowLocalhost: kDebugMode)) {
      throw StateError(
        'SUPABASE_URL harus menggunakan HTTPS yang valid'
        '${kDebugMode ? ' atau localhost untuk debug' : ''}.',
      );
    }

    if (AppConfig.hasInvoiceRenderService &&
        !_isAllowedRemoteUrl(
          AppConfig.invoiceRenderServiceUrl,
          allowLocalhost:
              kDebugMode || AppConfig.allowInsecureInvoiceRenderService,
          allowPrivateNetwork:
              kDebugMode || AppConfig.allowInsecureInvoiceRenderService,
        )) {
      throw StateError(
        'INVOICE_RENDER_SERVICE_URL harus menggunakan HTTPS yang valid'
        '${kDebugMode ? ' atau localhost/private network untuk debug' : ''}.',
      );
    }
  }

  static Uri? buildSecureRemoteUri(
    String rawUrl, {
    String? appendPathSegment,
    bool allowLocalhost = false,
    bool allowPrivateNetwork = false,
  }) {
    final value = rawUrl.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !_isAllowedRemoteUrl(
          value,
          allowLocalhost: allowLocalhost,
          allowPrivateNetwork: allowPrivateNetwork,
        )) {
      return null;
    }

    if ((appendPathSegment ?? '').trim().isEmpty) return uri;
    final nextSegments = <String>[
      ...uri.pathSegments.where((segment) => segment.trim().isNotEmpty),
      appendPathSegment!.trim(),
    ];
    return uri.replace(pathSegments: nextSegments);
  }

  static bool isAllowedExternalUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'mailto' || scheme == 'tel') return true;
    if (scheme != 'https') return false;
    return _allowedExternalHosts.contains(uri.host.toLowerCase());
  }

  static String sanitizeUserFacingError(
    String rawMessage, {
    String fallback = 'Terjadi kendala sistem. Silakan coba lagi.',
  }) {
    final message = rawMessage.replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) return fallback;

    final normalized = message.toLowerCase();
    const sensitiveMarkers = <String>[
      'postgrestexception',
      'schema cache',
      'stack trace',
      'access_token',
      'refresh_token',
      'apikey',
      'bearer ',
      'jwt',
      'select ',
      'insert ',
      'update ',
      'delete ',
      'relation ',
      'column ',
      'sql',
      'constraint',
    ];
    final looksSensitive = sensitiveMarkers.any(normalized.contains);
    if (looksSensitive) return fallback;

    if (message.length > 220) return fallback;
    return message;
  }

  static void debugLog(String message,
      {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    final buffer = StringBuffer(message);
    if (error != null) buffer.write(' | $error');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    debugPrint(buffer.toString());
  }

  static Widget buildReleaseErrorWidget(FlutterErrorDetails details) {
    if (kDebugMode) {
      return ErrorWidget(details.exception);
    }

    return Material(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 42,
                      color: Color(0xFF1D4ED8),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Terjadi kendala tampilan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Silakan muat ulang halaman atau buka ulang aplikasi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF475569),
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

  static int recommendedLoginCooldownSeconds(int failedAttempts) {
    if (failedAttempts >= 8) return 90;
    if (failedAttempts >= 5) return 45;
    if (failedAttempts >= 3) return 15;
    return 0;
  }

  static bool _isAllowedRemoteUrl(
    String rawUrl, {
    required bool allowLocalhost,
    bool allowPrivateNetwork = false,
  }) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.host.trim().isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final isLocalhost = host == 'localhost' || host == '127.0.0.1';
    if (scheme == 'https') return true;
    if (scheme != 'http') return false;
    if (allowLocalhost && isLocalhost) return true;
    return allowPrivateNetwork && _isPrivateNetworkHost(host);
  }

  static bool _isPrivateNetworkHost(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final numbers = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return false;
      numbers.add(value);
    }

    final first = numbers[0];
    final second = numbers[1];
    return first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168) ||
        (first == 169 && second == 254);
  }

  static String formatRemainingCooldown(Duration duration) {
    final seconds = max(1, duration.inSeconds);
    return '$seconds detik';
  }
}
