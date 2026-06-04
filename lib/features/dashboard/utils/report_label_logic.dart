import '../../../core/utils/formatters.dart';

String _pickReportText({
  required bool isEnglish,
  required String id,
  required String en,
}) {
  return isEnglish ? en : id;
}

String _reportCustomerKindSuffix({
  required String customerKind,
  required bool isEnglish,
}) {
  if (customerKind == Formatters.invoiceEntityCvAnt) return 'CV. ANT';
  if (customerKind == Formatters.invoiceEntityPtAnt) return 'PT. ANT';
  if (customerKind == Formatters.invoiceEntityPersonal) {
    return _pickReportText(
      isEnglish: isEnglish,
      id: 'Pribadi',
      en: 'Personal',
    );
  }
  return '';
}

String buildReportHeaderLabel({
  required bool includeIncome,
  required bool includeExpense,
  required String customerKind,
  required bool incomeByInvoice,
  required bool isEnglish,
}) {
  if (includeIncome && includeExpense) {
    return _pickReportText(
      isEnglish: isEnglish,
      id: 'Laporan (Pemasukkan Fix Invoice dan Pengeluaran)',
      en: 'Report (Fixed Invoice Income and Expense)',
    );
  }

  final suffix = _reportCustomerKindSuffix(
    customerKind: customerKind,
    isEnglish: isEnglish,
  );
  final suffixText = suffix.isEmpty ? '' : ' ($suffix)';

  if (includeIncome) {
    if (incomeByInvoice) {
      return _pickReportText(
        isEnglish: isEnglish,
        id: 'Laporan Pemasukkan Fix Invoice per Invoice$suffixText',
        en: 'Fixed Invoice Income Report by Invoice$suffixText',
      );
    }
    return _pickReportText(
      isEnglish: isEnglish,
      id: 'Laporan Pemasukkan Fix Invoice$suffixText',
      en: 'Fixed Invoice Income Report$suffixText',
    );
  }

  return _pickReportText(
    isEnglish: isEnglish,
    id: 'Laporan Pengeluaran$suffixText',
    en: 'Expense Report$suffixText',
  );
}

String buildReportScopeLabel({
  required bool includeIncome,
  required bool includeExpense,
  required bool incomeByInvoice,
  required bool isEnglish,
}) {
  if (includeIncome && includeExpense) {
    return _pickReportText(
      isEnglish: isEnglish,
      id: 'Income Fix Invoice + Expense',
      en: 'Fixed Invoice Income + Expense',
    );
  }
  if (includeIncome) {
    if (incomeByInvoice) {
      return _pickReportText(
        isEnglish: isEnglish,
        id: 'Income Fix Invoice per Invoice',
        en: 'Fixed Invoice Income by Invoice',
      );
    }
    return _pickReportText(
      isEnglish: isEnglish,
      id: 'Income Fix Invoice',
      en: 'Fixed Invoice Income',
    );
  }
  return _pickReportText(
    isEnglish: isEnglish,
    id: 'Expense',
    en: 'Expense',
  );
}

String buildReportPreviewInfo({
  required String scopeLabel,
  required String periodLabel,
  required bool includeIncome,
  required bool includeExpense,
  required bool includeDriverCostColumns,
  required bool incomeByInvoice,
  required int rowCount,
  required bool isEnglish,
}) {
  final periodText = _pickReportText(
    isEnglish: isEnglish,
    id: 'Periode',
    en: 'Period',
  );
  final orientationText = _pickReportText(
    isEnglish: isEnglish,
    id: 'Orientasi',
    en: 'Orientation',
  );
  final orientationLabel = _pickReportText(
    isEnglish: isEnglish,
    id: 'Portrait',
    en: 'Portrait',
  );
  final driverCostColumnInfo =
      includeIncome && includeExpense && includeDriverCostColumns
          ? ' • ${_pickReportText(
              isEnglish: isEnglish,
              id: 'Detail: Fix Invoice',
              en: 'Detail: Fixed Invoice',
            )}'
          : '';
  final rowLabel = incomeByInvoice
      ? _pickReportText(isEnglish: isEnglish, id: 'invoice', en: 'invoices')
      : _pickReportText(isEnglish: isEnglish, id: 'data', en: 'rows');

  return '$scopeLabel • $periodText: $periodLabel • $orientationText: '
      '$orientationLabel$driverCostColumnInfo • $rowCount $rowLabel';
}
