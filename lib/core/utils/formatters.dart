import 'package:intl/intl.dart';

class Formatters {
  const Formatters._();

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

  static String invoiceNumber(dynamic value, dynamic tanggal) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '-';

    final upper = raw.toUpperCase();
    final alreadyPattern = RegExp(r'^(INC|EXP)-\d{2}-\d{4}-\d{4}$');
    if (alreadyPattern.hasMatch(upper)) return upper;

    final match = RegExp(r'^(INC|EXP)-(\d{4})-(\d{4})$').firstMatch(upper);
    if (match == null) return raw;

    final dt = parseDate(tanggal);
    if (dt == null) return raw;
    final mm = dt.month.toString().padLeft(2, '0');
    return '${match.group(1)}-$mm-${match.group(2)}-${match.group(3)}';
  }
}
