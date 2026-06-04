import 'package:cvant_mobile/features/dashboard/utils/armada_identifier_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('armada identifier logic', () {
    test('normalizes plate and armada names consistently', () {
      expect(normalizeArmadaPlateText(' b  9615  tit '), 'B 9615 TIT');
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
      expect(buildArmadaPlateById(armadas)['a2'], 'L 8465 UDD');
      expect(buildArmadaPlateByName(armadas)['178'], 'L 9548 UI');
    });
  });
}
