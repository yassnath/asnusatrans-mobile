import 'package:cvant_mobile/features/dashboard/utils/invoice_print_selector_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Invoice print selector logic', () {
    test('splits multi-detail income into one selectable row per detail', () {
      final rows = expandInvoicePrintSelectorRows([
        {
          'id': 'invoice-1',
          'invoice_entity': 'cv_ant',
          'nama_pelanggan': 'CV MUSTIKATAMA',
          'tanggal': '2026-06-24',
          'lokasi_muat': 'Mojoagung',
          'lokasi_bongkar': 'T. Langon',
          'rincian': [
            {
              'lokasi_muat': 'Mojoagung',
              'lokasi_bongkar': 'T. Langon',
              'armada_start_date': '2026-06-24',
              'plat_nomor': 'L 8581 UH',
              'muatan': 'Batubara',
              'tonase': 30000,
              'harga': 55,
              'subtotal_auto': true,
            },
            {
              'lokasi_muat': 'T. Langon',
              'lokasi_bongkar': 'Mojoagung',
              'armada_start_date': '2026-06-24',
              'plat_nomor': 'B 9064 TIU',
              'muatan': 'Batubara',
              'tonase': 31000,
              'harga': 55,
              'subtotal_auto': true,
            },
          ],
        },
      ]);

      expect(rows, hasLength(2));
      expect(
          rows.map(invoicePrintSelectorRowKey), ['invoice-1:0', 'invoice-1:1']);
      expect(rows.map((row) => row['lokasi_muat']), ['Mojoagung', 'T. Langon']);
      expect(
          rows.map((row) => row['lokasi_bongkar']), ['T. Langon', 'Mojoagung']);
      expect(rows.map((row) => row['total_biaya']), [1650000.0, 1705000.0]);
      expect(rows.map((row) => (row['rincian'] as List).length), [1, 1]);
    });

    test('keeps single-detail income as one selectable row', () {
      final rows = expandInvoicePrintSelectorRows([
        {
          'id': 'invoice-2',
          'invoice_entity': 'personal',
          'nama_pelanggan': 'Hengky',
          'tanggal': '2026-06-11',
          'lokasi_muat': 'Wings Driyo',
          'lokasi_bongkar': 'T. Langon',
          'rincian': [
            {
              'lokasi_muat': 'Wings Driyo',
              'lokasi_bongkar': 'T. Langon',
              'tonase': 32290,
              'harga': 45,
              'subtotal_auto': true,
            },
          ],
        },
      ]);

      expect(rows, hasLength(1));
      expect(invoicePrintSelectorRowKey(rows.single), 'invoice-2');
      expect(rows.single['__invoice_list_expanded_detail'], isNot(true));
      expect((rows.single['rincian'] as List), hasLength(1));
    });

    test('resolves fixed identity source id and detail index', () {
      expect(isInvoiceFixedDetailKey('invoice-1:12'), isTrue);
      expect(isInvoiceFixedDetailKey('invoice-1'), isFalse);
      expect(invoiceFixedSourceId('invoice-1:12'), 'invoice-1');
      expect(invoiceFixedSourceId('invoice-1'), 'invoice-1');
      expect(invoiceFixedDetailIndex('invoice-1:12'), 12);
      expect(invoiceFixedDetailIndex('invoice-1'), isNull);
    });

    test('resolves fixed invoice rows per detail without loading full parent',
        () {
      final rows = resolveFixedInvoiceSourceRows(
        fixedIds: const ['invoice-1:1'],
        sourceInvoices: [
          {
            'id': 'invoice-1',
            'invoice_entity': 'personal',
            'nama_pelanggan': 'CV MUSTIKATAMA',
            'tanggal': '2026-06-24',
            'rincian': [
              {
                'lokasi_muat': 'Mojoagung',
                'lokasi_bongkar': 'T. Langon',
                'armada_start_date': '2026-06-24',
                'tonase': 30000,
                'harga': 55,
                'subtotal_auto': true,
              },
              {
                'lokasi_muat': 'T. Langon',
                'lokasi_bongkar': 'Mojoagung',
                'armada_start_date': '2026-06-25',
                'tonase': 31000,
                'harga': 55,
                'subtotal_auto': true,
              },
            ],
          },
        ],
      );

      expect(rows, hasLength(1));
      expect(rows.single['lokasi_muat'], 'T. Langon');
      expect(rows.single['lokasi_bongkar'], 'Mojoagung');
      expect(rows.single['tanggal'], '2026-06-25');
      expect(rows.single['total_biaya'], 1705000.0);
      expect(rows.single['__fixed_invoice_identity'], 'invoice-1:1');
      expect((rows.single['rincian'] as List), hasLength(1));
    });

    test('resolves legacy fixed invoice rows by parent invoice id', () {
      final rows = resolveFixedInvoiceSourceRows(
        fixedIds: const ['invoice-2'],
        sourceInvoices: [
          {
            'id': 'invoice-2',
            'invoice_entity': 'personal',
            'nama_pelanggan': 'Hengky',
            'tanggal': '2026-06-11',
            'rincian': [
              {
                'lokasi_muat': 'Wings Driyo',
                'lokasi_bongkar': 'T. Langon',
                'tonase': 32290,
                'harga': 45,
                'subtotal_auto': true,
              },
            ],
          },
        ],
      );

      expect(rows, hasLength(1));
      expect(invoiceFixedIdentityForRow(rows.single), 'invoice-2');
      expect(rows.single['nama_pelanggan'], 'Hengky');
      expect(rows.single['__fixed_invoice_identity'], isNull);
    });
  });
}
