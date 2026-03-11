import 'package:intl/intl.dart';

class Formatters {
  const Formatters._();

  static const _companyKeywords = <String>[
    r'\bcv\b',
    r'\bpt\b',
    r'\bfa\b',
    r'\bud\b',
    r'\bpo\b',
    r'\byayasan\b',
    r'\bbumn\b',
    r'\bbumd\b',
    r'\bperum\b',
    r'\bkoperasi\b',
    r'\bpersekutuan\s+perdata\b',
    r'\bmaatschap\b',
  ];
  static const _romanMonths = <String>[
    '',
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII',
    'IX',
    'X',
    'XI',
    'XII',
  ];

  static final NumberFormat _idr = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String rupiah(num value) => _idr.format(value);

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    if (raw.contains('T')) {
      return DateTime.tryParse(raw)?.toLocal();
    }

    final ddMmYyyy = RegExp(r'^\d{2}-\d{2}-\d{4}$');
    if (ddMmYyyy.hasMatch(raw)) {
      final parts = raw.split('-');
      return DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
    }

    final yyyyMmDd = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (yyyyMmDd.hasMatch(raw)) {
      return DateTime.tryParse(raw);
    }

    return DateTime.tryParse(raw);
  }

  static String dmy(dynamic value) {
    final date = parseDate(value);
    if (date == null) return '-';
    return DateFormat('dd-MM-yyyy').format(date);
  }

  static String _normalizeCompanyText(String value) {
    return value
        .toLowerCase()
        .replaceAll('.', ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isCompanyCustomerName(String value) {
    final normalized = _normalizeCompanyText(value);
    if (normalized.isEmpty) return false;
    for (final keyword in _companyKeywords) {
      if (RegExp(keyword).hasMatch(normalized)) {
        return true;
      }
    }
    return false;
  }

  static bool _isCompanyByInvoicePattern(String value) {
    final compact = value.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (compact.contains('/CV.ANT/') || compact.contains('CV.ANT')) return true;
    if (compact.contains('/ANT/') && !compact.contains('CV.ANT')) return false;
    return true;
  }

  static String _romanMonth(int month) {
    if (month < 1 || month > 12) return '-';
    return _romanMonths[month];
  }

  static String invoiceNumber(
    dynamic value,
    dynamic tanggal, {
    dynamic customerName,
    bool? isCompany,
  }) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '-';

    final cleaned = raw
        .replaceFirst(RegExp(r'^\s*NO\s*:\s*', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) return '-';

    final upper = cleaned.toUpperCase();
    final looksIncome = upper.startsWith('INC-');
    if (!looksIncome) {
      final alreadyPattern = RegExp(r'^EXP-\d{2}-\d{4}-\d{4}$');
      if (alreadyPattern.hasMatch(upper)) return upper;

      final oldExpensePattern = RegExp(r'^EXP-(\d{4})-(\d{4})$');
      final oldExpense = oldExpensePattern.firstMatch(upper);
      if (oldExpense != null) {
        final dt = parseDate(tanggal);
        if (dt == null) return upper;
        final mm = dt.month.toString().padLeft(2, '0');
        return 'EXP-$mm-${oldExpense.group(1)}-${oldExpense.group(2)}';
      }
      return cleaned;
    }

    final customerRaw = (customerName ?? '').toString().trim();
    final resolvedIsCompany = isCompany ??
        (customerRaw.isNotEmpty
            ? _isCompanyCustomerName(customerRaw)
            : _isCompanyByInvoicePattern(cleaned));

    final patternWithMonth = RegExp(r'^INC-(\d{2})-(\d{4})-(\d{1,})$');
    final matchWithMonth = patternWithMonth.firstMatch(upper);
    if (matchWithMonth != null) {
      final month = int.tryParse(matchWithMonth.group(1) ?? '') ?? 0;
      final seq = matchWithMonth.group(3) ?? '1';
      final prefix = resolvedIsCompany ? '480 / CV.ANT' : '268 / ANT';
      return '$prefix / ${_romanMonth(month)} / $seq';
    }

    final oldPattern = RegExp(r'^INC-(\d{4})-(\d{1,})$');
    final oldMatch = oldPattern.firstMatch(upper);
    if (oldMatch != null) {
      final dt = parseDate(tanggal);
      final month = dt?.month ?? DateTime.now().month;
      final seq = oldMatch.group(2) ?? '1';
      final prefix = resolvedIsCompany ? '480 / CV.ANT' : '268 / ANT';
      return '$prefix / ${_romanMonth(month)} / $seq';
    }

    return cleaned;
  }
}
