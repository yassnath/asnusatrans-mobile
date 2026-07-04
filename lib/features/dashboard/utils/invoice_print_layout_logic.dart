const invoiceCompanyCompactDetailRowLimit = 18;
const invoicePersonalCompactDetailRowLimit = 21;
const invoiceCompanyPortraitExtraRows = 12;
const invoicePersonalPortraitExtraRows = 9;

int invoiceCompactDetailRowLimit({required bool isCompanyInvoice}) {
  return isCompanyInvoice
      ? invoiceCompanyCompactDetailRowLimit
      : invoicePersonalCompactDetailRowLimit;
}

int invoiceRowsPerSheet({
  required bool compact,
  required bool isCompanyInvoice,
}) {
  final compactLimit = invoiceCompactDetailRowLimit(
    isCompanyInvoice: isCompanyInvoice,
  );
  final portraitExtraRows = isCompanyInvoice
      ? invoiceCompanyPortraitExtraRows
      : invoicePersonalPortraitExtraRows;
  return compact ? compactLimit : (compactLimit * 2) + portraitExtraRows;
}

bool invoiceShouldUsePortraitLayout({
  required int detailRowCount,
  required bool isCompanyInvoice,
}) {
  return detailRowCount >
      invoiceCompactDetailRowLimit(isCompanyInvoice: isCompanyInvoice);
}
