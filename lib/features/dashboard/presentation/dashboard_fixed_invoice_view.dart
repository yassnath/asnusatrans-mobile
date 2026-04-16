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
  static const _fixedInvoiceNormalizationDoneKey =
      'fixed_invoice_normalization_done_v1';
  late Future<List<Map<String, dynamic>>> _future;
  final _search = TextEditingController();
  bool _backgroundInvoiceNumberNormalizationRunning = false;
  late int _selectedMonth;
  late int _selectedYear;
  String _customerKind = 'all';

  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  String _t(String id, String en) => _isEn ? en : id;

  ButtonStyle _mobileActionButtonStyle({
    required BuildContext context,
    required Color color,
  }) {
    return CvantButtonStyles.outlined(
      context,
      color: color,
      borderColor: color,
    ).copyWith(
      minimumSize: const WidgetStatePropertyAll(Size(44, 38)),
      maximumSize: const WidgetStatePropertyAll(Size(44, 38)),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _future = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_normalizeInvoiceNumbersInBackground());
    });
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

  Future<void> _normalizeInvoiceNumbersInBackground() async {
    if (_backgroundInvoiceNumberNormalizationRunning) return;
    _backgroundInvoiceNumberNormalizationRunning = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_fixedInvoiceNormalizationDoneKey) == true) {
        return;
      }
      final report = await widget.repository.normalizeLegacyInvoiceNumbers();
      await prefs.setBool(_fixedInvoiceNormalizationDoneKey, true);
      if (report.updatedInvoices <= 0 && report.updatedFixedBatches <= 0) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _future = _load();
      });
    } catch (_) {
      // Best effort: halaman fix invoice tetap bisa dibuka walau migrasi gagal.
    } finally {
      _backgroundInvoiceNumberNormalizationRunning = false;
    }
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
      status: batch.status,
      paidAt: batch.paidAt,
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

  String _extractPreviewPlate(Map<String, dynamic> row) {
    final direct =
        '${row['plat_nomor'] ?? row['no_polisi'] ?? ''}'.toUpperCase().trim();
    if (direct.isNotEmpty && direct != '-') return direct;

    for (final key in const ['armada_manual', 'armada_label', 'armada']) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isEmpty) continue;
      final parsed = _extractPlateFromText(value);
      if (parsed != null) return parsed;
      if (key == 'armada_manual') return value;
    }

    return '-';
  }

  Map<String, dynamic> _fallbackPreviewDetailRow(
    Map<String, dynamic> item,
  ) {
    return <String, dynamic>{
      'armada_start_date': item['armada_start_date'] ?? item['tanggal'],
      'armada_end_date': item['armada_end_date'],
      'tanggal': item['tanggal'],
      'plat_nomor': item['plat_nomor'] ?? item['no_polisi'],
      'no_polisi': item['no_polisi'] ?? item['plat_nomor'],
      'armada_manual': item['armada_manual'],
      'armada_label': item['armada_label'] ?? item['armada'],
      'nama_supir': item['nama_supir'] ?? item['supir'],
      'muatan': item['muatan'],
      'lokasi_muat': item['lokasi_muat'],
      'lokasi_bongkar': item['lokasi_bongkar'],
      'tonase': item['tonase'],
      'harga': item['harga'],
      'subtotal': item['subtotal'] ?? item['total_biaya'],
    };
  }

  List<Map<String, dynamic>> _buildPreviewDetailRows(
    Map<String, dynamic> item,
  ) {
    final rows = _toDetailList(item['rincian']);
    final detailRows = rows.isNotEmpty
        ? rows.map((row) => Map<String, dynamic>.from(row)).toList()
        : <Map<String, dynamic>>[_fallbackPreviewDetailRow(item)];

    detailRows.sort((a, b) {
      final aDate = Formatters.parseDate(
            a['armada_start_date'] ?? a['tanggal'],
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = Formatters.parseDate(
            b['armada_start_date'] ?? b['tanggal'],
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final byDate = aDate.compareTo(bDate);
      if (byDate != 0) return byDate;
      return _extractPreviewPlate(a).compareTo(_extractPreviewPlate(b));
    });

    return detailRows;
  }

  double _previewDetailSubtotal(Map<String, dynamic> row) {
    for (final key in const ['subtotal', 'total', 'total_biaya', 'jumlah']) {
      final value = fixedInvoiceNum(row[key]);
      if (value > 0) return value;
    }
    return fixedInvoiceNum(row['tonase']) * fixedInvoiceNum(row['harga']);
  }

  String _resolveDisplayNumber(Map<String, dynamic> item) {
    final batchNumber = '${item['__batch_invoice_number'] ?? ''}'.trim();
    if (batchNumber.isNotEmpty) {
      final normalized = Formatters.invoiceNumber(
        batchNumber,
        item['tanggal_kop'] ?? item['tanggal'],
        customerName: item['nama_pelanggan'],
      );
      return normalized == '-' ? batchNumber : normalized;
    }
    return Formatters.invoiceNumber(
      item['no_invoice'],
      item['tanggal_kop'] ?? item['tanggal'],
      customerName: item['nama_pelanggan'],
    );
  }

  Future<void> _editFixedInvoiceStatus(Map<String, dynamic> item) async {
    final batchId = '${item['__batch_id'] ?? item['id'] ?? ''}'.trim();
    if (batchId.isEmpty) {
      _snack(
        _t('Batch invoice tidak ditemukan.', 'Batch invoice not found.'),
        error: true,
      );
      return;
    }
    final rawStatus = '${item['status'] ?? 'Unpaid'}'.trim();
    final initialStatus = rawStatus.isEmpty ? 'Unpaid' : rawStatus;
    final rawPaidAt = '${item['paid_at'] ?? ''}'.trim();
    final initialPaidDate =
        rawPaidAt.isEmpty ? null : Formatters.parseDate(rawPaidAt);

    final result = await showDialog<Map<String, String?>>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        var selectedStatus = initialStatus;
        DateTime? selectedPaidDate = initialPaidDate;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickPaidDate() async {
              final initial = selectedPaidDate ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: initial,
              );
              if (picked == null) return;
              setDialogState(() {
                selectedPaidDate = picked;
              });
            }

            String paidDateLabel() {
              if (selectedPaidDate == null) return '-';
              return Formatters.dmy(selectedPaidDate);
            }

            return AlertDialog(
              title: Text(_t('Edit Status Fix Invoice', 'Edit Fixed Invoice')),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CvantDropdownField<String>(
                      initialValue: selectedStatus,
                      decoration: InputDecoration(
                        labelText: _t('Status', 'Status'),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Unpaid',
                          child: Text('Unpaid'),
                        ),
                        DropdownMenuItem(
                          value: 'Paid',
                          child: Text('Paid'),
                        ),
                      ],
                      onChanged: (value) => setDialogState(() {
                        selectedStatus = value ?? 'Unpaid';
                        if (selectedStatus != 'Paid') {
                          selectedPaidDate = null;
                        } else {
                          selectedPaidDate ??= DateTime.now();
                        }
                      }),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: selectedStatus == 'Paid' ? pickPaidDate : null,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: _t('Tanggal Pelunasan', 'Payment Date'),
                        ),
                        child: Text(paidDateLabel()),
                      ),
                    ),
                  ],
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
                  child: Text(_t('Batal', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final paidAt =
                        selectedStatus == 'Paid' && selectedPaidDate != null
                            ? _toDbDate(selectedPaidDate!)
                            : null;
                    Navigator.pop(context, {
                      'status': selectedStatus,
                      'paid_at': paidAt,
                    });
                  },
                  style: CvantButtonStyles.filled(
                    context,
                    color: AppColors.success,
                  ),
                  child: Text(_t('Simpan', 'Save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;
    final newStatus = (result['status'] ?? 'Unpaid').toString().trim();
    final newPaidAt = (result['paid_at'] ?? '').toString().trim();

    try {
      final batches = await _loadFixedBatches();
      final index = batches.indexWhere((batch) => batch.batchId == batchId);
      if (index >= 0) {
        final current = batches[index];
        final updated = _FixedInvoiceBatch(
          batchId: current.batchId,
          invoiceIds: current.invoiceIds,
          invoiceNumber: current.invoiceNumber,
          customerName: current.customerName,
          kopDate: current.kopDate,
          kopLocation: current.kopLocation,
          status: newStatus.isEmpty ? 'Unpaid' : newStatus,
          paidAt: newPaidAt.isEmpty ? null : newPaidAt,
          createdAt: current.createdAt,
        );
        batches[index] = updated;
        await _saveFixedBatches(batches);
        await _upsertRemoteFixedBatch(updated);
      }
      if (!mounted) return;
      _snack(
        _t('Status fix invoice diperbarui.', 'Fixed invoice status updated.'),
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
    final total = fixedInvoiceNum(item['total_bayar'] ?? item['total_biaya']);
    final invoiceEntityLabel = _resolveInvoiceEntityLabelShared(
      invoiceNumber: item['no_invoice'],
      customerName: item['nama_pelanggan'],
    );
    final invoiceNumberColor = _invoiceEntityAccentColor(item);
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
                  Text('${_t('Tipe', 'Type')}: $invoiceEntityLabel'),
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
                  const SizedBox(height: 2),
                  Text(
                    '${_t('Status', 'Status')}: ${item['status'] ?? '-'}',
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_t('Tanggal Pelunasan', 'Payment Date')}: ${((item['paid_at'] ?? '').toString().trim().isEmpty ? '-' : Formatters.dmy(item['paid_at']))}',
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
                      final detailRows = _buildPreviewDetailRows(source);
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
                                fixedInvoiceNum(
                                  source['total_bayar'] ??
                                      source['total_biaya'],
                                ),
                              ),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _t(
                                'Detail keberangkatan armada',
                                'Armada departure details',
                              ),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            ...detailRows.asMap().entries.map((entry) {
                              final index = entry.key;
                              final detail = entry.value;
                              final startDate = detail['armada_start_date'] ??
                                  detail['tanggal'] ??
                                  source['tanggal'];
                              final endDate = detail['armada_end_date'];
                              final startLabel = Formatters.dmy(startDate);
                              final endLabel = '${endDate ?? ''}'.trim().isEmpty
                                  ? ''
                                  : Formatters.dmy(endDate);
                              final dateLabel =
                                  endLabel.isEmpty || endLabel == startLabel
                                      ? startLabel
                                      : '$startLabel - $endLabel';
                              final driver =
                                  '${detail['nama_supir'] ?? detail['supir'] ?? '-'}'
                                      .trim();
                              final muatan =
                                  '${detail['muatan'] ?? '-'}'.trim();
                              final muat = _normalizeInvoicePrintLocationLabel(
                                detail['lokasi_muat'],
                              );
                              final bongkar =
                                  _normalizeInvoicePrintLocationLabel(
                                detail['lokasi_bongkar'],
                              );
                              final tonase = fixedInvoiceNum(detail['tonase']);
                              final harga = fixedInvoiceNum(detail['harga']);
                              final subtotal = _previewDetailSubtotal(detail);

                              return Container(
                                width: double.infinity,
                                margin: EdgeInsets.only(
                                  bottom:
                                      index == detailRows.length - 1 ? 0 : 6,
                                ),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSoft(context),
                                  border: Border.all(
                                    color: AppColors.cardBorder(context),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${index + 1}. $dateLabel • ${_extractPreviewPlate(detail)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          Formatters.rupiah(subtotal),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${driver.isEmpty ? '-' : driver}: $muat-$bongkar',
                                      style: TextStyle(
                                        color: AppColors.textMutedFor(context),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        '${_t('Muatan', 'Load')}: ${muatan.isEmpty ? '-' : muatan}',
                                        if (tonase > 0)
                                          '${_t('Tonase', 'Tonnage')}: ${formatInvoiceTonase(tonase)}',
                                        if (harga > 0)
                                          '${_t('Harga/ton', 'Price/ton')}: ${formatInvoiceHargaPerTon(harga)}',
                                      ].join(' • '),
                                      style: TextStyle(
                                        color: AppColors.textMutedFor(context),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
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
    final payload = await Future.wait<dynamic>([
      _loadFixedIds(),
      _loadFixedBatches(),
      _loadRemoteFixedBatches(),
    ]);
    final localIds = payload[0] as Set<String>;
    var localBatches = payload[1] as List<_FixedInvoiceBatch>;
    final initialRemoteBatches = payload[2] as List<_FixedInvoiceBatch>;
    final rows = <Map<String, dynamic>>[];

    final invoiceIdsToFetch = <String>{
      ...localIds,
      for (final batch in localBatches) ...batch.invoiceIds,
      for (final batch in initialRemoteBatches) ...batch.invoiceIds,
    };
    final invoices =
        await widget.repository.fetchInvoicesByIds(invoiceIdsToFetch);
    final invoiceById = <String, Map<String, dynamic>>{
      for (final item in invoices)
        '${item['id'] ?? ''}'.trim(): Map<String, dynamic>.from(item),
    };

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
      await Future.wait(localBatches.map(_upsertRemoteFixedBatch));
    }

    final remoteBatches = localBatches.isEmpty
        ? initialRemoteBatches
        : await _loadRemoteFixedBatches();
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
        (sum, row) =>
            sum + fixedInvoiceNum(row['total_bayar'] ?? row['total_biaya']),
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
        'status':
            batch.status.isEmpty ? (first['status'] ?? 'Unpaid') : batch.status,
        'paid_at': batch.paidAt,
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

  bool _matchesFixedInvoiceFilters(Map<String, dynamic> item) {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty && !_flattenSearchText(item).toLowerCase().contains(q)) {
      return false;
    }

    final date = Formatters.parseDate(
      item['tanggal_kop'] ??
          item['tanggal'] ??
          item['__batch_created_at'] ??
          item['created_at'],
    );
    if (date == null) return false;
    if (date.month != _selectedMonth || date.year != _selectedYear) {
      return false;
    }

    return _matchesCustomerKind(item);
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
        final rows = (snapshot.data ?? const <Map<String, dynamic>>[])
            .where(_matchesFixedInvoiceFilters)
            .toList();
        final now = DateTime.now();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                children: [
                  TextField(
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _customerKind = 'all'),
                          style: CvantButtonStyles.outlined(
                            context,
                            color: _customerKind == 'all'
                                ? AppColors.blue
                                : AppColors.textMutedFor(context),
                            borderColor: _customerKind == 'all'
                                ? AppColors.blue
                                : AppColors.cardBorder(context),
                          ),
                          child: Text(_t('Semua', 'All')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() =>
                              _customerKind = Formatters.invoiceEntityCvAnt),
                          style: CvantButtonStyles.outlined(
                            context,
                            color:
                                _customerKind == Formatters.invoiceEntityCvAnt
                                    ? AppColors.success
                                    : AppColors.textMutedFor(context),
                            borderColor:
                                _customerKind == Formatters.invoiceEntityCvAnt
                                    ? AppColors.success
                                    : AppColors.cardBorder(context),
                          ),
                          child: const Text('CV. ANT'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() =>
                              _customerKind = Formatters.invoiceEntityPtAnt),
                          style: CvantButtonStyles.outlined(
                            context,
                            color:
                                _customerKind == Formatters.invoiceEntityPtAnt
                                    ? AppColors.cyan
                                    : AppColors.textMutedFor(context),
                            borderColor:
                                _customerKind == Formatters.invoiceEntityPtAnt
                                    ? AppColors.cyan
                                    : AppColors.cardBorder(context),
                          ),
                          child: const Text('PT. ANT'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() =>
                              _customerKind = Formatters.invoiceEntityPersonal),
                          style: CvantButtonStyles.outlined(
                            context,
                            color: _customerKind ==
                                    Formatters.invoiceEntityPersonal
                                ? AppColors.warning
                                : AppColors.textMutedFor(context),
                            borderColor: _customerKind ==
                                    Formatters.invoiceEntityPersonal
                                ? AppColors.warning
                                : AppColors.cardBorder(context),
                          ),
                          child: Text(_t('Pribadi', 'Personal')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CvantDropdownField<int>(
                          initialValue: _selectedMonth,
                          decoration: InputDecoration(
                            labelText: _t('Bulan', 'Month'),
                          ),
                          items: List.generate(
                            12,
                            (index) => DropdownMenuItem<int>(
                              value: index + 1,
                              child: Text(
                                _t(
                                  const [
                                    'Januari',
                                    'Februari',
                                    'Maret',
                                    'April',
                                    'Mei',
                                    'Juni',
                                    'Juli',
                                    'Agustus',
                                    'September',
                                    'Oktober',
                                    'November',
                                    'Desember',
                                  ][index],
                                  const [
                                    'January',
                                    'February',
                                    'March',
                                    'April',
                                    'May',
                                    'June',
                                    'July',
                                    'August',
                                    'September',
                                    'October',
                                    'November',
                                    'December',
                                  ][index],
                                ),
                              ),
                            ),
                          ),
                          onChanged: (value) => setState(
                            () => _selectedMonth = value ?? now.month,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CvantDropdownField<int>(
                          initialValue: _selectedYear,
                          decoration: InputDecoration(
                            labelText: _t('Tahun', 'Year'),
                          ),
                          items: List.generate(
                            6,
                            (index) {
                              final year = now.year - index;
                              return DropdownMenuItem<int>(
                                value: year,
                                child: Text('$year'),
                              );
                            },
                          ),
                          onChanged: (value) => setState(
                            () => _selectedYear = value ?? now.year,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
                        final total = fixedInvoiceNum(
                          item['total_bayar'] ?? item['total_biaya'],
                        );
                        final customerTypeLabel =
                            _resolveInvoiceEntityLabelShared(
                          invoiceNumber: item['no_invoice'],
                          customerName: item['nama_pelanggan'],
                        );
                        final invoiceNumberColor =
                            _invoiceEntityAccentColor(item);
                        final customerTypeColor =
                            _invoiceEntityAccentColor(item);
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
                                          Tooltip(
                                            message: _t(
                                              'Edit Status',
                                              'Edit Status',
                                            ),
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  _editFixedInvoiceStatus(item),
                                              style: _mobileActionButtonStyle(
                                                context: context,
                                                color: AppColors.success,
                                              ),
                                              child: const Icon(
                                                Icons.edit_note_outlined,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                          Tooltip(
                                            message: _t('Preview', 'Preview'),
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  _openBatchPreview(item),
                                              style: _mobileActionButtonStyle(
                                                context: context,
                                                color: AppColors.warning,
                                              ),
                                              child: const Icon(
                                                Icons.visibility_outlined,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                          Tooltip(
                                            message: _t(
                                              'Kembalikan ke List',
                                              'Return to List',
                                            ),
                                            child: OutlinedButton(
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
                                                await _returnToInvoiceList(
                                                  item,
                                                );
                                              },
                                              style: _mobileActionButtonStyle(
                                                context: context,
                                                color: AppColors.blue,
                                              ),
                                              child: const Icon(
                                                Icons.undo_outlined,
                                                size: 18,
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
