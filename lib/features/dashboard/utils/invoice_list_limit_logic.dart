bool isInvoiceListAutoExpenseRow(Map<String, dynamic> row) {
  return '${row['__type'] ?? ''}' == 'Expense' &&
      (row['__is_auto_sangu'] == true || row['__is_auto_gabungan'] == true);
}

bool shouldShowStandaloneInvoiceListExpense(Map<String, dynamic> row) {
  return '${row['__type'] ?? ''}' == 'Expense' &&
      !isInvoiceListAutoExpenseRow(row);
}

List<List<Map<String, dynamic>>> buildInvoiceListRowGroups({
  required List<Map<String, dynamic>> incomeRows,
  required Map<String, List<Map<String, dynamic>>> expenseByIncomeId,
  required List<Map<String, dynamic>> standaloneExpenses,
}) {
  final groups = <List<Map<String, dynamic>>>[];
  final attachedExpenseIncomeIds = <String>{};

  for (final income in incomeRows) {
    final group = <Map<String, dynamic>>[income];
    final id = '${income['id'] ?? ''}'.trim();
    final children = expenseByIncomeId[id];
    if (id.isNotEmpty &&
        attachedExpenseIncomeIds.add(id) &&
        children != null &&
        children.isNotEmpty) {
      group.addAll(children);
    }
    groups.add(group);
  }

  groups.addAll(
    standaloneExpenses
        .where(shouldShowStandaloneInvoiceListExpense)
        .map((expense) => <Map<String, dynamic>>[expense]),
  );
  return groups;
}

List<Map<String, dynamic>> limitInvoiceListRows(
  List<Map<String, dynamic>> rows, {
  required int maxRows,
}) {
  if (maxRows <= 0 || rows.length <= maxRows) return rows;

  var end = maxRows;
  while (end < rows.length && isInvoiceListAutoExpenseRow(rows[end])) {
    end++;
  }
  return rows.take(end).toList(growable: false);
}
