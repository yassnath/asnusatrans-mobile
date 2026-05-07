const double fixedInvoicePaymentRoundingTolerance = 10.0;

double fixedInvoiceRoundedRemaining({
  required double total,
  required double paid,
  double tolerance = fixedInvoicePaymentRoundingTolerance,
}) {
  final remaining = total - paid;
  if (remaining <= 0) return 0;
  return remaining <= tolerance ? 0 : remaining;
}

bool fixedInvoicePaymentCoversTotal({
  required double total,
  required double paid,
  double tolerance = fixedInvoicePaymentRoundingTolerance,
}) {
  if (total <= 0 || paid <= 0) return false;
  return fixedInvoiceRoundedRemaining(
        total: total,
        paid: paid,
        tolerance: tolerance,
      ) <=
      0;
}
