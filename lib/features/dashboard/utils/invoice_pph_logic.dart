import 'dart:math';

double roundInvoiceRupiah(num value) {
  final amount = value.toDouble();
  if (!amount.isFinite || amount <= 0) return 0;
  return amount.roundToDouble();
}

double calculateInvoicePph2Percent(num subtotal) {
  final value = roundInvoiceRupiah(subtotal);
  if (!value.isFinite || value <= 0) return 0;
  return max(0, (value * 0.02).roundToDouble());
}

double calculateInvoiceTotalAfterPph(num subtotal) {
  final value = roundInvoiceRupiah(subtotal);
  if (!value.isFinite || value <= 0) return 0;
  return max(0, value - calculateInvoicePph2Percent(value));
}
