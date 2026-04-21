import 'package:cvant_mobile/features/dashboard/utils/report_grouping_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Report grouping logic', () {
    test('prefers fixed invoice date for report reference date', () {
      expect(
        resolveIncomeReportInvoiceDate({
          'tanggal_kop': '2026-04-15',
          'tanggal': '2026-04-10',
          'created_at': '2026-04-01T10:00:00',
        }),
        '2026-04-15',
      );
      expect(
        resolveIncomeReportInvoiceDate({
          'tanggal_kop': '',
          'tanggal': '2026-04-10',
          'created_at': '2026-04-01T10:00:00',
        }),
        '2026-04-10',
      );
    });

    test('sorts income report rows by invoice ascending', () {
      final sorted = sortIncomeReportRowsByInvoice([
        {
          '__key': 'row-2',
          '__number': 'CV.ANT260402',
          '__invoice_sort': 'CV.ANT260402',
          '__date': '2026-04-02',
          '__departure_date': '2026-04-03',
          '__customer': 'B Customer',
        },
        {
          '__key': 'row-1b',
          '__number': 'CV.ANT260401',
          '__invoice_sort': 'CV.ANT260401',
          '__date': '2026-04-01',
          '__departure_date': '2026-04-05',
          '__customer': 'A Customer',
        },
        {
          '__key': 'row-1a',
          '__number': 'CV.ANT260401',
          '__invoice_sort': 'CV.ANT260401',
          '__date': '2026-04-01',
          '__departure_date': '2026-04-02',
          '__customer': 'A Customer',
        },
      ]);

      expect(
        sorted.map((row) => row['__key']).toList(),
        ['row-1a', 'row-1b', 'row-2'],
      );
    });

    test('groups income rows by customer and sums totals', () {
      final grouped = groupIncomeReportRowsByCustomer([
        {
          '__key': 'income:1:0',
          '__type': 'Income',
          '__date': '2026-04-10',
          '__customer': 'PT Bornava Indobara Mandiri',
          '__name': 'PT Bornava Indobara Mandiri',
          '__status': 'Paid',
          '__jumlah': 1000.0,
          '__pph': 20.0,
          '__total': 980.0,
          '__income': 980.0,
          '__tujuan': 'Batang',
        },
        {
          '__key': 'income:2:0',
          '__type': 'Income',
          '__date': '2026-04-12',
          '__customer': 'PT Bornava Indobara Mandiri',
          '__name': 'PT Bornava Indobara Mandiri',
          '__status': 'Unpaid',
          '__jumlah': 500.0,
          '__pph': 10.0,
          '__total': 490.0,
          '__income': 490.0,
          '__tujuan': 'Batang | Kendal',
        },
        {
          '__key': 'income:3:0',
          '__type': 'Income',
          '__date': '2026-04-11',
          '__customer': 'CV Tritunggal Makmur Abadi',
          '__name': 'CV Tritunggal Makmur Abadi',
          '__status': 'Paid',
          '__jumlah': 700.0,
          '__pph': 14.0,
          '__total': 686.0,
          '__income': 686.0,
          '__tujuan': 'Batang',
        },
      ]);

      expect(grouped, hasLength(2));

      final bornava = grouped.firstWhere(
        (row) => row['__customer'] == 'PT Bornava Indobara Mandiri',
      );
      expect(bornava['__group_mode'], 'customer_income');
      expect(bornava['__item_count'], 2);
      expect(bornava['__jumlah'], 1500.0);
      expect(bornava['__pph'], 30.0);
      expect(bornava['__total'], 1470.0);
      expect(bornava['__income'], 1470.0);
      expect(bornava['__date'], '2026-04-12');
      expect(bornava['__tujuan'], 'Batang | Kendal');
    });

    test('ignores non income rows', () {
      final grouped = groupIncomeReportRowsByCustomer([
        {
          '__key': 'expense:1',
          '__type': 'Expense',
          '__date': '2026-04-10',
          '__customer': 'Sangu Sopir',
          '__jumlah': 200,
          '__pph': 0,
          '__total': 200,
          '__income': 0,
          '__tujuan': '-',
        },
      ]);

      expect(grouped, isEmpty);
    });
  });
}
