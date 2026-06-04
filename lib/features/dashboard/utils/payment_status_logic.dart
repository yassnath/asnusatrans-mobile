import 'payment_rounding_logic.dart';

const paymentStatusPaid = 'Paid';
const paymentStatusPartial = 'Partial';
const paymentStatusUnpaid = 'Unpaid';

String normalizePaymentStatusText(dynamic value) {
  return '${value ?? ''}'
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _hasPaymentStatusToken(dynamic value, String token) {
  final normalized = normalizePaymentStatusText(value);
  if (normalized.isEmpty) return false;
  return normalized.split(' ').contains(token);
}

bool isUnpaidPaymentStatus(dynamic value) {
  final normalized = normalizePaymentStatusText(value);
  if (normalized.isEmpty) return false;
  return _hasPaymentStatusToken(normalized, 'unpaid') ||
      normalized == 'un paid' ||
      normalized.startsWith('un paid ') ||
      normalized == 'not paid' ||
      normalized.startsWith('not paid ') ||
      normalized == 'belum lunas' ||
      normalized.startsWith('belum lunas ');
}

bool isPartialPaymentStatus(dynamic value) {
  return _hasPaymentStatusToken(value, 'partial') ||
      _hasPaymentStatusToken(value, 'partially');
}

bool isPaidPaymentStatus(dynamic value) {
  if (isUnpaidPaymentStatus(value) || isPartialPaymentStatus(value)) {
    return false;
  }
  return _hasPaymentStatusToken(value, 'paid') ||
      _hasPaymentStatusToken(value, 'lunas');
}

bool isPaymentStartedStatus(dynamic value) {
  return isPaidPaymentStatus(value) || isPartialPaymentStatus(value);
}

String resolvePaymentStatusLabel({
  required double total,
  required double paid,
  bool hasAnyPayment = false,
  dynamic explicitStatus,
}) {
  if (fixedInvoicePaymentCoversTotal(total: total, paid: paid)) {
    return paymentStatusPaid;
  }
  if (paid > 0 || hasAnyPayment) return paymentStatusPartial;
  if (isPaidPaymentStatus(explicitStatus)) return paymentStatusPaid;
  if (isPartialPaymentStatus(explicitStatus)) return paymentStatusPartial;
  return paymentStatusUnpaid;
}
