import 'tolakan_logic.dart';

String normalizeIncomePricingRuleKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool incomePricingIsBetoyoLocationKey(String value) {
  final key = normalizeIncomePricingRuleKey(value);
  return key == 'betoyo' || key.replaceAll(' ', '') == 'betoyo';
}

bool incomePricingIsNonBetoyoPickupRuleKey(String value) {
  final key = normalizeIncomePricingRuleKey(value);
  final compact = key.replaceAll(' ', '');
  return key == 'selain betoyo' ||
      key == 'non betoyo' ||
      compact == 'selainbetoyo' ||
      compact == 'nonbetoyo';
}

bool isOngkosKuliCargo(String value) {
  return normalizeIncomePricingRuleKey(value) == 'ongkos kuli';
}

bool isForcedBatangIncomePricingRule(Map<String, dynamic>? rule) {
  if (rule == null) return false;
  return incomePricingLocationKeyMatches(
    normalizeIncomePricingRuleKey('${rule['lokasi_bongkar'] ?? ''}'),
    normalizeIncomePricingRuleKey('batang'),
  );
}

bool incomePricingLocationKeyMatches(String inputKey, String ruleKey) {
  if (inputKey.isEmpty || ruleKey.isEmpty) return false;
  if (incomePricingIsNonBetoyoPickupRuleKey(ruleKey)) {
    return !incomePricingIsBetoyoLocationKey(inputKey);
  }
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
  final pickupIsBetoyo = incomePricingIsBetoyoLocationKey(pickupKey);

  Map<String, dynamic>? betoyoDerivedRule({
    required String lokasiBongkar,
    required double baseHarga,
    String? ruleCustomerName,
    double? flatTotal,
    int priority = 130,
    double priceOffset = 7,
  }) {
    if (!pickupIsBetoyo) return null;
    if (incomePricingLocationKeyMatches(destinationKey, 'muncar')) return null;
    if (!incomePricingLocationKeyMatches(
      destinationKey,
      normalizeIncomePricingRuleKey(lokasiBongkar),
    )) {
      return null;
    }
    return <String, dynamic>{
      'customer_name': ruleCustomerName,
      'lokasi_muat': 'Betoyo',
      'lokasi_bongkar': lokasiBongkar,
      'harga_per_ton': baseHarga + priceOffset,
      'flat_total': flatTotal,
      'priority': priority,
      'is_active': true,
    };
  }

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

  final betoyoRoyalRule = incomePricingCustomerNameMatches(
    customerKey,
    'unergi',
  )
      ? betoyoDerivedRule(
          lokasiBongkar: 'Royal',
          baseHarga: 43.0,
          ruleCustomerName: 'Unergi',
          priority: 215,
        )
      : null;
  if (betoyoRoyalRule != null) return betoyoRoyalRule;

  final betoyoBatangRule = betoyoDerivedRule(
    lokasiBongkar: 'Batang',
    baseHarga: incomePricingCustomerNameMatches(customerKey, 'bornava')
        ? 225.0
        : 235.0,
    ruleCustomerName: incomePricingCustomerNameMatches(customerKey, 'bornava')
        ? 'Bornava'
        : null,
    priority:
        incomePricingCustomerNameMatches(customerKey, 'bornava') ? 225 : 125,
    priceOffset: 0,
  );
  if (betoyoBatangRule != null) return betoyoBatangRule;

  final betoyoRexRule = incomePricingCustomerNameMatches(customerKey, 'swadaya')
      ? betoyoDerivedRule(
          lokasiBongkar: 'Rex',
          baseHarga: 55.0,
          ruleCustomerName: 'Swadaya',
          flatTotal: 700000.0,
          priority: 140,
        )
      : null;
  if (betoyoRexRule != null) return betoyoRexRule;

  final betoyoGenericRules = <({String lokasiBongkar, double baseHarga})>[
    (lokasiBongkar: 'Pare', baseHarga: 80.0),
    (lokasiBongkar: 'Sudali', baseHarga: 58.0),
    (lokasiBongkar: 'MKP', baseHarga: 50.0),
    (lokasiBongkar: 'Bricon Mojo', baseHarga: 55.0),
    (lokasiBongkar: 'Sarana', baseHarga: 110.0),
    (lokasiBongkar: 'Surya Warna / Sukoharjo', baseHarga: 165.0),
    (lokasiBongkar: 'Gempol', baseHarga: 55.0),
    (lokasiBongkar: 'Bumindo', baseHarga: 55.0),
    (lokasiBongkar: 'Temanggung', baseHarga: 165.0),
    (lokasiBongkar: 'Danliris', baseHarga: 155.0),
    (lokasiBongkar: 'Minatex', baseHarga: 80.0),
    (lokasiBongkar: 'Jaskin', baseHarga: 168.0),
  ];
  for (final rule in betoyoGenericRules) {
    final betoyoRule = betoyoDerivedRule(
      lokasiBongkar: rule.lokasiBongkar,
      baseHarga: rule.baseHarga,
    );
    if (betoyoRule != null) return betoyoRule;
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

  if (incomePricingLocationKeyMatches(destinationKey, 'batang')) {
    final isBornava = incomePricingCustomerNameMatches(customerKey, 'bornava');
    return <String, dynamic>{
      'customer_name': isBornava ? 'Bornava' : null,
      'lokasi_muat': null,
      'lokasi_bongkar': 'Batang',
      'harga_per_ton': isBornava ? 225.0 : 235.0,
      'flat_total': null,
      'priority': isBornava ? 220 : 120,
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

  if (incomePricingCustomerNameMatches(customerKey, 'swadaya') &&
      incomePricingLocationKeyMatches(pickupKey, 't langon') &&
      incomePricingLocationKeyMatches(destinationKey, 'rex')) {
    return <String, dynamic>{
      'customer_name': 'Swadaya',
      'lokasi_muat': 'T. Langon',
      'lokasi_bongkar': 'Rex',
      'harga_per_ton': 55.0,
      'flat_total': 700000.0,
      'priority': 135,
      'is_active': true,
    };
  }

  if (incomePricingLocationKeyMatches(pickupKey, 't langon') &&
      incomePricingLocationKeyMatches(
        destinationKey,
        'surya warna sukoharjo',
      )) {
    return <String, dynamic>{
      'customer_name': null,
      'lokasi_muat': 'T. Langon',
      'lokasi_bongkar': 'Surya Warna / Sukoharjo',
      'harga_per_ton': 165.0,
      'flat_total': null,
      'priority': 125,
      'is_active': true,
    };
  }

  if (incomePricingLocationKeyMatches(pickupKey, 'betoyo') &&
      incomePricingLocationKeyMatches(destinationKey, 'muncar')) {
    return <String, dynamic>{
      'customer_name': null,
      'lokasi_muat': 'Betoyo',
      'lokasi_bongkar': 'Muncar',
      'harga_per_ton': 195.0,
      'flat_total': null,
      'priority': 110,
      'is_active': true,
    };
  }

  if (incomePricingCustomerNameMatches(customerKey, 'antok') &&
      incomePricingLocationKeyMatches(pickupKey, 'maspion') &&
      incomePricingLocationKeyMatches(destinationKey, 't langon')) {
    return <String, dynamic>{
      'customer_name': 'Antok',
      'lokasi_muat': 'Maspion',
      'lokasi_bongkar': 'T. Langon',
      'harga_per_ton': 21.0,
      'flat_total': null,
      'priority': 230,
      'is_active': true,
    };
  }

  if (incomePricingLocationKeyMatches(pickupKey, 'maspion') &&
      incomePricingLocationKeyMatches(destinationKey, 't langon')) {
    return <String, dynamic>{
      'customer_name': null,
      'lokasi_muat': 'Maspion',
      'lokasi_bongkar': 'T. Langon',
      'harga_per_ton': 26.0,
      'flat_total': null,
      'priority': 125,
      'is_active': true,
    };
  }

  if (!pickupIsBetoyo &&
      incomePricingLocationKeyMatches(destinationKey, 'gempol')) {
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

  if (!pickupIsBetoyo &&
      incomePricingLocationKeyMatches(destinationKey, 'bumindo')) {
    return <String, dynamic>{
      'customer_name': null,
      'lokasi_muat': null,
      'lokasi_bongkar': 'Bumindo',
      'harga_per_ton': 55.0,
      'flat_total': null,
      'priority': 120,
      'is_active': true,
    };
  }

  if (!pickupIsBetoyo &&
      incomePricingLocationKeyMatches(destinationKey, 'temanggung')) {
    return <String, dynamic>{
      'customer_name': null,
      'lokasi_muat': null,
      'lokasi_bongkar': 'Temanggung',
      'harga_per_ton': 165.0,
      'flat_total': null,
      'priority': 120,
      'is_active': true,
    };
  }

  if (!pickupIsBetoyo &&
      incomePricingLocationKeyMatches(destinationKey, 'danliris')) {
    return <String, dynamic>{
      'customer_name': null,
      'lokasi_muat': null,
      'lokasi_bongkar': 'Danliris',
      'harga_per_ton': 155.0,
      'flat_total': null,
      'priority': 120,
      'is_active': true,
    };
  }

  if (!pickupIsBetoyo &&
      incomePricingLocationKeyMatches(destinationKey, 'minatex')) {
    return <String, dynamic>{
      'customer_name': null,
      'lokasi_muat': null,
      'lokasi_bongkar': 'Minatex',
      'harga_per_ton': 80.0,
      'flat_total': null,
      'priority': 120,
      'is_active': true,
    };
  }

  if (!pickupIsBetoyo &&
      incomePricingLocationKeyMatches(destinationKey, 'jaskin')) {
    return <String, dynamic>{
      'customer_name': null,
      'lokasi_muat': null,
      'lokasi_bongkar': 'Jaskin',
      'harga_per_ton': 168.0,
      'flat_total': null,
      'priority': 120,
      'is_active': true,
    };
  }

  return null;
}

Map<String, dynamic>? resolveBuiltInIncomePricingRuleForCargo({
  required String customerName,
  required String pickup,
  required String destination,
  required String cargo,
}) {
  final directRule = resolveBuiltInIncomePricingRule(
    customerName: customerName,
    pickup: pickup,
    destination: destination,
  );
  if (!isTolakanCargo(cargo)) return directRule;

  final reverseRule = resolveBuiltInIncomePricingRule(
    customerName: customerName,
    pickup: destination,
    destination: pickup,
  );
  return reverseRule ?? directRule;
}
