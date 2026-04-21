import 'package:cvant_mobile/features/dashboard/utils/income_pricing_rule_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Income pricing rule logic', () {
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
