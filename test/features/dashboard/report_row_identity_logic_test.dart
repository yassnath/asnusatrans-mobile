import 'package:cvant_mobile/features/dashboard/utils/report_row_identity_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Report row identity logic', () {
    test('deduplicates repeated invoice objects with the same database ID', () {
      final rows = dedupeReportInvoiceRowsById([
        {'id': 'invoice-118', 'lokasi_bongkar': 'Gema'},
        {'id': 'invoice-118', 'lokasi_bongkar': 'Gema'},
      ]);

      expect(rows, hasLength(1));
    });

    test('keeps separate invoice IDs even when business data is identical', () {
      final rows = dedupeReportInvoiceRowsById([
        {'id': 'invoice-119', 'lokasi_bongkar': 'Sudali'},
        {'id': 'invoice-123', 'lokasi_bongkar': 'Sudali'},
      ]);

      expect(rows, hasLength(2));
    });

    test('reserves each invoice detail only once across report sources', () {
      final seen = <String>{};
      final invoice = <String, dynamic>{'id': 'invoice-118'};

      expect(
        reserveReportIncomeDetailIdentity(
          seenIdentities: seen,
          invoice: invoice,
          detailIndex: 0,
        ),
        isTrue,
      );
      expect(
        reserveReportIncomeDetailIdentity(
          seenIdentities: seen,
          invoice: invoice,
          detailIndex: 0,
        ),
        isFalse,
      );
      expect(
        reserveReportIncomeDetailIdentity(
          seenIdentities: seen,
          invoice: invoice,
          detailIndex: 1,
        ),
        isTrue,
      );
    });
  });
}
