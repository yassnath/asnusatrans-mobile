const invoiceCompanyCompactDetailRowLimit = 18;
const invoicePersonalCompactDetailRowLimit = 21;
const invoicePortraitExtraRows = 14;

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
  return compact ? compactLimit : (compactLimit * 2) + invoicePortraitExtraRows;
}

bool invoiceShouldUsePortraitLayout({
  required int detailRowCount,
  required bool isCompanyInvoice,
}) {
  return detailRowCount >
      invoiceCompactDetailRowLimit(isCompanyInvoice: isCompanyInvoice);
}
