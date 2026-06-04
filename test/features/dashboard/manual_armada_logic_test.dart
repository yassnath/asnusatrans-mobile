import 'package:cvant_mobile/features/dashboard/utils/manual_armada_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('manual armada logic', () {
    test('normalizes manual armada text consistently', () {
      expect(normalizeManualArmadaText('Input   Manual!!'), 'input manual');
      expect(normalizeManualArmadaText('Other Gabungan'), 'other gabungan');
    });

    test('detects common manual armada labels', () {
      expect(isManualArmadaText('Gabungan'), isTrue);
      expect(isManualArmadaText('Input Manual'), isTrue);
      expect(isManualArmadaText('Other Gabungan'), isTrue);
      expect(isManualArmadaText('B 9615 TIT'), isFalse);
    });

    test('detects manual armada rows from flag, manual field, or labels', () {
      expect(rowUsesManualArmada({'armada_is_manual': true}), isTrue);
      expect(rowUsesManualArmada({'armada_is_manual': '1'}), isTrue);
      expect(rowUsesManualArmada({'armada_manual': 'Custom truck'}), isTrue);
      expect(rowUsesManualArmada({'armada_label': 'Gabungan'}), isTrue);
      expect(rowUsesManualArmada({'plat_nomor': 'B 9615 TIT'}), isFalse);
    });

    test('resolves the best display label for manual armada rows', () {
      expect(
        manualArmadaLabelFromRow({
          'armada_manual': '',
          'armada_label': 'Gabungan',
          'plat_nomor': 'B 9615 TIT',
        }),
        'Gabungan',
      );
      expect(
        manualArmadaLabelFromRow({
          'armada_manual': 'Truk Sewa',
          'armada_label': 'Gabungan',
        }),
        'Truk Sewa',
      );
    });
  });
}
