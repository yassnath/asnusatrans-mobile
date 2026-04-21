import '../../../core/utils/formatters.dart';

dynamic resolveIncomeReportInvoiceDate(Map<String, dynamic> source) {
  for (final value in <dynamic>[
    source['tanggal_kop'],
    source['tanggal'],
    source['created_at'],
  ]) {
    if (value is DateTime) return value;
    final text = '$value'.trim();
    if (text.isNotEmpty) return value;
  }
  return null;
}

String buildIncomeReportInvoiceSortKey({
  required dynamic invoiceNumber,
  dynamic invoiceDate,
  dynamic customerName,
  dynamic invoiceEntity,
}) {
  final normalized = Formatters.invoiceNumber(
    invoiceNumber,
    invoiceDate,
    customerName: customerName,
    invoiceEntity: invoiceEntity,
  );
  if (normalized != '-') return normalized;
  final fallback = '${invoiceNumber ?? ''}'
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'\s+'), '');
  return fallback.isEmpty ? 'ZZZ' : fallback;
}

List<Map<String, dynamic>> sortIncomeReportRowsByInvoice(
  List<Map<String, dynamic>> rows,
) {
  final result = rows.toList();
  result.sort((a, b) {
    final aInvoice =
        '${a['__invoice_sort'] ?? a['__number'] ?? ''}'.trim().toUpperCase();
    final bInvoice =
        '${b['__invoice_sort'] ?? b['__number'] ?? ''}'.trim().toUpperCase();
    final byInvoice = aInvoice.compareTo(bInvoice);
    if (byInvoice != 0) return byInvoice;

    final aFixedDate =
        _toDate(a['__date']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bFixedDate =
        _toDate(b['__date']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final byFixedDate = aFixedDate.compareTo(bFixedDate);
    if (byFixedDate != 0) return byFixedDate;

    final aDepartureDate = _toDate(a['__departure_date']) ?? aFixedDate;
    final bDepartureDate = _toDate(b['__departure_date']) ?? bFixedDate;
    final byDepartureDate = aDepartureDate.compareTo(bDepartureDate);
    if (byDepartureDate != 0) return byDepartureDate;

    final aCustomer =
        '${a['__customer'] ?? a['__name'] ?? ''}'.trim().toLowerCase();
    final bCustomer =
        '${b['__customer'] ?? b['__name'] ?? ''}'.trim().toLowerCase();
    final byCustomer = aCustomer.compareTo(bCustomer);
    if (byCustomer != 0) return byCustomer;

    return '${a['__key'] ?? ''}'.compareTo('${b['__key'] ?? ''}');
  });
  return result;
}

List<Map<String, dynamic>> groupIncomeReportRowsByCustomer(
  List<Map<String, dynamic>> rows,
) {
  final groups = <String, _IncomeCustomerReportGroup>{};

  String normalizeKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  for (final row in rows) {
    if ('${row['__type']}' != 'Income') continue;
    final customerName = '${row['__customer'] ?? row['__name'] ?? '-'}'.trim();
    final key = normalizeKey(customerName.isEmpty ? '-' : customerName);
    final group = groups.putIfAbsent(
      key,
      () => _IncomeCustomerReportGroup(
        key: key,
        customerName: customerName.isEmpty ? '-' : customerName,
      ),
    );
    group.add(row);
  }

  final result = groups.values.map((group) => group.toRow()).toList();
  result.sort((a, b) {
    final aName =
        '${a['__customer'] ?? a['__name'] ?? ''}'.toLowerCase().trim();
    final bName =
        '${b['__customer'] ?? b['__name'] ?? ''}'.toLowerCase().trim();
    final byName = aName.compareTo(bName);
    if (byName != 0) return byName;
    final aDate =
        _toDate(a['__date']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate =
        _toDate(b['__date']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  });
  return result;
}

class _IncomeCustomerReportGroup {
  _IncomeCustomerReportGroup({
    required this.key,
    required this.customerName,
  });

  final String key;
  final String customerName;
  final Set<String> _statuses = <String>{};
  final Set<String> _tujuan = <String>{};
  double _jumlah = 0;
  double _pph = 0;
  double _total = 0;
  double _income = 0;
  int _itemCount = 0;
  dynamic _latestDateRaw;
  DateTime? _latestDate;

  void add(Map<String, dynamic> row) {
    _itemCount++;
    _jumlah += _toDouble(row['__jumlah']);
    _pph += _toDouble(row['__pph']);
    _total += _toDouble(row['__total']);
    _income += _toDouble(row['__income']);

    final status = '${row['__status'] ?? ''}'.trim();
    if (status.isNotEmpty) {
      _statuses.add(status);
    }

    final tujuanRaw = '${row['__tujuan'] ?? ''}'.trim();
    if (tujuanRaw.isNotEmpty && tujuanRaw != '-') {
      for (final chunk in tujuanRaw.split('|')) {
        final cleaned = chunk.trim();
        if (cleaned.isNotEmpty && cleaned != '-') {
          _tujuan.add(cleaned);
        }
      }
    }

    final candidateDate = _toDate(row['__date']);
    if (candidateDate == null) return;
    if (_latestDate == null || candidateDate.isAfter(_latestDate!)) {
      _latestDate = candidateDate;
      _latestDateRaw = row['__date'];
    }
  }

  Map<String, dynamic> toRow() {
    return <String, dynamic>{
      '__key': 'income-customer:$key',
      '__type': 'Income',
      '__group_mode': 'customer_income',
      '__item_count': _itemCount,
      '__number': _itemCount == 1 ? '1 invoice' : '$_itemCount invoices',
      '__date': _latestDateRaw,
      '__name': customerName,
      '__customer': customerName,
      '__status': _statuses.join(', '),
      '__amount': _total,
      '__jumlah': _jumlah,
      '__pph': _pph,
      '__total': _total,
      '__tujuan': _tujuan.isEmpty ? '-' : _tujuan.join(' | '),
      '__income': _income,
      '__expense': 0.0,
    };
  }
}

DateTime? _toDate(dynamic value) {
  if (value is DateTime) return value;
  return Formatters.parseDate(value);
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}
