import 'invoice_pph_logic.dart';

double parseInvoiceDetailAmount(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();

  final raw = value.toString().trim();
  if (raw.isEmpty) return 0;
  var cleaned = raw.replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (cleaned.isEmpty || cleaned == '-' || cleaned == '.' || cleaned == ',') {
    return 0;
  }

  if (cleaned.contains(',')) {
    cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
  } else {
    final dotCount = '.'.allMatches(cleaned).length;
    if (dotCount > 1) {
      cleaned = cleaned.replaceAll('.', '');
    } else if (dotCount == 1) {
      final parts = cleaned.split('.');
      final fraction = parts.length == 2 ? parts.last : '';
      if (fraction.length == 3) {
        cleaned = cleaned.replaceAll('.', '');
      }
    }
  }

  return double.tryParse(cleaned) ?? 0;
}

bool isTruthySubtotalAuto(dynamic value) {
  if (value is bool) return value;
  final normalized = '${value ?? ''}'.trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

double resolveInvoiceDetailSubtotal(
  Map<String, dynamic> detail, {
  Map<String, dynamic>? fallback,
  num fallbackSubtotal = 0,
}) {
  double pick(String key) {
    final direct = parseInvoiceDetailAmount(detail[key]);
    if (direct > 0) return direct;
    return fallback == null ? 0 : parseInvoiceDetailAmount(fallback[key]);
  }

  for (final key in const ['manual_subtotal', 'subtotal_manual']) {
    final manual = pick(key);
    if (manual > 0) return manual;
  }

  final tonase = pick('tonase');
  final harga = pick('harga');
  final computed = tonase > 0 && harga > 0 ? tonase * harga : 0.0;
  if (isTruthySubtotalAuto(detail['subtotal_auto']) && computed > 0) {
    return computed;
  }

  for (final key in const ['subtotal', 'total', 'total_biaya', 'jumlah']) {
    final explicit = pick(key);
    if (explicit > 0) return explicit;
  }

  if (computed > 0) return computed;
  return parseInvoiceDetailAmount(fallbackSubtotal);
}

double resolveInvoiceDetailExcelSubtotal(
  Map<String, dynamic> detail, {
  Map<String, dynamic>? fallback,
  num fallbackSubtotal = 0,
}) {
  return roundInvoiceRupiah(
    resolveInvoiceDetailSubtotal(
      detail,
      fallback: fallback,
      fallbackSubtotal: fallbackSubtotal,
    ),
  );
}

double resolveInvoiceDetailsExcelSubtotal(
  Iterable<Map<String, dynamic>> details, {
  num fallbackSubtotal = 0,
}) {
  final rowTotal = details.fold<double>(
    0,
    (sum, detail) => sum + resolveInvoiceDetailExcelSubtotal(detail),
  );
  if (rowTotal > 0) return rowTotal;
  return roundInvoiceRupiah(fallbackSubtotal);
}
