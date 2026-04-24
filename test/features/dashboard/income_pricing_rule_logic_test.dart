import 'package:cvant_mobile/features/dashboard/utils/income_pricing_rule_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Income pricing rule logic', () {
    test('detects Ongkos Kuli cargo case-insensitively', () {
      expect(isOngkosKuliCargo('Ongkos Kuli'), isTrue);
      expect(isOngkosKuliCargo('ongkos   kuli'), isTrue);
      expect(isOngkosKuliCargo('ONGKOS-KULI'), isTrue);
      expect(isOngkosKuliCargo('Batubara'), isFalse);
    });

    test('returns built-in Giono sewa rule for Nganjuk to Driyo', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'gIoNo',
        pickup: 'NGANJUK',
        destination: 'dRiYo',
      );

      expect(rule, isNotNull);
      expect(rule?['customer_name'], 'Giono');
      expect(rule?['lokasi_muat'], 'Nganjuk');
      expect(rule?['lokasi_bongkar'], 'Driyo');
      expect(rule?['flat_total'], 1600000.0);
      expect(rule?['harga_per_ton'], 0.0);
    });

    test('returns built-in Gempol fallback rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'GeMpOl',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_bongkar'], 'Gempol');
      expect(rule?['harga_per_ton'], 55.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns built-in T. Langon to Sarana fallback rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 't.LANGON',
        destination: 'sArAnA',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_muat'], 'T. Langon');
      expect(rule?['lokasi_bongkar'], 'Sarana');
      expect(rule?['harga_per_ton'], 110.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns built-in Betoyo to Muncar fallback rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'bEtOyO',
        destination: 'mUnCaR',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_muat'], 'Betoyo');
      expect(rule?['lokasi_bongkar'], 'Muncar');
      expect(rule?['harga_per_ton'], 193.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns built-in Hasan geser rule for T. Langon to T. Langon', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'HaSaN',
        pickup: 't. LANGON',
        destination: 'TLangon',
      );

      expect(rule, isNotNull);
      expect(rule?['customer_name'], 'Hasan');
      expect(rule?['lokasi_muat'], 'T. Langon');
      expect(rule?['lokasi_bongkar'], 'T. Langon');
      expect(rule?['flat_total'], 200000.0);
      expect(rule?['harga_per_ton'], 0.0);
    });

    test('returns built-in Unergi Royal customer-specific rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'PT UNERGI INTI PERSADA',
        pickup: 'T. Langon',
        destination: 'rOyAl',
      );

      expect(rule, isNotNull);
      expect(rule?['customer_name'], 'Unergi');
      expect(rule?['lokasi_bongkar'], 'Royal');
      expect(rule?['harga_per_ton'], 43.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns null for unrelated route', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Giono',
        pickup: 'T. Langon',
        destination: 'Batang',
      );

      expect(rule, isNull);
    });
  });
}
