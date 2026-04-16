part of 'dashboard_page.dart';

class _InvoicePrintOverrides {
  const _InvoicePrintOverrides({
    required this.invoiceNumber,
    this.kopDate,
    this.kopLocation,
  });

  final String invoiceNumber;
  final String? kopDate;
  final String? kopLocation;
}

class _InvoicePrintGroup {
  const _InvoicePrintGroup({
    required this.id,
    required this.items,
  });

  final String id;
  final List<Map<String, dynamic>> items;

  Map<String, dynamic> get baseItem => items.first;
}

class _FixedInvoiceBatch {
  const _FixedInvoiceBatch({
    required this.batchId,
    required this.invoiceIds,
    required this.invoiceNumber,
    required this.customerName,
    this.kopDate,
    this.kopLocation,
    this.status = 'Unpaid',
    this.paidAt,
    this.createdAt,
  });

  final String batchId;
  final List<String> invoiceIds;
  final String invoiceNumber;
  final String customerName;
  final String? kopDate;
  final String? kopLocation;
  final String status;
  final String? paidAt;
  final String? createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'batch_id': batchId,
        'invoice_ids': invoiceIds,
        'invoice_number': (() {
          final normalized = Formatters.invoiceNumber(
            invoiceNumber,
            kopDate ?? createdAt,
            customerName: customerName,
          );
          return normalized == '-' ? invoiceNumber : normalized;
        })(),
        'customer_name': customerName,
        'kop_date': kopDate,
        'kop_location': kopLocation,
        'status': status,
        'paid_at': paidAt,
        'created_at': createdAt,
      };

  static _FixedInvoiceBatch? fromJson(Map<String, dynamic> map) {
    final batchId = '${map['batch_id'] ?? ''}'.trim();
    final customerName = '${map['customer_name'] ?? ''}'.trim();
    final kopDate = '${map['kop_date'] ?? ''}'.trim();
    final createdAt = '${map['created_at'] ?? ''}'.trim();
    final rawInvoiceNumber = '${map['invoice_number'] ?? ''}'.trim();
    final status = '${map['status'] ?? 'Unpaid'}'.trim();
    final paidAt = '${map['paid_at'] ?? ''}'.trim();
    final normalizedInvoiceNumber = rawInvoiceNumber.isEmpty
        ? rawInvoiceNumber
        : (() {
            final normalized = Formatters.invoiceNumber(
              rawInvoiceNumber,
              kopDate.isEmpty ? createdAt : kopDate,
              customerName: customerName,
            );
            return normalized == '-' ? rawInvoiceNumber : normalized;
          })();
    final invoiceIds = (map['invoice_ids'] as List<dynamic>? ?? const [])
        .map((id) => '$id'.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (batchId.isEmpty || invoiceIds.isEmpty) return null;
    return _FixedInvoiceBatch(
      batchId: batchId,
      invoiceIds: invoiceIds,
      invoiceNumber: normalizedInvoiceNumber,
      customerName: customerName,
      kopDate: kopDate,
      kopLocation: '${map['kop_location'] ?? ''}'.trim(),
      status: status.isEmpty ? 'Unpaid' : status,
      paidAt: paidAt.isEmpty ? null : paidAt,
      createdAt: createdAt,
    );
  }
}

String _resolveInvoiceEntityShared({
  dynamic invoiceEntity,
  dynamic invoiceNumber,
  dynamic customerName,
  bool fallback = true,
}) {
  final explicitEntity = '${invoiceEntity ?? ''}'.trim();
  final entityFromNumber = Formatters.invoiceEntityFromInvoiceNumber(
      '${invoiceNumber ?? ''}'.trim());
  return Formatters.normalizeInvoiceEntity(
    explicitEntity.isNotEmpty ? explicitEntity : entityFromNumber,
    invoiceNumber: invoiceNumber,
    customerName: customerName,
    isCompany: fallback,
  );
}

bool _resolveIsCompanyInvoiceShared({
  dynamic invoiceEntity,
  dynamic invoiceNumber,
  dynamic customerName,
  bool fallback = true,
}) {
  final entity = _resolveInvoiceEntityShared(
    invoiceEntity: invoiceEntity,
    invoiceNumber: invoiceNumber,
    customerName: customerName,
    fallback: fallback,
  );
  return Formatters.isCompanyInvoiceEntity(entity);
}

String _resolveInvoiceEntityLabelShared({
  dynamic invoiceEntity,
  dynamic invoiceNumber,
  dynamic customerName,
}) {
  final entity = _resolveInvoiceEntityShared(
    invoiceEntity: invoiceEntity,
    invoiceNumber: invoiceNumber,
    customerName: customerName,
  );
  return Formatters.invoiceEntityLabel(entity);
}

Color _resolveInvoiceEntityAccentColorShared({
  dynamic invoiceEntity,
  dynamic invoiceNumber,
  dynamic customerName,
}) {
  final entity = _resolveInvoiceEntityShared(
    invoiceEntity: invoiceEntity,
    invoiceNumber: invoiceNumber,
    customerName: customerName,
  );
  return AppColors.invoiceEntityAccent(entity);
}

String _displayInvoiceNumberShared(String number) {
  return number.trim().isEmpty ? '-' : number.trim();
}
