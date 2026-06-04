import 'package:cvant_mobile/core/utils/formatters.dart';

class ReportPaymentDefaults {
  const ReportPaymentDefaults({
    required this.paidLocked,
    required this.lockedPaidAmount,
    required this.defaultBayar,
    required this.defaultSisa,
  });

  final bool paidLocked;
  final double lockedPaidAmount;
  final double defaultBayar;
  final double defaultSisa;
}

class ReportPaymentInputDraft {
  const ReportPaymentInputDraft({
    required this.bayar,
    required this.sisa,
    required this.bayarText,
    required this.sisaText,
  });

  final double bayar;
  final double sisa;
  final String bayarText;
  final String sisaText;
}

typedef ReportPaymentAmountFormatter = String Function(num value);
typedef ReportPaymentAmountParser = double Function(String value);

double parseEditableReportAmount(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty) return 0;
  final cleaned = raw
      .replaceAll(RegExp(r'[^0-9,.-]'), '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  return double.tryParse(cleaned) ?? 0;
}

String formatEditableReportAmount(num value) {
  final number = value.toDouble();
  if (!number.isFinite || number <= 0) return '';
  return Formatters.decimal(number, useGrouping: true);
}

ReportPaymentDefaults resolveReportPaymentDefaults(Map<String, dynamic> row) {
  final paidLocked = row['__paid_locked'] == true;
  final total = _toReportPaymentNum(row['__total']);
  final storedBayarDefault = _toReportPaymentNum(row['__bayar_default']);
  final lockedPaidAmount = storedBayarDefault > 0 ? storedBayarDefault : total;

  return ReportPaymentDefaults(
    paidLocked: paidLocked,
    lockedPaidAmount: lockedPaidAmount,
    defaultBayar: paidLocked ? lockedPaidAmount : storedBayarDefault,
    defaultSisa: paidLocked ? 0.0 : _toReportPaymentNum(row['__sisa_default']),
  );
}

ReportPaymentInputDraft resolveReportPaymentInputDraft({
  required Map<String, dynamic> row,
  required String bayarText,
  required String sisaText,
  required ReportPaymentAmountFormatter formatAmount,
  required ReportPaymentAmountParser parseAmount,
}) {
  final defaults = resolveReportPaymentDefaults(row);
  if (defaults.paidLocked) {
    final lockedBayarText = formatAmount(defaults.lockedPaidAmount);
    return ReportPaymentInputDraft(
      bayar: defaults.lockedPaidAmount,
      sisa: 0.0,
      bayarText: lockedBayarText,
      sisaText: '',
    );
  }

  final cleanedBayarText = bayarText.trim();
  final cleanedSisaText = sisaText.trim();
  return ReportPaymentInputDraft(
    bayar: parseAmount(cleanedBayarText),
    sisa: parseAmount(cleanedSisaText),
    bayarText: cleanedBayarText,
    sisaText: cleanedSisaText,
  );
}

double _toReportPaymentNum(dynamic value) {
  if (value is num) return value.toDouble();
  final cleaned = '${value ?? ''}'
      .replaceAll(RegExp(r'[^0-9,.-]'), '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  return double.tryParse(cleaned) ?? 0;
}
