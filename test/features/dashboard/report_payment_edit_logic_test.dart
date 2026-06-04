import 'package:cvant_mobile/features/dashboard/utils/report_payment_edit_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Report payment edit logic', () {
    test('parses and formats editable report amounts consistently', () {
      expect(parseEditableReportAmount('Rp 1.250.000'), 1250000);
      expect(parseEditableReportAmount('1.250,5'), 1250.5);
      expect(parseEditableReportAmount(''), 0);
      expect(formatEditableReportAmount(1250000), '1.250.000');
      expect(formatEditableReportAmount(0), '');
      expect(formatEditableReportAmount(double.nan), '');
    });

    test('resolves locked payment defaults from paid default or total', () {
      final withPaidDefault = resolveReportPaymentDefaults(
        const {
          '__paid_locked': true,
          '__total': 1000,
          '__bayar_default': 700,
          '__sisa_default': 300,
        },
      );
      final withTotalFallback = resolveReportPaymentDefaults(
        const {
          '__paid_locked': true,
          '__total': 1000,
          '__bayar_default': 0,
          '__sisa_default': 300,
        },
      );

      expect(withPaidDefault.paidLocked, isTrue);
      expect(withPaidDefault.lockedPaidAmount, 700);
      expect(withPaidDefault.defaultBayar, 700);
      expect(withPaidDefault.defaultSisa, 0);
      expect(withTotalFallback.lockedPaidAmount, 1000);
    });

    test('resolves editable payment defaults without forcing values', () {
      final defaults = resolveReportPaymentDefaults(
        const {
          '__paid_locked': false,
          '__total': 1000,
          '__bayar_default': 250,
          '__sisa_default': 750,
        },
      );

      expect(defaults.paidLocked, isFalse);
      expect(defaults.lockedPaidAmount, 250);
      expect(defaults.defaultBayar, 250);
      expect(defaults.defaultSisa, 750);
    });

    test('builds locked payment input draft from canonical locked amount', () {
      final draft = resolveReportPaymentInputDraft(
        row: const {
          '__paid_locked': true,
          '__total': 1000,
          '__bayar_default': 0,
        },
        bayarText: '123',
        sisaText: '456',
        formatAmount: formatEditableReportAmount,
        parseAmount: parseEditableReportAmount,
      );

      expect(draft.bayar, 1000);
      expect(draft.sisa, 0);
      expect(draft.bayarText, '1.000');
      expect(draft.sisaText, '');
    });

    test('builds editable payment input draft from user text', () {
      final draft = resolveReportPaymentInputDraft(
        row: const {
          '__paid_locked': false,
          '__total': 1000000,
          '__bayar_default': 0,
        },
        bayarText: 'Rp 250.000',
        sisaText: '750.000',
        formatAmount: formatEditableReportAmount,
        parseAmount: parseEditableReportAmount,
      );

      expect(draft.bayar, 250000);
      expect(draft.sisa, 750000);
      expect(draft.bayarText, 'Rp 250.000');
      expect(draft.sisaText, '750.000');
    });
  });
}
