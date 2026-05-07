import 'package:cvant_mobile/features/dashboard/utils/invoice_pph_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Invoice PPH logic', () {
    test('matches Excel rounding for exact and fractional 2 percent values',
        () {
      expect(calculateInvoicePph2Percent(26033300), 520666);
      expect(calculateInvoiceTotalAfterPph(26033300), 25512634);

      expect(calculateInvoicePph2Percent(12181740), 243635);
      expect(calculateInvoiceTotalAfterPph(12181740), 11938105);
    });

    test('rounds subtotal to rupiah before calculating PPH', () {
      expect(roundInvoiceRupiah(1880835.6), 1880836);
      expect(calculateInvoicePph2Percent(25512633.5), 510253);
      expect(calculateInvoiceTotalAfterPph(25512633.5), 25002381);
    });
  });
}
