import 'package:cvant_mobile/core/monitoring/app_error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppErrorReporter', () {
    test('sanitizes noisy context names consistently', () {
      expect(
        AppErrorReporter.sanitizeContext('Flutter Framework / Screen #1'),
        'flutter_framework_screen_1',
      );
      expect(AppErrorReporter.sanitizeContext(''), 'unknown');
      expect(
        AppErrorReporter.sanitizeContext('A'.padRight(120, 'A')).length,
        80,
      );
    });

    test('builds stable fingerprints from message and top stack frames', () {
      const stack = '''
#0      InvoicePage.build (invoice_page.dart:10:3)
#1      Element.updateChild (framework.dart:3982:15)
#2      Irrelevant.extra (other.dart:1:1)
''';

      final first = AppErrorReporter.fingerprintFor('boom', stack);
      final second = AppErrorReporter.fingerprintFor('boom', stack);
      final different = AppErrorReporter.fingerprintFor('other', stack);

      expect(first, second);
      expect(first, isNot(different));
      expect(first, matches(RegExp(r'^[0-9a-f]{8}$')));
    });
  });
}
