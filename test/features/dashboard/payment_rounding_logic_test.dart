import 'package:cvant_mobile/features/dashboard/utils/payment_rounding_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fixed invoice payment rounding', () {
    test('treats tiny remaining amount as paid without changing paid nominal',
        () {
      final total = 10612774.0;
      final paid = 10612770.0;

      expect(
        fixedInvoiceRoundedRemaining(total: total, paid: paid),
        0,
      );
      expect(
        fixedInvoicePaymentCoversTotal(total: total, paid: paid),
        isTrue,
      );
    });

    test('keeps meaningful underpayment as remaining balance', () {
      final total = 10612774.0;
      final paid = 10600000.0;

      expect(
        fixedInvoiceRoundedRemaining(total: total, paid: paid),
        12774,
      );
      expect(
        fixedInvoicePaymentCoversTotal(total: total, paid: paid),
        isFalse,
      );
    });
  });
}
