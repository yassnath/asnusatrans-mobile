part of 'dashboard_page.dart';

class _AdminFixedInvoiceView extends StatefulWidget {
  const _AdminFixedInvoiceView({
    required this.repository,
    this.onDataChanged,
  });

  final DashboardRepository repository;
  final VoidCallback? onDataChanged;

  @override
  State<_AdminFixedInvoiceView> createState() => _AdminFixedInvoiceViewState();
}

class _AdminFixedInvoiceViewState extends State<_AdminFixedInvoiceView> {
  static const _fixedInvoicePrefsKey = 'fixed_invoice_ids_v1';
  static const _fixedInvoiceBatchPrefsKey = 'fixed_invoice_batches_v1';
  late Future<List<Map<String, dynamic>>> _future;
  final _search = TextEditingController();

  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  String _t(String id, String en) => _isEn ? en : id;

  double _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    final cleaned = value
        .toString()
        .replaceAll(RegExp(r'[^0-9,.-]'), '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
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

  int _extractInvoiceSequence(dynamic rawValue) {
    final raw = '${rawValue ?? ''}'.trim();
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
      final modeKey =
          '${item['no_invoice'] ?? ''}'.toUpperCase().contains('CV.ANT')
              ? 'company'
              : 'personal';
      final key = '$modeKey|$customerKey|$kopDateKey|$kopLocationKey';
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
    }
    return grouped.values.map(_buildLegacyBatch).toList();
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    showCvantPopup(
      context: context,
      type: error ? CvantPopupType.error : CvantPopupType.success,
      title: error ? _t('Error', 'Error') : _t('Success', 'Success'),
      message: msg,
    );
  }

  Future<Set<String>> _loadFixedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_fixedInvoicePrefsKey) ?? const <String>[])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<_FixedInvoiceBatch>> _loadRemoteFixedBatches() async {
    final rows = await widget.repository.fetchFixedInvoiceBatches();
    return rows
        .map(_FixedInvoiceBatch.fromJson)
        .whereType<_FixedInvoiceBatch>()
        .toList(growable: false);
  }

  Future<void> _upsertRemoteFixedBatch(_FixedInvoiceBatch batch) {
    return widget.repository.upsertFixedInvoiceBatch(
      batchId: batch.batchId,
      invoiceIds: batch.invoiceIds,
      invoiceNumber: batch.invoiceNumber,
      customerName: batch.customerName,
      kopDate: batch.kopDate,
      kopLocation: batch.kopLocation,
      createdAt: batch.createdAt,
    );
  }

  Future<void> _syncLocalCacheFromBatches(
    List<_FixedInvoiceBatch> batches,
  ) async {
    final ids = batches
        .expand((batch) => batch.invoiceIds)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    await _saveFixedIds(ids);
    await _saveFixedBatches(batches);
  }

  Future<void> _saveFixedIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final values = ids.toList()..sort();
    await prefs.setStringList(_fixedInvoicePrefsKey, values);
  }

  Future<List<_FixedInvoiceBatch>> _loadFixedBatches() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValues =
        prefs.getStringList(_fixedInvoiceBatchPrefsKey) ?? const <String>[];
    final batches = <_FixedInvoiceBatch>[];
    for (final raw in rawValues) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final batch = _FixedInvoiceBatch.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          if (batch != null) {
            batches.add(batch);
          }
        }
      } catch (_) {
        // Ignore malformed legacy values.
      }
    }
    return batches;
  }

  Future<void> _saveFixedBatches(List<_FixedInvoiceBatch> batches) async {
    final prefs = await SharedPreferences.getInstance();
    final values = batches
        .map((batch) => jsonEncode(batch.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_fixedInvoiceBatchPrefsKey, values);
  }

  String _buildRouteSummary(Map<String, dynamic> item) {
    final details = _toDetailList(item['rincian']);
    String route(dynamic muatValue, dynamic bongkarValue) {
      final muat = '${muatValue ?? ''}'.trim();
      final bongkar = '${bongkarValue ?? ''}'.trim();
      if (muat.isEmpty && bongkar.isEmpty) return '-';
      return '${muat.isEmpty ? '-' : muat}-${bongkar.isEmpty ? '-' : bongkar}';
    }

    final routes = <String>{};
    for (final row in details) {
      final value = route(row['lokasi_muat'], row['lokasi_bongkar']);
      if (value != '-') routes.add(value);
    }
    if (routes.isNotEmpty) return routes.join(' | ');
    return route(item['lokasi_muat'], item['lokasi_bongkar']);
  }

  String _buildDepartureSummary(Map<String, dynamic> item) {
    final details = _toDetailList(item['rincian']);
    final lines = <String>[];
    final seen = <String>{};

    String extractPlate(Map<String, dynamic> row) {
      final direct =
          '${row['plat_nomor'] ?? row['no_polisi'] ?? ''}'.toUpperCase().trim();
      if (direct.isNotEmpty && direct != '-') return direct;
      final manual = '${row['armada_manual'] ?? ''}'.trim();
      if (manual.isNotEmpty) {
        final parsed = _extractPlateFromText(manual);
        if (parsed != null) return parsed;
      }
      final label = '${row['armada_label'] ?? row['armada'] ?? ''}'.trim();
      final parsed = _extractPlateFromText(label);
      if (parsed != null) return parsed;
      return '-';
    }

    void pushLine(Map<String, dynamic> row, dynamic fallbackDate) {
      final date = row['armada_start_date'] ?? fallbackDate ?? '';
      final dateLabel = Formatters.dmy(date);
      final plate = extractPlate(row);
      final key = '$dateLabel|$plate'.toUpperCase();
      if (!seen.add(key)) return;
      lines.add('$dateLabel • $plate');
    }

    if (details.isNotEmpty) {
      for (final row in details) {
        pushLine(
          row,
          item['armada_start_date'] ?? item['tanggal_kop'] ?? item['tanggal'],
        );
      }
    } else {
      pushLine(
        item,
        item['armada_start_date'] ?? item['tanggal_kop'] ?? item['tanggal'],
      );
    }
    return lines.isEmpty ? '-' : lines.join(' | ');
  }

  String _resolveDisplayNumber(Map<String, dynamic> item) {
    final batchNumber = '${item['__batch_invoice_number'] ?? ''}'.trim();
    if (batchNumber.isNotEmpty) return batchNumber;
    return Formatters.invoiceNumber(
      item['no_invoice'],
      item['tanggal_kop'] ?? item['tanggal'],
      customerName: item['nama_pelanggan'],
    );
  }

  Future<void> _openBatchPreview(Map<String, dynamic> item) async {
    final sourceItems =
        (item['__batch_items'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
    final effectiveSourceItems =
        sourceItems.isNotEmpty ? sourceItems : <Map<String, dynamic>>[item];
    final invoiceNumber = _resolveDisplayNumber(item);
    final customerName = '${item['nama_pelanggan'] ?? '-'}';
    final total = _toNum(item['total_bayar'] ?? item['total_biaya']);
    final isCompanyInvoice = _resolveIsCompanyInvoiceShared(
      invoiceNumber: item['no_invoice'],
      customerName: item['nama_pelanggan'],
    );
    final invoiceNumberColor =
        isCompanyInvoice ? AppColors.success : AppColors.blue;
    final wantsPrint = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        return AlertDialog(
          title: Text(_t('Preview Fix Invoice', 'Fixed Invoice Preview')),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoiceNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: invoiceNumberColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${_t('Nama', 'Name')}: $customerName'),
                  const SizedBox(height: 2),
                  Text(
                    '${_t('Tanggal KOP', 'Header Date')}: ${Formatters.dmy(item['tanggal_kop'] ?? item['tanggal'])}',
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_t('Lokasi KOP', 'Header Location')}: ${item['lokasi_kop'] ?? '-'}',
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_t('Total', 'Total')}: ${Formatters.rupiah(total)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('Invoice yang digabung', 'Merged source invoices'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (effectiveSourceItems.isEmpty)
                    Text(
                      _t(
                        'Belum ada invoice sumber yang tersimpan.',
                        'No source invoices are available.',
                      ),
                      style: TextStyle(color: AppColors.textMutedFor(context)),
                    )
                  else
                    ...effectiveSourceItems.map((source) {
                      final sourceNumber = Formatters.invoiceNumber(
                        source['no_invoice'],
                        source['tanggal_kop'] ?? source['tanggal'],
                        customerName: source['nama_pelanggan'],
                      );
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: AppColors.cardBorder(context)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sourceNumber,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(_buildDepartureSummary(source)),
                            const SizedBox(height: 2),
                            Text(_buildRouteSummary(source)),
                            const SizedBox(height: 4),
                            Text(
                              Formatters.rupiah(
                                _toNum(
                                  source['total_bayar'] ??
                                      source['total_biaya'],
                                ),
                              ),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: CvantButtonStyles.outlined(
                context,
                color: AppColors.isLight(context)
                    ? AppColors.textSecondaryLight
                    : const Color(0xFFE2E8F0),
                borderColor: AppColors.neutralOutline,
              ),
              child: Text(_t('Tutup', 'Close')),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              style: CvantButtonStyles.filled(
                context,
                color: AppColors.success,
              ),
              icon: const Icon(Icons.print_outlined, size: 16),
              label: Text(_t('Print', 'Print')),
            ),
          ],
        );
      },
    );
    if (wantsPrint != true) return;
    if (!mounted) return;

    final merged = _mergeInvoiceItemsForPdf(
      effectiveSourceItems,
      invoiceNumberOverride: invoiceNumber,
      kopDateOverride: '${item['tanggal_kop'] ?? ''}'.trim(),
      kopLocationOverride: '${item['lokasi_kop'] ?? ''}'.trim(),
    );
    final printer = _DashboardInvoicePrintDelegate(
      context: context,
      repository: widget.repository,
      translate: _t,
      snack: _snack,
      isMounted: () => mounted,
    );
    await _printDashboardInvoicePdf(
      printer,
      merged.item,
      merged.details,
      invoiceNumberOverride: invoiceNumber,
      kopDateOverride: '${item['tanggal_kop'] ?? ''}'.trim(),
      kopLocationOverride: '${item['lokasi_kop'] ?? ''}'.trim(),
    );
  }

  Future<void> _returnToInvoiceList(Map<String, dynamic> item) async {
    final batchId = '${item['__batch_id'] ?? ''}'.trim();
    final idsToReturn =
        (item['__batch_invoice_ids'] as List<dynamic>? ?? const <dynamic>[])
            .map((id) => '$id'.trim())
            .where((id) => id.isNotEmpty)
            .toSet();
    final directId = '${item['id'] ?? ''}'.trim();
    if (idsToReturn.isEmpty && directId.isEmpty) return;
    if (idsToReturn.isEmpty && directId.isNotEmpty) {
      idsToReturn.add(directId);
    }
    try {
      if (batchId.isNotEmpty) {
        await widget.repository.deleteFixedInvoiceBatch(batchId);
      }
      final ids = await _loadFixedIds();
      if (idsToReturn.every((id) => !ids.contains(id))) return;
      ids.removeAll(idsToReturn);
      await _saveFixedIds(ids);
      final batches = await _loadFixedBatches();
      if (batchId.isNotEmpty) {
        batches.removeWhere((batch) => batch.batchId == batchId);
      } else {
        batches.removeWhere(
          (batch) => batch.invoiceIds.any(idsToReturn.contains),
        );
      }
      await _saveFixedBatches(batches);
      if (!mounted) return;
      _snack(
        _t(
          'Invoice dikembalikan ke daftar invoice.',
          'Invoice has been returned to invoice list.',
        ),
      );
      setState(() {
        _future = _load();
      });
      widget.onDataChanged?.call();
    } catch (e) {
      if (!mounted) return;
      _snack(
        e.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final invoices = await widget.repository.fetchInvoices();
    final localIds = await _loadFixedIds();
    final invoiceById = <String, Map<String, dynamic>>{
      for (final item in invoices)
        '${item['id'] ?? ''}'.trim(): Map<String, dynamic>.from(item),
    };
    var localBatches = await _loadFixedBatches();
    final rows = <Map<String, dynamic>>[];

    final legacyItems = invoices
        .where((item) {
          final id = '${item['id'] ?? ''}'.trim();
          return id.isNotEmpty &&
              localIds.contains(id) &&
              !localBatches.any((batch) => batch.invoiceIds.contains(id));
        })
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (legacyItems.isNotEmpty) {
      final legacyBatches = _buildLegacyBatches(legacyItems);
      if (legacyBatches.isNotEmpty) {
        final existingBatchIds =
            localBatches.map((batch) => batch.batchId).toSet();
        localBatches = [
          ...localBatches,
          ...legacyBatches.where(
            (batch) => !existingBatchIds.contains(batch.batchId),
          ),
        ];
        await _saveFixedBatches(localBatches);
      }
    }

    if (localBatches.isNotEmpty) {
      for (final batch in localBatches) {
        await _upsertRemoteFixedBatch(batch);
      }
    }

    final remoteBatches = await _loadRemoteFixedBatches();
    final batches = remoteBatches.isNotEmpty ? remoteBatches : localBatches;
    if (batches.isEmpty) return <Map<String, dynamic>>[];
    await _syncLocalCacheFromBatches(batches);

    for (final batch in batches) {
      final batchItems = batch.invoiceIds
          .map((id) => invoiceById[id])
          .whereType<Map<String, dynamic>>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      if (batchItems.isEmpty) continue;
      final total = batchItems.fold<double>(
        0,
        (sum, row) => sum + _toNum(row['total_bayar'] ?? row['total_biaya']),
      );
      final first = batchItems.first;
      rows.add({
        ...first,
        'id': batch.batchId,
        'no_invoice': batch.invoiceNumber.isEmpty
            ? first['no_invoice']
            : batch.invoiceNumber,
        'nama_pelanggan': batch.customerName.isEmpty
            ? first['nama_pelanggan']
            : batch.customerName,
        'tanggal_kop': (batch.kopDate ?? '').trim().isEmpty
            ? first['tanggal_kop']
            : batch.kopDate,
        'lokasi_kop': (batch.kopLocation ?? '').trim().isEmpty
            ? first['lokasi_kop']
            : batch.kopLocation,
        'total_bayar': total,
        '__batch_id': batch.batchId,
        '__batch_invoice_ids': batch.invoiceIds,
        '__batch_invoice_number': batch.invoiceNumber,
        '__batch_items': batchItems,
        '__batch_created_at': batch.createdAt,
      });
    }

    rows.sort((a, b) {
      final aDate = Formatters.parseDate(
            a['__batch_created_at'] ??
                a['tanggal_kop'] ??
                a['tanggal'] ??
                a['created_at'],
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = Formatters.parseDate(
            b['__batch_created_at'] ??
                b['tanggal_kop'] ??
                b['tanggal'] ??
                b['created_at'],
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError) {
          return _ErrorView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() {
              _future = _load();
            }),
          );
        }
        final rows = (snapshot.data ?? const <Map<String, dynamic>>[]).where(
          (item) {
            final q = _search.text.trim().toLowerCase();
            if (q.isEmpty) return true;
            return _flattenSearchText(item).toLowerCase().contains(q);
          },
        ).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _t(
                    'Cari invoice fix...',
                    'Search fixed invoice...',
                  ),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? _SimplePlaceholderView(
                      title: _t('Fix Invoice kosong', 'No fixed invoice'),
                      message: _t(
                        'Invoice yang dicetak dari tombol Cetak Invoice akan tampil di sini.',
                        'Invoices printed from the Print Invoice button will appear here.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      itemCount: rows.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == rows.length) {
                          return const _DashboardContentFooter();
                        }
                        final item = rows[index];
                        final number = _resolveDisplayNumber(item);
                        final total = _toNum(
                          item['total_bayar'] ?? item['total_biaya'],
                        );
                        final customerTypeLabel =
                            _resolveIsCompanyInvoiceShared(
                          invoiceNumber: item['no_invoice'],
                          customerName: item['nama_pelanggan'],
                        )
                                ? _t('Perusahaan', 'Company')
                                : _t('Pribadi', 'Personal');
                        final isCompanyInvoice =
                            _resolveIsCompanyInvoiceShared(
                          invoiceNumber: item['no_invoice'],
                          customerName: item['nama_pelanggan'],
                        );
                        final invoiceNumberColor = isCompanyInvoice
                            ? AppColors.success
                            : AppColors.blue;
                        final customerTypeColor = isCompanyInvoice
                            ? AppColors.success
                            : AppColors.blue;
                        final batchItems =
                            (item['__batch_items'] as List<dynamic>? ??
                                    const <dynamic>[])
                                .whereType<Map>()
                                .map((row) => Map<String, dynamic>.from(row))
                                .toList();
                        final mergedCount = batchItems.length;
                        return _PanelCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      number,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: invoiceNumberColor,
                                      ),
                                    ),
                                  ),
                                  _StatusPill(
                                      label: '${item['status'] ?? '-'}'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_t('Tanggal', 'Date')}: ${Formatters.dmy(item['tanggal_kop'] ?? item['tanggal'] ?? item['created_at'])}',
                                style: TextStyle(
                                  color: AppColors.textMutedFor(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_t('Nama', 'Name')}: ${item['nama_pelanggan'] ?? '-'}',
                                style: TextStyle(
                                  color: AppColors.textMutedFor(context),
                                ),
                              ),
                              if (mergedCount > 1) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${_t('Gabungan', 'Merged')}: $mergedCount ${_t('invoice', 'invoices')}',
                                  style: TextStyle(
                                    color: AppColors.textMutedFor(context),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                Formatters.rupiah(total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      customerTypeLabel,
                                      style: TextStyle(
                                        color: customerTypeColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _openBatchPreview(item),
                                            style: CvantButtonStyles.outlined(
                                              context,
                                              color: AppColors.warning,
                                              borderColor: AppColors.warning,
                                            ),
                                            icon: const Icon(Icons.visibility,
                                                size: 16),
                                            label: Text(_t('Preview', 'Preview')),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              final ok =
                                                  await showCvantConfirmPopup(
                                                context: context,
                                                title: _t(
                                                  'Kembalikan Invoice',
                                                  'Return Invoice',
                                                ),
                                                message: _t(
                                                  'Kembalikan invoice ini ke daftar invoice?',
                                                  'Return this invoice to invoice list?',
                                                ),
                                                type: CvantPopupType.info,
                                                cancelLabel:
                                                    _t('Batal', 'Cancel'),
                                                confirmLabel: _t(
                                                  'Kembalikan',
                                                  'Return',
                                                ),
                                              );
                                              if (!ok) return;
                                              await _returnToInvoiceList(item);
                                            },
                                            style: CvantButtonStyles.outlined(
                                              context,
                                              color: AppColors.neutralOutline,
                                              borderColor:
                                                  AppColors.neutralOutline,
                                            ),
                                            icon:
                                                const Icon(Icons.undo, size: 16),
                                            label: Text(
                                              _t(
                                                'Kembalikan ke List',
                                                'Return to List',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
