import 'package:flutter_test/flutter_test.dart';
import 'package:cvant_mobile/core/utils/formatters.dart';

void main() {
  group('Formatters.parseDate', () {
    test('parses dd-MM-yyyy', () {
      final result = Formatters.parseDate('11-03-2026');
      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 3);
      expect(result.day, 11);
    });

    test('parses yyyy-MM-dd', () {
      final result = Formatters.parseDate('2026-12-01');
      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 12);
      expect(result.day, 1);
    });

    test('returns null for empty or null', () {
      expect(Formatters.parseDate(null), isNull);
      expect(Formatters.parseDate('   '), isNull);
    });
  });

  group('Formatters.dmy', () {
    test('formats valid date', () {
      expect(Formatters.dmy('2026-03-11'), '11-03-2026');
    });

    test('returns dash for invalid date', () {
      expect(Formatters.dmy(''), '-');
      expect(Formatters.dmy(null), '-');
    });
  });

  group('Formatters.invoiceNumber', () {
    test('returns dash for empty value', () {
      expect(Formatters.invoiceNumber('', '2026-03-11'), '-');
      expect(Formatters.invoiceNumber(null, '2026-03-11'), '-');
    });

    test('normalizes expense old format', () {
      final out = Formatters.invoiceNumber('EXP-2026-0001', '2026-03-11');
      expect(out, 'EXP-03-2026-0001');
    });

    test('keeps expense new format', () {
      final out = Formatters.invoiceNumber('exp-03-2026-0012', '2026-03-11');
      expect(out, 'EXP-03-2026-0012');
    });

    test('converts company income pattern with month', () {
      final out = Formatters.invoiceNumber(
        'INC-03-2026-15',
        '2026-03-11',
        customerName: 'PT Maju Terus',
      );
      expect(out, '480 / CV.ANT / III / 15');
    });

    test('converts personal income pattern with month', () {
      final out = Formatters.invoiceNumber(
        'INC-03-2026-15',
        '2026-03-11',
        customerName: 'Budi Santoso',
      );
      expect(out, '268 / ANT / III / 15');
    });

    test('converts old income pattern using tanggal month', () {
      final out = Formatters.invoiceNumber(
        'INC-2026-20',
        '2026-08-01',
        customerName: 'cv. nusa jaya',
      );
      expect(out, '480 / CV.ANT / VIII / 20');
    });

    test('strips NO: prefix for non-income values', () {
      final out = Formatters.invoiceNumber('No : EXP-03-2026-0005', '2026-03-11');
      expect(out, 'EXP-03-2026-0005');
    });
  });
}

