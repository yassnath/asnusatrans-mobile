import 'package:cvant_mobile/features/dashboard/utils/expense_number_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Expense number logic', () {
    test('uses the number period even when the stored date differs', () {
      final next = buildNextExpenseNumberForPeriod(
        month: 6,
        year: 2026,
        existingRows: const [
          {
            'id': 'expense-1',
            'no_expense': 'EXP-06-2026-0001',
            'tanggal': '2026-05-29',
          },
          {
            'id': 'expense-2',
            'no_expense': 'EXP-06-2026-0003',
            'tanggal': '2026-05-26',
          },
        ],
      );

      expect(next, 'EXP-06-2026-0004');
    });

    test('ignores other periods and an excluded expense', () {
      final next = buildNextExpenseNumberForPeriod(
        month: 6,
        year: 2026,
        excludeExpenseId: 'expense-2',
        existingRows: const [
          {'id': 'expense-1', 'no_expense': 'EXP-05-2026-0099'},
          {'id': 'expense-2', 'no_expense': 'EXP-06-2026-0005'},
          {'id': 'expense-3', 'no_expense': 'EXP-06-2026-0002'},
        ],
      );

      expect(next, 'EXP-06-2026-0003');
    });
  });
}
