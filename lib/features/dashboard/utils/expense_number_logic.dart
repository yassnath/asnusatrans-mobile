int expenseSequenceForPeriod(
  dynamic value, {
  required int month,
  required int year,
}) {
  final number = '${value ?? ''}'.trim().toUpperCase();
  final match = RegExp(r'^EXP-(\d{2})-(\d{4})-(\d{1,4})$').firstMatch(number);
  if (match == null) return 0;

  final rowMonth = int.tryParse(match.group(1) ?? '') ?? 0;
  final rowYear = int.tryParse(match.group(2) ?? '') ?? 0;
  if (rowMonth != month || rowYear != year) return 0;
  return int.tryParse(match.group(3) ?? '') ?? 0;
}

String buildNextExpenseNumberForPeriod({
  required int month,
  required int year,
  required Iterable<Map<String, dynamic>> existingRows,
  String? excludeExpenseId,
}) {
  final excludedId = excludeExpenseId?.trim() ?? '';
  var maxSequence = 0;

  for (final row in existingRows) {
    final id = '${row['id'] ?? ''}'.trim();
    if (excludedId.isNotEmpty && id == excludedId) continue;
    final sequence = expenseSequenceForPeriod(
      row['no_expense'],
      month: month,
      year: year,
    );
    if (sequence > maxSequence) maxSequence = sequence;
  }

  final next = maxSequence + 1;
  if (next > 9999) {
    throw StateError('Expense sequence limit reached for $month-$year.');
  }
  final mm = month.toString().padLeft(2, '0');
  return 'EXP-$mm-$year-${next.toString().padLeft(4, '0')}';
}
