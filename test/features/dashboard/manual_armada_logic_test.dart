import 'package:cvant_mobile/features/dashboard/utils/gabungan_pricing_rule_logic.dart';
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
      expect(
        rowUsesManualArmada({
          'armada_id': 'fleet-1',
          'armada_is_manual': true,
          'armada_manual': 'Gabungan',
          'armada_label': 'Other Gabungan',
        }),
        isFalse,
      );
    });

    test('listed fleet selection clears stale manual state', () {
      final row = <String, dynamic>{
        'armada_is_manual': true,
        'armada_manual': 'Gabungan',
        'armada_label': 'Other Gabungan',
        'armada': 'Manual',
        'plat_nomor': 'Gabungan',
        'no_polisi': 'B 9615 TIT',
      };

      applyListedArmadaSelection(row, ' fleet-1 ');

      expect(row['armada_id'], 'fleet-1');
      expect(row['armada_is_manual'], isFalse);
      expect(row['armada_manual'], isEmpty);
      expect(row['armada_label'], isEmpty);
      expect(row['armada'], isEmpty);
      expect(row['plat_nomor'], isEmpty);
      expect(row['no_polisi'], 'B 9615 TIT');
      expect(rowUsesManualArmada(row), isFalse);
    });

    test('listed fleet selection makes pricing resolve as regular fleet', () {
      final row = <String, dynamic>{
        'armada_is_manual': true,
        'armada_manual': 'Gabungan',
      };

      applyListedArmadaSelection(row, 'fleet-1');

      final harga = resolveIncomeAutoHargaPerKg(
        regularHarga: 80,
        usesManualArmada: rowUsesManualArmada(row),
        pickup: 'T. Langon',
        destination: 'Pare',
        gabunganRules: const [
          {
            'customer_name': 'Gabungan',
            'lokasi_muat': '',
            'lokasi_bongkar': 'Pare',
            'harga_per_ton': 78,
            'priority': 310,
            'is_active': true,
          },
        ],
      );

      expect(harga, 80);
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
