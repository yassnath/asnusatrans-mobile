List<Map<String, dynamic>> dedupeReportInvoiceRowsById(
  Iterable<Map<String, dynamic>> rows,
) {
  final seenIds = <String>{};
  final result = <Map<String, dynamic>>[];
  for (final row in rows) {
    final id = '${row['id'] ?? ''}'.trim();
    if (id.isEmpty || seenIds.add(id)) {
      result.add(row);
    }
  }
  return result;
}

bool reserveReportIncomeDetailIdentity({
  required Set<String> seenIdentities,
  required Map<String, dynamic> invoice,
  required int detailIndex,
}) {
  final invoiceId = '${invoice['id'] ?? ''}'.trim();
  if (invoiceId.isEmpty) return true;
  return seenIdentities.add('$invoiceId:$detailIndex');
}
