String normalizeSanguPlace(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) return normalized;
  if (normalized.contains('purwodadi')) return 'purwodadi';
  if (normalized.contains('pare')) return 'pare';
  if (normalized.contains('sudali') || normalized.contains('soedali')) {
    return 'sudali';
  }
  if (normalized.contains('kedawung') || normalized.contains('dawung')) {
    return 'kedawung';
  }
  if (normalized.contains('singosari') ||
      (normalized.contains('ksi') && normalized.contains('singosari'))) {
    return 'singosari';
  }
  if (normalized == 'langon' ||
      normalized == 't langon' ||
      normalized == 'tlangon') {
    return 'langon';
  }
  if (normalized.contains('cj') && normalized.contains('mojoagung')) {
    return 'mojoagung';
  }
  if (normalized.contains('mojoagung')) return 'mojoagung';
  if (normalized.contains('bricon') && normalized.contains('mojo')) {
    return 'bricon';
  }
  if (normalized.contains('bricon')) return 'bricon';
  if (normalized.contains('kletek') && normalized.contains('bmc')) {
    return 'kletek';
  }
  if (normalized.contains('safelock')) return 'safelock';
  if (normalized.contains('tuban') || normalized.contains('jenu')) {
    return 'tuban jenu';
  }
  if (normalized.contains('kediri')) return 'kediri';
  if (normalized.contains('sragen')) return 'sragen';
  if (normalized.contains('bimoli')) return 'bimoli';
  if (normalized.contains('manyar') ||
      normalized.contains('mie sedaap') ||
      normalized.contains('mie sedap')) {
    return 'manyar_mie_sedap';
  }
  if (normalized.contains('bumindo')) return 'bumindo';
  if (normalized.contains('batang')) return 'batang';
  if (normalized.contains('kig')) return 'kig';
  if (normalized.contains('kendal')) return 'kendal';
  if (normalized.contains('gema')) return 'gema';
  if (normalized.contains('gempol')) return 'gempol';
  if (normalized.contains('mkp')) return 'mkp';
  if (normalized.contains('sgm')) return 'sgm';
  if (normalized.contains('molindo')) return 'molindo';
  if (normalized.contains('muncar')) return 'muncar';
  if (normalized.contains('rex')) return 'rex';
  if (normalized.contains('royal')) return 'royal';
  if (normalized.contains('temanggung')) return 'temanggung';
  if (normalized.contains('danliris')) return 'danliris';
  if (normalized.contains('jaskin')) return 'jaskin';
  if (normalized.contains('indostar') ||
      (normalized.contains('indo') && normalized.contains('star'))) {
    return 'indostar';
  }
  if (normalized.contains('wings')) return 'wings';
  if (normalized.contains('sukoharjo') ||
      (normalized.contains('surya') && normalized.contains('warna'))) {
    return 'surya warna sukoharjo';
  }
  if (normalized.contains('tongas')) return 'tongas';
  if (normalized.contains('tanggulangin')) return 'tanggulangin';
  if (normalized.contains('tim')) return 'tim';
  if (normalized.contains('aspal')) return 'aspal';
  return normalized;
}

bool sanguIsBetoyoPlace(String value) {
  final key = normalizeSanguPlace(value);
  return key == 'betoyo' || key.replaceAll(' ', '') == 'betoyo';
}

bool sanguIsNonBetoyoPickupRule(String value) {
  final key = normalizeSanguPlace(value);
  final compact = key.replaceAll(' ', '');
  return key == 'selain betoyo' ||
      key == 'non betoyo' ||
      compact == 'selainbetoyo' ||
      compact == 'nonbetoyo';
}

bool manualArmadaRouteUsesSanguExpense({
  required String pickup,
  required String destination,
}) {
  final pickupNorm = normalizeSanguPlace(pickup);
  final destinationNorm = normalizeSanguPlace(destination);
  if (pickupNorm.isEmpty || destinationNorm.isEmpty) return false;
  if (!sanguIsBetoyoPlace(pickupNorm) && destinationNorm == 'benowo') {
    return true;
  }
  if (!sanguIsBetoyoPlace(pickupNorm) && destinationNorm == 'indostar') {
    return true;
  }
  if (!sanguIsBetoyoPlace(pickupNorm) && destinationNorm == 'sgm') {
    return true;
  }
  return false;
}

String normalizeSanguCustomerKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String normalizeSanguEntityKey(String value) {
  return normalizeSanguCustomerKey(value).replaceAll(' ', '_');
}

bool sanguIsTritunggalMakmurCustomer(String value) {
  final key = normalizeSanguCustomerKey(value);
  if (key.isEmpty) return false;
  return key.contains('tritunggal') &&
      key.contains('makmur') &&
      key.contains('sejahtera');
}

bool sanguIsPersonalContext({
  required String customerName,
  required String invoiceEntity,
}) {
  final entityKey = normalizeSanguEntityKey(invoiceEntity);
  if (entityKey == 'personal' || entityKey == 'pribadi') return true;
  if (entityKey == 'cv_ant' ||
      entityKey == 'pt_ant' ||
      entityKey == 'cv' ||
      entityKey == 'pt') {
    return false;
  }

  final customerKey = normalizeSanguCustomerKey(customerName);
  if (customerKey.isEmpty) return false;
  if (sanguIsTritunggalMakmurCustomer(customerName)) return false;
  return !RegExp(r'(^|\s)(pt|cv|tbk|ud|pd)(\s|$)').hasMatch(customerKey);
}

Map<String, dynamic>? resolvePrioritizedSanguRouteRule({
  required String pickup,
  required String destination,
  String customerName = '',
  String invoiceEntity = '',
}) {
  final pickupNorm = normalizeSanguPlace(pickup);
  final destinationNorm = normalizeSanguPlace(destination);
  final isNonBetoyoToSingosari = pickupNorm.isNotEmpty &&
      !sanguIsBetoyoPlace(pickupNorm) &&
      destinationNorm == 'singosari';
  if (isNonBetoyoToSingosari && sanguIsTritunggalMakmurCustomer(customerName)) {
    return <String, dynamic>{
      'tempat': 'PT TRITUNGGAL MAKMUR ABADHI SEJAHTERA - SINGOSARI',
      'lokasi_muat': '',
      'lokasi_bongkar': 'SINGOSARI',
      'nominal': 1035000,
      'customer_name': 'PT Tritunggal Makmur Abadhi Sejahtera',
      '__customer_norm': 'pt tritunggal makmur abadhi sejahtera',
      '__muat_norm': '',
      '__bongkar_norm': 'singosari',
    };
  }

  final nonBetoyoToSingosari = pickupNorm.isNotEmpty &&
      !sanguIsBetoyoPlace(pickupNorm) &&
      destinationNorm == 'singosari' &&
      sanguIsPersonalContext(
        customerName: customerName,
        invoiceEntity: invoiceEntity,
      );
  if (nonBetoyoToSingosari) {
    return <String, dynamic>{
      'tempat': 'SELAIN BETOYO - SINGOSARI',
      'lokasi_muat': 'Selain Betoyo',
      'lokasi_bongkar': 'SINGOSARI',
      'nominal': 980000,
      'invoice_entity': 'personal',
      '__entity_norm': 'personal',
      '__muat_norm': 'selain betoyo',
      '__bongkar_norm': 'singosari',
    };
  }

  final batangToLangon = pickupNorm == 'batang' && destinationNorm == 'langon';
  final langonToBatang = pickupNorm == 'langon' && destinationNorm == 'batang';
  if (batangToLangon || langonToBatang) {
    return <String, dynamic>{
      'tempat': batangToLangon ? 'BATANG - T. LANGON' : 'T. LANGON - BATANG',
      'lokasi_muat': batangToLangon ? 'BATANG' : 'T. LANGON',
      'lokasi_bongkar': batangToLangon ? 'T. LANGON' : 'BATANG',
      'nominal': 3400000,
      '__muat_norm': batangToLangon ? 'batang' : 'langon',
      '__bongkar_norm': batangToLangon ? 'langon' : 'batang',
    };
  }

  final kendalToBetoyo = pickupNorm == 'kendal' && destinationNorm == 'betoyo';
  if (kendalToBetoyo) {
    return <String, dynamic>{
      'tempat': 'KENDAL - BETOYO',
      'lokasi_muat': 'KENDAL',
      'lokasi_bongkar': 'BETOYO',
      'nominal': 1700000,
      '__muat_norm': 'kendal',
      '__bongkar_norm': 'betoyo',
    };
  }

  final langonToSarana = pickupNorm == 'langon' && destinationNorm == 'sarana';
  if (langonToSarana) {
    return <String, dynamic>{
      'tempat': 'T. LANGON - SARANA',
      'lokasi_muat': 'T. LANGON',
      'lokasi_bongkar': 'SARANA',
      'nominal': 1265000,
      '__muat_norm': 'langon',
      '__bongkar_norm': 'sarana',
    };
  }

  final langonToMuncar = pickupNorm == 'langon' && destinationNorm == 'muncar';
  if (langonToMuncar) {
    return <String, dynamic>{
      'tempat': 'T. LANGON - MUNCAR',
      'lokasi_muat': 'T. LANGON',
      'lokasi_bongkar': 'MUNCAR',
      'nominal': 3000000,
      '__muat_norm': 'langon',
      '__bongkar_norm': 'muncar',
    };
  }

  final langonToRex = pickupNorm == 'langon' && destinationNorm == 'rex';
  if (langonToRex) {
    return <String, dynamic>{
      'tempat': 'T. LANGON - REX',
      'lokasi_muat': 'T. LANGON',
      'lokasi_bongkar': 'REX',
      'nominal': 690000,
      '__muat_norm': 'langon',
      '__bongkar_norm': 'rex',
    };
  }

  final betoyoToMuncar = pickupNorm == 'betoyo' && destinationNorm == 'muncar';
  if (betoyoToMuncar) {
    return <String, dynamic>{
      'tempat': 'BETOYO - MUNCAR',
      'lokasi_muat': 'BETOYO',
      'lokasi_bongkar': 'MUNCAR',
      'nominal': 3100000,
      '__muat_norm': 'betoyo',
      '__bongkar_norm': 'muncar',
    };
  }

  final betoyoToBimoli = pickupNorm == 'betoyo' && destinationNorm == 'bimoli';
  if (betoyoToBimoli) {
    return <String, dynamic>{
      'tempat': 'BETOYO - BIMOLI',
      'lokasi_muat': 'BETOYO',
      'lokasi_bongkar': 'BIMOLI',
      'nominal': 550000,
      '__muat_norm': 'betoyo',
      '__bongkar_norm': 'bimoli',
    };
  }

  final betoyoToBatang = pickupNorm == 'betoyo' && destinationNorm == 'batang';
  if (betoyoToBatang) {
    return <String, dynamic>{
      'tempat': 'BETOYO - BATANG',
      'lokasi_muat': 'BETOYO',
      'lokasi_bongkar': 'BATANG',
      'nominal': 3400000,
      '__muat_norm': 'betoyo',
      '__bongkar_norm': 'batang',
    };
  }

  final betoyoToLangon = pickupNorm == 'betoyo' && destinationNorm == 'langon';
  if (betoyoToLangon) {
    return <String, dynamic>{
      'tempat': 'BETOYO - T. LANGON',
      'lokasi_muat': 'BETOYO',
      'lokasi_bongkar': 'T. LANGON',
      'nominal': 500000,
      '__muat_norm': 'betoyo',
      '__bongkar_norm': 'langon',
    };
  }

  final betoyoBaseSanguRules = <String, ({String label, int nominal})>{
    'batang': (label: 'BATANG', nominal: 3400000),
    'sarana': (label: 'SARANA', nominal: 1265000),
    'rex': (label: 'REX', nominal: 690000),
    'pare': (label: 'PARE', nominal: 1050000),
    'sudali': (label: 'SUDALI', nominal: 805000),
    'mkp': (label: 'MKP', nominal: 690000),
    'bricon': (label: 'BRICON MOJO', nominal: 750000),
    'gempol': (label: 'GEMPOL', nominal: 690000),
    'royal': (label: 'ROYAL', nominal: 520000),
    'temanggung': (label: 'TEMANGGUNG', nominal: 2435000),
    'bumindo': (label: 'BUMINDO', nominal: 690000),
    'jaskin': (label: 'JASKIN', nominal: 2530000),
    'surya warna sukoharjo': (
      label: 'SURYA WARNA / SUKOHARJO',
      nominal: 2435000,
    ),
  };
  if (pickupNorm == 'betoyo') {
    final baseRule = betoyoBaseSanguRules[destinationNorm];
    if (baseRule != null) {
      return <String, dynamic>{
        'tempat': 'BETOYO - ${baseRule.label}',
        'lokasi_muat': 'BETOYO',
        'lokasi_bongkar': baseRule.label,
        'nominal': baseRule.nominal + 115000,
        '__muat_norm': 'betoyo',
        '__bongkar_norm': destinationNorm,
      };
    }
  }

  if (destinationNorm == 'bimoli') {
    return <String, dynamic>{
      'tempat': 'BIMOLI',
      'lokasi_muat': '',
      'lokasi_bongkar': 'BIMOLI',
      'nominal': 550000,
      '__muat_norm': '',
      '__bongkar_norm': 'bimoli',
    };
  }

  final depoToLangon = pickupNorm == 'depo' && destinationNorm == 'langon';
  if (depoToLangon) {
    return <String, dynamic>{
      'tempat': 'DEPO - T. LANGON',
      'lokasi_muat': 'DEPO',
      'lokasi_bongkar': 'T. LANGON',
      'nominal': 400000,
      '__muat_norm': 'depo',
      '__bongkar_norm': 'langon',
    };
  }

  final maspionToLangon =
      pickupNorm == 'maspion' && destinationNorm == 'langon';
  if (maspionToLangon) {
    return <String, dynamic>{
      'tempat': 'MASPION - T. LANGON',
      'lokasi_muat': 'MASPION',
      'lokasi_bongkar': 'T. LANGON',
      'nominal': 400000,
      '__muat_norm': 'maspion',
      '__bongkar_norm': 'langon',
    };
  }

  final manyarMieSedapToLangon =
      pickupNorm == 'manyar_mie_sedap' && destinationNorm == 'langon';
  final langonToManyarMieSedap =
      pickupNorm == 'langon' && destinationNorm == 'manyar_mie_sedap';
  if (manyarMieSedapToLangon || langonToManyarMieSedap) {
    return <String, dynamic>{
      'tempat': manyarMieSedapToLangon
          ? 'MANYAR / MIE SEDAP - T. LANGON'
          : 'T. LANGON - MANYAR / MIE SEDAP',
      'lokasi_muat':
          manyarMieSedapToLangon ? 'MANYAR / MIE SEDAP' : 'T. LANGON',
      'lokasi_bongkar':
          manyarMieSedapToLangon ? 'T. LANGON' : 'MANYAR / MIE SEDAP',
      'nominal': 450000,
      '__muat_norm': manyarMieSedapToLangon ? 'manyar_mie_sedap' : 'langon',
      '__bongkar_norm': manyarMieSedapToLangon ? 'langon' : 'manyar_mie_sedap',
    };
  }

  final langonToSuryaWarna =
      pickupNorm == 'langon' && destinationNorm == 'surya warna sukoharjo';
  if (langonToSuryaWarna) {
    return <String, dynamic>{
      'tempat': 'T. LANGON - SURYA WARNA / SUKOHARJO',
      'lokasi_muat': 'T. LANGON',
      'lokasi_bongkar': 'SURYA WARNA / SUKOHARJO',
      'nominal': 2435000,
      '__muat_norm': 'langon',
      '__bongkar_norm': 'surya warna sukoharjo',
    };
  }

  final nganjukToDriyo = pickupNorm == 'nganjuk' && destinationNorm == 'driyo';
  if (nganjukToDriyo) {
    return <String, dynamic>{
      'tempat': 'NGANJUK - DRIYO',
      'lokasi_muat': 'NGANJUK',
      'lokasi_bongkar': 'DRIYO',
      'nominal': 700000,
      '__muat_norm': 'nganjuk',
      '__bongkar_norm': 'driyo',
    };
  }

  final wingsToLangon = pickupNorm == 'wings' && destinationNorm == 'langon';
  if (wingsToLangon) {
    return <String, dynamic>{
      'tempat': 'WINGS - T. LANGON',
      'lokasi_muat': 'WINGS',
      'lokasi_bongkar': 'T. LANGON',
      'nominal': 450000,
      '__muat_norm': 'wings',
      '__bongkar_norm': 'langon',
    };
  }

  final driyoToLangon = pickupNorm == 'driyo' && destinationNorm == 'langon';
  if (driyoToLangon) {
    return <String, dynamic>{
      'tempat': 'DRIYO - T. LANGON',
      'lokasi_muat': 'DRIYO',
      'lokasi_bongkar': 'T. LANGON',
      'nominal': 520000,
      '__muat_norm': 'driyo',
      '__bongkar_norm': 'langon',
    };
  }

  final nonBetoyoToDriyo = pickupNorm.isNotEmpty &&
      !sanguIsBetoyoPlace(pickupNorm) &&
      destinationNorm == 'driyo';
  if (nonBetoyoToDriyo) {
    return <String, dynamic>{
      'tempat': 'SELAIN BETOYO - DRIYO',
      'lokasi_muat': 'Selain Betoyo',
      'lokasi_bongkar': 'DRIYO',
      'nominal': 520000,
      '__muat_norm': 'selain betoyo',
      '__bongkar_norm': 'driyo',
    };
  }

  final nonBetoyoToWings = pickupNorm.isNotEmpty &&
      !sanguIsBetoyoPlace(pickupNorm) &&
      destinationNorm == 'wings';
  if (nonBetoyoToWings) {
    return <String, dynamic>{
      'tempat': 'SELAIN BETOYO - WINGS',
      'lokasi_muat': 'Selain Betoyo',
      'lokasi_bongkar': 'WINGS',
      'nominal': 450000,
      '__muat_norm': 'selain betoyo',
      '__bongkar_norm': 'wings',
    };
  }

  final nonBetoyoToBenowo = pickupNorm.isNotEmpty &&
      !sanguIsBetoyoPlace(pickupNorm) &&
      destinationNorm == 'benowo';
  if (nonBetoyoToBenowo) {
    return <String, dynamic>{
      'tempat': 'SELAIN BETOYO - BENOWO',
      'lokasi_muat': 'Selain Betoyo',
      'lokasi_bongkar': 'BENOWO',
      'nominal': 400000,
      '__muat_norm': 'selain betoyo',
      '__bongkar_norm': 'benowo',
    };
  }

  final nonBetoyoToIndostar = pickupNorm.isNotEmpty &&
      !sanguIsBetoyoPlace(pickupNorm) &&
      destinationNorm == 'indostar';
  if (nonBetoyoToIndostar) {
    return <String, dynamic>{
      'tempat': 'SELAIN BETOYO - INDOSTAR',
      'lokasi_muat': 'Selain Betoyo',
      'lokasi_bongkar': 'INDOSTAR',
      'nominal': 1035000,
      '__muat_norm': 'selain betoyo',
      '__bongkar_norm': 'indostar',
    };
  }

  if (destinationNorm == 'sgm') {
    return <String, dynamic>{
      'tempat': 'SGM',
      'lokasi_muat': '',
      'lokasi_bongkar': 'SGM',
      'nominal': 520000,
      '__muat_norm': '',
      '__bongkar_norm': 'sgm',
    };
  }

  if (destinationNorm == 'royal') {
    return <String, dynamic>{
      'tempat': 'ROYAL',
      'lokasi_muat': '',
      'lokasi_bongkar': 'ROYAL',
      'nominal': 520000,
      '__muat_norm': '',
      '__bongkar_norm': 'royal',
    };
  }

  if (destinationNorm == 'temanggung') {
    return <String, dynamic>{
      'tempat': 'TEMANGGUNG',
      'lokasi_muat': '',
      'lokasi_bongkar': 'TEMANGGUNG',
      'nominal': 2435000,
      '__muat_norm': '',
      '__bongkar_norm': 'temanggung',
    };
  }

  if (destinationNorm == 'bumindo') {
    return <String, dynamic>{
      'tempat': 'BUMINDO',
      'lokasi_muat': '',
      'lokasi_bongkar': 'BUMINDO',
      'nominal': 690000,
      '__muat_norm': '',
      '__bongkar_norm': 'bumindo',
    };
  }

  if (destinationNorm == 'jaskin') {
    return <String, dynamic>{
      'tempat': 'JASKIN',
      'lokasi_muat': '',
      'lokasi_bongkar': 'JASKIN',
      'nominal': 2530000,
      '__muat_norm': '',
      '__bongkar_norm': 'jaskin',
    };
  }

  return null;
}
