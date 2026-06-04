import 'package:cvant_mobile/features/dashboard/utils/invoice_detail_amount_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('invoice detail amount logic', () {
    test('parses common rupiah and decimal formats', () {
      expect(parseInvoiceDetailAmount('Rp 1.500.000'), 1500000);
      expect(parseInvoiceDetailAmount('1.500.000'), 1500000);
      expect(parseInvoiceDetailAmount('27,5'), 27.5);
      expect(parseInvoiceDetailAmount(50), 50);
    });

    test('prioritizes manual subtotal over automatic and explicit totals', () {
      final detail = {
        'manual_subtotal': '500.000',
        'tonase': 10,
        'harga': 99,
        'subtotal_auto': true,
        'subtotal': 123,
      };

      expect(resolveInvoiceDetailSubtotal(detail), 500000);
      expect(resolveInvoiceDetailExcelSubtotal(detail), 500000);
    });

    test('uses automatic tonase x harga when subtotal_auto is true', () {
      final detail = {
        'tonase': '31.960',
        'harga': '50',
        'subtotal_auto': true,
        'subtotal': 100,
      };

      expect(resolveInvoiceDetailSubtotal(detail), 1598000);
    });

    test('uses explicit subtotal before computed subtotal when not auto', () {
      final detail = {
        'tonase': 10,
        'harga': 50,
        'subtotal': 900,
      };

      expect(resolveInvoiceDetailSubtotal(detail), 900);
    });

    test('can use invoice fallback values for report detail rows', () {
      final detail = {
        'lokasi_muat': 'T. Langon',
        'lokasi_bongkar': 'MKP',
      };
      final invoice = {
        'tonase': 10,
        'harga': 50,
      };

      expect(resolveInvoiceDetailSubtotal(detail, fallback: invoice), 500);
    });

    test(
        'sums details and falls back to parent subtotal when details are empty',
        () {
      expect(
        resolveInvoiceDetailsExcelSubtotal(
          [
            {'manual_subtotal': 100.4},
            {'tonase': 2, 'harga': 50, 'subtotal_auto': true},
          ],
        ),
        200,
      );
      expect(
          resolveInvoiceDetailsExcelSubtotal([], fallbackSubtotal: 123.6), 124);
    });
  });
}
