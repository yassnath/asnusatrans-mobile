import 'package:cvant_mobile/features/dashboard/utils/expense_classifier_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Expense classifier logic', () {
    test('detects auto sangu from note and legacy description', () {
      expect(
        isAutoSanguExpense({'note': 'AUTO_SANGU:INV-001'}),
        isTrue,
      );
      expect(
        isAutoSanguExpense({'keterangan': 'Auto sangu sopir - INV-002'}),
        isTrue,
      );
      expect(
        extractAutoExpenseMarker({'note': 'AUTO_SANGU:INV-001'}),
        'INV-001',
      );
      expect(
        extractAutoExpenseMarker({'keterangan': 'Auto sangu sopir - INV-002'}),
        'INV-002',
      );
    });

    test('detects auto gabungan from note and legacy description', () {
      expect(
        isAutoGabunganExpense({'note': 'AUTO_GABUNGAN:abc-123'}),
        isTrue,
      );
      expect(
        isAutoGabunganExpense({'keterangan': 'Auto gabungan - abc-456'}),
        isTrue,
      );
      expect(
        extractAutoExpenseMarker({'note': 'AUTO_GABUNGAN:abc-123'}),
        'abc-123',
      );
      expect(
        extractAutoExpenseMarker({'keterangan': 'Auto gabungan - abc-456'}),
        'abc-456',
      );
    });

    test('classifies sangu and gabungan from rincian text', () {
      final sangu = {
        'kategori': 'Operasional',
        'rincian': [
          {'nama': 'Uang jalan sopir Victor'},
        ],
      };
      final gabungan = {
        'kategori': 'Operasional',
        'rincian': '[{"nama":"Armada manual Gabungan"}]',
      };

      expect(isSanguExpense(sangu), isTrue);
      expect(isGabunganExpense(gabungan), isTrue);
      expect(expenseClassifierText(gabungan), contains('gabungan'));
    });

    test('normalizes link tokens consistently', () {
      expect(expenseLinkToken('INV-001 / PT.ANT'), 'INV001PTANT');
      expect(expenseLinkToken(null), '');
    });
  });
}
