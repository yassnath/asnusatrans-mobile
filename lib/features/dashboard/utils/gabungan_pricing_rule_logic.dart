import 'income_pricing_rule_logic.dart';

const gabunganHargaRuleCustomerName = 'Gabungan';

double parseGabunganRuleNumber(dynamic value) {
  if (value is num) return value.toDouble();
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty) return 0;
  final cleaned = raw
      .replaceAll(RegExp(r'[^0-9,.-]'), '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  return double.tryParse(cleaned) ?? 0;
}

String normalizeGabunganRouteKey(dynamic value) {
  final key = normalizeIncomePricingRuleKey('${value ?? ''}');
  if (key.contains('bimoli')) return 'bimoli';
  if (key.contains('driyo')) return 'driyo';
  if (key.contains('kendal')) return 'kendal';
  if (key.contains('kediri')) return 'kediri';
  if (key.contains('semarang')) return 'semarang';
  if (key.contains('gerobokan') || key.contains('grobogan')) {
    return 'gerobokan';
  }
  if (key.contains('kedawung') || key.contains('dawung')) return 'kedawung';
  if (key.contains('royal')) return 'royal';
  if (key.contains('pare')) return 'pare';
  if (key.contains('gempol')) return 'gempol';
  if (key.contains('bricon')) return 'bricon_mojo';
  if (key.contains('mkp')) return 'mkp';
  if (key.contains('bululawang')) return 'bululawang';
  if (key.contains('kedamean')) return 'kedamean';
  if (key.contains('temanggung')) return 'temanggung';
  if (key.contains('kig')) return 'kig';
  if (key.contains('sgm')) return 'sgm';
  if (key.contains('safelock')) return 'safelock';
  if (key.contains('rex') || key.contains('beji')) return 'rex_beji';
  if (key == 't langon' || key == 'langon' || key == 'tlangon') {
    return 'langon';
  }
  if (key.contains('maspion')) return 'maspion';
  if (key == 'betoyo') return 'betoyo';
  return key;
}

String gabunganRouteKey({
  required String pickup,
  required String destination,
}) {
  return '${normalizeGabunganRouteKey(pickup)}|'
      '${normalizeGabunganRouteKey(destination)}';
}

bool isGabunganHargaRuleCustomer(dynamic value) {
  final key = normalizeIncomePricingRuleKey('${value ?? ''}');
  return key == normalizeIncomePricingRuleKey(gabunganHargaRuleCustomerName);
}

bool isLikelyLeakedGabunganHargaRule(Map<String, dynamic> rule) {
  if (isGabunganHargaRuleCustomer(rule['customer_name'])) return true;
  if (normalizeIncomePricingRuleKey('${rule['customer_name'] ?? ''}')
      .isNotEmpty) {
    return false;
  }

  final pickup = '${rule['lokasi_muat'] ?? ''}'.trim();
  final destination = '${rule['lokasi_bongkar'] ?? ''}'.trim();
  final storedHarga =
      parseGabunganRuleNumber(rule['harga_per_ton'] ?? rule['harga']);
  if (destination.isEmpty || storedHarga <= 0) return false;

  final pickupCandidates = <String>{
    if (pickup.isNotEmpty) pickup,
    'Selain Betoyo',
    'Betoyo',
  };
  for (final candidatePickup in pickupCandidates) {
    final gabunganHarga = resolveBuiltInGabunganHargaPerKg(
      pickup: candidatePickup,
      destination: destination,
    );
    if (gabunganHarga <= 0 || (storedHarga - gabunganHarga).abs() > 0.001) {
      continue;
    }

    final regularRule = resolveBuiltInIncomePricingRule(
      customerName: '',
      pickup: candidatePickup,
      destination: destination,
    );
    final regularHarga = parseGabunganRuleNumber(
      regularRule?['harga_per_ton'] ?? regularRule?['harga'],
    );
    if (regularHarga > 0 && (regularHarga - storedHarga).abs() > 0.001) {
      return true;
    }
  }
  return false;
}

bool isRegularIncomeHargaRule(Map<String, dynamic> rule) {
  return rule['is_active'] != false && !isLikelyLeakedGabunganHargaRule(rule);
}

double resolveGabunganRuleHargaPerKg({
  required List<Map<String, dynamic>> rules,
  required String pickup,
  required String destination,
}) {
  if (rules.isEmpty) return 0;
  final pickupKey = normalizeIncomePricingRuleKey(pickup);
  final destinationKey = normalizeIncomePricingRuleKey(destination);
  if (destinationKey.isEmpty) return 0;

  int locationScore(String inputKey, String ruleKey) {
    if (ruleKey.isEmpty) return 100;
    if (inputKey.isEmpty) return 0;
    if (!incomePricingLocationKeyMatches(inputKey, ruleKey)) return 0;
    final inputCompact = inputKey.replaceAll(' ', '');
    final ruleCompact = ruleKey.replaceAll(' ', '');
    if (inputKey == ruleKey || inputCompact == ruleCompact) return 1000;
    return 600;
  }

  Map<String, dynamic>? bestRule;
  var bestScore = -1;
  for (final rule in rules) {
    if (rule['is_active'] == false) continue;
    if (!isGabunganHargaRuleCustomer(rule['customer_name'])) continue;
    final harga =
        parseGabunganRuleNumber(rule['harga_per_ton'] ?? rule['harga']);
    if (harga <= 0) continue;

    final ruleBongkarKey =
        normalizeIncomePricingRuleKey('${rule['lokasi_bongkar'] ?? ''}');
    if (!incomePricingLocationKeyMatches(destinationKey, ruleBongkarKey)) {
      continue;
    }

    final ruleMuatKey =
        normalizeIncomePricingRuleKey('${rule['lokasi_muat'] ?? ''}');
    if (ruleMuatKey.isEmpty && incomePricingIsBetoyoLocationKey(pickupKey)) {
      continue;
    }
    if (ruleMuatKey.isNotEmpty &&
        !incomePricingLocationKeyMatches(pickupKey, ruleMuatKey)) {
      continue;
    }

    final priority = int.tryParse('${rule['priority'] ?? ''}') ??
        parseGabunganRuleNumber(rule['priority']).toInt();
    final score = priority +
        locationScore(pickupKey, ruleMuatKey) +
        locationScore(destinationKey, ruleBongkarKey);
    if (score > bestScore) {
      bestScore = score;
      bestRule = rule;
    }
  }

  return parseGabunganRuleNumber(
    bestRule?['harga_per_ton'] ?? bestRule?['harga'],
  );
}

double resolveBuiltInGabunganHargaPerKg({
  required String pickup,
  required String destination,
}) {
  final pickupKey = normalizeGabunganRouteKey(pickup);
  final destinationKey = normalizeGabunganRouteKey(destination);
  final pickupIsBetoyo = incomePricingIsBetoyoLocationKey(pickupKey);
  final pickupIsNonBetoyo = pickupKey.isNotEmpty && !pickupIsBetoyo;
  if (pickupKey == 'betoyo' && destinationKey == 'bimoli') return 33;
  if (pickupKey == 'betoyo' && destinationKey == 'mkp') return 53;
  if (pickupKey == 'betoyo' && destinationKey == 'langon') return 27;
  if (pickupKey == 'langon' && destinationKey == 'betoyo') return 27;
  if (pickupKey == 'driyo' && destinationKey == 'langon') return 40;
  if (pickupIsNonBetoyo && destinationKey == 'driyo') return 40;
  if (pickupKey == 'maspion' && destinationKey == 'langon') return 23;
  switch (destinationKey) {
    case 'bululawang':
      return pickupIsNonBetoyo ? 100 : 0;
    case 'kendal':
      return pickupIsNonBetoyo ? 170 : 0;
    case 'kediri':
      return pickupIsNonBetoyo ? 80 : 0;
    case 'semarang':
      return pickupIsNonBetoyo ? 158 : 0;
    case 'gerobokan':
      return pickupIsNonBetoyo ? 158 : 0;
    case 'kedawung':
      return pickupIsNonBetoyo ? 40 : 0;
    case 'royal':
      return pickupIsNonBetoyo ? 40 : 0;
    case 'pare':
      return pickupIsNonBetoyo ? 78 : 0;
    case 'gempol':
      return pickupIsNonBetoyo ? 50 : 0;
    case 'bricon_mojo':
      return pickupIsNonBetoyo ? 53 : 0;
    case 'mkp':
      return pickupIsNonBetoyo ? 50 : 0;
    case 'kedamean':
      return pickupIsNonBetoyo ? 41 : 0;
    case 'temanggung':
      return pickupIsNonBetoyo ? 230 : 0;
    case 'kig':
      return pickupIsNonBetoyo ? 38 : 0;
    case 'sgm':
      return pickupIsNonBetoyo ? 41 : 0;
    case 'safelock':
      return pickupIsNonBetoyo ? 50 : 0;
    case 'rex_beji':
      return pickupIsNonBetoyo ? 53 : 0;
    default:
      return 0;
  }
}

double resolveGabunganHargaPerKg({
  required String pickup,
  required String destination,
  List<Map<String, dynamic>> rules = const <Map<String, dynamic>>[],
}) {
  final ruleHarga = resolveGabunganRuleHargaPerKg(
    rules: rules,
    pickup: pickup,
    destination: destination,
  );
  if (ruleHarga > 0) return ruleHarga;
  return resolveBuiltInGabunganHargaPerKg(
    pickup: pickup,
    destination: destination,
  );
}

bool isGabunganReportOnlyIncomeRoute({
  required String pickup,
  required String destination,
}) {
  final pickupKey = normalizeGabunganRouteKey(pickup);
  final destinationKey = normalizeGabunganRouteKey(destination);
  return (destinationKey == 'langon' &&
          (pickupKey == 'driyo' || pickupKey == 'wings')) ||
      (pickupKey == 'langon' &&
          (destinationKey == 'driyo' || destinationKey == 'wings'));
}

double? resolveIncomeRegularHargaForRoute({
  required Map<String, dynamic>? regularRule,
  required double? adjustedRegularHarga,
  required String pickup,
  required String destination,
}) {
  final normalizedAdjusted =
      adjustedRegularHarga != null && adjustedRegularHarga > 0
          ? adjustedRegularHarga
          : null;
  if (!isGabunganReportOnlyIncomeRoute(
    pickup: pickup,
    destination: destination,
  )) {
    return normalizedAdjusted;
  }

  final builtInRule = resolveBuiltInIncomePricingRule(
    customerName: '',
    pickup: pickup,
    destination: destination,
  );
  final rawBuiltInHarga = parseGabunganRuleNumber(
    builtInRule?['harga_per_ton'] ?? builtInRule?['harga'],
  );

  final rawRuleHarga = parseGabunganRuleNumber(
    regularRule?['harga_per_ton'] ?? regularRule?['harga'],
  );
  if (rawRuleHarga > 0) {
    final gabunganHarga = resolveBuiltInGabunganHargaPerKg(
      pickup: pickup,
      destination: destination,
    );
    final isStaleGabunganRule = gabunganHarga > 0 &&
        rawBuiltInHarga > 0 &&
        (rawRuleHarga - gabunganHarga).abs() <= 0.001 &&
        (rawRuleHarga - rawBuiltInHarga).abs() > 0.001;
    final isSuspiciousLowerThanRegular =
        rawBuiltInHarga > 0 && rawRuleHarga < rawBuiltInHarga;
    if (!isStaleGabunganRule && !isSuspiciousLowerThanRegular) {
      return rawRuleHarga;
    }
  }

  if (rawBuiltInHarga > 0) return rawBuiltInHarga;

  return normalizedAdjusted;
}

double? resolveIncomeAutoHargaPerKg({
  required double? regularHarga,
  required bool usesManualArmada,
  required String pickup,
  required String destination,
  List<Map<String, dynamic>> gabunganRules = const <Map<String, dynamic>>[],
}) {
  final normalizedRegular =
      regularHarga != null && regularHarga > 0 ? regularHarga : null;
  if (!usesManualArmada) return normalizedRegular;
  if (isGabunganReportOnlyIncomeRoute(
    pickup: pickup,
    destination: destination,
  )) {
    return normalizedRegular;
  }

  final gabunganHarga = resolveGabunganHargaPerKg(
    rules: gabunganRules,
    pickup: pickup,
    destination: destination,
  );
  return gabunganHarga > 0 ? gabunganHarga : normalizedRegular;
}

double resolveGabunganExpenseHargaPerKg({
  required double storedHarga,
  required String pickup,
  required String destination,
  List<Map<String, dynamic>> gabunganRules = const <Map<String, dynamic>>[],
}) {
  final gabunganHarga = resolveGabunganHargaPerKg(
    rules: gabunganRules,
    pickup: pickup,
    destination: destination,
  );
  if (gabunganHarga > 0) return gabunganHarga;
  return storedHarga > 0 ? storedHarga : 0;
}
