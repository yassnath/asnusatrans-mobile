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
    this.paymentDetails = const <_FixedInvoicePaymentEntry>[],
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
  final List<_FixedInvoicePaymentEntry> paymentDetails;

  _FixedInvoiceBatch copyWith({
    String? batchId,
    List<String>? invoiceIds,
    String? invoiceNumber,
    String? customerName,
    String? kopDate,
    String? kopLocation,
    String? status,
    String? paidAt,
    String? createdAt,
    List<_FixedInvoicePaymentEntry>? paymentDetails,
  }) {
    return _FixedInvoiceBatch(
      batchId: batchId ?? this.batchId,
      invoiceIds: invoiceIds ?? this.invoiceIds,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerName: customerName ?? this.customerName,
      kopDate: kopDate ?? this.kopDate,
      kopLocation: kopLocation ?? this.kopLocation,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
      paymentDetails: paymentDetails ?? this.paymentDetails,
    );
  }

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
        'payment_details':
            paymentDetails.map((entry) => entry.toJson()).toList(),
      };

  static _FixedInvoiceBatch? fromJson(Map<String, dynamic> map) {
    final batchId = '${map['batch_id'] ?? ''}'.trim();
    final customerName = '${map['customer_name'] ?? ''}'.trim();
    final kopDate = '${map['kop_date'] ?? ''}'.trim();
    final createdAt = '${map['created_at'] ?? ''}'.trim();
    final rawInvoiceNumber = '${map['invoice_number'] ?? ''}'.trim();
    final status = '${map['status'] ?? 'Unpaid'}'.trim();
    final paidAt = '${map['paid_at'] ?? ''}'.trim();
    final paymentDetails = _toFixedInvoicePaymentEntryList(
      map['payment_details'],
    );
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
      paymentDetails: paymentDetails,
    );
  }
}

class _FixedInvoicePaymentEntry {
  const _FixedInvoicePaymentEntry({
    required this.detailKey,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.routeLabel,
    required this.departureDate,
    required this.plate,
    required this.total,
    this.paid = false,
    this.paidAt,
  });

  final String detailKey;
  final String invoiceId;
  final String invoiceNumber;
  final String routeLabel;
  final String departureDate;
  final String plate;
  final double total;
  final bool paid;
  final String? paidAt;

  _FixedInvoicePaymentEntry copyWith({
    String? detailKey,
    String? invoiceId,
    String? invoiceNumber,
    String? routeLabel,
    String? departureDate,
    String? plate,
    double? total,
    bool? paid,
    String? paidAt,
  }) {
    return _FixedInvoicePaymentEntry(
      detailKey: detailKey ?? this.detailKey,
      invoiceId: invoiceId ?? this.invoiceId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      routeLabel: routeLabel ?? this.routeLabel,
      departureDate: departureDate ?? this.departureDate,
      plate: plate ?? this.plate,
      total: total ?? this.total,
      paid: paid ?? this.paid,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'detail_key': detailKey,
        'invoice_id': invoiceId,
        'invoice_number': invoiceNumber,
        'route_label': routeLabel,
        'departure_date': departureDate,
        'plate': plate,
        'total': total,
        'paid': paid,
        'paid_at': paidAt,
      };

  static _FixedInvoicePaymentEntry? fromJson(Map<String, dynamic> map) {
    final detailKey = '${map['detail_key'] ?? ''}'.trim();
    if (detailKey.isEmpty) return null;
    return _FixedInvoicePaymentEntry(
      detailKey: detailKey,
      invoiceId: '${map['invoice_id'] ?? ''}'.trim(),
      invoiceNumber: '${map['invoice_number'] ?? ''}'.trim(),
      routeLabel: '${map['route_label'] ?? ''}'.trim(),
      departureDate: '${map['departure_date'] ?? ''}'.trim(),
      plate: '${map['plate'] ?? ''}'.trim(),
      total: _fixedInvoicePaymentNum(map['total']),
      paid: map['paid'] == true,
      paidAt: '${map['paid_at'] ?? ''}'.trim().isEmpty
          ? null
          : '${map['paid_at'] ?? ''}'.trim(),
    );
  }
}

class _FixedInvoicePaymentSummary {
  const _FixedInvoicePaymentSummary({
    required this.entries,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    required this.allPaid,
    required this.anyPaid,
    this.paidAt,
  });

  final List<_FixedInvoicePaymentEntry> entries;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String status;
  final bool allPaid;
  final bool anyPaid;
  final String? paidAt;
}

double _fixedInvoicePaymentNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  var cleaned = value.toString().replaceAll(RegExp(r'[^0-9,.-]'), '');
  final dotCount = '.'.allMatches(cleaned).length;
  final hasComma = cleaned.contains(',');
  if (hasComma && dotCount >= 1) {
    cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
  } else if (!hasComma && dotCount > 1) {
    cleaned = cleaned.replaceAll('.', '');
  } else if (hasComma) {
    cleaned = cleaned.replaceAll(',', '.');
  }
  return double.tryParse(cleaned) ?? 0;
}

List<Map<String, dynamic>> _fixedInvoiceMapList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
  return const <Map<String, dynamic>>[];
}

List<_FixedInvoicePaymentEntry> _toFixedInvoicePaymentEntryList(dynamic value) {
  if (value is! List) return const <_FixedInvoicePaymentEntry>[];
  return value
      .whereType<Map>()
      .map((item) => _FixedInvoicePaymentEntry.fromJson(
            Map<String, dynamic>.from(item),
          ))
      .whereType<_FixedInvoicePaymentEntry>()
      .toList(growable: false);
}

String _fixedInvoicePaymentDateOnly(dynamic value) {
  final date = Formatters.parseDate(value);
  if (date == null) return '';
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '${date.year}-$mm-$dd';
}

String _fixedInvoicePaymentDetailKey({
  required String invoiceId,
  required int detailIndex,
}) {
  final cleanedInvoiceId = invoiceId.trim();
  return '$cleanedInvoiceId#$detailIndex';
}

String _fixedInvoicePaymentExtractPlate(Map<String, dynamic> row) {
  final direct =
      '${row['plat_nomor'] ?? row['no_polisi'] ?? ''}'.toUpperCase().trim();
  if (direct.isNotEmpty && direct != '-') return direct;

  for (final key in const ['armada_manual', 'armada_label', 'armada']) {
    final value = '${row[key] ?? ''}'.trim();
    if (value.isEmpty) continue;
    final match = RegExp(
      r'\b[A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{1,3}\b',
    ).firstMatch(value.toUpperCase());
    if (match != null) {
      final plate = (match.group(0) ?? '').trim();
      if (plate.isNotEmpty) return plate;
    }
    if (key == 'armada_manual') return value;
  }
  return '-';
}

String _fixedInvoicePaymentLocationLabel(dynamic value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? '-' : text;
}

double _fixedInvoicePaymentDetailSubtotal(
  Map<String, dynamic> row,
  Map<String, dynamic> invoice,
  int detailCount,
) {
  for (final key in const ['subtotal', 'total', 'total_biaya', 'jumlah']) {
    final value = _fixedInvoicePaymentNum(row[key]);
    if (value > 0) return value;
  }
  final tonase = _fixedInvoicePaymentNum(row['tonase'] ?? invoice['tonase']);
  final harga = _fixedInvoicePaymentNum(row['harga'] ?? invoice['harga']);
  final computed = tonase * harga;
  if (computed > 0) return computed;
  final fallback = _fixedInvoicePaymentNum(
    invoice['total_bayar'] ?? invoice['total_biaya'],
  );
  if (fallback <= 0) return 0;
  if (detailCount <= 1) return fallback;
  return fallback / detailCount;
}

List<_FixedInvoicePaymentEntry> _buildFixedInvoicePaymentEntries({
  _FixedInvoiceBatch? batch,
  required List<Map<String, dynamic>> sourceInvoices,
}) {
  final storedByKey = <String, _FixedInvoicePaymentEntry>{
    for (final entry in batch?.paymentDetails ?? const <_FixedInvoicePaymentEntry>[])
      entry.detailKey: entry,
  };
  final fallbackPaidAt = (batch?.paidAt ?? '').trim();
  final statusLower = (batch?.status ?? '').trim().toLowerCase();
  final markAllPaidByBatch =
      fallbackPaidAt.isNotEmpty || (statusLower == 'paid');
  final entries = <_FixedInvoicePaymentEntry>[];

  for (final invoice in sourceInvoices) {
    final invoiceId = '${invoice['id'] ?? ''}'.trim();
    final invoiceNumber = Formatters.invoiceNumber(
      invoice['no_invoice'],
      invoice['tanggal_kop'] ?? invoice['tanggal'],
      customerName: invoice['nama_pelanggan'],
    );
    final detailRows = _fixedInvoiceMapList(invoice['rincian']);
    final effectiveRows = detailRows.isNotEmpty
        ? detailRows
        : <Map<String, dynamic>>[
            <String, dynamic>{
              'armada_start_date':
                  invoice['armada_start_date'] ?? invoice['tanggal'],
              'tanggal': invoice['tanggal'],
              'plat_nomor': invoice['plat_nomor'] ?? invoice['no_polisi'],
              'no_polisi': invoice['no_polisi'] ?? invoice['plat_nomor'],
              'armada_manual': invoice['armada_manual'],
              'armada_label': invoice['armada_label'] ?? invoice['armada'],
              'nama_supir': invoice['nama_supir'] ?? invoice['supir'],
              'muatan': invoice['muatan'],
              'lokasi_muat': invoice['lokasi_muat'],
              'lokasi_bongkar': invoice['lokasi_bongkar'],
              'tonase': invoice['tonase'],
              'harga': invoice['harga'],
              'subtotal': invoice['subtotal'] ?? invoice['total_biaya'],
            }
          ];

    for (var index = 0; index < effectiveRows.length; index++) {
      final row = effectiveRows[index];
      final detailKey = _fixedInvoicePaymentDetailKey(
        invoiceId: invoiceId.isEmpty ? invoiceNumber : invoiceId,
        detailIndex: index,
      );
      final stored = storedByKey[detailKey];
      final departureDate = _fixedInvoicePaymentDateOnly(
        row['armada_start_date'] ?? row['tanggal'] ?? invoice['tanggal'],
      );
      final routeLabel =
          '${_fixedInvoicePaymentLocationLabel(row['lokasi_muat'] ?? invoice['lokasi_muat'])}-${_fixedInvoicePaymentLocationLabel(row['lokasi_bongkar'] ?? invoice['lokasi_bongkar'])}';
      final total = _fixedInvoicePaymentDetailSubtotal(
        row,
        invoice,
        effectiveRows.length,
      );
      final paid = stored?.paid == true || (stored == null && markAllPaidByBatch);
      final paidAt = (stored?.paidAt ?? '').trim().isNotEmpty
          ? stored!.paidAt
          : (markAllPaidByBatch ? fallbackPaidAt : null);
      entries.add(
        _FixedInvoicePaymentEntry(
          detailKey: detailKey,
          invoiceId: invoiceId,
          invoiceNumber: invoiceNumber,
          routeLabel: routeLabel,
          departureDate: departureDate,
          plate: _fixedInvoicePaymentExtractPlate(row),
          total: total,
          paid: paid,
          paidAt: paidAt,
        ),
      );
    }
  }

  entries.sort((a, b) {
    final aDate = Formatters.parseDate(a.departureDate) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = Formatters.parseDate(b.departureDate) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final byDate = aDate.compareTo(bDate);
    if (byDate != 0) return byDate;
    final byInvoice = a.invoiceNumber.compareTo(b.invoiceNumber);
    if (byInvoice != 0) return byInvoice;
    return a.detailKey.compareTo(b.detailKey);
  });
  return entries;
}

_FixedInvoicePaymentSummary _summarizeFixedInvoicePayments({
  _FixedInvoiceBatch? batch,
  required List<Map<String, dynamic>> sourceInvoices,
}) {
  final entries = _buildFixedInvoicePaymentEntries(
    batch: batch,
    sourceInvoices: sourceInvoices,
  );
  final totalAmount =
      entries.fold<double>(0, (sum, entry) => sum + entry.total);
  final paidAmount = entries
      .where((entry) => entry.paid)
      .fold<double>(0, (sum, entry) => sum + entry.total);
  final remainingAmount = max(0.0, totalAmount - paidAmount);
  final anyPaid = entries.any((entry) => entry.paid);
  final allPaid = entries.isNotEmpty && entries.every((entry) => entry.paid);
  final explicitStatus = (batch?.status ?? '').trim().toLowerCase();
  final paidAtCandidates = entries
      .map((entry) => _fixedInvoicePaymentDateOnly(entry.paidAt))
      .where((value) => value.isNotEmpty)
      .toList(growable: false)
    ..sort();
  final paidAt = allPaid
      ? (paidAtCandidates.isNotEmpty
          ? paidAtCandidates.last
          : ((batch?.paidAt ?? '').trim().isEmpty ? null : batch!.paidAt))
      : null;
  final status = allPaid
      ? 'Paid'
      : anyPaid
          ? 'Partial'
          : explicitStatus.contains('partial')
              ? 'Partial'
              : (explicitStatus == 'paid' && entries.isEmpty
                  ? 'Paid'
                  : 'Unpaid');
  return _FixedInvoicePaymentSummary(
    entries: entries,
    totalAmount: totalAmount,
    paidAmount: paidAmount,
    remainingAmount: remainingAmount,
    status: status,
    allPaid: allPaid,
    anyPaid: anyPaid,
    paidAt: paidAt,
  );
}

List<_FixedInvoiceBatch> _mergeFixedInvoiceBatchesWithLocalFallback({
  required List<_FixedInvoiceBatch> remoteBatches,
  required List<_FixedInvoiceBatch> localBatches,
}) {
  if (remoteBatches.isEmpty) return localBatches;
  if (localBatches.isEmpty) return remoteBatches;
  final localById = <String, _FixedInvoiceBatch>{
    for (final batch in localBatches) batch.batchId: batch,
  };
  final merged = remoteBatches.map((remote) {
    final local = localById[remote.batchId];
    if (local == null) return remote;
    final paymentDetails = remote.paymentDetails.isNotEmpty
        ? remote.paymentDetails
        : local.paymentDetails;
    return remote.copyWith(
      paymentDetails: paymentDetails,
      paidAt: (remote.paidAt ?? '').trim().isNotEmpty ? remote.paidAt : local.paidAt,
      status: remote.status.trim().isNotEmpty ? remote.status : local.status,
    );
  }).toList(growable: true);
  final remoteIds = remoteBatches.map((batch) => batch.batchId).toSet();
  merged.addAll(
    localBatches.where((batch) => !remoteIds.contains(batch.batchId)),
  );
  return merged;
}

List<_FixedInvoiceBatch> _buildLegacyFixedInvoiceBatchesFromInvoices({
  required List<Map<String, dynamic>> invoices,
  required Set<String> fixedIds,
  Iterable<_FixedInvoiceBatch> existingBatches = const <_FixedInvoiceBatch>[],
}) {
  if (fixedIds.isEmpty || invoices.isEmpty) return const <_FixedInvoiceBatch>[];
  final consumedInvoiceIds = existingBatches
      .expand((batch) => batch.invoiceIds)
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  final result = <_FixedInvoiceBatch>[];
  for (final invoice in invoices) {
    final invoiceId = '${invoice['id'] ?? ''}'.trim();
    if (invoiceId.isEmpty ||
        !fixedIds.contains(invoiceId) ||
        consumedInvoiceIds.contains(invoiceId)) {
      continue;
    }
    final rawInvoiceNumber = '${invoice['no_invoice'] ?? ''}'.trim();
    final kopDate = '${invoice['tanggal_kop'] ?? invoice['tanggal'] ?? ''}'.trim();
    final customerName = '${invoice['nama_pelanggan'] ?? ''}'.trim();
    final normalizedInvoiceNumber = rawInvoiceNumber.isEmpty
        ? rawInvoiceNumber
        : (() {
            final normalized = Formatters.invoiceNumber(
              rawInvoiceNumber,
              kopDate,
              customerName: customerName,
            );
            return normalized == '-' ? rawInvoiceNumber : normalized;
          })();
    result.add(
      _FixedInvoiceBatch(
        batchId: 'legacy_$invoiceId',
        invoiceIds: <String>[invoiceId],
        invoiceNumber: normalizedInvoiceNumber,
        customerName: customerName,
        kopDate: kopDate.isEmpty ? null : kopDate,
        kopLocation: '${invoice['lokasi_kop'] ?? ''}'.trim().isEmpty
            ? null
            : '${invoice['lokasi_kop'] ?? ''}'.trim(),
        status: '${invoice['status'] ?? 'Unpaid'}'.trim().isEmpty
            ? 'Unpaid'
            : '${invoice['status'] ?? 'Unpaid'}'.trim(),
        paidAt: '${invoice['paid_at'] ?? ''}'.trim().isEmpty
            ? null
            : '${invoice['paid_at'] ?? ''}'.trim(),
        createdAt: '${invoice['created_at'] ?? ''}'.trim().isEmpty
            ? DateTime.now().toIso8601String()
            : '${invoice['created_at'] ?? ''}'.trim(),
      ),
    );
  }
  return result;
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
  final bongkarKey = _normalizeIncomeRuleTextShared(lokasiBongkar);
  if (bongkarKey.isEmpty) return null;
  final muatKey = _normalizeIncomeRuleTextShared(lokasiMuat);
  final customerKey = _normalizeIncomeRuleTextShared(customerName);
  final builtInRule = resolveBuiltInIncomePricingRule(
    customerName: customerName,
    pickup: lokasiMuat,
    destination: lokasiBongkar,
  );
  if (rules.isEmpty) return builtInRule;

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
  return bestRule ?? builtInRule;
}

double? _resolveHargaPerTonValueShared(
  Map<String, dynamic>? rule, {
  required String muatan,
}) {
  if (rule == null) return null;
  return resolveTolakanAdjustedPositiveValue(
    rule['harga_per_ton'] ?? rule['harga'],
    cargo: muatan,
  );
}

double? _resolveHargaFlatTotalShared(
  Map<String, dynamic>? rule, {
  required String muatan,
}) {
  if (rule == null) return null;
  return resolveTolakanAdjustedPositiveValue(
    rule['flat_total'] ?? rule['subtotal'] ?? rule['total'],
    cargo: muatan,
  );
}
