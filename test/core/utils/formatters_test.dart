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

  group('Formatters.dMyShort', () {
    test('formats valid date using short month invoice style', () {
      expect(Formatters.dMyShort('2026-03-10'), '10-Mar-26');
      expect(Formatters.dMyShort('2026-10-01'), '01-Oct-26');
    });

    test('returns dash for invalid date', () {
      expect(Formatters.dMyShort(''), '-');
      expect(Formatters.dMyShort(null), '-');
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

    test('normalizes company income pattern with month into compact format',
        () {
      final out = Formatters.invoiceNumber(
        'INC-03-2026-15',
        '2026-03-11',
        customerName: 'PT Maju Terus',
      );
      expect(out, 'CV.ANT260315');
    });

    test('normalizes PT income pattern with explicit invoice entity', () {
      final out = Formatters.invoiceNumber(
        'INC-04-2026-1',
        '2026-04-15',
        invoiceEntity: Formatters.invoiceEntityPtAnt,
      );
      expect(out, 'PT.ANT260401');
    });

    test('normalizes personal income pattern with month into compact format',
        () {
      final out = Formatters.invoiceNumber(
        'INC-03-2026-15',
        '2026-03-11',
        customerName: 'Budi Santoso',
      );
      expect(out, 'BS260315');
    });

    test(
        'normalizes old income pattern using tanggal month into compact format',
        () {
      final out = Formatters.invoiceNumber(
        'INC-2026-20',
        '2026-08-01',
        customerName: 'cv. nusa jaya',
      );
      expect(out, 'CV.ANT260820');
    });

    test('normalizes legacy company format while syncing year from date', () {
      final out = Formatters.invoiceNumber(
        '017 / CV.ANT / I / 26',
        '2027-01-10',
      );
      expect(out, 'CV.ANT270117');
    });

    test('normalizes legacy personal format while syncing year from date', () {
      final out = Formatters.invoiceNumber(
        '017 / BS / I / 26',
        '2027-01-10',
      );
      expect(out, 'BS270117');
    });

    test('strips NO: prefix for non-income values', () {
      final out =
          Formatters.invoiceNumber('No : EXP-03-2026-0005', '2026-03-11');
      expect(out, 'EXP-03-2026-0005');
    });
  });

  group('Formatters.invoiceEntityFromInvoiceNumber', () {
    test('detects CV ANT invoice number', () {
      expect(
        Formatters.invoiceEntityFromInvoiceNumber('CV.ANT260401'),
        Formatters.invoiceEntityCvAnt,
      );
    });

    test('detects PT ANT invoice number', () {
      expect(
        Formatters.invoiceEntityFromInvoiceNumber('PT.ANT260401'),
        Formatters.invoiceEntityPtAnt,
      );
    });

    test('detects personal invoice number', () {
      expect(
        Formatters.invoiceEntityFromInvoiceNumber('BS260401'),
        Formatters.invoiceEntityPersonal,
      );
    });

    test('returns null for unrelated number', () {
      expect(Formatters.invoiceEntityFromInvoiceNumber('EXP-04-2026-0001'),
          isNull);
    });
  });

  group('Formatters.normalizeInvoiceEntity', () {
    test('prefers explicit PT ANT entity aliases', () {
      expect(
        Formatters.normalizeInvoiceEntity('PT ANT'),
        Formatters.invoiceEntityPtAnt,
      );
      expect(
        Formatters.normalizeInvoiceEntity('pt.ant'),
        Formatters.invoiceEntityPtAnt,
      );
    });

    test('falls back to invoice number pattern before customer heuristic', () {
      expect(
        Formatters.normalizeInvoiceEntity(
          '',
          invoiceNumber: 'PT.ANT260401',
          customerName: 'CV Maju Jaya',
        ),
        Formatters.invoiceEntityPtAnt,
      );
    });

    test('uses customer name heuristic for company invoices without number',
        () {
      expect(
        Formatters.normalizeInvoiceEntity(
          '',
          customerName: 'PT Maju Terus',
        ),
        Formatters.invoiceEntityCvAnt,
      );
    });

    test('defaults to personal when no company signal exists', () {
      expect(
        Formatters.normalizeInvoiceEntity(
          '',
          customerName: 'Budi Santoso',
        ),
        Formatters.invoiceEntityPersonal,
      );
    });
  });
}
