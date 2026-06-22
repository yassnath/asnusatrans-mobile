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
      expect(normalizeSanguPlace('JaSkIn'), 'jaskin');
      expect(normalizeSanguPlace('Manyar'), 'manyar_mie_sedap');
      expect(normalizeSanguPlace('Mie Sedaap'), 'manyar_mie_sedap');
      expect(normalizeSanguPlace('Mie Sedap'), 'manyar_mie_sedap');
      expect(normalizeSanguPlace('WiNgS'), 'wings');
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

    test('keeps Betoyo to Bimoli at fixed T. Langon Bimoli nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'Betoyo',
        destination: 'BiMoLi',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 550000);
      expect(rule['lokasi_muat'], 'BETOYO');
      expect(rule['lokasi_bongkar'], 'BIMOLI');
    });

    test('keeps Betoyo to Batang at fixed T. Langon Batang nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'Betoyo',
        destination: 'BaTaNg',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 3400000);
      expect(rule['lokasi_muat'], 'BETOYO');
      expect(rule['lokasi_bongkar'], 'BATANG');
    });

    test('prioritizes Betoyo to T. Langon route with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'Betoyo',
        destination: 'T. Langon',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 500000);
      expect(rule['lokasi_muat'], 'BETOYO');
      expect(rule['lokasi_bongkar'], 'T. LANGON');
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

    test('prioritizes Depo to T. Langon route with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'dEpO',
        destination: 't. LANGON',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 400000);
      expect(rule['lokasi_muat'], 'DEPO');
      expect(rule['lokasi_bongkar'], 'T. LANGON');
    });

    test('prioritizes Driyo and Benowo routes case-insensitively', () {
      final driyoLangon = resolvePrioritizedSanguRouteRule(
        pickup: 'dRiYo',
        destination: 't. LANGON',
      );
      final nonBetoyoDriyo = resolvePrioritizedSanguRouteRule(
        pickup: 'T. Langon',
        destination: 'DRIYO',
      );
      final nonBetoyoBenowo = resolvePrioritizedSanguRouteRule(
        pickup: 'Maspion',
        destination: 'bEnOwO',
      );
      final nonBetoyoIndostar = resolvePrioritizedSanguRouteRule(
        pickup: 'T. Langon',
        destination: 'iNdO Star',
      );
      final betoyoBenowo = resolvePrioritizedSanguRouteRule(
        pickup: 'Betoyo',
        destination: 'Benowo',
      );
      final betoyoIndostar = resolvePrioritizedSanguRouteRule(
        pickup: 'Betoyo',
        destination: 'Indostar',
      );

      expect(driyoLangon?['nominal'], 520000);
      expect(driyoLangon?['lokasi_muat'], 'DRIYO');
      expect(driyoLangon?['lokasi_bongkar'], 'T. LANGON');
      expect(nonBetoyoDriyo?['nominal'], 520000);
      expect(nonBetoyoDriyo?['lokasi_muat'], 'Selain Betoyo');
      expect(nonBetoyoBenowo?['nominal'], 400000);
      expect(nonBetoyoBenowo?['lokasi_muat'], 'Selain Betoyo');
      expect(nonBetoyoIndostar?['nominal'], 1035000);
      expect(nonBetoyoIndostar?['lokasi_muat'], 'Selain Betoyo');
      expect(nonBetoyoIndostar?['lokasi_bongkar'], 'INDOSTAR');
      expect(betoyoBenowo, isNull);
      expect(betoyoIndostar, isNull);
    });

    test('prioritizes Manyar Mie Sedap and Wings routes case-insensitively',
        () {
      final manyarLangon = resolvePrioritizedSanguRouteRule(
        pickup: 'mAnYaR',
        destination: 't. LANGON',
      );
      final mieSedaapLangon = resolvePrioritizedSanguRouteRule(
        pickup: 'MIE SEDAAP',
        destination: 'T. Langon',
      );
      final langonMieSedap = resolvePrioritizedSanguRouteRule(
        pickup: 'T. Langon',
        destination: 'mie sedap',
      );
      final wingsLangon = resolvePrioritizedSanguRouteRule(
        pickup: 'WiNgS',
        destination: 'T. Langon',
      );
      final langonWings = resolvePrioritizedSanguRouteRule(
        pickup: 'T. Langon',
        destination: 'WINGS',
      );

      expect(manyarLangon?['nominal'], 450000);
      expect(manyarLangon?['lokasi_muat'], 'MANYAR / MIE SEDAP');
      expect(manyarLangon?['lokasi_bongkar'], 'T. LANGON');
      expect(mieSedaapLangon?['nominal'], 450000);
      expect(langonMieSedap?['nominal'], 450000);
      expect(langonMieSedap?['lokasi_muat'], 'T. LANGON');
      expect(langonMieSedap?['lokasi_bongkar'], 'MANYAR / MIE SEDAP');
      expect(wingsLangon?['nominal'], 450000);
      expect(wingsLangon?['lokasi_muat'], 'WINGS');
      expect(wingsLangon?['lokasi_bongkar'], 'T. LANGON');
      expect(langonWings?['nominal'], 450000);
      expect(langonWings?['lokasi_muat'], 'Selain Betoyo');
      expect(langonWings?['lokasi_bongkar'], 'WINGS');
    });

    test('prioritizes SGM destination with fixed nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'T. Langon',
        destination: 'sGm',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 520000);
      expect(rule['lokasi_bongkar'], 'SGM');
    });

    test('keeps manual Driyo and Wings to T. Langon as Gabungan expense', () {
      expect(
        manualArmadaRouteUsesSanguExpense(
          pickup: 'dRiYo',
          destination: 't. LANGON',
        ),
        isFalse,
      );
      expect(
        manualArmadaRouteUsesSanguExpense(
          pickup: 'Wings Driyo',
          destination: 'T. Langon',
        ),
        isFalse,
      );
      expect(
        manualArmadaRouteUsesSanguExpense(
          pickup: 'T. Langon',
          destination: 'DRIYO',
        ),
        isFalse,
      );
      expect(
        manualArmadaRouteUsesSanguExpense(
          pickup: 'T. Langon',
          destination: 'wings driyo',
        ),
        isFalse,
      );
    });

    test('routes selected manual destinations to sangu', () {
      expect(
        manualArmadaRouteUsesSanguExpense(
          pickup: 'Maspion',
          destination: 'bEnOwO',
        ),
        isTrue,
      );
      expect(
        manualArmadaRouteUsesSanguExpense(
          pickup: 'T. Langon',
          destination: 'iNdOsTaR',
        ),
        isTrue,
      );
      expect(
        manualArmadaRouteUsesSanguExpense(
          pickup: 'Betoyo',
          destination: 'Benowo',
        ),
        isFalse,
      );
      expect(
        manualArmadaRouteUsesSanguExpense(
          pickup: 'T. Langon',
          destination: 'SGM',
        ),
        isTrue,
      );
    });

    test('prioritizes non-Betoyo pickup to Singosari private sangu', () {
      final langon = resolvePrioritizedSanguRouteRule(
        pickup: 'T. Langon',
        destination: 'Singosari',
        customerName: 'Iwan',
        invoiceEntity: 'personal',
      );
      final maspion = resolvePrioritizedSanguRouteRule(
        pickup: 'Maspion',
        destination: 'KSI Singosari',
        customerName: 'Iwan',
        invoiceEntity: 'pribadi',
      );
      final betoyo = resolvePrioritizedSanguRouteRule(
        pickup: 'Betoyo',
        destination: 'Singosari',
        customerName: 'Iwan',
        invoiceEntity: 'personal',
      );
      final unknownEntity = resolvePrioritizedSanguRouteRule(
        pickup: 'T. Langon',
        destination: 'Singosari',
        customerName: 'PT Siapa Saja',
      );

      expect(langon, isNotNull);
      expect(langon!['nominal'], 980000);
      expect(langon['lokasi_muat'], 'Selain Betoyo');
      expect(langon['lokasi_bongkar'], 'SINGOSARI');
      expect(maspion?['nominal'], 980000);
      expect(betoyo, isNull);
      expect(unknownEntity, isNull);
    });

    test('keeps PT Tritunggal Singosari sangu at company nominal', () {
      final rule = resolvePrioritizedSanguRouteRule(
        pickup: 'T. Langon',
        destination: 'Singosari',
        customerName: 'PT TRITUNGGAL MAKMUR ABADHI SEJAHTERA',
        invoiceEntity: 'pt_ant',
      );

      expect(rule, isNotNull);
      expect(rule!['nominal'], 1035000);
      expect(rule['lokasi_bongkar'], 'SINGOSARI');
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

    test('prioritizes Jaskin destination and Betoyo derivative sangu', () {
      final generic = resolvePrioritizedSanguRouteRule(
        pickup: 'T. Langon',
        destination: 'jAsKiN',
      );
      final betoyo = resolvePrioritizedSanguRouteRule(
        pickup: 'BETOYO',
        destination: 'JASKIN',
      );

      expect(generic, isNotNull);
      expect(generic!['nominal'], 2530000);
      expect(generic['lokasi_bongkar'], 'JASKIN');
      expect(betoyo, isNotNull);
      expect(betoyo!['nominal'], 2645000);
      expect(betoyo['lokasi_muat'], 'BETOYO');
      expect(betoyo['lokasi_bongkar'], 'JASKIN');
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
