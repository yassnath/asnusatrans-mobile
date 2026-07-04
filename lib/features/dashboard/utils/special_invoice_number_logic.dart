String buildSpecialPersonalInvoiceNumber(int sequence) {
  final safeSequence = sequence < 1 ? 1 : sequence;
  return safeSequence.toString().padLeft(3, '0');
}

String specialPersonalInvoicePeriodKey(DateTime date) {
  final localDate = date.toLocal();
  final month = localDate.month.toString().padLeft(2, '0');
  return '${localDate.year}-$month';
}

bool isSameSpecialPersonalInvoicePeriod(DateTime a, DateTime b) {
  return specialPersonalInvoicePeriodKey(a) ==
      specialPersonalInvoicePeriodKey(b);
}

final DateTime tritunggalSpecialPersonalCutoffDate = DateTime(2026, 6, 20);

bool isTritunggalSpecialPersonalDepartureDate(DateTime? departureDate) {
  return departureDate != null &&
      departureDate.isAfter(tritunggalSpecialPersonalCutoffDate);
}

int extractSpecialPersonalInvoiceSequence(String invoiceNumber) {
  final cleaned = invoiceNumber
      .replaceFirst(RegExp(r'^\s*NO\s*:\s*', caseSensitive: false), '')
      .trim();
  if (!RegExp(r'^\d{3,}$').hasMatch(cleaned)) return 0;
  return int.tryParse(cleaned) ?? 0;
}
