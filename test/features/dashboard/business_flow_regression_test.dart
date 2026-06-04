import 'package:cvant_mobile/features/dashboard/utils/gabungan_pricing_rule_logic.dart';
import 'package:cvant_mobile/features/dashboard/utils/report_print_selection_logic.dart';
import 'package:cvant_mobile/features/dashboard/utils/sangu_rule_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Business flow regression', () {
    String formatAmount(num value) => value.toStringAsFixed(0);

    double parseAmount(String value) {
      final cleaned = value
          .replaceAll(RegExp(r'[^0-9,.-]'), '')
          .replaceAll('.', '')
          .replaceAll(',', '.');
      return double.tryParse(cleaned) ?? 0;
    }

    test(
      'keeps Gabungan pricing, Singosari sangu, and report totals aligned',
      () {
        final gabunganHarga = resolveGabunganHargaPerKg(
          pickup: 'T. Langon',
          destination: 'SGM',
          rules: const [],
        );
        final gabunganIncome = (10000 * gabunganHarga).round();

        final privateSingosariSangu = resolvePrioritizedSanguRouteRule(
          pickup: 'T. Langon',
          destination: 'Singosari',
          customerName: 'Iwan',
          invoiceEntity: 'personal',
        );
        final companySingosariSangu = resolvePrioritizedSanguRouteRule(
          pickup: 'T. Langon',
          destination: 'Singosari',
          customerName: 'PT TRITUNGGAL MAKMUR ABADHI SEJAHTERA',
          invoiceEntity: 'pt_ant',
        );

        expect(gabunganHarga, 41);
        expect(privateSingosariSangu?['nominal'], 980000);
        expect(companySingosariSangu?['nominal'], 1035000);

        final selectedRows = buildSelectedReportRowsForPrint(
          allRows: [
            {
              '__key': 'income-gabungan-sgm',
              '__type': 'Income',
              '__income': gabunganIncome,
              '__total': gabunganIncome,
              '__sangu_sopir': 0,
              '__paid_locked': false,
            },
            {
              '__key': 'income-private-singosari',
              '__type': 'Income',
              '__income': 2869600,
              '__total': 2869600,
              '__sangu_sopir': privateSingosariSangu?['nominal'],
              '__paid_locked': false,
            },
            {
              '__key': 'expense-manual',
              '__type': 'Expense',
              '__expense': 125000,
            },
          ],
          selectedKeys: const {
            'income-gabungan-sgm',
            'income-private-singosari',
          },
          incomeInvoiceReport: true,
          bayarInputs: {
            'income-gabungan-sgm': '$gabunganIncome',
            'income-private-singosari': 'Rp 2.869.600',
          },
          sisaInputs: const {
            'income-gabungan-sgm': '0',
            'income-private-singosari': '0',
          },
          formatAmount: formatAmount,
          parseAmount: parseAmount,
        );

        expect(selectedRows, hasLength(2));
        expect(selectedRows.first['__bayar'], gabunganIncome);
        expect(selectedRows.first['__sisa'], 0);

        final totals = calculateReportPrintTotals(selectedRows);
        expect(totals.income, gabunganIncome + 2869600);
        expect(totals.expense, 980000);
      },
    );
  });
}
