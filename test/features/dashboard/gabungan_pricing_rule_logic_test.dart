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
          pickup: 'Driyo',
          destination: 'T. Langon',
        ),
        40,
      );
      expect(
        resolveBuiltInGabunganHargaPerKg(
          pickup: 'T. Langon',
          destination: 'Driyo',
        ),
        40,
      );
      expect(
        resolveBuiltInGabunganHargaPerKg(
          pickup: 'Betoyo',
          destination: 'T. Langon',
        ),
        27,
      );
      expect(
        resolveBuiltInGabunganHargaPerKg(
          pickup: 'T. Langon',
          destination: 'Betoyo',
        ),
        27,
      );
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
          destination: 'Gerobokan',
        ),
        158,
      );
      expect(
        resolveBuiltInGabunganHargaPerKg(
          pickup: 'T. Langon',
          destination: 'Bricon Mojo',
        ),
        53,
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
          destination: 'Semarang',
        ),
        0,
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

    test('does not apply generic Gabungan destination rules to Betoyo pickup',
        () {
      final rules = <Map<String, dynamic>>[
        {
          'customer_name': 'Gabungan',
          'lokasi_muat': '',
          'lokasi_bongkar': 'Semarang',
          'harga_per_ton': 158,
          'priority': 310,
          'is_active': true,
        },
        {
          'customer_name': 'Gabungan',
          'lokasi_muat': 'Betoyo',
          'lokasi_bongkar': 'T. Langon',
          'harga_per_ton': 27,
          'priority': 380,
          'is_active': true,
        },
      ];

      expect(
        resolveGabunganHargaPerKg(
          pickup: 'T. Langon',
          destination: 'Semarang',
          rules: rules,
        ),
        158,
      );
      expect(
        resolveGabunganHargaPerKg(
          pickup: 'Betoyo',
          destination: 'Semarang',
          rules: rules,
        ),
        0,
      );
      expect(
        resolveGabunganHargaPerKg(
          pickup: 'Betoyo',
          destination: 'T. Langon',
          rules: rules,
        ),
        27,
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

    test('separates regular and Gabungan rule sets defensively', () {
      expect(
        isRegularIncomeHargaRule({
          'customer_name': null,
          'lokasi_bongkar': 'Pare',
          'harga_per_ton': 80,
          'is_active': true,
        }),
        isTrue,
      );
      expect(
        isRegularIncomeHargaRule({
          'customer_name': 'Gabungan',
          'lokasi_bongkar': 'Pare',
          'harga_per_ton': 78,
          'is_active': true,
        }),
        isFalse,
      );
      expect(
        isRegularIncomeHargaRule({
          'customer_name': null,
          'lokasi_bongkar': 'Pare',
          'harga_per_ton': 80,
          'is_active': false,
        }),
        isFalse,
      );
    });

    test('uses Gabungan pricing only for manual fleet rows', () {
      final rules = <Map<String, dynamic>>[
        {
          'customer_name': 'Gabungan',
          'lokasi_muat': '',
          'lokasi_bongkar': 'Pare',
          'harga_per_ton': 78,
          'priority': 310,
          'is_active': true,
        },
      ];
      expect(
        resolveIncomeAutoHargaPerKg(
          regularHarga: 80,
          usesManualArmada: false,
          pickup: 'T. Langon',
          destination: 'Pare',
        ),
        80,
      );
      expect(
        resolveIncomeAutoHargaPerKg(
          regularHarga: 80,
          usesManualArmada: true,
          pickup: 'T. Langon',
          destination: 'Pare',
          gabunganRules: rules,
        ),
        78,
      );
    });

    test('keeps Betoyo MKP pricing separated by fleet type', () {
      final rules = <Map<String, dynamic>>[
        {
          'customer_name': 'Gabungan',
          'lokasi_muat': 'Selain Betoyo',
          'lokasi_bongkar': 'MKP',
          'harga_per_ton': 50,
          'priority': 310,
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
        resolveIncomeAutoHargaPerKg(
          regularHarga: 57,
          usesManualArmada: false,
          pickup: 'Betoyo',
          destination: 'MKP',
          gabunganRules: rules,
        ),
        57,
      );
      expect(
        resolveIncomeAutoHargaPerKg(
          regularHarga: 57,
          usesManualArmada: true,
          pickup: 'Betoyo',
          destination: 'MKP',
          gabunganRules: rules,
        ),
        53,
      );
      expect(
        resolveIncomeAutoHargaPerKg(
          regularHarga: 50,
          usesManualArmada: false,
          pickup: 'T. Langon',
          destination: 'MKP',
          gabunganRules: rules,
        ),
        50,
      );
      expect(
        resolveIncomeAutoHargaPerKg(
          regularHarga: 50,
          usesManualArmada: true,
          pickup: 'T. Langon',
          destination: 'MKP',
          gabunganRules: rules,
        ),
        50,
      );
    });

    test('keeps Driyo pricing separated by fleet type', () {
      final rules = <Map<String, dynamic>>[
        {
          'customer_name': 'Gabungan',
          'lokasi_muat': 'Driyo',
          'lokasi_bongkar': 'T. Langon',
          'harga_per_ton': 40,
          'priority': 390,
          'is_active': true,
        },
        {
          'customer_name': 'Gabungan',
          'lokasi_muat': 'Selain Betoyo',
          'lokasi_bongkar': 'Driyo',
          'harga_per_ton': 40,
          'priority': 390,
          'is_active': true,
        },
      ];

      expect(
        resolveIncomeAutoHargaPerKg(
          regularHarga: 45,
          usesManualArmada: false,
          pickup: 'Driyo',
          destination: 'T. Langon',
          gabunganRules: rules,
        ),
        45,
      );
      expect(
        resolveIncomeAutoHargaPerKg(
          regularHarga: 45,
          usesManualArmada: true,
          pickup: 'Driyo',
          destination: 'T. Langon',
          gabunganRules: rules,
        ),
        40,
      );
      expect(
        resolveIncomeAutoHargaPerKg(
          regularHarga: 45,
          usesManualArmada: false,
          pickup: 'Maspion',
          destination: 'Driyo',
          gabunganRules: rules,
        ),
        45,
      );
      expect(
        resolveIncomeAutoHargaPerKg(
          regularHarga: 45,
          usesManualArmada: true,
          pickup: 'Maspion',
          destination: 'Driyo',
          gabunganRules: rules,
        ),
        40,
      );
    });

    test('does not leak any known Gabungan route into listed fleet pricing',
        () {
      final cases = <({
        String pickup,
        String destination,
        double gabunganHarga,
      })>[
        (pickup: 'Betoyo', destination: 'Bimoli', gabunganHarga: 33),
        (pickup: 'Driyo', destination: 'T. Langon', gabunganHarga: 40),
        (pickup: 'T. Langon', destination: 'Driyo', gabunganHarga: 40),
        (pickup: 'Betoyo', destination: 'T. Langon', gabunganHarga: 27),
        (pickup: 'T. Langon', destination: 'Betoyo', gabunganHarga: 27),
        (pickup: 'T. Langon', destination: 'Bululawang', gabunganHarga: 100),
        (pickup: 'T. Langon', destination: 'Bricon Mojo', gabunganHarga: 53),
        (pickup: 'T. Langon', destination: 'Gempol', gabunganHarga: 50),
        (pickup: 'T. Langon', destination: 'Gerobokan', gabunganHarga: 158),
        (pickup: 'T. Langon', destination: 'Kedamean', gabunganHarga: 41),
        (pickup: 'T. Langon', destination: 'Kedawung', gabunganHarga: 40),
        (pickup: 'T. Langon', destination: 'Kediri', gabunganHarga: 80),
        (pickup: 'T. Langon', destination: 'Kendal', gabunganHarga: 170),
        (pickup: 'Betoyo', destination: 'MKP', gabunganHarga: 53),
        (pickup: 'T. Langon', destination: 'MKP', gabunganHarga: 50),
        (pickup: 'T. Langon', destination: 'Pare', gabunganHarga: 78),
        (pickup: 'T. Langon', destination: 'Royal', gabunganHarga: 40),
        (pickup: 'T. Langon', destination: 'Safelock', gabunganHarga: 50),
        (pickup: 'T. Langon', destination: 'Semarang', gabunganHarga: 158),
        (pickup: 'T. Langon', destination: 'SGM', gabunganHarga: 41),
        (pickup: 'Maspion', destination: 'T. Langon', gabunganHarga: 23),
        (pickup: 'T. Langon', destination: 'Temanggung', gabunganHarga: 230),
      ];
      final rules = cases
          .map(
            (entry) => <String, dynamic>{
              'customer_name': 'Gabungan',
              'lokasi_muat': switch ((entry.pickup, entry.destination)) {
                ('Betoyo', 'Bimoli') ||
                ('Betoyo', 'MKP') ||
                ('Betoyo', 'T. Langon') =>
                  'Betoyo',
                ('Driyo', 'T. Langon') => 'Driyo',
                ('T. Langon', 'Betoyo') => 'T. Langon',
                ('T. Langon', 'MKP') || ('T. Langon', 'SGM') => 'Selain Betoyo',
                ('T. Langon', 'Driyo') ||
                ('T. Langon', 'Bricon Mojo') ||
                ('T. Langon', 'Gerobokan') =>
                  'Selain Betoyo',
                ('Maspion', 'T. Langon') => 'Maspion',
                _ => null,
              },
              'lokasi_bongkar': entry.destination,
              'harga_per_ton': entry.gabunganHarga,
              'priority': 300,
              'is_active': true,
            },
          )
          .toList(growable: false);

      for (final entry in cases) {
        const regularHarga = 999.0;
        expect(
          resolveIncomeAutoHargaPerKg(
            regularHarga: regularHarga,
            usesManualArmada: false,
            pickup: entry.pickup,
            destination: entry.destination,
            gabunganRules: rules,
          ),
          regularHarga,
          reason:
              '${entry.pickup}-${entry.destination} must stay on regular pricing for listed fleets',
        );
        expect(
          resolveIncomeAutoHargaPerKg(
            regularHarga: regularHarga,
            usesManualArmada: true,
            pickup: entry.pickup,
            destination: entry.destination,
            gabunganRules: rules,
          ),
          entry.gabunganHarga,
          reason:
              '${entry.pickup}-${entry.destination} must use Gabungan pricing for manual fleets',
        );
      }
    });

    test('falls back to regular pricing when manual route has no database rule',
        () {
      expect(
        resolveIncomeAutoHargaPerKg(
          regularHarga: 80,
          usesManualArmada: true,
          pickup: 'T. Langon',
          destination: 'Pare',
        ),
        80,
      );
      expect(
        resolveIncomeAutoHargaPerKg(
          regularHarga: null,
          usesManualArmada: false,
          pickup: 'T. Langon',
          destination: 'Pare',
        ),
        isNull,
      );
    });

    test('uses stored price for Gabungan expense without a database rule', () {
      expect(
        resolveGabunganExpenseHargaPerKg(
          storedHarga: 80,
          pickup: 'T. Langon',
          destination: 'Pare',
        ),
        80,
      );
      expect(
        resolveGabunganExpenseHargaPerKg(
          storedHarga: 80,
          pickup: 'T. Langon',
          destination: 'Pare',
          gabunganRules: [
            {
              'customer_name': 'Gabungan',
              'lokasi_muat': '',
              'lokasi_bongkar': 'Pare',
              'harga_per_ton': 78,
              'priority': 310,
              'is_active': true,
            },
          ],
        ),
        78,
      );
    });
  });
}
