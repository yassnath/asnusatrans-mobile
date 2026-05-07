import 'package:cvant_mobile/features/dashboard/utils/sangu_rule_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sangu rule logic', () {
    test('normalizes key route aliases consistently', () {
      expect(normalizeSanguPlace('T. Langon'), 'langon');
      expect(normalizeSanguPlace('tlangon'), 'langon');
      expect(normalizeSanguPlace('Purwodadi Timur'), 'purwodadi');
      expect(normalizeSanguPlace('Soedali'), 'sudali');
      expect(normalizeSanguPlace('Tuban Jenu'), 'tuban jenu');
      expect(normalizeSanguPlace('GeMpOl'), 'gempol');
      expect(normalizeSanguPlace('Royal Mix'), 'royal');
      expect(normalizeSanguPlace('TEMANGGUNG'), 'temanggung');
      expect(normalizeSanguPlace('bumindo'), 'bumindo');
      expect(
        normalizeSanguPlace('Surya Warna / Sukoharjo'),
        'surya warna sukoharjo',
      );
      expect(normalizeSanguPlace('sukoharjo'), 'surya warna sukoharjo');
    });

    test('prioritizes batang to langon route with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'Batang',
        destination: 'T. Langon',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 3400000);
      expect(rule['lokasi_muat'], 'BATANG');
      expect(rule['lokasi_bongkar'], 'T. LANGON');
    });

    test('prioritizes langon to batang route with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'T. Langon',
        destination: 'Batang',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 3400000);
      expect(rule['lokasi_muat'], 'T. LANGON');
      expect(rule['lokasi_bongkar'], 'BATANG');
    });

    test('prioritizes kendal to betoyo route with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'KeNdAl',
        destination: 'bEtOyO',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 1700000);
      expect(rule['lokasi_muat'], 'KENDAL');
      expect(rule['lokasi_bongkar'], 'BETOYO');
    });

    test('prioritizes T. Langon to Sarana route with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'T. LANGON',
        destination: 'sarana',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 1265000);
      expect(rule['lokasi_muat'], 'T. LANGON');
      expect(rule['lokasi_bongkar'], 'SARANA');
    });

    test('prioritizes T. Langon to Muncar route with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'T. LANGON',
        destination: 'muncar',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 3000000);
      expect(rule['lokasi_muat'], 'T. LANGON');
      expect(rule['lokasi_bongkar'], 'MUNCAR');
    });

    test('prioritizes T. Langon to Rex route with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 't. langon',
        destination: 'rEx',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 690000);
      expect(rule['lokasi_muat'], 'T. LANGON');
      expect(rule['lokasi_bongkar'], 'REX');
    });

    test('prioritizes Betoyo to Muncar route with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'Betoyo',
        destination: 'MUNCAR',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 3100000);
      expect(rule['lokasi_muat'], 'BETOYO');
      expect(rule['lokasi_bongkar'], 'MUNCAR');
    });

    test('prioritizes Betoyo to Pare route with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'bEtOyO',
        destination: 'PaRe',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 1165000);
      expect(rule['lokasi_muat'], 'BETOYO');
      expect(rule['lokasi_bongkar'], 'PARE');
    });

    test('prioritizes Betoyo derivative sangu routes', () {
      final sudali = resolvePrioritizedSanguRouteRule(
        pickup: 'Betoyo',
        destination: 'sUdAli',
      );
      final mkp = resolvePrioritizedSanguRouteRule(
        pickup: 'BETOYO',
        destination: 'mkp',
      );
      final bricon = resolvePrioritizedSanguRouteRule(
        pickup: 'betoyo',
        destination: 'Bricon Mojo',
      );

      expect(sudali?['nominal'], 920000);
      expect(mkp?['nominal'], 805000);
      expect(bricon?['nominal'], 865000);
    });

    test('prioritizes Maspion to T. Langon route with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'mAsPiOn',
        destination: 't. LANGON',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 400000);
      expect(rule['lokasi_muat'], 'MASPION');
      expect(rule['lokasi_bongkar'], 'T. LANGON');
    });

    test('prioritizes T. Langon to Surya Warna Sukoharjo route', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'T. Langon',
        destination: 'sukoharjo',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 2435000);
      expect(rule['lokasi_muat'], 'T. LANGON');
      expect(rule['lokasi_bongkar'], 'SURYA WARNA / SUKOHARJO');
    });

    test('prioritizes Betoyo to Surya Warna Sukoharjo route', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'BETOYO',
        destination: 'Surya Warna',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 2550000);
      expect(rule['lokasi_muat'], 'BETOYO');
      expect(rule['lokasi_bongkar'], 'SURYA WARNA / SUKOHARJO');
    });

    test('prioritizes nganjuk to driyo route with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'NGANJUK',
        destination: 'driyo',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 700000);
      expect(rule['lokasi_muat'], 'NGANJUK');
      expect(rule['lokasi_bongkar'], 'DRIYO');
    });

    test('prioritizes royal destination with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'T. Langon',
        destination: 'rOyAl',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 520000);
      expect(rule['lokasi_bongkar'], 'ROYAL');
    });

    test('prioritizes temanggung destination with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'T. Langon',
        destination: 'TeMaNgGuNg',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 2435000);
      expect(rule['lokasi_bongkar'], 'TEMANGGUNG');
    });

    test('prioritizes bumindo destination with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'T. Langon',
        destination: 'BuMiNdO',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 690000);
      expect(rule['lokasi_bongkar'], 'BUMINDO');
    });

    test('returns null for unrelated route', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'Tidak Ada',
        destination: 'Tidak Ada',
      );

      expect(rule, isNull);
    });
  });
}
