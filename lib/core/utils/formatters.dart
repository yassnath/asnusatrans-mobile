import 'package:intl/intl.dart';

class Formatters {
  const Formatters._();

  static const invoiceEntityCvAnt = 'cv_ant';
  static const invoiceEntityPtAnt = 'pt_ant';
  static const invoiceEntityPersonal = 'personal';

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

  static final NumberFormat _idrInteger = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String decimal(
    num value, {
    int maxDecimalDigits = 12,
    bool trimTrailingZeros = true,
    bool useGrouping = false,
  }) {
    final number = value.toDouble();
    if (!number.isFinite) return '0';
    final floored = number.floor();
    return useGrouping
        ? NumberFormat.decimalPattern('id_ID').format(floored)
        : floored.toString();
  }

  static String decimalFixed(
    num value, {
    int decimalDigits = 1,
    bool useGrouping = true,
  }) {
    final number = value.toDouble();
    if (!number.isFinite) {
      final zeroFormatter = useGrouping
          ? NumberFormat.decimalPatternDigits(
              locale: 'id_ID',
              decimalDigits: decimalDigits,
            )
          : NumberFormat(
              decimalDigits <= 0 ? '0' : '0.${'0' * decimalDigits}',
              'id_ID',
            );
      return zeroFormatter.format(0);
    }

    final formatter = useGrouping
        ? NumberFormat.decimalPatternDigits(
            locale: 'id_ID',
            decimalDigits: decimalDigits,
          )
        : NumberFormat(
            decimalDigits <= 0 ? '0' : '0.${'0' * decimalDigits}',
            'id_ID',
          );
    return formatter.format(number);
  }

  static String rupiah(
    num value, {
    int maxDecimalDigits = 12,
    bool trimTrailingZeros = true,
  }) {
    final number = value.toDouble();
    if (!number.isFinite) return _idrInteger.format(0);
    return _idrInteger.format(number.floor());
  }

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
      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? 1970;
      return DateTime(year, month, day);
    }

    final yyyyMmDd = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (yyyyMmDd.hasMatch(raw)) {
      final parts = raw.split('-');
      final year = int.tryParse(parts[0]) ?? 1970;
      final month = int.tryParse(parts[1]) ?? 1;
      final day = int.tryParse(parts[2]) ?? 1;
      return DateTime(year, month, day);
    }

    return DateTime.tryParse(raw)?.toLocal();
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
    if (compact.contains('/CV.ANT/') ||
        compact.contains('CV.ANT') ||
        compact.contains('/PT.ANT/') ||
        compact.contains('PT.ANT')) {
      return true;
    }
    if ((compact.contains('/BS/') ||
            compact.contains('/ANT/') ||
            compact.startsWith('BS')) &&
        !compact.contains('CV.ANT')) {
      return false;
    }
    return true;
  }

  static bool isCompanyInvoiceEntity(String entity) {
    final normalized = normalizeInvoiceEntity(entity);
    return normalized != invoiceEntityPersonal;
  }

  static String invoiceEntityLabel(String entity) {
    switch (normalizeInvoiceEntity(entity)) {
      case invoiceEntityPtAnt:
        return 'PT. ANT';
      case invoiceEntityPersonal:
        return 'Pribadi';
      case invoiceEntityCvAnt:
      default:
        return 'CV. ANT';
    }
  }

  static String normalizeInvoiceEntity(
    String? entity, {
    dynamic invoiceNumber,
    dynamic customerName,
    bool? isCompany,
  }) {
    final cleaned = (entity ?? '').trim().toLowerCase();
    switch (cleaned) {
      case invoiceEntityCvAnt:
      case 'cv.ant':
      case 'cv ant':
      case 'company':
        return invoiceEntityCvAnt;
      case invoiceEntityPtAnt:
      case 'pt.ant':
      case 'pt ant':
        return invoiceEntityPtAnt;
      case invoiceEntityPersonal:
      case 'pribadi':
        return invoiceEntityPersonal;
    }

    final rawNumber = '${invoiceNumber ?? ''}'.trim();
    final compact = rawNumber.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (compact.contains('/PT.ANT/') || compact.contains('PT.ANT')) {
      return invoiceEntityPtAnt;
    }
    if (compact.contains('/CV.ANT/') || compact.contains('CV.ANT')) {
      return invoiceEntityCvAnt;
    }
    if ((compact.contains('/BS/') ||
            compact.contains('/ANT/') ||
            compact.startsWith('BS')) &&
        !compact.contains('CV.ANT') &&
        !compact.contains('PT.ANT')) {
      return invoiceEntityPersonal;
    }

    final customerRaw = '${customerName ?? ''}'.trim();
    if (customerRaw.isNotEmpty && _isCompanyCustomerName(customerRaw)) {
      return invoiceEntityCvAnt;
    }

    if (isCompany == true) return invoiceEntityCvAnt;
    return invoiceEntityPersonal;
  }

  static String invoiceEntityCode(String entity) {
    switch (normalizeInvoiceEntity(entity)) {
      case invoiceEntityPtAnt:
        return 'PT.ANT';
      case invoiceEntityPersonal:
        return 'BS';
      case invoiceEntityCvAnt:
      default:
        return 'CV.ANT';
    }
  }

  static String invoiceNumber(
    dynamic value,
    dynamic tanggal, {
    dynamic customerName,
    bool? isCompany,
    String? invoiceEntity,
  }) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '-';

    final cleaned = raw
        .replaceFirst(RegExp(r'^\s*NO\s*:\s*', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) return '-';

    final upper = cleaned.toUpperCase();

    // Expense number normalization stays independent from income format rules.
    if (upper.startsWith('EXP-')) {
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
    final resolvedEntity = normalizeInvoiceEntity(
      invoiceEntity,
      invoiceNumber: cleaned,
      customerName: customerRaw,
      isCompany: isCompany ??
          (customerRaw.isNotEmpty
              ? _isCompanyCustomerName(customerRaw)
              : _isCompanyByInvoicePattern(cleaned)),
    );

    String composeNumber({
      required int sequence,
      required int month,
      required int yearTwoDigits,
      required String entity,
    }) {
      final seq = sequence.toString().padLeft(2, '0');
      final yy = yearTwoDigits.toString().padLeft(2, '0');
      final mm = month.toString().padLeft(2, '0');
      final code = invoiceEntityCode(entity);
      return '$code$yy$mm$seq';
    }

    // New preferred format:
    // BS260401
    // CV.ANT260401
    // PT.ANT260401
    final compactPattern = RegExp(
      r'^(CV\.ANT|PT\.ANT|BS)(\d{2})(\d{2})(\d{2,})$',
      caseSensitive: false,
    );
    final compactMatch = compactPattern.firstMatch(upper);
    if (compactMatch != null) {
      final prefix = (compactMatch.group(1) ?? '').toUpperCase().trim();
      final entityFromPrefix = switch (prefix) {
        'PT.ANT' => invoiceEntityPtAnt,
        'CV.ANT' => invoiceEntityCvAnt,
        _ => invoiceEntityPersonal,
      };
      final yearTwoDigits = int.tryParse(compactMatch.group(2) ?? '') ??
          (parseDate(tanggal)?.year ?? DateTime.now().year) % 100;
      final month = int.tryParse(compactMatch.group(3) ?? '') ??
          parseDate(tanggal)?.month ??
          DateTime.now().month;
      final seq = int.tryParse(compactMatch.group(4) ?? '') ?? 1;
      return composeNumber(
        sequence: seq,
        month: month <= 0 ? DateTime.now().month : month,
        yearTwoDigits: yearTwoDigits,
        entity: entityFromPrefix,
      );
    }

    // Legacy preferred format:
    // 017 / BS / I / 26
    // 017 / CV.ANT / I / 26
    // 017 / PT.ANT / I / 26
    final newPattern = RegExp(
      r'^(\d{1,4})\s*\/\s*(CV\.ANT|PT\.ANT|BS|ANT)\s*\/\s*([IVX]+)\s*\/\s*(\d{2})$',
      caseSensitive: false,
    );
    final newMatch = newPattern.firstMatch(upper);
    if (newMatch != null) {
      final dt = parseDate(tanggal);
      final seq = int.tryParse(newMatch.group(1) ?? '') ?? 1;
      final prefix = (newMatch.group(2) ?? '').toUpperCase().trim();
      final entityFromPrefix = switch (prefix) {
        'PT.ANT' => invoiceEntityPtAnt,
        'CV.ANT' => invoiceEntityCvAnt,
        _ => invoiceEntityPersonal,
      };
      final month = dt?.month ??
          _romanMonths.indexOf((newMatch.group(3) ?? '').toUpperCase());
      final yearTwoDigits = dt != null
          ? (dt.year % 100)
          : (int.tryParse(newMatch.group(4) ?? '') ??
              (DateTime.now().year % 100));
      return composeNumber(
        sequence: seq,
        month: month <= 0 ? DateTime.now().month : month,
        yearTwoDigits: yearTwoDigits,
        entity: entityFromPrefix,
      );
    }

    final patternWithMonth = RegExp(r'^INC-(\d{2})-(\d{4})-(\d{1,})$');
    final matchWithMonth = patternWithMonth.firstMatch(upper);
    if (matchWithMonth != null) {
      final dt = parseDate(tanggal);
      final month =
          dt?.month ?? (int.tryParse(matchWithMonth.group(1) ?? '') ?? 0);
      final year = dt?.year ??
          (int.tryParse(matchWithMonth.group(2) ?? '') ?? DateTime.now().year);
      final seq = int.tryParse(matchWithMonth.group(3) ?? '') ?? 1;
      return composeNumber(
        sequence: seq,
        month: month <= 0 ? DateTime.now().month : month,
        yearTwoDigits: year % 100,
        entity: resolvedEntity,
      );
    }

    // Legacy converted format: keep sequence, but ensure Roman month follows
    // the provided reference date when available (e.g. tanggal_kop).
    final convertedPattern = RegExp(
      r'^(480\s*\/\s*CV\.ANT|268\s*\/\s*ANT)\s*\/\s*([IVX]+)\s*\/\s*(\d+)\s*$',
      caseSensitive: false,
    );
    final convertedMatch = convertedPattern.firstMatch(upper);
    if (convertedMatch != null) {
      final dt = parseDate(tanggal);
      final month = dt?.month ??
          _romanMonths.indexOf((convertedMatch.group(2) ?? '').toUpperCase());
      final seq = int.tryParse(convertedMatch.group(3) ?? '') ?? 1;
      final yearTwoDigits =
          dt != null ? (dt.year % 100) : (DateTime.now().year % 100);
      return composeNumber(
        sequence: seq,
        month: month <= 0 ? DateTime.now().month : month,
        yearTwoDigits: yearTwoDigits,
        entity: resolvedEntity,
      );
    }

    final oldPattern = RegExp(r'^INC-(\d{4})-(\d{1,})$');
    final oldMatch = oldPattern.firstMatch(upper);
    if (oldMatch != null) {
      final dt = parseDate(tanggal);
      final month = dt?.month ?? DateTime.now().month;
      final year = dt?.year ??
          (int.tryParse(oldMatch.group(1) ?? '') ?? DateTime.now().year);
      final seq = int.tryParse(oldMatch.group(2) ?? '') ?? 1;
      return composeNumber(
        sequence: seq,
        month: month,
        yearTwoDigits: year % 100,
        entity: resolvedEntity,
      );
    }

    return cleaned;
  }
}
