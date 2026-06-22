import 'package:cvant_mobile/features/dashboard/utils/invoice_list_limit_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Invoice list limit logic', () {
    test('keeps linked children and manual standalone expenses visible', () {
      final groups = buildInvoiceListRowGroups(
        incomeRows: [
          {'__type': 'Income', 'id': 'income-1'},
          {'__type': 'Income', 'id': 'income-2'},
        ],
        expenseByIncomeId: {
          'income-1': [
            {
              '__type': 'Expense',
              '__is_auto_sangu': true,
              'id': 'sangu-1',
            },
          ],
        },
        standaloneExpenses: [
          {'__type': 'Expense', 'id': 'manual-expense'},
          {
            '__type': 'Expense',
            '__is_auto_gabungan': true,
            'id': 'unmatched-gabungan',
          },
        ],
      );

      final rows = groups.expand((group) => group).toList();

      expect(
        rows.map((row) => row['id']),
        ['income-1', 'sangu-1', 'income-2', 'manual-expense'],
      );
    });

    test('hides auto expenses without a visible income parent', () {
      final hiddenGroups = buildInvoiceListRowGroups(
        incomeRows: const [],
        expenseByIncomeId: const {},
        standaloneExpenses: const [
          {
            '__type': 'Expense',
            '__is_auto_sangu': true,
            'id': 'hidden-sangu',
          },
          {
            '__type': 'Expense',
            '__is_auto_gabungan': true,
            'id': 'hidden-gabungan',
          },
        ],
      );

      expect(hiddenGroups, isEmpty);
    });

    test('shows auto expenses again when their income parent returns', () {
      final restoredGroups = buildInvoiceListRowGroups(
        incomeRows: const [
          {'__type': 'Income', 'id': 'income-restored'},
        ],
        expenseByIncomeId: const {
          'income-restored': [
            {
              '__type': 'Expense',
              '__is_auto_sangu': true,
              'id': 'restored-sangu',
            },
            {
              '__type': 'Expense',
              '__is_auto_gabungan': true,
              'id': 'restored-gabungan',
            },
          ],
        },
        standaloneExpenses: const [],
      );

      expect(
        restoredGroups.single.map((row) => row['id']),
        ['income-restored', 'restored-sangu', 'restored-gabungan'],
      );
    });

    test('attaches children to expanded invoice detail row keys', () {
      final groups = buildInvoiceListRowGroups(
        incomeRows: const [
          {
            '__type': 'Income',
            'id': 'invoice-1',
            '__invoice_list_row_key': 'invoice-1#0',
          },
          {
            '__type': 'Income',
            'id': 'invoice-1',
            '__invoice_list_row_key': 'invoice-1#1',
          },
        ],
        expenseByIncomeId: const {
          'invoice-1#0': [
            {
              '__type': 'Expense',
              '__is_auto_gabungan': true,
              'id': 'gabungan-0',
            },
          ],
          'invoice-1#1': [
            {
              '__type': 'Expense',
              '__is_auto_gabungan': true,
              'id': 'gabungan-1',
            },
          ],
        },
        standaloneExpenses: const [],
      );

      expect(groups, hasLength(2));
      expect(groups.first.map((row) => row['id']), ['invoice-1', 'gabungan-0']);
      expect(groups.last.map((row) => row['id']), ['invoice-1', 'gabungan-1']);
    });

    test('keeps auto sangu and Gabungan rows attached at the cutoff', () {
      final rows = <Map<String, dynamic>>[
        for (var index = 0; index < 10; index++)
          {'__type': 'Income', 'id': 'income-$index'},
        {
          '__type': 'Expense',
          '__is_auto_sangu': true,
          'id': 'sangu-9',
        },
        {
          '__type': 'Expense',
          '__is_auto_gabungan': true,
          'id': 'gabungan-9',
        },
        {'__type': 'Income', 'id': 'income-10'},
      ];

      final limited = limitInvoiceListRows(rows, maxRows: 10);

      expect(limited, hasLength(12));
      expect(limited.last['id'], 'gabungan-9');
    });

    test('does not append unrelated expense rows', () {
      final rows = <Map<String, dynamic>>[
        {'__type': 'Income', 'id': 'income-1'},
        {'__type': 'Expense', 'id': 'manual-expense'},
      ];

      final limited = limitInvoiceListRows(rows, maxRows: 1);

      expect(limited, hasLength(1));
      expect(limited.single['id'], 'income-1');
    });
  });
}
