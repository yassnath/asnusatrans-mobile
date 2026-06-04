import 'dart:math';

import 'package:cvant_mobile/core/utils/formatters.dart';

import 'payment_status_logic.dart';

class ReportTableLayout {
  const ReportTableLayout({
    required this.headers,
    required this.numericColumns,
    required this.dateColumns,
    required this.priorityTextColumns,
  });

  final List<String> headers;
  final Set<int> numericColumns;
  final Set<int> dateColumns;
  final Set<int> priorityTextColumns;
}

class ReportTableFontSizing {
  const ReportTableFontSizing({
    required this.headerFont,
    required this.cellFont,
  });

  final double headerFont;
  final double cellFont;
}

class ReportTableMode {
  const ReportTableMode({
    required this.incomeInvoiceTable,
    required this.combinedDriverCostColumns,
    required this.showCombinedPphColumn,
    required this.companyMode,
    required this.showIncomePphColumn,
  });

  final bool incomeInvoiceTable;
  final bool combinedDriverCostColumns;
  final bool showCombinedPphColumn;
  final bool companyMode;
  final bool showIncomePphColumn;
}

typedef ReportAmountFormatter = String Function(num value);
typedef ReportDateFormatter = String Function(dynamic value);
typedef ReportRowTextResolver = String Function(Map<String, dynamic> row);

ReportTableMode resolveReportTableMode({
  required bool includeIncome,
  required bool includeExpense,
  required bool includeDriverCostColumns,
  required String customerKind,
  required Iterable<Map<String, dynamic>> rows,
}) {
  final incomeInvoiceTable = includeIncome && !includeExpense;
  final combinedDriverCostColumns =
      includeIncome && includeExpense && includeDriverCostColumns;
  final showCombinedPphColumn = combinedDriverCostColumns &&
      customerKind != Formatters.invoiceEntityPersonal;
  final hasPph = rows.any((row) => _toReportNum(row['__pph']) > 0);
  final companyMode = customerKind == Formatters.invoiceEntityCvAnt ||
      customerKind == Formatters.invoiceEntityPtAnt ||
      hasPph;
  final showIncomePphColumn = incomeInvoiceTable
      ? customerKind == Formatters.invoiceEntityCvAnt ||
          customerKind == Formatters.invoiceEntityPtAnt ||
          (customerKind != Formatters.invoiceEntityPersonal && hasPph)
      : companyMode;

  return ReportTableMode(
    incomeInvoiceTable: incomeInvoiceTable,
    combinedDriverCostColumns: combinedDriverCostColumns,
    showCombinedPphColumn: showCombinedPphColumn,
    companyMode: companyMode,
    showIncomePphColumn: showIncomePphColumn,
  );
}

ReportTableLayout buildReportTableLayout({
  required bool incomeInvoiceTable,
  required bool showIncomePphColumn,
  required bool combinedDriverCostColumns,
  required bool showCombinedPphColumn,
  required bool companyMode,
}) {
  if (incomeInvoiceTable) {
    return showIncomePphColumn
        ? const ReportTableLayout(
            headers: [
              'NO',
              'TANGGAL',
              'CUSTOMER',
              'JUMLAH',
              'PPH',
              'TOTAL',
              'BAYAR',
              'SISA',
              'TGL BAYAR',
            ],
            numericColumns: {3, 4, 5, 6, 7},
            dateColumns: {1, 8},
            priorityTextColumns: {2},
          )
        : const ReportTableLayout(
            headers: [
              'NO',
              'TANGGAL',
              'CUSTOMER',
              'JUMLAH',
              'TOTAL',
              'BAYAR',
              'SISA',
              'TGL BAYAR',
            ],
            numericColumns: {3, 4, 5, 6},
            dateColumns: {1, 7},
            priorityTextColumns: {2},
          );
  }

  if (combinedDriverCostColumns) {
    final headers = [
      'NO',
      'TGL',
      'CUSTOMER',
      'PLAT NOMOR',
      'MUAT',
      'BONGKAR',
      'JUMLAH',
      'SOPIR',
      'GABUNGAN',
      if (showCombinedPphColumn) 'PPH',
      'TOTAL',
      'LABA',
    ];
    return ReportTableLayout(
      headers: headers,
      numericColumns: showCombinedPphColumn
          ? const {6, 7, 8, 9, 10, 11}
          : const {6, 7, 8, 9, 10},
      dateColumns: const {1},
      priorityTextColumns: const {2, 3, 4, 5},
    );
  }

  if (companyMode) {
    return const ReportTableLayout(
      headers: [
        'NO',
        'TANGGAL',
        'CUSTOMER',
        'JUMLAH',
        'PPH',
        'TOTAL',
        'TUJUAN',
      ],
      numericColumns: {3, 4, 5},
      dateColumns: {1},
      priorityTextColumns: {2, 6},
    );
  }

  return const ReportTableLayout(
    headers: [
      'NO',
      'TANGGAL',
      'CUSTOMER',
      'JUMLAH',
      'TOTAL',
      'TUJUAN',
    ],
    numericColumns: {3, 4},
    dateColumns: {1},
    priorityTextColumns: {2, 5},
  );
}

Map<int, double> buildReportColumnWidthFlexes({
  required List<String> headers,
  required List<List<String>> data,
  required Set<int> dateColumns,
  required Set<int> numericColumns,
  required Set<int> priorityTextColumns,
  required bool incomeInvoiceTable,
  required bool showIncomePphColumn,
  required bool combinedDriverCostColumns,
  required bool showCombinedPphColumn,
  required bool companyMode,
}) {
  final widths = _buildDynamicColumnWidthFlexes(
    headers: headers,
    data: data,
    dateColumns: dateColumns,
    numericColumns: numericColumns,
    priorityTextColumns: priorityTextColumns,
  );

  if (incomeInvoiceTable) {
    if (showIncomePphColumn) {
      widths
        ..[0] = 3.0
        ..[1] = 8.0
        ..[2] = 32.0
        ..[3] = 9.0
        ..[4] = 7.0
        ..[5] = 9.0
        ..[6] = 8.5
        ..[7] = 8.5
        ..[8] = 8.5;
    } else {
      widths
        ..[0] = 3.0
        ..[1] = 8.2
        ..[2] = 34.0
        ..[3] = 9.4
        ..[4] = 9.4
        ..[5] = 8.7
        ..[6] = 8.7
        ..[7] = 8.7;
    }
    return widths;
  }

  if (combinedDriverCostColumns) {
    if (showCombinedPphColumn) {
      widths
        ..[0] = 2.6
        ..[1] = 6.8
        ..[2] = 15.5
        ..[3] = 8.2
        ..[4] = 7.4
        ..[5] = 8.0
        ..[6] = 7.3
        ..[7] = 7.3
        ..[8] = 7.3
        ..[9] = 5.8
        ..[10] = 7.3
        ..[11] = 7.3;
    } else {
      widths
        ..[0] = 2.8
        ..[1] = 7.2
        ..[2] = 17.0
        ..[3] = 8.8
        ..[4] = 8.2
        ..[5] = 8.8
        ..[6] = 8.0
        ..[7] = 8.0
        ..[8] = 8.0
        ..[9] = 8.0
        ..[10] = 8.0;
    }
    return widths;
  }

  widths[2] = max(widths[2] ?? 16.0, companyMode ? 26.0 : 24.0);
  return widths;
}

ReportTableFontSizing buildReportTableFontSizing({
  required Iterable<Map<String, dynamic>> rows,
  required ReportRowTextResolver paidAtDisplay,
  required bool incomeInvoiceTable,
  required bool combinedDriverCostColumns,
}) {
  final rowList = rows.toList(growable: false);
  final maxNumberLen = rowList
      .map((row) => '${row['__number'] ?? '-'}'.length)
      .fold<int>(0, max);
  final maxCustomerLen = rowList
      .map((row) => '${row['__customer'] ?? row['__name'] ?? '-'}'.length)
      .fold<int>(0, max);
  final maxPaidAtLen =
      rowList.map((row) => paidAtDisplay(row).length).fold<int>(0, max);

  var headerFont = 8.0;
  var cellFont = 7.0;
  if (maxNumberLen > 28 || maxCustomerLen > 24 || rowList.length > 24) {
    headerFont -= 0.5;
    cellFont -= 0.5;
  }
  if (maxNumberLen > 40 || maxPaidAtLen > 12 || rowList.length > 36) {
    headerFont -= 0.5;
    cellFont -= 0.5;
  }
  if (incomeInvoiceTable) {
    headerFont -= 0.4;
    cellFont -= 0.4;
  }
  if (combinedDriverCostColumns) {
    headerFont -= 0.75;
    cellFont -= 0.75;
  }

  return ReportTableFontSizing(
    headerFont: headerFont.clamp(7.0, 8.5).toDouble(),
    cellFont: cellFont.clamp(6.2, 7.5).toDouble(),
  );
}

double resolveReportOneLineFontSize({
  required int index,
  required String text,
  required bool header,
  required bool totalRow,
  required bool numericColumn,
  required ReportTableFontSizing sizing,
}) {
  var size = header ? sizing.headerFont : sizing.cellFont;
  if (totalRow) size = max(5.7, size - 0.2);
  if (index == 2) {
    final len = text.replaceAll(RegExp(r'\s+'), ' ').trim().length;
    if (len > 30) {
      size -= min(1.25, (len - 30) * 0.055);
    }
    if (len > 44) {
      size -= min(0.75, (len - 44) * 0.045);
    }
    return size
        .clamp(4.8, header ? sizing.headerFont : sizing.cellFont)
        .toDouble();
  }
  if (numericColumn) {
    return size
        .clamp(5.4, header ? sizing.headerFont : sizing.cellFont)
        .toDouble();
  }
  return size
      .clamp(5.2, header ? sizing.headerFont : sizing.cellFont)
      .toDouble();
}

bool shouldHighlightPaidIncomeNumber({
  required Map<String, dynamic> row,
  required bool incomeInvoiceTable,
}) {
  if (!incomeInvoiceTable || '${row['__type']}' != 'Income') {
    return false;
  }

  final status = '${row['__status'] ?? row['status'] ?? ''}';
  if (row['__paid_locked'] == true || isPaymentStartedStatus(status)) {
    return true;
  }

  final total = _toReportNum(row['__total']);
  final paid = max(
    _toReportNum(row['__bayar']),
    _toReportNum(row['__bayar_default']),
  );
  return total > 0 && paid > 0;
}

List<String> buildReportTableTotalRow({
  required Iterable<Map<String, dynamic>> rows,
  required bool incomeInvoiceTable,
  required bool showIncomePphColumn,
  required bool combinedDriverCostColumns,
  required bool showCombinedPphColumn,
  required bool companyMode,
  required ReportAmountFormatter formatAmount,
}) {
  if (incomeInvoiceTable) {
    final totalJumlah = _sumRows(rows, '__jumlah');
    final totalPph = _sumRows(rows, '__pph');
    final totalNilai = _sumRows(rows, '__total');
    final totalBayar = _sumRows(rows, '__bayar');
    final totalSisa = _sumRows(rows, '__sisa');

    return showIncomePphColumn
        ? [
            '',
            '',
            'TOTAL',
            formatAmount(totalJumlah),
            formatAmount(totalPph),
            formatAmount(totalNilai),
            formatAmount(totalBayar),
            formatAmount(totalSisa),
            '',
          ]
        : [
            '',
            '',
            'TOTAL',
            formatAmount(totalJumlah),
            formatAmount(totalNilai),
            formatAmount(totalBayar),
            formatAmount(totalSisa),
            '',
          ];
  }

  if (combinedDriverCostColumns) {
    final incomeRows = rows.where((row) => '${row['__type']}' == 'Income');
    final totalJumlah = _sumRows(incomeRows, '__jumlah');
    final totalPph = _sumRows(incomeRows, '__pph');
    final totalNilai = _sumRows(incomeRows, '__total');
    final totalSangu = _sumRows(rows, '__sangu_sopir');
    final totalGabungan = _sumRows(rows, '__gabungan');
    final totalLaba = _sumRows(rows, '__laba');

    return [
      '',
      '',
      '',
      '',
      '',
      'TOTAL',
      formatAmount(totalJumlah),
      formatAmount(totalSangu),
      formatAmount(totalGabungan),
      if (showCombinedPphColumn) formatAmount(totalPph),
      formatAmount(totalNilai),
      formatAmount(totalLaba),
    ];
  }

  final totalJumlah = _sumRows(rows, '__jumlah');
  final totalPph = companyMode ? _sumRows(rows, '__pph') : 0.0;
  final totalNilai = _sumRows(rows, '__total');

  return companyMode
      ? [
          '',
          '',
          'TOTAL',
          formatAmount(totalJumlah),
          formatAmount(totalPph),
          formatAmount(totalNilai),
          '',
        ]
      : [
          '',
          '',
          'TOTAL',
          formatAmount(totalJumlah),
          formatAmount(totalNilai),
          '',
        ];
}

List<String> buildReportTableDataRow({
  required Map<String, dynamic> row,
  required int rowNumber,
  required bool incomeInvoiceTable,
  required bool showIncomePphColumn,
  required bool combinedDriverCostColumns,
  required bool showCombinedPphColumn,
  required bool companyMode,
  required ReportDateFormatter formatDate,
  required ReportAmountFormatter formatAmount,
  String paidAtDisplay = '',
}) {
  if (incomeInvoiceTable) {
    if (showIncomePphColumn) {
      return [
        '$rowNumber',
        formatDate(row['__date']),
        _textOrFallback(row['__customer'] ?? row['__name']),
        formatAmount(_toReportNum(row['__jumlah'])),
        formatAmount(_toReportNum(row['__pph'])),
        formatAmount(_toReportNum(row['__total'])),
        _formatOptionalEditableAmount(
            row, '__bayar_text', '__bayar', formatAmount),
        _formatOptionalEditableAmount(
            row, '__sisa_text', '__sisa', formatAmount),
        paidAtDisplay,
      ];
    }
    return [
      '$rowNumber',
      formatDate(row['__date']),
      _textOrFallback(row['__customer'] ?? row['__name']),
      formatAmount(_toReportNum(row['__jumlah'])),
      formatAmount(_toReportNum(row['__total'])),
      _formatOptionalEditableAmount(
          row, '__bayar_text', '__bayar', formatAmount),
      _formatOptionalEditableAmount(row, '__sisa_text', '__sisa', formatAmount),
      paidAtDisplay,
    ];
  }

  if (combinedDriverCostColumns) {
    final isExpense = '${row['__type']}' == 'Expense';
    return [
      '$rowNumber',
      formatDate(row['__date']),
      _textOrFallback(row['__customer'] ?? row['__name']),
      _textOrFallback(row['__plat_nomor']),
      _textOrFallback(row['__muat']),
      _textOrFallback(row['__bongkar'] ?? row['__tujuan']),
      isExpense ? '' : formatAmount(_toReportNum(row['__jumlah'])),
      _formatOptionalReportAmount(row['__sangu_sopir'], formatAmount),
      _formatOptionalReportAmount(row['__gabungan'], formatAmount),
      if (showCombinedPphColumn)
        isExpense ? '' : formatAmount(_toReportNum(row['__pph'])),
      isExpense ? '' : formatAmount(_toReportNum(row['__total'])),
      formatAmount(_toReportNum(row['__laba'])),
    ];
  }

  final categoryExpense = _isCombinedExpenseCategoryRow(
    row,
    combinedDriverCostColumns: combinedDriverCostColumns,
  );
  if (companyMode) {
    return [
      '$rowNumber',
      formatDate(row['__date']),
      _textOrFallback(row['__customer'] ?? row['__name']),
      categoryExpense ? '' : formatAmount(_toReportNum(row['__jumlah'])),
      categoryExpense ? '' : formatAmount(_toReportNum(row['__pph'])),
      categoryExpense ? '' : formatAmount(_toReportNum(row['__total'])),
      if (combinedDriverCostColumns) ...[
        _formatOptionalReportAmount(row['__sangu_sopir'], formatAmount),
        _formatOptionalReportAmount(row['__gabungan'], formatAmount),
      ],
      _textOrFallback(row['__tujuan']),
    ];
  }

  return [
    '$rowNumber',
    formatDate(row['__date']),
    _textOrFallback(row['__customer'] ?? row['__name']),
    categoryExpense ? '' : formatAmount(_toReportNum(row['__jumlah'])),
    categoryExpense ? '' : formatAmount(_toReportNum(row['__total'])),
    if (combinedDriverCostColumns) ...[
      _formatOptionalReportAmount(row['__sangu_sopir'], formatAmount),
      _formatOptionalReportAmount(row['__gabungan'], formatAmount),
    ],
    _textOrFallback(row['__tujuan']),
  ];
}

double _sumRows(Iterable<Map<String, dynamic>> rows, String key) {
  return rows.fold<double>(
    0,
    (sum, row) => sum + _toReportNum(row[key]),
  );
}

Map<int, double> _buildDynamicColumnWidthFlexes({
  required List<String> headers,
  required List<List<String>> data,
  required Set<int> dateColumns,
  required Set<int> numericColumns,
  required Set<int> priorityTextColumns,
}) {
  final widths = <int, double>{};
  for (var index = 0; index < headers.length; index++) {
    var longest = _textMeasure(headers[index]).toDouble();
    for (final row in data) {
      if (index >= row.length) continue;
      longest = max(longest, _textMeasure(row[index]).toDouble());
    }

    if (index == 0) {
      longest = max(longest, 3);
    } else if (dateColumns.contains(index)) {
      longest = max(longest, 9);
    } else if (numericColumns.contains(index)) {
      longest = max(longest, 9);
    } else {
      longest = max(longest, 7);
    }

    if (priorityTextColumns.contains(index)) {
      longest *= 1.2;
    } else if (!numericColumns.contains(index) &&
        !dateColumns.contains(index) &&
        index != 0) {
      longest *= 1.08;
    }

    final minWeight = index == 0
        ? 3.2
        : dateColumns.contains(index)
            ? 8.5
            : numericColumns.contains(index)
                ? 8.5
                : 7.0;
    final maxWeight = priorityTextColumns.contains(index)
        ? 34.0
        : numericColumns.contains(index)
            ? 16.0
            : dateColumns.contains(index)
                ? 11.5
                : 20.0;
    widths[index] = longest.clamp(minWeight, maxWeight).toDouble();
  }
  return widths;
}

int _textMeasure(String value) {
  final normalized = value.replaceAll('\r', '');
  return normalized
      .split('\n')
      .map((line) => line.trim().length)
      .fold<int>(0, (longest, len) => max(longest, len));
}

bool _isCombinedExpenseCategoryRow(
  Map<String, dynamic> row, {
  required bool combinedDriverCostColumns,
}) {
  return combinedDriverCostColumns &&
      '${row['__type']}' == 'Expense' &&
      (_toReportNum(row['__sangu_sopir']) > 0 ||
          _toReportNum(row['__gabungan']) > 0);
}

String _formatOptionalEditableAmount(
  Map<String, dynamic> row,
  String textKey,
  String valueKey,
  ReportAmountFormatter formatAmount,
) {
  final explicit = '${row[textKey] ?? ''}'.trim();
  final value = _toReportNum(row[valueKey]);
  if (explicit.isEmpty && value <= 0) return '';
  return formatAmount(value);
}

String _formatOptionalReportAmount(
  dynamic value,
  ReportAmountFormatter formatAmount,
) {
  final number = _toReportNum(value);
  if (!number.isFinite || number <= 0) return '';
  return formatAmount(number);
}

String _textOrFallback(dynamic value) {
  final text = '${value ?? '-'}'.trim();
  return text.isEmpty ? '-' : text;
}

double _toReportNum(dynamic value) {
  if (value is num) return value.toDouble();
  final cleaned = '${value ?? ''}'
      .replaceAll(RegExp(r'[^0-9,.-]'), '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  return double.tryParse(cleaned) ?? 0;
}
