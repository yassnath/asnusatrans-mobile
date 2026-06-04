import 'package:cvant_mobile/features/dashboard/utils/invoice_print_layout_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('invoice print layout logic', () {
    test('keeps company half-sheet capacity at 18 detail rows', () {
      expect(invoiceCompactDetailRowLimit(isCompanyInvoice: true), 18);
      expect(
        invoiceRowsPerSheet(compact: true, isCompanyInvoice: true),
        18,
      );
      expect(
        invoiceShouldUsePortraitLayout(
          detailRowCount: 18,
          isCompanyInvoice: true,
        ),
        isFalse,
      );
      expect(
        invoiceShouldUsePortraitLayout(
          detailRowCount: 19,
          isCompanyInvoice: true,
        ),
        isTrue,
      );
    });

    test('keeps personal half-sheet capacity at 21 detail rows', () {
      expect(invoiceCompactDetailRowLimit(isCompanyInvoice: false), 21);
      expect(
        invoiceRowsPerSheet(compact: true, isCompanyInvoice: false),
        21,
      );
      expect(
        invoiceShouldUsePortraitLayout(
          detailRowCount: 21,
          isCompanyInvoice: false,
        ),
        isFalse,
      );
    });

    test('computes portrait rows from compact capacity plus extra rows', () {
      expect(
        invoiceRowsPerSheet(compact: false, isCompanyInvoice: true),
        50,
      );
      expect(
        invoiceRowsPerSheet(compact: false, isCompanyInvoice: false),
        56,
      );
    });
  });
}
