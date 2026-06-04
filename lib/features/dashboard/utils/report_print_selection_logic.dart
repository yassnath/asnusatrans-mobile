import 'report_payment_edit_logic.dart';

class ReportPrintTotals {
  const ReportPrintTotals({
    required this.income,
    required this.expense,
  });

  final double income;
  final double expense;
}

List<Map<String, dynamic>> buildSelectedReportRowsForPrint({
  required Iterable<Map<String, dynamic>> allRows,
  required Set<String> selectedKeys,
  required bool incomeInvoiceReport,
  required Map<String, String> bayarInputs,
  required Map<String, String> sisaInputs,
  required ReportPaymentAmountFormatter formatAmount,
  required ReportPaymentAmountParser parseAmount,
}) {
  if (selectedKeys.isEmpty) return <Map<String, dynamic>>[];

  return allRows
      .where((row) => selectedKeys.contains('${row['__key']}'))
      .map((row) {
    if (!incomeInvoiceReport || '${row['__type']}' != 'Income') {
      return row;
    }

    final key = '${row['__key']}';
    final paymentInput = resolveReportPaymentInputDraft(
      row: row,
      bayarText: (bayarInputs[key] ?? '').toString(),
      sisaText: (sisaInputs[key] ?? '').toString(),
      formatAmount: formatAmount,
      parseAmount: parseAmount,
    );
    return {
      ...row,
      '__bayar': paymentInput.bayar,
      '__sisa': paymentInput.sisa,
      '__bayar_text': paymentInput.bayarText,
      '__sisa_text': paymentInput.sisaText,
    };
  }).toList();
}

ReportPrintTotals calculateReportPrintTotals(
  Iterable<Map<String, dynamic>> rows,
) {
  var totalIncome = 0.0;
  var totalExpense = 0.0;

  for (final row in rows) {
    if ('${row['__type']}' == 'Income') {
      totalIncome += _toReportPrintNum(row['__income']);
      totalExpense += _toReportPrintNum(row['__sangu_sopir']);
      continue;
    }
    totalExpense += _toReportPrintNum(row['__expense']);
  }

  return ReportPrintTotals(
    income: totalIncome,
    expense: totalExpense,
  );
}

double _toReportPrintNum(dynamic value) {
  if (value is num) return value.toDouble();
  final cleaned = '${value ?? ''}'
      .replaceAll(RegExp(r'[^0-9,.-]'), '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  return double.tryParse(cleaned) ?? 0;
}
