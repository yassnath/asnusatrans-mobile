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

    test('matches Selain Betoyo pickup rule only outside Betoyo', () {
      expect(
        incomePricingLocationKeyMatches(
          normalizeIncomePricingRuleKey('Kendal'),
          normalizeIncomePricingRuleKey('Selain Betoyo'),
        ),
        isTrue,
      );
      expect(
        incomePricingLocationKeyMatches(
          normalizeIncomePricingRuleKey('T. Langon'),
          normalizeIncomePricingRuleKey('Selain Betoyo'),
        ),
        isTrue,
      );
      expect(
        incomePricingLocationKeyMatches(
          normalizeIncomePricingRuleKey('Betoyo'),
          normalizeIncomePricingRuleKey('Selain Betoyo'),
        ),
        isFalse,
      );
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

    test('returns regular listed-fleet Pare fallback rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'pArE',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_muat'], 'Selain Betoyo');
      expect(rule?['lokasi_bongkar'], 'Pare');
      expect(rule?['harga_per_ton'], 80.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns regular listed-fleet Bricon Mojo fallback rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'bricon mojo',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_muat'], 'Selain Betoyo');
      expect(rule?['lokasi_bongkar'], 'Bricon Mojo');
      expect(rule?['harga_per_ton'], 55.0);
      expect(rule?['flat_total'], isNull);
    });

    test('keeps regular listed-fleet Kendal price separated from Gabungan', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'KeNdAl',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_muat'], 'Selain Betoyo');
      expect(rule?['lokasi_bongkar'], 'Kendal');
      expect(rule?['harga_per_ton'], 175.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns regular listed-fleet Mojosari fallback rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'mOjOsArI',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_muat'], 'Selain Betoyo');
      expect(rule?['lokasi_bongkar'], 'Mojosari');
      expect(rule?['harga_per_ton'], 55.0);
      expect(rule?['flat_total'], isNull);
    });

    test('keeps Wings Driyo to T. Langon listed-fleet price at 45', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Hengky',
        pickup: 'Wings Driyo',
        destination: 'T. Langon',
      );

      expect(rule, isNotNull);
      expect(rule?['harga_per_ton'], 45.0);
    });

    test('returns built-in Bumindo fallback rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'BuMiNdO',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_bongkar'], 'Bumindo');
      expect(rule?['harga_per_ton'], 55.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns built-in Temanggung fallback rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'temanggung',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_bongkar'], 'Temanggung');
      expect(rule?['harga_per_ton'], 165.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns generic fallback rule when pickup is still empty', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: '',
        destination: 'temanggung',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_muat'], isNull);
      expect(rule?['lokasi_bongkar'], 'Temanggung');
      expect(rule?['harga_per_ton'], 165.0);
    });

    test('derives Betoyo fallback rule from generic destination rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'Betoyo',
        destination: 'temanggung',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_muat'], 'Betoyo');
      expect(rule?['lokasi_bongkar'], 'Temanggung');
      expect(rule?['harga_per_ton'], 172.0);
    });

    test('returns built-in Danliris fallback rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'DANLIRIS',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_bongkar'], 'Danliris');
      expect(rule?['harga_per_ton'], 155.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns built-in Minatex fallback and Betoyo derivative rule', () {
      final generic = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'mInAtEx',
      );
      final betoyo = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'bEtOyO',
        destination: 'MINATEX',
      );

      expect(generic, isNotNull);
      expect(generic?['lokasi_muat'], isNull);
      expect(generic?['lokasi_bongkar'], 'Minatex');
      expect(generic?['harga_per_ton'], 80.0);
      expect(betoyo, isNotNull);
      expect(betoyo?['lokasi_muat'], 'Betoyo');
      expect(betoyo?['lokasi_bongkar'], 'Minatex');
      expect(betoyo?['harga_per_ton'], 87.0);
    });

    test('returns built-in Jaskin fallback and Betoyo derivative rule', () {
      final generic = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'jAsKiN',
      );
      final betoyo = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'BETOYO',
        destination: 'JASKIN',
      );

      expect(generic, isNotNull);
      expect(generic?['lokasi_muat'], isNull);
      expect(generic?['lokasi_bongkar'], 'Jaskin');
      expect(generic?['harga_per_ton'], 168.0);
      expect(betoyo, isNotNull);
      expect(betoyo?['lokasi_muat'], 'Betoyo');
      expect(betoyo?['lokasi_bongkar'], 'Jaskin');
      expect(betoyo?['harga_per_ton'], 175.0);
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

    test('returns built-in T. Langon to Rex borongan rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'CV Swadaya Alam Makmur',
        pickup: 'T. LANGON',
        destination: 'rEx',
      );

      expect(rule, isNotNull);
      expect(rule?['customer_name'], 'Swadaya');
      expect(rule?['lokasi_muat'], 'T. Langon');
      expect(rule?['lokasi_bongkar'], 'Rex');
      expect(rule?['harga_per_ton'], 55.0);
      expect(rule?['flat_total'], 700000.0);
    });

    test('does not apply Rex borongan rule outside Swadaya customer', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'Rex',
      );

      expect(rule, isNull);
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
      expect(rule?['harga_per_ton'], 195.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns built-in Betoyo to Pare fallback rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'BETOYO',
        destination: 'pArE',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_muat'], 'Betoyo');
      expect(rule?['lokasi_bongkar'], 'Pare');
      expect(rule?['harga_per_ton'], 87.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns built-in Betoyo derivative rules for new destinations', () {
      final bimoli = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'Betoyo',
        destination: 'Bimoli',
      );
      final sudali = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'BETOYO',
        destination: 'sUdAli',
      );
      final mkp = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'betoyo',
        destination: 'MKP',
      );
      final bricon = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'Betoyo',
        destination: 'Bricon Mojo',
      );

      expect(bimoli?['harga_per_ton'], 35.0);
      expect(sudali?['harga_per_ton'], 65.0);
      expect(mkp?['harga_per_ton'], 57.0);
      expect(bricon?['harga_per_ton'], 62.0);
    });

    test('returns regular Bimoli pricing for listed fleet routes', () {
      final nonBetoyo = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'bImOli',
      );
      final betoyo = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'Betoyo',
        destination: 'BIMOLI',
      );

      expect(nonBetoyo?['lokasi_muat'], 'Selain Betoyo');
      expect(nonBetoyo?['lokasi_bongkar'], 'Bimoli');
      expect(nonBetoyo?['harga_per_ton'], 28.0);
      expect(betoyo?['lokasi_muat'], 'Betoyo');
      expect(betoyo?['lokasi_bongkar'], 'Bimoli');
      expect(betoyo?['harga_per_ton'], 35.0);
    });

    test('returns built-in Maspion to T. Langon fallback rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'mAsPiOn',
        destination: 't. LANGON',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_muat'], 'Maspion');
      expect(rule?['lokasi_bongkar'], 'T. Langon');
      expect(rule?['harga_per_ton'], 26.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns built-in Depo to T. Langon fallback rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'dEpO',
        destination: 't. LANGON',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_muat'], 'Depo');
      expect(rule?['lokasi_bongkar'], 'T. Langon');
      expect(rule?['harga_per_ton'], 30.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns built-in Driyo and Benowo fallback rules', () {
      final driyoLangon = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'dRiYo',
        destination: 't. LANGON',
      );
      final nonBetoyoDriyo = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'DRIYO',
      );
      final nonBetoyoBenowo = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'Maspion',
        destination: 'bEnOwO',
      );
      final nonBetoyoIndostar = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'iNdOsTaR',
      );
      final betoyoBenowo = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'Betoyo',
        destination: 'Benowo',
      );
      final betoyoIndostar = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'Betoyo',
        destination: 'Indostar',
      );

      expect(driyoLangon?['lokasi_muat'], 'Driyo');
      expect(driyoLangon?['lokasi_bongkar'], 'T. Langon');
      expect(driyoLangon?['harga_per_ton'], 45.0);
      expect(nonBetoyoDriyo?['lokasi_muat'], 'Selain Betoyo');
      expect(nonBetoyoDriyo?['harga_per_ton'], 45.0);
      expect(nonBetoyoBenowo?['lokasi_muat'], 'Selain Betoyo');
      expect(nonBetoyoBenowo?['harga_per_ton'], 35.0);
      expect(nonBetoyoIndostar?['lokasi_muat'], 'Selain Betoyo');
      expect(nonBetoyoIndostar?['lokasi_bongkar'], 'Indostar');
      expect(nonBetoyoIndostar?['harga_per_ton'], 88.0);
      expect(betoyoBenowo, isNull);
      expect(betoyoIndostar, isNull);
    });

    test('returns regular Manyar Mie Sedap and Wings route pricing', () {
      final manyarLangon = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'mAnYaR',
        destination: 't. LANGON',
      );
      final mieSedaapLangon = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'MIE SEDAAP',
        destination: 'T. Langon',
      );
      final langonMieSedap = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'mie sedap',
      );
      final wingsLangon = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'WiNgS',
        destination: 'T. Langon',
      );
      final langonWings = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'WINGS',
      );

      expect(manyarLangon?['harga_per_ton'], 30.0);
      expect(manyarLangon?['lokasi_muat'], 'Manyar / Mie Sedap');
      expect(manyarLangon?['lokasi_bongkar'], 'T. Langon');
      expect(mieSedaapLangon?['harga_per_ton'], 30.0);
      expect(langonMieSedap?['harga_per_ton'], 30.0);
      expect(langonMieSedap?['lokasi_muat'], 'T. Langon');
      expect(langonMieSedap?['lokasi_bongkar'], 'Manyar / Mie Sedap');
      expect(wingsLangon?['harga_per_ton'], 45.0);
      expect(wingsLangon?['lokasi_muat'], 'Wings');
      expect(wingsLangon?['lokasi_bongkar'], 'T. Langon');
      expect(langonWings?['harga_per_ton'], 45.0);
      expect(langonWings?['lokasi_muat'], 'Selain Betoyo');
      expect(langonWings?['lokasi_bongkar'], 'Wings');
    });

    test('prioritizes Antok tongkang rate for Maspion to T. Langon', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'aNtOk',
        pickup: 'MASPION',
        destination: 't. langon',
      );

      expect(rule, isNotNull);
      expect(rule?['customer_name'], 'Antok');
      expect(rule?['lokasi_muat'], 'Maspion');
      expect(rule?['lokasi_bongkar'], 'T. Langon');
      expect(rule?['harga_per_ton'], 21.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns built-in T. Langon to Surya Warna Sukoharjo rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'T. Langon',
        destination: 'sUkOhArJo',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_muat'], 'T. Langon');
      expect(rule?['lokasi_bongkar'], 'Surya Warna / Sukoharjo');
      expect(rule?['harga_per_ton'], 165.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns built-in Betoyo to Surya Warna Sukoharjo rule', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Siapa Saja',
        pickup: 'BETOYO',
        destination: 'Surya Warna',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_muat'], 'Betoyo');
      expect(rule?['lokasi_bongkar'], 'Surya Warna / Sukoharjo');
      expect(rule?['harga_per_ton'], 172.0);
      expect(rule?['flat_total'], isNull);
    });

    test('returns reverse base rule for Tolakan cargo before halving', () {
      final rule = resolveBuiltInIncomePricingRuleForCargo(
        customerName: 'Siapa Saja',
        pickup: 'Muncar',
        destination: 'Betoyo',
        cargo: 'Muatan TOLAKAN',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_muat'], 'Betoyo');
      expect(rule?['lokasi_bongkar'], 'Muncar');
      expect(rule?['harga_per_ton'], 195.0);
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

    test('returns Bornava-specific Batang rule case-insensitively', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'pt BoRnAvA indobara mandiri',
        pickup: 'T. Langon',
        destination: 'BaTaNg',
      );

      expect(rule, isNotNull);
      expect(rule?['customer_name'], 'Bornava');
      expect(rule?['lokasi_bongkar'], 'Batang');
      expect(rule?['harga_per_ton'], 225.0);
    });

    test('marks Batang built-in pricing as forced', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'CV Siapa Saja',
        pickup: 'Manual',
        destination: 'Ba-TaNg',
      );

      expect(isForcedBatangIncomePricingRule(rule), isTrue);
    });

    test('returns generic Batang rule outside Bornava', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'CV Tritunggal Makmur Abadi',
        pickup: 'T. Langon',
        destination: 'batang',
      );

      expect(rule, isNotNull);
      expect(rule?['customer_name'], isNull);
      expect(rule?['lokasi_bongkar'], 'Batang');
      expect(rule?['harga_per_ton'], 235.0);
    });

    test('returns generic Batang rule when pickup is still empty', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'CV Tritunggal Makmur Abadi',
        pickup: '',
        destination: 'batang',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_bongkar'], 'Batang');
      expect(rule?['harga_per_ton'], 235.0);
    });

    test('returns generic Batang rule even from Betoyo pickup', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'CV Tritunggal Makmur Abadi',
        pickup: 'Betoyo',
        destination: 'batang',
      );

      expect(rule, isNotNull);
      expect(rule?['lokasi_bongkar'], 'Batang');
      expect(rule?['harga_per_ton'], 235.0);
    });

    test('keeps Bornava Batang rule even from Betoyo pickup', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'PT Bornava Indobara Mandiri',
        pickup: 'Betoyo',
        destination: 'batang',
      );

      expect(rule, isNotNull);
      expect(rule?['customer_name'], 'Bornava');
      expect(rule?['lokasi_bongkar'], 'Batang');
      expect(rule?['harga_per_ton'], 225.0);
    });

    test('returns null for unrelated route', () {
      final rule = resolveBuiltInIncomePricingRule(
        customerName: 'Giono',
        pickup: 'T. Langon',
        destination: 'Tidak Ada',
      );

      expect(rule, isNull);
    });
  });
}
