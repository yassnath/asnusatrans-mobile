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

    test('returns null for unrelated route', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'Betoyo',
        destination: 'Pare',
      );

      expect(rule, isNull);
    });
  });
}
