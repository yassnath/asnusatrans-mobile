import 'package:cvant_mobile/features/dashboard/utils/payment_status_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Payment status logic', () {
    test('does not classify unpaid variants as paid', () {
      for (final status in const [
        'Unpaid',
        'un-paid',
        'Not paid',
        'Belum lunas',
      ]) {
        expect(isUnpaidPaymentStatus(status), isTrue);
        expect(isPaidPaymentStatus(status), isFalse);
        expect(isPaymentStartedStatus(status), isFalse);
      }
    });

    test('classifies paid and partial statuses safely', () {
      expect(isPaidPaymentStatus('Paid'), isTrue);
      expect(isPaidPaymentStatus('Lunas'), isTrue);
      expect(isPartialPaymentStatus('Partial'), isTrue);
      expect(isPartialPaymentStatus('Partially paid'), isTrue);
      expect(isPaidPaymentStatus('Partially paid'), isFalse);
      expect(isPaymentStartedStatus('Partial'), isTrue);
    });

    test('resolves payment status from amounts before explicit fallback', () {
      expect(
        resolvePaymentStatusLabel(total: 1000000, paid: 1000000),
        paymentStatusPaid,
      );
      expect(
        resolvePaymentStatusLabel(total: 1000000, paid: 250000),
        paymentStatusPartial,
      );
      expect(
        resolvePaymentStatusLabel(
          total: 1000000,
          paid: 0,
          explicitStatus: 'Paid',
        ),
        paymentStatusPaid,
      );
      expect(
        resolvePaymentStatusLabel(
          total: 1000000,
          paid: 0,
          explicitStatus: 'Unpaid',
        ),
        paymentStatusUnpaid,
      );
    });
  });
}
