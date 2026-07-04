import 'package:cvant_mobile/features/dashboard/utils/special_invoice_number_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Special personal invoice numbering', () {
    test('starts from three digits and keeps increasing', () {
      expect(buildSpecialPersonalInvoiceNumber(1), '001');
      expect(buildSpecialPersonalInvoiceNumber(2), '002');
      expect(buildSpecialPersonalInvoiceNumber(10), '010');
    });

    test('extracts only the dedicated numeric format', () {
      expect(extractSpecialPersonalInvoiceSequence('001'), 1);
      expect(extractSpecialPersonalInvoiceSequence('NO: 009'), 9);
      expect(extractSpecialPersonalInvoiceSequence('BS260601'), 0);
      expect(extractSpecialPersonalInvoiceSequence('CV.ANT260601'), 0);
    });

    test('resets sequence scope for every invoice month', () {
      expect(
        specialPersonalInvoicePeriodKey(DateTime(2026, 6, 30)),
        '2026-06',
      );
      expect(
        specialPersonalInvoicePeriodKey(DateTime(2026, 7, 1)),
        '2026-07',
      );
      expect(
        isSameSpecialPersonalInvoicePeriod(
          DateTime(2026, 6, 1),
          DateTime(2026, 6, 30),
        ),
        isTrue,
      );
      expect(
        isSameSpecialPersonalInvoicePeriod(
          DateTime(2026, 6, 30),
          DateTime(2026, 7, 1),
        ),
        isFalse,
      );
    });

    test('activates only after 20 June 2026', () {
      expect(
        isTritunggalSpecialPersonalDepartureDate(DateTime(2026, 6, 19)),
        isFalse,
      );
      expect(
        isTritunggalSpecialPersonalDepartureDate(DateTime(2026, 6, 20)),
        isFalse,
      );
      expect(
        isTritunggalSpecialPersonalDepartureDate(DateTime(2026, 6, 21)),
        isTrue,
      );
    });
  });
}
