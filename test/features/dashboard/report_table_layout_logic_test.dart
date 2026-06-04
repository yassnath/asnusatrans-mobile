import 'package:cvant_mobile/features/dashboard/utils/report_table_layout_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Report table layout logic', () {
    test('resolves report table mode for income and combined report cases', () {
      final cvIncome = resolveReportTableMode(
        includeIncome: true,
        includeExpense: false,
        includeDriverCostColumns: false,
        customerKind: 'cv_ant',
        rows: const [],
      );
      final personalIncome = resolveReportTableMode(
        includeIncome: true,
        includeExpense: false,
        includeDriverCostColumns: false,
        customerKind: 'personal',
        rows: const [],
      );
      final personalCombined = resolveReportTableMode(
        includeIncome: true,
        includeExpense: true,
        includeDriverCostColumns: true,
        customerKind: 'personal',
        rows: const [
          {'__pph': 0}
        ],
      );
      final pphFallback = resolveReportTableMode(
        includeIncome: true,
        includeExpense: true,
        includeDriverCostColumns: false,
        customerKind: 'all',
        rows: const [
          {'__pph': 20}
        ],
      );

      expect(cvIncome.incomeInvoiceTable, isTrue);
      expect(cvIncome.showIncomePphColumn, isTrue);
      expect(personalIncome.companyMode, isFalse);
      expect(personalIncome.showIncomePphColumn, isFalse);
      expect(personalCombined.combinedDriverCostColumns, isTrue);
      expect(personalCombined.showCombinedPphColumn, isFalse);
      expect(pphFallback.companyMode, isTrue);
      expect(pphFallback.showIncomePphColumn, isTrue);
    });

    test('builds income invoice layout with PPH columns', () {
      final layout = buildReportTableLayout(
        incomeInvoiceTable: true,
        showIncomePphColumn: true,
        combinedDriverCostColumns: false,
        showCombinedPphColumn: false,
        companyMode: true,
      );

      expect(layout.headers, [
        'NO',
        'TANGGAL',
        'CUSTOMER',
        'JUMLAH',
        'PPH',
        'TOTAL',
        'BAYAR',
        'SISA',
        'TGL BAYAR',
      ]);
      expect(layout.numericColumns, {3, 4, 5, 6, 7});
      expect(layout.dateColumns, {1, 8});
      expect(layout.priorityTextColumns, {2});
    });

    test('builds income invoice layout without PPH columns', () {
      final layout = buildReportTableLayout(
        incomeInvoiceTable: true,
        showIncomePphColumn: false,
        combinedDriverCostColumns: false,
        showCombinedPphColumn: false,
        companyMode: false,
      );

      expect(layout.headers, [
        'NO',
        'TANGGAL',
        'CUSTOMER',
        'JUMLAH',
        'TOTAL',
        'BAYAR',
        'SISA',
        'TGL BAYAR',
      ]);
      expect(layout.numericColumns, {3, 4, 5, 6});
      expect(layout.dateColumns, {1, 7});
    });

    test('builds combined driver-cost layout with optional PPH', () {
      final withPph = buildReportTableLayout(
        incomeInvoiceTable: false,
        showIncomePphColumn: false,
        combinedDriverCostColumns: true,
        showCombinedPphColumn: true,
        companyMode: true,
      );
      final withoutPph = buildReportTableLayout(
        incomeInvoiceTable: false,
        showIncomePphColumn: false,
        combinedDriverCostColumns: true,
        showCombinedPphColumn: false,
        companyMode: false,
      );

      expect(withPph.headers, [
        'NO',
        'TGL',
        'CUSTOMER',
        'PLAT NOMOR',
        'MUAT',
        'BONGKAR',
        'JUMLAH',
        'SOPIR',
        'GABUNGAN',
        'PPH',
        'TOTAL',
        'LABA',
      ]);
      expect(withPph.numericColumns, {6, 7, 8, 9, 10, 11});
      expect(withoutPph.headers, isNot(contains('PPH')));
      expect(withoutPph.numericColumns, {6, 7, 8, 9, 10});
      expect(withoutPph.priorityTextColumns, {2, 3, 4, 5});
    });

    test('builds simple company and personal layouts', () {
      final company = buildReportTableLayout(
        incomeInvoiceTable: false,
        showIncomePphColumn: false,
        combinedDriverCostColumns: false,
        showCombinedPphColumn: false,
        companyMode: true,
      );
      final personal = buildReportTableLayout(
        incomeInvoiceTable: false,
        showIncomePphColumn: false,
        combinedDriverCostColumns: false,
        showCombinedPphColumn: false,
        companyMode: false,
      );

      expect(company.headers, [
        'NO',
        'TANGGAL',
        'CUSTOMER',
        'JUMLAH',
        'PPH',
        'TOTAL',
        'TUJUAN',
      ]);
      expect(company.numericColumns, {3, 4, 5});
      expect(personal.headers, [
        'NO',
        'TANGGAL',
        'CUSTOMER',
        'JUMLAH',
        'TOTAL',
        'TUJUAN',
      ]);
      expect(personal.priorityTextColumns, {2, 5});
    });

    test('builds report column width presets for printable report modes', () {
      final incomeLayout = buildReportTableLayout(
        incomeInvoiceTable: true,
        showIncomePphColumn: true,
        combinedDriverCostColumns: false,
        showCombinedPphColumn: false,
        companyMode: true,
      );
      final incomeFlexes = buildReportColumnWidthFlexes(
        headers: incomeLayout.headers,
        data: const [
          ['1', '04-Jun-26', 'PT Test', '1000', '20', '980', '500', '480', '']
        ],
        dateColumns: incomeLayout.dateColumns,
        numericColumns: incomeLayout.numericColumns,
        priorityTextColumns: incomeLayout.priorityTextColumns,
        incomeInvoiceTable: true,
        showIncomePphColumn: true,
        combinedDriverCostColumns: false,
        showCombinedPphColumn: false,
        companyMode: true,
      );

      expect(incomeFlexes[0], 3.0);
      expect(incomeFlexes[2], 32.0);
      expect(incomeFlexes[8], 8.5);

      final combinedLayout = buildReportTableLayout(
        incomeInvoiceTable: false,
        showIncomePphColumn: false,
        combinedDriverCostColumns: true,
        showCombinedPphColumn: false,
        companyMode: false,
      );
      final combinedFlexes = buildReportColumnWidthFlexes(
        headers: combinedLayout.headers,
        data: const [
          [
            '1',
            '04-Jun-26',
            'Felix',
            'B 1234 CD',
            'T. Langon',
            'Pare',
            '1000',
            '',
            '',
            '1000',
            '1000',
          ]
        ],
        dateColumns: combinedLayout.dateColumns,
        numericColumns: combinedLayout.numericColumns,
        priorityTextColumns: combinedLayout.priorityTextColumns,
        incomeInvoiceTable: false,
        showIncomePphColumn: false,
        combinedDriverCostColumns: true,
        showCombinedPphColumn: false,
        companyMode: false,
      );

      expect(combinedFlexes[0], 2.8);
      expect(combinedFlexes[2], 17.0);
      expect(combinedFlexes[10], 8.0);

      final simpleLayout = buildReportTableLayout(
        incomeInvoiceTable: false,
        showIncomePphColumn: false,
        combinedDriverCostColumns: false,
        showCombinedPphColumn: false,
        companyMode: true,
      );
      final simpleFlexes = buildReportColumnWidthFlexes(
        headers: simpleLayout.headers,
        data: const [
          ['1', '04-Jun-26', 'CV ANT', '1000', '20', '980', 'Pare']
        ],
        dateColumns: simpleLayout.dateColumns,
        numericColumns: simpleLayout.numericColumns,
        priorityTextColumns: simpleLayout.priorityTextColumns,
        incomeInvoiceTable: false,
        showIncomePphColumn: false,
        combinedDriverCostColumns: false,
        showCombinedPphColumn: false,
        companyMode: true,
      );

      expect(simpleFlexes[2], 26.0);
    });

    test('builds report table font sizing for compact and crowded reports', () {
      final compact = buildReportTableFontSizing(
        rows: const [
          {'__number': 'INV-1', '__customer': 'CV ANT'}
        ],
        paidAtDisplay: (_) => '',
        incomeInvoiceTable: false,
        combinedDriverCostColumns: false,
      );

      expect(compact.headerFont, 8.0);
      expect(compact.cellFont, 7.0);

      final incomeCrowded = buildReportTableFontSizing(
        rows: const [
          {
            '__number': 'INV-1',
            '__customer': 'PT TRITUNGGAL MAKMUR ABADHI SEJAHTERA',
          }
        ],
        paidAtDisplay: (_) => '',
        incomeInvoiceTable: true,
        combinedDriverCostColumns: false,
      );

      expect(incomeCrowded.headerFont, closeTo(7.1, 0.001));
      expect(incomeCrowded.cellFont, 6.2);

      final combinedCrowded = buildReportTableFontSizing(
        rows: List.generate(
          37,
          (_) => const {
            '__number': 'CV.ANT-2026-06-04-VERY-LONG-INVOICE-NUMBER',
            '__customer': 'PT TEST',
          },
        ),
        paidAtDisplay: (_) => 'Very long unpaid destination',
        incomeInvoiceTable: false,
        combinedDriverCostColumns: true,
      );

      expect(combinedCrowded.headerFont, 7.0);
      expect(combinedCrowded.cellFont, 6.2);
    });

    test('resolves one-line report font size by column type and content', () {
      const sizing = ReportTableFontSizing(headerFont: 8.0, cellFont: 7.0);

      final longCustomerSize = resolveReportOneLineFontSize(
        index: 2,
        text: 'PT TRITUNGGAL MAKMUR ABADHI SEJAHTERA CABANG SURABAYA',
        header: false,
        totalRow: false,
        numericColumn: false,
        sizing: sizing,
      );
      final numericTotalSize = resolveReportOneLineFontSize(
        index: 4,
        text: '1.000.000',
        header: false,
        totalRow: true,
        numericColumn: true,
        sizing: const ReportTableFontSizing(headerFont: 7.0, cellFont: 6.2),
      );

      expect(longCustomerSize, lessThan(7.0));
      expect(longCustomerSize, greaterThanOrEqualTo(4.8));
      expect(numericTotalSize, closeTo(6.0, 0.001));
    });

    test('highlights paid income numbers only for started income payments', () {
      expect(
        shouldHighlightPaidIncomeNumber(
          row: const {'__type': 'Income', '__status': 'Paid'},
          incomeInvoiceTable: true,
        ),
        isTrue,
      );
      expect(
        shouldHighlightPaidIncomeNumber(
          row: const {'__type': 'Income', '__status': 'Partial'},
          incomeInvoiceTable: true,
        ),
        isTrue,
      );
      expect(
        shouldHighlightPaidIncomeNumber(
          row: const {'__type': 'Income', '__paid_locked': true},
          incomeInvoiceTable: true,
        ),
        isTrue,
      );
      expect(
        shouldHighlightPaidIncomeNumber(
          row: const {
            '__type': 'Income',
            '__status': 'Unpaid',
            '__total': 500000,
            '__bayar_default': 100000,
          },
          incomeInvoiceTable: true,
        ),
        isTrue,
      );
      expect(
        shouldHighlightPaidIncomeNumber(
          row: const {
            '__type': 'Income',
            '__status': 'Unpaid',
            '__total': 500000,
            '__bayar_default': 0,
          },
          incomeInvoiceTable: true,
        ),
        isFalse,
      );
      expect(
        shouldHighlightPaidIncomeNumber(
          row: const {'__type': 'Expense', '__status': 'Paid'},
          incomeInvoiceTable: true,
        ),
        isFalse,
      );
      expect(
        shouldHighlightPaidIncomeNumber(
          row: const {'__type': 'Income', '__status': 'Paid'},
          incomeInvoiceTable: false,
        ),
        isFalse,
      );
    });

    test('builds income invoice total row with and without PPH', () {
      final rows = [
        {
          '__jumlah': 1000,
          '__pph': 20,
          '__total': 980,
          '__bayar': 600,
          '__sisa': 380,
        },
        {
          '__jumlah': 500,
          '__pph': 10,
          '__total': 490,
          '__bayar': 0,
          '__sisa': 490,
        },
      ];

      expect(
        buildReportTableTotalRow(
          rows: rows,
          incomeInvoiceTable: true,
          showIncomePphColumn: true,
          combinedDriverCostColumns: false,
          showCombinedPphColumn: false,
          companyMode: true,
          formatAmount: (value) => value.toStringAsFixed(0),
        ),
        ['', '', 'TOTAL', '1500', '30', '1470', '600', '870', ''],
      );
      expect(
        buildReportTableTotalRow(
          rows: rows,
          incomeInvoiceTable: true,
          showIncomePphColumn: false,
          combinedDriverCostColumns: false,
          showCombinedPphColumn: false,
          companyMode: false,
          formatAmount: (value) => value.toStringAsFixed(0),
        ),
        ['', '', 'TOTAL', '1500', '1470', '600', '870', ''],
      );
    });

    test(
        'builds combined driver-cost total row from income rows only for income totals',
        () {
      final rows = [
        {
          '__type': 'Income',
          '__jumlah': 1000,
          '__pph': 20,
          '__total': 980,
          '__sangu_sopir': 250,
          '__gabungan': 100,
          '__laba': 630,
        },
        {
          '__type': 'Expense',
          '__jumlah': 9999,
          '__pph': 999,
          '__total': 9999,
          '__sangu_sopir': 50,
          '__gabungan': 25,
          '__laba': -75,
        },
      ];

      expect(
        buildReportTableTotalRow(
          rows: rows,
          incomeInvoiceTable: false,
          showIncomePphColumn: false,
          combinedDriverCostColumns: true,
          showCombinedPphColumn: true,
          companyMode: true,
          formatAmount: (value) => value.toStringAsFixed(0),
        ),
        ['', '', '', '', '', 'TOTAL', '1000', '300', '125', '20', '980', '555'],
      );
    });

    test('builds simple report total rows for company and personal modes', () {
      final rows = [
        {'__jumlah': 1000, '__pph': 20, '__total': 980},
        {'__jumlah': 500, '__pph': 10, '__total': 490},
      ];

      expect(
        buildReportTableTotalRow(
          rows: rows,
          incomeInvoiceTable: false,
          showIncomePphColumn: false,
          combinedDriverCostColumns: false,
          showCombinedPphColumn: false,
          companyMode: true,
          formatAmount: (value) => value.toStringAsFixed(0),
        ),
        ['', '', 'TOTAL', '1500', '30', '1470', ''],
      );
      expect(
        buildReportTableTotalRow(
          rows: rows,
          incomeInvoiceTable: false,
          showIncomePphColumn: false,
          combinedDriverCostColumns: false,
          showCombinedPphColumn: false,
          companyMode: false,
          formatAmount: (value) => value.toStringAsFixed(0),
        ),
        ['', '', 'TOTAL', '1500', '1470', ''],
      );
    });

    test('builds income invoice data rows', () {
      final row = {
        '__date': '2026-06-04',
        '__customer': 'PT Test',
        '__jumlah': 1000,
        '__pph': 20,
        '__total': 980,
        '__bayar': 500,
        '__sisa': 480,
      };

      expect(
        buildReportTableDataRow(
          row: row,
          rowNumber: 3,
          incomeInvoiceTable: true,
          showIncomePphColumn: true,
          combinedDriverCostColumns: false,
          showCombinedPphColumn: false,
          companyMode: true,
          formatDate: (value) => 'date:$value',
          formatAmount: (value) => value.toStringAsFixed(0),
          paidAtDisplay: '04-Jun-26',
        ),
        [
          '3',
          'date:2026-06-04',
          'PT Test',
          '1000',
          '20',
          '980',
          '500',
          '480',
          '04-Jun-26'
        ],
      );
    });

    test('builds combined driver-cost data rows for income and expense', () {
      final income = {
        '__type': 'Income',
        '__date': '2026-06-04',
        '__customer': 'PT Test',
        '__plat_nomor': 'B 1234 CD',
        '__muat': 'T. Langon',
        '__bongkar': 'Pare',
        '__jumlah': 1000,
        '__sangu_sopir': 250,
        '__gabungan': 100,
        '__pph': 20,
        '__total': 980,
        '__laba': 630,
      };
      final expense = {
        '__type': 'Expense',
        '__date': '2026-06-04',
        '__customer': 'Auto Sangu',
        '__plat_nomor': '',
        '__muat': '',
        '__tujuan': 'Pare',
        '__sangu_sopir': 250,
        '__gabungan': 0,
        '__pph': 20,
        '__total': 250,
        '__laba': -250,
      };

      expect(
        buildReportTableDataRow(
          row: income,
          rowNumber: 1,
          incomeInvoiceTable: false,
          showIncomePphColumn: false,
          combinedDriverCostColumns: true,
          showCombinedPphColumn: true,
          companyMode: true,
          formatDate: (value) => 'date:$value',
          formatAmount: (value) => value.toStringAsFixed(0),
        ),
        [
          '1',
          'date:2026-06-04',
          'PT Test',
          'B 1234 CD',
          'T. Langon',
          'Pare',
          '1000',
          '250',
          '100',
          '20',
          '980',
          '630',
        ],
      );
      expect(
        buildReportTableDataRow(
          row: expense,
          rowNumber: 2,
          incomeInvoiceTable: false,
          showIncomePphColumn: false,
          combinedDriverCostColumns: true,
          showCombinedPphColumn: true,
          companyMode: true,
          formatDate: (value) => 'date:$value',
          formatAmount: (value) => value.toStringAsFixed(0),
        ),
        [
          '2',
          'date:2026-06-04',
          'Auto Sangu',
          '-',
          '-',
          'Pare',
          '',
          '250',
          '',
          '',
          '',
          '-250',
        ],
      );
    });

    test('builds simple company and personal data rows', () {
      final row = {
        '__date': '2026-06-04',
        '__customer': 'Felix',
        '__jumlah': 500000,
        '__pph': 0,
        '__total': 500000,
        '__tujuan': 'T. Langon',
      };

      expect(
        buildReportTableDataRow(
          row: row,
          rowNumber: 4,
          incomeInvoiceTable: false,
          showIncomePphColumn: false,
          combinedDriverCostColumns: false,
          showCombinedPphColumn: false,
          companyMode: true,
          formatDate: (value) => 'date:$value',
          formatAmount: (value) => value.toStringAsFixed(0),
        ),
        ['4', 'date:2026-06-04', 'Felix', '500000', '0', '500000', 'T. Langon'],
      );
      expect(
        buildReportTableDataRow(
          row: row,
          rowNumber: 4,
          incomeInvoiceTable: false,
          showIncomePphColumn: false,
          combinedDriverCostColumns: false,
          showCombinedPphColumn: false,
          companyMode: false,
          formatDate: (value) => 'date:$value',
          formatAmount: (value) => value.toStringAsFixed(0),
        ),
        ['4', 'date:2026-06-04', 'Felix', '500000', '500000', 'T. Langon'],
      );
    });
  });
}
