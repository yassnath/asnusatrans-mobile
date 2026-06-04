import 'package:cvant_mobile/features/dashboard/utils/report_print_selection_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Report print selection logic', () {
    String formatAmount(num value) => value.toStringAsFixed(0);

    double parseAmount(String value) {
      final cleaned = value
          .replaceAll(RegExp(r'[^0-9,.-]'), '')
          .replaceAll('.', '')
          .replaceAll(',', '.');
      return double.tryParse(cleaned) ?? 0;
    }

    test('selects only checked rows and applies income invoice payment inputs',
        () {
      final rows = buildSelectedReportRowsForPrint(
        allRows: const [
          {
            '__key': 'income-1',
            '__type': 'Income',
            '__paid_locked': false,
            '__total': 1000,
          },
          {
            '__key': 'expense-1',
            '__type': 'Expense',
            '__expense': 250,
          },
          {
            '__key': 'income-2',
            '__type': 'Income',
            '__total': 500,
          },
        ],
        selectedKeys: {'income-1', 'expense-1'},
        incomeInvoiceReport: true,
        bayarInputs: {'income-1': 'Rp 400'},
        sisaInputs: {'income-1': '600'},
        formatAmount: formatAmount,
        parseAmount: parseAmount,
      );

      expect(rows, hasLength(2));
      expect(rows[0]['__key'], 'income-1');
      expect(rows[0]['__bayar'], 400);
      expect(rows[0]['__sisa'], 600);
      expect(rows[1]['__key'], 'expense-1');
      expect(rows[1].containsKey('__bayar'), isFalse);
    });

    test('does not apply payment inputs outside income invoice report mode',
        () {
      final rows = buildSelectedReportRowsForPrint(
        allRows: const [
          {
            '__key': 'income-1',
            '__type': 'Income',
            '__paid_locked': false,
            '__total': 1000,
          },
        ],
        selectedKeys: {'income-1'},
        incomeInvoiceReport: false,
        bayarInputs: {'income-1': '400'},
        sisaInputs: {'income-1': '600'},
        formatAmount: formatAmount,
        parseAmount: parseAmount,
      );

      expect(rows.single.containsKey('__bayar'), isFalse);
      expect(rows.single.containsKey('__sisa'), isFalse);
    });

    test('calculates report print totals from income, sangu, and expense rows',
        () {
      final totals = calculateReportPrintTotals(
        const [
          {
            '__type': 'Income',
            '__income': 1000,
            '__sangu_sopir': 250,
          },
          {
            '__type': 'Income',
            '__income': 'Rp 500',
            '__sangu_sopir': '50',
          },
          {
            '__type': 'Expense',
            '__expense': 300,
          },
        ],
      );

      expect(totals.income, 1500);
      expect(totals.expense, 600);
    });
  });
}
