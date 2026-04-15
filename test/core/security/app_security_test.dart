import 'package:cvant_mobile/core/security/app_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSecurity.sanitizeUserFacingError', () {
    test('returns fallback for sensitive database messages', () {
      final sanitized = AppSecurity.sanitizeUserFacingError(
        'PostgrestException: relation public.invoices does not exist',
        fallback: 'Fallback aman',
      );

      expect(sanitized, 'Fallback aman');
    });

    test('keeps short user-safe message', () {
      final sanitized = AppSecurity.sanitizeUserFacingError(
        'Username/Password tidak valid, Mohon dicek kembali!',
      );

      expect(sanitized, 'Username/Password tidak valid, Mohon dicek kembali!');
    });

    test('returns fallback for overlong error payload', () {
      final sanitized = AppSecurity.sanitizeUserFacingError(
        'x' * 300,
        fallback: 'Pesan aman',
      );

      expect(sanitized, 'Pesan aman');
    });
  });

  group('AppSecurity.recommendedLoginCooldownSeconds', () {
    test('applies progressive cooldown', () {
      expect(AppSecurity.recommendedLoginCooldownSeconds(2), 0);
      expect(AppSecurity.recommendedLoginCooldownSeconds(3), 15);
      expect(AppSecurity.recommendedLoginCooldownSeconds(5), 45);
      expect(AppSecurity.recommendedLoginCooldownSeconds(8), 90);
    });
  });
}
