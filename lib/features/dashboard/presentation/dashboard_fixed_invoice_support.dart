part of 'dashboard_page.dart';

extension _AdminFixedInvoiceSupport on _AdminFixedInvoiceViewState {
  double fixedInvoiceNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    final cleaned = value
        .toString()
        .replaceAll(RegExp(r'[^0-9,.-]'), '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  String _toDbDate(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '${value.year}-$mm-$dd';
  }

  List<Map<String, dynamic>> _toDetailList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  String? _extractPlateFromText(String value) {
    final match = RegExp(
      r'\b[A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{1,3}\b',
    ).firstMatch(value.toUpperCase());
    final plate = (match?.group(0) ?? '').trim();
    return plate.isEmpty ? null : plate;
  }

  String _normalizeTextKey(dynamic value) {
    return '${value ?? ''}'
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Color _invoiceEntityAccentColor(Map<String, dynamic> item) {
    return _resolveInvoiceEntityAccentColorShared(
      invoiceNumber: item['no_invoice'],
      customerName: item['nama_pelanggan'],
      invoiceEntity: item['invoice_entity'],
    );
  }

  bool _matchesCustomerKind(Map<String, dynamic> item) {
    if (_customerKind == 'all') return true;
    final entity = _resolveInvoiceEntityShared(
      invoiceNumber: item['no_invoice'],
      customerName: item['nama_pelanggan'],
      invoiceEntity: item['invoice_entity'],
    );
    switch (_customerKind) {
      case Formatters.invoiceEntityCvAnt:
        return entity == Formatters.invoiceEntityCvAnt;
      case Formatters.invoiceEntityPtAnt:
        return entity == Formatters.invoiceEntityPtAnt;
      case Formatters.invoiceEntityPersonal:
        return entity == Formatters.invoiceEntityPersonal;
      default:
        return true;
    }
  }

  int _extractInvoiceSequence(dynamic rawValue) {
    final raw = '${rawValue ?? ''}'.trim();
    final compactMatch = RegExp(
      r'^(?:CV\.ANT|BS)(\d{2})(\d{2})(\d{2,})$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (compactMatch != null) {
      return int.tryParse(compactMatch.group(3) ?? '') ?? 0;
    }
    final match = RegExp(r'(\d{1,4})').firstMatch(raw);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  _FixedInvoiceBatch _buildLegacyBatch(List<Map<String, dynamic>> items) {
    final sortedItems = items.toList()
      ..sort((a, b) {
        final seqCompare = _extractInvoiceSequence(
          b['no_invoice'],
        ).compareTo(_extractInvoiceSequence(a['no_invoice']));
        if (seqCompare != 0) return seqCompare;
        final aDate = Formatters.parseDate(
              a['updated_at'] ??
                  a['created_at'] ??
                  a['tanggal_kop'] ??
                  a['tanggal'],
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = Formatters.parseDate(
              b['updated_at'] ??
                  b['created_at'] ??
                  b['tanggal_kop'] ??
                  b['tanggal'],
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    final representative = sortedItems.first;
    final invoiceIds = sortedItems
        .map((item) => '${item['id'] ?? ''}'.trim())
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort();
    final createdAt =
        '${representative['updated_at'] ?? representative['created_at'] ?? ''}'
            .trim();
    final status = '${representative['status'] ?? 'Unpaid'}'.trim();
    final paidAt = '${representative['paid_at'] ?? ''}'.trim();
    return _FixedInvoiceBatch(
      batchId: 'legacy_${invoiceIds.join('_')}',
      invoiceIds: invoiceIds,
      invoiceNumber: Formatters.invoiceNumber(
        representative['no_invoice'],
        representative['tanggal_kop'] ?? representative['tanggal'],
        customerName: representative['nama_pelanggan'],
      ),
      customerName: '${representative['nama_pelanggan'] ?? ''}'.trim(),
      kopDate:
          '${representative['tanggal_kop'] ?? representative['tanggal'] ?? ''}'
              .trim(),
      kopLocation: '${representative['lokasi_kop'] ?? ''}'.trim(),
      status: status.isEmpty ? 'Unpaid' : status,
      paidAt: paidAt.isEmpty ? null : paidAt,
      createdAt:
          createdAt.isEmpty ? DateTime.now().toIso8601String() : createdAt,
    );
  }

  List<_FixedInvoiceBatch> _buildLegacyBatches(
    List<Map<String, dynamic>> items,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final customerKey = _normalizeTextKey(item['nama_pelanggan']);
      final kopDateKey =
          _normalizeTextKey(item['tanggal_kop'] ?? item['tanggal']);
      final kopLocationKey = _normalizeTextKey(item['lokasi_kop']);
      final modeKey = _resolveInvoiceEntityShared(
        invoiceNumber: item['no_invoice'],
        customerName: item['nama_pelanggan'],
      );
      final key = '$modeKey|$customerKey|$kopDateKey|$kopLocationKey';
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
    }
    return grouped.values.map(_buildLegacyBatch).toList();
  }
}
