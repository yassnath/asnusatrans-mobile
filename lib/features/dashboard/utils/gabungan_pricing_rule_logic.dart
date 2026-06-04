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
  if (key.contains('kendal')) return 'kendal';
  if (key.contains('kediri')) return 'kediri';
  if (key.contains('semarang')) return 'semarang';
  if (key.contains('kedawung') || key.contains('dawung')) return 'kedawung';
  if (key.contains('royal')) return 'royal';
  if (key.contains('pare')) return 'pare';
  if (key.contains('gempol')) return 'gempol';
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
    final isGenericMkpRule = ruleMuatKey.isEmpty &&
        incomePricingLocationKeyMatches(ruleBongkarKey, 'mkp') &&
        incomePricingLocationKeyMatches(destinationKey, 'mkp');
    if (isGenericMkpRule && incomePricingIsBetoyoLocationKey(pickupKey)) {
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
  if (pickupKey == 'betoyo' && destinationKey == 'bimoli') return 33;
  if (pickupKey == 'betoyo' && destinationKey == 'mkp') return 53;
  if (pickupKey == 'maspion' && destinationKey == 'langon') return 23;
  switch (destinationKey) {
    case 'bululawang':
      return 100;
    case 'kendal':
      return 170;
    case 'kediri':
      return 80;
    case 'semarang':
      return 158;
    case 'kedawung':
      return 40;
    case 'royal':
      return 40;
    case 'pare':
      return 78;
    case 'gempol':
      return 50;
    case 'mkp':
      if (pickupKey.isEmpty || incomePricingIsBetoyoLocationKey(pickupKey)) {
        return 0;
      }
      return 50;
    case 'kedamean':
      return 41;
    case 'temanggung':
      return 230;
    case 'kig':
      return 38;
    case 'sgm':
      return 40;
    case 'safelock':
      return 50;
    case 'rex_beji':
      return 53;
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
