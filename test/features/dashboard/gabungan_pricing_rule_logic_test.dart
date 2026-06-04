import 'package:cvant_mobile/features/dashboard/utils/gabungan_pricing_rule_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Gabungan pricing rule logic', () {
    test('normalizes supported route aliases consistently', () {
      expect(normalizeGabunganRouteKey('T. Langon'), 'langon');
      expect(normalizeGabunganRouteKey('KSI Safelock'), 'safelock');
      expect(normalizeGabunganRouteKey('Kec. Bululawang'), 'bululawang');
      expect(normalizeGabunganRouteKey('REX Beji'), 'rex_beji');
    });

    test('uses built-in Gabungan fallback rates', () {
      expect(
        resolveBuiltInGabunganHargaPerKg(
          pickup: 'T. Langon',
          destination: 'Bululawang',
        ),
        100,
      );
      expect(
        resolveBuiltInGabunganHargaPerKg(
          pickup: 'Betoyo',
          destination: 'MKP',
        ),
        53,
      );
      expect(
        resolveBuiltInGabunganHargaPerKg(
          pickup: 'T. Langon',
          destination: 'MKP',
        ),
        50,
      );
      expect(
        resolveBuiltInGabunganHargaPerKg(
          pickup: 'Maspion',
          destination: 'T. Langon',
        ),
        23,
      );
      expect(
        resolveBuiltInGabunganHargaPerKg(
          pickup: 'Depo',
          destination: 'Safelock',
        ),
        50,
      );
      expect(
        resolveBuiltInGabunganHargaPerKg(
          pickup: 'T. Langon',
          destination: 'SGM',
        ),
        41,
      );
      expect(
        resolveBuiltInGabunganHargaPerKg(
          pickup: 'Betoyo',
          destination: 'SGM',
        ),
        0,
      );
    });

    test('prioritizes database Gabungan route rules over fallback', () {
      final rules = <Map<String, dynamic>>[
        {
          'customer_name': 'Gabungan',
          'lokasi_muat': '',
          'lokasi_bongkar': 'MKP',
          'harga_per_ton': 50,
          'priority': 300,
          'is_active': true,
        },
        {
          'customer_name': 'Gabungan',
          'lokasi_muat': 'Betoyo',
          'lokasi_bongkar': 'MKP',
          'harga_per_ton': 53,
          'priority': 380,
          'is_active': true,
        },
      ];

      expect(
        resolveGabunganHargaPerKg(
          pickup: 'Betoyo',
          destination: 'MKP',
          rules: rules,
        ),
        53,
      );
      expect(
        resolveGabunganHargaPerKg(
          pickup: 'T. Langon',
          destination: 'MKP',
          rules: rules,
        ),
        50,
      );
    });

    test('matches database Selain Betoyo Gabungan rule safely', () {
      final rules = <Map<String, dynamic>>[
        {
          'customer_name': 'Gabungan',
          'lokasi_muat': 'Selain Betoyo',
          'lokasi_bongkar': 'SGM',
          'harga_per_ton': 41,
          'priority': 320,
          'is_active': true,
        },
      ];

      expect(
        resolveGabunganHargaPerKg(
          pickup: 'T. Langon',
          destination: 'SGM',
          rules: rules,
        ),
        41,
      );
      expect(
        resolveGabunganHargaPerKg(
          pickup: 'Betoyo',
          destination: 'SGM',
          rules: rules,
        ),
        0,
      );
    });

    test('ignores inactive or non-Gabungan rules', () {
      final rules = <Map<String, dynamic>>[
        {
          'customer_name': 'Customer Biasa',
          'lokasi_muat': '',
          'lokasi_bongkar': 'Safelock',
          'harga_per_ton': 999,
          'priority': 999,
          'is_active': true,
        },
        {
          'customer_name': 'Gabungan',
          'lokasi_muat': '',
          'lokasi_bongkar': 'Safelock',
          'harga_per_ton': 777,
          'priority': 999,
          'is_active': false,
        },
      ];

      expect(
        resolveGabunganHargaPerKg(
          pickup: 'Depo',
          destination: 'Safelock',
          rules: rules,
        ),
        50,
      );
    });
  });
}
