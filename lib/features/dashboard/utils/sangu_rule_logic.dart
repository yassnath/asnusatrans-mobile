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
  if (normalized.contains('batang')) return 'batang';
  if (normalized.contains('kig')) return 'kig';
  if (normalized.contains('kendal')) return 'kendal';
  if (normalized.contains('gema')) return 'gema';
  if (normalized.contains('gempol')) return 'gempol';
  if (normalized.contains('mkp')) return 'mkp';
  if (normalized.contains('sgm')) return 'sgm';
  if (normalized.contains('molindo')) return 'molindo';
  if (normalized.contains('muncar')) return 'muncar';
  if (normalized.contains('royal')) return 'royal';
  if (normalized.contains('tongas')) return 'tongas';
  if (normalized.contains('tanggulangin')) return 'tanggulangin';
  if (normalized.contains('tim')) return 'tim';
  if (normalized.contains('aspal')) return 'aspal';
  return normalized;
}

Map<String, dynamic>? resolvePrioritizedSanguRouteRule({
  required String pickup,
  required String destination,
}) {
  final pickupNorm = normalizeSanguPlace(pickup);
  final destinationNorm = normalizeSanguPlace(destination);
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

  return null;
}
