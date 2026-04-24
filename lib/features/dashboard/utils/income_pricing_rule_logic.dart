String normalizeIncomePricingRuleKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool isOngkosKuliCargo(String value) {
  return normalizeIncomePricingRuleKey(value) == 'ongkos kuli';
}

bool incomePricingLocationKeyMatches(String inputKey, String ruleKey) {
  if (inputKey.isEmpty || ruleKey.isEmpty) return false;
  if (inputKey == ruleKey) return true;

  final inputCompact = inputKey.replaceAll(' ', '');
  final ruleCompact = ruleKey.replaceAll(' ', '');
  if (inputCompact.isNotEmpty && inputCompact == ruleCompact) return true;

  final inputTokens = inputKey
      .split(' ')
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  final ruleTokens = ruleKey
      .split(' ')
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  if (inputTokens.contains(ruleKey) || ruleTokens.contains(inputKey)) {
    return true;
  }
  if (ruleTokens.length == 1 && ruleTokens.first.length >= 2) {
    return inputTokens.contains(ruleTokens.first);
  }
  if (inputTokens.length == 1 && inputTokens.first.length >= 2) {
    return ruleTokens.contains(inputTokens.first);
  }

  if (inputTokens.length < 2 || ruleTokens.isEmpty) return false;
  final shorter =
      inputTokens.length <= ruleTokens.length ? inputTokens : ruleTokens;
  final longer =
      inputTokens.length <= ruleTokens.length ? ruleTokens : inputTokens;
  return shorter.length >= 2 &&
      shorter.every((token) => longer.contains(token));
}

bool incomePricingCustomerNameMatches(
    String customerName, String ruleCustomer) {
  final inputKey = normalizeIncomePricingRuleKey(customerName);
  final ruleKey = normalizeIncomePricingRuleKey(ruleCustomer);
  if (ruleKey.isEmpty) return true;
  if (inputKey.isEmpty) return false;
  if (inputKey == ruleKey) return true;
  if (inputKey.contains(ruleKey) || ruleKey.contains(inputKey)) {
    return true;
  }

  final inputTokens = inputKey
      .split(' ')
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  final ruleTokens = ruleKey
      .split(' ')
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (inputTokens.isEmpty || ruleTokens.isEmpty) return false;
  return ruleTokens.every(inputTokens.contains);
}

Map<String, dynamic>? resolveBuiltInIncomePricingRule({
  required String customerName,
  required String pickup,
  required String destination,
}) {
  final customerKey = normalizeIncomePricingRuleKey(customerName);
  final pickupKey = normalizeIncomePricingRuleKey(pickup);
  final destinationKey = normalizeIncomePricingRuleKey(destination);

  if (incomePricingCustomerNameMatches(customerKey, 'giono') &&
      incomePricingLocationKeyMatches(pickupKey, 'nganjuk') &&
      incomePricingLocationKeyMatches(destinationKey, 'driyo')) {
    return <String, dynamic>{
      'customer_name': 'Giono',
      'lokasi_muat': 'Nganjuk',
      'lokasi_bongkar': 'Driyo',
      'harga_per_ton': 0.0,
      'flat_total': 1600000.0,
      'priority': 250,
      'is_active': true,
    };
  }

  if (incomePricingCustomerNameMatches(customerKey, 'hasan') &&
      incomePricingLocationKeyMatches(pickupKey, 't langon') &&
      incomePricingLocationKeyMatches(destinationKey, 't langon')) {
    return <String, dynamic>{
      'customer_name': 'Hasan',
      'lokasi_muat': 'T. Langon',
      'lokasi_bongkar': 'T. Langon',
      'harga_per_ton': 0.0,
      'flat_total': 200000.0,
      'priority': 260,
      'is_active': true,
    };
  }

  if (incomePricingCustomerNameMatches(customerKey, 'unergi') &&
      incomePricingLocationKeyMatches(destinationKey, 'royal')) {
    return <String, dynamic>{
      'customer_name': 'Unergi',
      'lokasi_muat': null,
      'lokasi_bongkar': 'Royal',
      'harga_per_ton': 43.0,
      'flat_total': null,
      'priority': 210,
      'is_active': true,
    };
  }

  if (incomePricingLocationKeyMatches(pickupKey, 't langon') &&
      incomePricingLocationKeyMatches(destinationKey, 'sarana')) {
    return <String, dynamic>{
      'customer_name': null,
      'lokasi_muat': 'T. Langon',
      'lokasi_bongkar': 'Sarana',
      'harga_per_ton': 110.0,
      'flat_total': null,
      'priority': 105,
      'is_active': true,
    };
  }

  if (incomePricingLocationKeyMatches(pickupKey, 'betoyo') &&
      incomePricingLocationKeyMatches(destinationKey, 'muncar')) {
    return <String, dynamic>{
      'customer_name': null,
      'lokasi_muat': 'Betoyo',
      'lokasi_bongkar': 'Muncar',
      'harga_per_ton': 193.0,
      'flat_total': null,
      'priority': 110,
      'is_active': true,
    };
  }

  if (incomePricingLocationKeyMatches(destinationKey, 'gempol')) {
    return <String, dynamic>{
      'customer_name': null,
      'lokasi_muat': null,
      'lokasi_bongkar': 'Gempol',
      'harga_per_ton': 55.0,
      'flat_total': null,
      'priority': 100,
      'is_active': true,
    };
  }

  return null;
}
