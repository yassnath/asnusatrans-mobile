import '../../../core/utils/formatters.dart';
import 'invoice_detail_amount_logic.dart';
import 'invoice_pph_logic.dart';

String invoicePrintSelectorRowKey(Map<String, dynamic> item) {
  final sourceId = '${item['__source_invoice_id'] ?? item['id'] ?? ''}'.trim();
  final detailIndex = '${item['__detail_index'] ?? ''}'.trim();
  if (item['__invoice_list_expanded_detail'] == true &&
      sourceId.isNotEmpty &&
      detailIndex.isNotEmpty) {
    return '$sourceId:$detailIndex';
  }

  final id = '${item['id'] ?? ''}'.trim();
  if (id.isNotEmpty) return id;
  return '${item['nama_pelanggan'] ?? ''}|'
      '${item['tanggal'] ?? item['created_at'] ?? ''}|'
      '${item['lokasi_muat'] ?? ''}|'
      '${item['lokasi_bongkar'] ?? ''}';
}

bool isInvoiceFixedDetailKey(String value) {
  final cleaned = value.trim();
  final separator = cleaned.lastIndexOf(':');
  if (separator <= 0 || separator >= cleaned.length - 1) return false;
  final detailIndex = int.tryParse(cleaned.substring(separator + 1));
  return detailIndex != null && detailIndex >= 0;
}

String invoiceFixedSourceId(String value) {
  final cleaned = value.trim();
  if (!isInvoiceFixedDetailKey(cleaned)) return cleaned;
  return cleaned.substring(0, cleaned.lastIndexOf(':')).trim();
}

int? invoiceFixedDetailIndex(String value) {
  final cleaned = value.trim();
  if (!isInvoiceFixedDetailKey(cleaned)) return null;
  return int.tryParse(cleaned.substring(cleaned.lastIndexOf(':') + 1));
}

String invoiceFixedIdentityForRow(Map<String, dynamic> item) {
  final id = '${item['id'] ?? ''}'.trim();
  if (item['__invoice_list_expanded_detail'] != true) return id;

  final key = invoicePrintSelectorRowKey(item).trim();
  return key.isNotEmpty ? key : id;
}

List<Map<String, dynamic>> _invoicePrintSelectorDetailList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

String? _cleanInvoicePrintSelectorText(dynamic value) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty ||
      text.toLowerCase() == 'null' ||
      text.toLowerCase() == 'undefined') {
    return null;
  }
  return text;
}

dynamic _invoicePrintSelectorDetailValue(
  Map<String, dynamic> detail,
  Map<String, dynamic> row,
  String key,
) {
  final detailText = _cleanInvoicePrintSelectorText(detail[key]);
  if (detailText != null) return detail[key];
  return row[key];
}

double? _positiveInvoicePrintSelectorDetailNumber(
  Map<String, dynamic> detail,
  Map<String, dynamic> row,
  String key,
) {
  final detailNumber = parseInvoiceDetailAmount(detail[key]);
  if (detailNumber > 0) return detailNumber;
  final rowNumber = parseInvoiceDetailAmount(row[key]);
  return rowNumber > 0 ? rowNumber : null;
}

List<Map<String, dynamic>> expandInvoicePrintSelectorRows(
  Iterable<Map<String, dynamic>> rows,
) {
  final expanded = <Map<String, dynamic>>[];
  for (final source in rows) {
    final row = Map<String, dynamic>.from(source);
    final details = _invoicePrintSelectorDetailList(row['rincian']);
    if (details.length <= 1) {
      row['__print_selector_key'] = invoicePrintSelectorRowKey(row);
      expanded.add(row);
      continue;
    }

    final entity = Formatters.normalizeInvoiceEntity(
      row['invoice_entity'],
      invoiceNumber: row['no_invoice'],
      customerName: row['nama_pelanggan'],
    );
    final includePph = Formatters.isCompanyInvoiceEntity(entity);

    for (var index = 0; index < details.length; index++) {
      final detail = Map<String, dynamic>.from(details[index]);
      final subtotal = resolveInvoiceDetailExcelSubtotal(detail);
      final pph = includePph ? calculateInvoicePph2Percent(subtotal) : 0.0;
      final totalBayar =
          includePph ? calculateInvoiceTotalAfterPph(subtotal) : subtotal;
      final detailDate =
          _cleanInvoicePrintSelectorText(detail['armada_start_date']) ??
              _cleanInvoicePrintSelectorText(detail['tanggal']) ??
              _cleanInvoicePrintSelectorText(row['armada_start_date']) ??
              _cleanInvoicePrintSelectorText(row['tanggal']);
      final expandedRow = <String, dynamic>{
        ...row,
        '__invoice_list_expanded_detail': true,
        '__source_invoice_id': row['id'],
        '__detail_index': index,
        'rincian': [detail],
        'tanggal': detailDate ?? row['tanggal'],
        'armada_start_date': detailDate ?? row['armada_start_date'],
        'armada_end_date':
            _invoicePrintSelectorDetailValue(detail, row, 'armada_end_date') ??
                row['armada_end_date'],
        'lokasi_muat':
            _invoicePrintSelectorDetailValue(detail, row, 'lokasi_muat'),
        'lokasi_bongkar':
            _invoicePrintSelectorDetailValue(detail, row, 'lokasi_bongkar'),
        'muatan': _invoicePrintSelectorDetailValue(detail, row, 'muatan'),
        'nama_supir':
            _invoicePrintSelectorDetailValue(detail, row, 'nama_supir'),
        'armada_id': _invoicePrintSelectorDetailValue(detail, row, 'armada_id'),
        'armada_manual':
            _invoicePrintSelectorDetailValue(detail, row, 'armada_manual'),
        'armada_label':
            _invoicePrintSelectorDetailValue(detail, row, 'armada_label'),
        'plat_nomor':
            _invoicePrintSelectorDetailValue(detail, row, 'plat_nomor'),
        'no_polisi': _invoicePrintSelectorDetailValue(detail, row, 'no_polisi'),
        'tonase':
            _positiveInvoicePrintSelectorDetailNumber(detail, row, 'tonase'),
        'harga':
            _positiveInvoicePrintSelectorDetailNumber(detail, row, 'harga'),
        'total_biaya': subtotal,
        'pph': pph,
        'total_bayar': totalBayar,
      };
      expandedRow['__print_selector_key'] =
          invoicePrintSelectorRowKey(expandedRow);
      expanded.add(expandedRow);
    }
  }
  return expanded;
}

List<Map<String, dynamic>> resolveFixedInvoiceSourceRows({
  required Iterable<String> fixedIds,
  required Iterable<Map<String, dynamic>> sourceInvoices,
}) {
  final invoiceById = <String, Map<String, dynamic>>{
    for (final item in sourceInvoices)
      '${item['id'] ?? ''}'.trim(): Map<String, dynamic>.from(item),
  }..removeWhere((id, _) => id.isEmpty);
  final rows = <Map<String, dynamic>>[];

  for (final rawFixedId in fixedIds) {
    final fixedId = rawFixedId.trim();
    if (fixedId.isEmpty) continue;
    final sourceId = invoiceFixedSourceId(fixedId);
    final source = invoiceById[sourceId];
    if (source == null) continue;

    if (!isInvoiceFixedDetailKey(fixedId)) {
      rows.add(Map<String, dynamic>.from(source));
      continue;
    }

    final expandedRows = expandInvoicePrintSelectorRows([source]);
    for (final row in expandedRows) {
      if (invoiceFixedIdentityForRow(row) != fixedId) continue;
      rows.add({
        ...row,
        '__fixed_invoice_identity': fixedId,
      });
      break;
    }
  }

  return rows;
}
