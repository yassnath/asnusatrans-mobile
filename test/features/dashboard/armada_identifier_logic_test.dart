import 'package:cvant_mobile/features/dashboard/utils/armada_identifier_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('armada identifier logic', () {
    test('normalizes plate and armada names consistently', () {
      expect(normalizeArmadaPlateText(' b  9615  tit '), 'B 9615 TIT');
      expect(normalizeArmadaPlateKey(' l-8465 udd '), 'L8465UDD');
      expect(normalizeArmadaNameKey('Truck 178 / L 9548 UI'),
          'truck 178 l 9548 ui');
    });

    test('extracts Indonesian-style truck plates from mixed text', () {
      expect(extractArmadaPlateFromText('Gabungan B9615TIT'), 'B9615TIT');
      expect(extractArmadaPlateFromText('Armada - L 9548 UI'), 'L 9548 UI');
      expect(extractArmadaPlateFromText('Tidak ada plat'), isNull);
    });

    test('builds armada lookup maps from normalized plates and names', () {
      final armadas = [
        {'id': 'a1', 'nama_truk': '178', 'plat_nomor': ' l 9548 ui '},
        {'id': 'a2', 'nama_truk': '05', 'plat_nomor': 'L 8465 UDD'},
      ];

      expect(buildArmadaIdByPlate(armadas)['L 9548 UI'], 'a1');
      expect(buildArmadaIdByPlate(armadas)['L8465UDD'], 'a2');
      expect(buildArmadaPlateById(armadas)['a2'], 'L 8465 UDD');
      expect(buildArmadaPlateByName(armadas)['178'], 'L 9548 UI');
      expect(buildArmadaPlateKeys(armadas), contains('L8465UDD'));
    });

    test('resolves listed fleet id from mixed manual plate formats', () {
      final armadaIdByPlate = buildArmadaIdByPlate(const [
        {'id': 'a2', 'plat_nomor': 'L 8465 UDD'},
      ]);

      for (final input in const [
        'l8465udd',
        'L-8465-udd',
        'Truk manual l 8465 UDD',
      ]) {
        expect(
          resolveArmadaIdFromPlateInput(
            armadaId: '',
            armadaInput: input,
            armadaIdByPlate: armadaIdByPlate,
          ),
          'a2',
        );
      }
      expect(
        resolveListedArmadaIdFromRow(
          const {
            'armada_is_manual': true,
            'armada_manual': 'l-8465-udd',
          },
          armadaIdByPlate: armadaIdByPlate,
        ),
        'a2',
      );
    });

    test('matches manually typed plate to listed fleet case-insensitively', () {
      const listedPlates = ['L 8465 UDD', 'B 9615 TIT'];

      expect(
        rowMatchesListedArmadaPlate(
          {'armada_manual': 'l8465udd'},
          listedPlates: listedPlates,
        ),
        isTrue,
      );
      expect(
        rowMatchesListedArmadaPlate(
          {'armada_label': 'Truk manual L-8465-udd'},
          listedPlates: listedPlates,
        ),
        isTrue,
      );
      expect(
        rowMatchesListedArmadaPlate(
          {'armada_manual': 'L 9999 XX'},
          listedPlates: listedPlates,
        ),
        isFalse,
      );
    });
  });
}
