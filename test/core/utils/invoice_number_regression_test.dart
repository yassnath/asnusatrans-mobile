import 'package:cvant_mobile/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Invoice Number Regression', () {
    test('normalizes personal legacy converted pattern by kop date', () {
      final out = Formatters.invoiceNumber(
        '268 / ANT / III / 3',
        '2026-01-08',
      );
      expect(out, '003 / BS / I / 26');
    });

    test('normalizes company legacy converted pattern by kop date', () {
      final out = Formatters.invoiceNumber(
        '480 / CV.ANT / XI / 9',
        '2026-02-01',
      );
      expect(out, '009 / CV.ANT / II / 26');
    });

    test('keeps sequence but syncs personal month from date', () {
      final out = Formatters.invoiceNumber(
        '017 / BS / I / 26',
        '2026-09-10',
      );
      expect(out, '017 / BS / IX / 26');
    });

    test('keeps sequence but syncs company month and year from date', () {
      final out = Formatters.invoiceNumber(
        '017 / CV.ANT / I / 26',
        '2027-04-10',
      );
      expect(out, '017 / CV.ANT / IV / 27');
    });

    test('uses explicit isCompany override for INC legacy format', () {
      final out = Formatters.invoiceNumber(
        'INC-03-2026-7',
        '2026-03-10',
        customerName: 'Budi',
        isCompany: true,
      );
      expect(out, '007 / CV.ANT / III / 26');
    });

    test('normalizes NO prefix and casing for personal format', () {
      final out = Formatters.invoiceNumber(
        'No : 7 / bs / i / 26',
        '2026-10-03',
      );
      expect(out, '007 / BS / X / 26');
    });
  });
}
