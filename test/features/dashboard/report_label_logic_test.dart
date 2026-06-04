import 'package:cvant_mobile/core/utils/formatters.dart';
import 'package:cvant_mobile/features/dashboard/utils/report_label_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Report label logic', () {
    test('builds localized report headers', () {
      expect(
        buildReportHeaderLabel(
          includeIncome: true,
          includeExpense: true,
          customerKind: 'all',
          incomeByInvoice: false,
          isEnglish: false,
        ),
        'Laporan (Pemasukkan Fix Invoice dan Pengeluaran)',
      );
      expect(
        buildReportHeaderLabel(
          includeIncome: true,
          includeExpense: false,
          customerKind: Formatters.invoiceEntityCvAnt,
          incomeByInvoice: true,
          isEnglish: true,
        ),
        'Fixed Invoice Income Report by Invoice (CV. ANT)',
      );
      expect(
        buildReportHeaderLabel(
          includeIncome: false,
          includeExpense: true,
          customerKind: Formatters.invoiceEntityPersonal,
          incomeByInvoice: false,
          isEnglish: false,
        ),
        'Laporan Pengeluaran (Pribadi)',
      );
    });

    test('builds scope labels for major report modes', () {
      expect(
        buildReportScopeLabel(
          includeIncome: true,
          includeExpense: true,
          incomeByInvoice: false,
          isEnglish: true,
        ),
        'Fixed Invoice Income + Expense',
      );
      expect(
        buildReportScopeLabel(
          includeIncome: true,
          includeExpense: false,
          incomeByInvoice: true,
          isEnglish: false,
        ),
        'Income Fix Invoice per Invoice',
      );
      expect(
        buildReportScopeLabel(
          includeIncome: false,
          includeExpense: true,
          incomeByInvoice: false,
          isEnglish: true,
        ),
        'Expense',
      );
    });

    test('builds preview info with optional fixed invoice detail marker', () {
      expect(
        buildReportPreviewInfo(
          scopeLabel: 'Income Fix Invoice + Expense',
          periodLabel: 'Juni 2026',
          includeIncome: true,
          includeExpense: true,
          includeDriverCostColumns: true,
          incomeByInvoice: false,
          rowCount: 12,
          isEnglish: false,
        ),
        'Income Fix Invoice + Expense • Periode: Juni 2026 • Orientasi: '
        'Portrait • Detail: Fix Invoice • 12 data',
      );
      expect(
        buildReportPreviewInfo(
          scopeLabel: 'Fixed Invoice Income by Invoice',
          periodLabel: 'June 2026',
          includeIncome: true,
          includeExpense: false,
          includeDriverCostColumns: false,
          incomeByInvoice: true,
          rowCount: 7,
          isEnglish: true,
        ),
        'Fixed Invoice Income by Invoice • Period: June 2026 • Orientation: '
        'Portrait • 7 invoices',
      );
    });
  });
}
