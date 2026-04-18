part of 'dashboard_page.dart';

class _InvoicePrintOverrides {
  const _InvoicePrintOverrides({
    required this.invoiceNumber,
    this.kopDate,
    this.kopLocation,
  });

  final String invoiceNumber;
  final String? kopDate;
  final String? kopLocation;
}

class _InvoicePrintGroup {
  const _InvoicePrintGroup({
    required this.id,
    required this.items,
  });

  final String id;
  final List<Map<String, dynamic>> items;

  Map<String, dynamic> get baseItem => items.first;
}

class _FixedInvoiceBatch {
  const _FixedInvoiceBatch({
    required this.batchId,
    required this.invoiceIds,
    required this.invoiceNumber,
    required this.customerName,
    this.kopDate,
    this.kopLocation,
    this.status = 'Unpaid',
    this.paidAt,
    this.createdAt,
  });

  final String batchId;
  final List<String> invoiceIds;
  final String invoiceNumber;
  final String customerName;
  final String? kopDate;
  final String? kopLocation;
  final String status;
  final String? paidAt;
  final String? createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'batch_id': batchId,
        'invoice_ids': invoiceIds,
        'invoice_number': (() {
          final normalized = Formatters.invoiceNumber(
            invoiceNumber,
            kopDate ?? createdAt,
            customerName: customerName,
          );
          return normalized == '-' ? invoiceNumber : normalized;
        })(),
        'customer_name': customerName,
        'kop_date': kopDate,
        'kop_location': kopLocation,
        'status': status,
        'paid_at': paidAt,
        'created_at': createdAt,
      };

  static _FixedInvoiceBatch? fromJson(Map<String, dynamic> map) {
    final batchId = '${map['batch_id'] ?? ''}'.trim();
    final customerName = '${map['customer_name'] ?? ''}'.trim();
    final kopDate = '${map['kop_date'] ?? ''}'.trim();
    final createdAt = '${map['created_at'] ?? ''}'.trim();
    final rawInvoiceNumber = '${map['invoice_number'] ?? ''}'.trim();
    final status = '${map['status'] ?? 'Unpaid'}'.trim();
    final paidAt = '${map['paid_at'] ?? ''}'.trim();
    final normalizedInvoiceNumber = rawInvoiceNumber.isEmpty
        ? rawInvoiceNumber
        : (() {
            final normalized = Formatters.invoiceNumber(
              rawInvoiceNumber,
              kopDate.isEmpty ? createdAt : kopDate,
              customerName: customerName,
            );
            return normalized == '-' ? rawInvoiceNumber : normalized;
          })();
    final invoiceIds = (map['invoice_ids'] as List<dynamic>? ?? const [])
        .map((id) => '$id'.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (batchId.isEmpty || invoiceIds.isEmpty) return null;
    return _FixedInvoiceBatch(
      batchId: batchId,
      invoiceIds: invoiceIds,
      invoiceNumber: normalizedInvoiceNumber,
      customerName: customerName,
      kopDate: kopDate,
      kopLocation: '${map['kop_location'] ?? ''}'.trim(),
      status: status.isEmpty ? 'Unpaid' : status,
      paidAt: paidAt.isEmpty ? null : paidAt,
      createdAt: createdAt,
    );
  }
}

String _resolveInvoiceEntityShared({
  dynamic invoiceEntity,
  dynamic invoiceNumber,
  dynamic customerName,
  bool fallback = true,
}) {
  final explicitEntity = '${invoiceEntity ?? ''}'.trim();
  final entityFromNumber = Formatters.invoiceEntityFromInvoiceNumber(
      '${invoiceNumber ?? ''}'.trim());
  return Formatters.normalizeInvoiceEntity(
    explicitEntity.isNotEmpty ? explicitEntity : entityFromNumber,
    invoiceNumber: invoiceNumber,
    customerName: customerName,
    isCompany: fallback,
  );
}

bool _resolveIsCompanyInvoiceShared({
  dynamic invoiceEntity,
  dynamic invoiceNumber,
  dynamic customerName,
  bool fallback = true,
}) {
  final entity = _resolveInvoiceEntityShared(
    invoiceEntity: invoiceEntity,
    invoiceNumber: invoiceNumber,
    customerName: customerName,
    fallback: fallback,
  );
  return Formatters.isCompanyInvoiceEntity(entity);
}

String _resolveInvoiceEntityLabelShared({
  dynamic invoiceEntity,
  dynamic invoiceNumber,
  dynamic customerName,
}) {
  final entity = _resolveInvoiceEntityShared(
    invoiceEntity: invoiceEntity,
    invoiceNumber: invoiceNumber,
    customerName: customerName,
  );
  return Formatters.invoiceEntityLabel(entity);
}

Color _resolveInvoiceEntityAccentColorShared({
  dynamic invoiceEntity,
  dynamic invoiceNumber,
  dynamic customerName,
}) {
  final entity = _resolveInvoiceEntityShared(
    invoiceEntity: invoiceEntity,
    invoiceNumber: invoiceNumber,
    customerName: customerName,
  );
  return AppColors.invoiceEntityAccent(entity);
}

String _displayInvoiceNumberShared(String number) {
  return number.trim().isEmpty ? '-' : number.trim();
}

String _normalizeIncomeRuleTextShared(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _incomeLocationKeyMatchesShared(String inputKey, String ruleKey) {
  if (inputKey.isEmpty || ruleKey.isEmpty) return false;
  if (inputKey == ruleKey) return true;

  final inputCompact = inputKey.replaceAll(' ', '');
  final ruleCompact = ruleKey.replaceAll(' ', '');
  if (inputCompact.isNotEmpty && inputCompact == ruleCompact) return true;

  final inputList = inputKey
      .split(' ')
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  final ruleList = ruleKey
      .split(' ')
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  if (inputList.contains(ruleKey) || ruleList.contains(inputKey)) {
    return true;
  }
  if (ruleList.length == 1 && ruleList.first.length >= 2) {
    return inputList.contains(ruleList.first);
  }
  if (inputList.length == 1 && inputList.first.length >= 2) {
    return ruleList.contains(inputList.first);
  }

  if (inputList.length < 2 || ruleList.isEmpty) return false;
  final shorter = inputList.length <= ruleList.length ? inputList : ruleList;
  final longer = inputList.length <= ruleList.length ? ruleList : inputList;
  return shorter.length >= 2 &&
      shorter.every((token) => longer.contains(token));
}

bool _incomeCustomerKeyMatchesShared(String customerName, String ruleCustomer) {
  final inputKey = _normalizeIncomeRuleTextShared(customerName);
  final ruleKey = _normalizeIncomeRuleTextShared(ruleCustomer);
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

bool _isTolakanCargoShared(String value) {
  return _normalizeIncomeRuleTextShared(value).contains('tolakan');
}

String _formatEditableNumberShared(dynamic value) {
  final number = _toNum(value);
  if (number == 0) return '';
  if ((number - number.roundToDouble()).abs() < 0.000001) {
    return number.round().toString();
  }
  return number
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

double _resolveInvoiceDetailSubtotalShared(Map<String, dynamic> row) {
  final explicit = _toNum(row['subtotal'] ?? row['total'] ?? row['jumlah']);
  if (explicit > 0) return explicit;
  return _toNum(row['tonase']) * _toNum(row['harga']);
}

Map<String, dynamic>? _resolveHargaRuleShared({
  required List<Map<String, dynamic>> rules,
  required String customerName,
  required String lokasiMuat,
  required String lokasiBongkar,
}) {
  if (rules.isEmpty) return null;
  final bongkarKey = _normalizeIncomeRuleTextShared(lokasiBongkar);
  if (bongkarKey.isEmpty) return null;
  final muatKey = _normalizeIncomeRuleTextShared(lokasiMuat);
  final customerKey = _normalizeIncomeRuleTextShared(customerName);

  int specificityScore(String value) {
    if (value.isEmpty) return 0;
    final tokenCount = value.split(' ').where((part) => part.isNotEmpty).length;
    return (tokenCount * 100) + value.length;
  }

  int customerScore(String ruleCustomerKey) {
    if (ruleCustomerKey.isEmpty) return 100;
    if (!_incomeCustomerKeyMatchesShared(customerKey, ruleCustomerKey)) {
      return -1;
    }
    if (customerKey == ruleCustomerKey) {
      return 5000 + specificityScore(ruleCustomerKey);
    }
    return 4200 + specificityScore(ruleCustomerKey);
  }

  int lokasiScore(String inputKey, String ruleKey) {
    if (ruleKey.isEmpty) return 120;
    if (inputKey.isEmpty) return 0;
    if (!_incomeLocationKeyMatchesShared(inputKey, ruleKey)) return 0;
    final inputCompact = inputKey.replaceAll(' ', '');
    final ruleCompact = ruleKey.replaceAll(' ', '');
    if (inputKey == ruleKey || inputCompact == ruleCompact) {
      return 1500 + specificityScore(ruleKey);
    }
    return 900 + specificityScore(ruleKey);
  }

  Map<String, dynamic>? bestRule;
  var bestScore = -1;
  for (final rule in rules) {
    final ruleBongkarKey =
        _normalizeIncomeRuleTextShared('${rule['lokasi_bongkar'] ?? ''}');
    if (!_incomeLocationKeyMatchesShared(bongkarKey, ruleBongkarKey)) {
      continue;
    }

    final ruleCustomerKey =
        _normalizeIncomeRuleTextShared('${rule['customer_name'] ?? ''}');
    final currentCustomerScore = customerScore(ruleCustomerKey);
    if (currentCustomerScore < 0) continue;

    final ruleMuatKey =
        _normalizeIncomeRuleTextShared('${rule['lokasi_muat'] ?? ''}');
    if (muatKey.isNotEmpty &&
        ruleMuatKey.isNotEmpty &&
        !_incomeLocationKeyMatchesShared(muatKey, ruleMuatKey)) {
      continue;
    }

    final priority = int.tryParse('${rule['priority'] ?? ''}') ??
        _toNum(rule['priority']).toInt();
    final totalScore = currentCustomerScore +
        lokasiScore(muatKey, ruleMuatKey) +
        lokasiScore(bongkarKey, ruleBongkarKey) +
        priority;

    if (totalScore > bestScore) {
      bestScore = totalScore;
      bestRule = rule;
    }
  }
  return bestRule;
}

double? _resolveHargaPerTonValueShared(
  Map<String, dynamic>? rule, {
  required String muatan,
}) {
  if (rule == null) return null;
  final base = _toNum(rule['harga_per_ton'] ?? rule['harga']);
  if (base <= 0) return null;
  return _isTolakanCargoShared(muatan) ? base / 2 : base;
}

double? _resolveHargaFlatTotalShared(
  Map<String, dynamic>? rule, {
  required String muatan,
}) {
  if (rule == null) return null;
  final base = _toNum(rule['flat_total'] ?? rule['subtotal'] ?? rule['total']);
  if (base <= 0) return null;
  return _isTolakanCargoShared(muatan) ? base / 2 : base;
}
