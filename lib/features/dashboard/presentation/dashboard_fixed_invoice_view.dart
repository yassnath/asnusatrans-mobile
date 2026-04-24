part of 'dashboard_page.dart';

class _AdminFixedInvoiceView extends StatefulWidget {
  const _AdminFixedInvoiceView({
    required this.repository,
    required this.refreshToken,
    this.onDataChanged,
  });

  final DashboardRepository repository;
  final int refreshToken;
  final VoidCallback? onDataChanged;

  @override
  State<_AdminFixedInvoiceView> createState() => _AdminFixedInvoiceViewState();
}

class _AdminFixedInvoiceViewState extends State<_AdminFixedInvoiceView> {
  static const _fixedInvoicePrefsKey = 'fixed_invoice_ids_v1';
  static const _fixedInvoiceBatchPrefsKey = 'fixed_invoice_batches_v1';
  static const _fixedInvoiceNormalizationDoneKey =
      'fixed_invoice_normalization_done_v1';
  static const _fixedInvoiceRemotePromotionDoneKey =
      'fixed_invoice_remote_promotion_done_v1';
  late Future<List<Map<String, dynamic>>> _future;
  final _search = TextEditingController();
  RealtimeChannel? _fixedInvoiceRealtimeChannel;
  Timer? _fixedInvoiceRealtimeDebounce;
  bool _backgroundInvoiceNumberNormalizationRunning = false;
  bool _refreshingFixedInvoices = false;
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
      _subscribeToFixedInvoiceChanges();
      unawaited(_normalizeInvoiceNumbersInBackground());
    });
  }

  @override
  void dispose() {
    _fixedInvoiceRealtimeDebounce?.cancel();
    final channel = _fixedInvoiceRealtimeChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AdminFixedInvoiceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_refreshFixedInvoices());
      });
    }
  }

  void _snack(String msg, {bool error = false}) {
    showCvantPopup(
      context: context,
      type: error ? CvantPopupType.error : CvantPopupType.success,
      title: error ? _t('Error', 'Error') : _t('Success', 'Success'),
      message: msg,
    );
  }

  void _subscribeToFixedInvoiceChanges() {
    if (_fixedInvoiceRealtimeChannel != null) return;
    try {
      final channel = Supabase.instance.client.channel(
        'fixed-invoice-batches-sync',
      );
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'fixed_invoice_batches',
            callback: (_) => _scheduleFixedInvoiceRefresh(),
          )
          .subscribe();
      _fixedInvoiceRealtimeChannel = channel;
    } catch (_) {
      // Manual refresh tetap tersedia jika Realtime belum aktif di Supabase.
    }
  }

  void _scheduleFixedInvoiceRefresh() {
    _fixedInvoiceRealtimeDebounce?.cancel();
    _fixedInvoiceRealtimeDebounce = Timer(
      const Duration(milliseconds: 450),
      () {
        if (!mounted) return;
        unawaited(_refreshFixedInvoices());
      },
    );
  }

  Future<void> _refreshFixedInvoices({bool showMessage = false}) async {
    if (_refreshingFixedInvoices) return;
    final nextFuture = _load();
    setState(() {
      _refreshingFixedInvoices = true;
      _future = nextFuture;
    });
    try {
      await nextFuture;
      if (!mounted) return;
      if (showMessage) {
        _snack(
          _t(
            'Fix invoice disinkronkan dari database.',
            'Fixed invoices synced from database.',
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (showMessage) {
        _snack(
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _refreshingFixedInvoices = false);
      }
    }
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
    final batches = rows
        .map(_FixedInvoiceBatch.fromJson)
        .whereType<_FixedInvoiceBatch>()
        .toList(growable: false);
    for (final batchId in _duplicateFixedInvoiceBatchIds(batches)) {
      try {
        await widget.repository.deleteFixedInvoiceBatch(batchId);
      } catch (_) {
        // Tampilan tetap aman karena batch lama sudah difilter dari hasil merge.
      }
    }
    return _dedupeFixedInvoiceBatches(batches);
  }

  Future<_FixedInvoiceBatch?> _loadRemoteFixedBatchById(String batchId) async {
    final cleanedBatchId = batchId.trim();
    if (cleanedBatchId.isEmpty) return null;
    try {
      for (final batch in await _loadRemoteFixedBatches()) {
        if (batch.batchId == cleanedBatchId) return batch;
      }
    } catch (_) {
      // Cache lokal tetap dipakai jika perangkat sedang offline.
    }
    return null;
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
      paymentDetails:
          batch.paymentDetails.map((entry) => entry.toJson()).toList(),
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

  Future<List<_FixedInvoiceBatch>> _loadMergedFixedBatches() async {
    final prefs = await SharedPreferences.getInstance();
    final remotePromotionDone =
        prefs.getBool(_fixedInvoiceRemotePromotionDoneKey) ?? false;
    final localIds = await _loadFixedIds();
    final localBatches = await _loadFixedBatches();
    final remoteBatches = await _loadRemoteFixedBatches();
    final knownInvoiceIds = <String>{
      ...localBatches.expand((batch) => batch.invoiceIds),
      ...remoteBatches.expand((batch) => batch.invoiceIds),
    }.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    final legacyIds = localIds.difference(knownInvoiceIds);
    final legacyBatches = legacyIds.isEmpty
        ? const <_FixedInvoiceBatch>[]
        : _buildLegacyFixedInvoiceBatchesFromInvoices(
            invoices: await widget.repository.fetchInvoicesByIds(legacyIds),
            fixedIds: legacyIds,
            existingBatches: <_FixedInvoiceBatch>[
              ...localBatches,
              ...remoteBatches,
            ],
          );
    final promotedLocalBatches = <_FixedInvoiceBatch>[
      ...localBatches,
      ...legacyBatches,
    ];

    if (remotePromotionDone) {
      final finalBatches = _mergeFixedInvoiceBatchesWithLocalFallback(
        remoteBatches: remoteBatches,
        localBatches: promotedLocalBatches,
        includeLocalOnly: false,
      );
      await _syncLocalCacheFromBatches(finalBatches);
      return finalBatches;
    }

    final merged = _mergeFixedInvoiceBatchesWithLocalFallback(
      remoteBatches: remoteBatches,
      localBatches: promotedLocalBatches,
    );
    if (merged.isNotEmpty) {
      await Future.wait(merged.map(_upsertRemoteFixedBatch));
    }
    await prefs.setBool(_fixedInvoiceRemotePromotionDoneKey, true);
    final refreshedRemote = await _loadRemoteFixedBatches();
    final finalBatches = _mergeFixedInvoiceBatchesWithLocalFallback(
      remoteBatches: refreshedRemote,
      localBatches: merged,
      includeLocalOnly: false,
    );
    await _syncLocalCacheFromBatches(finalBatches);
    return finalBatches;
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

  List<Map<String, dynamic>> _resolveBatchSourceItems(
      Map<String, dynamic> item) {
    final sourceItems =
        (item['__batch_items'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
    return sourceItems.isNotEmpty ? sourceItems : <Map<String, dynamic>>[item];
  }

  _FixedInvoiceBatch _buildBatchSnapshotFromItem(Map<String, dynamic> item) {
    final batchId = '${item['__batch_id'] ?? item['id'] ?? ''}'.trim();
    final invoiceIds =
        (item['__batch_invoice_ids'] as List<dynamic>? ?? const <dynamic>[])
            .map((id) => '$id'.trim())
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
    return _FixedInvoiceBatch(
      batchId: batchId,
      invoiceIds: invoiceIds,
      invoiceNumber:
          '${item['__batch_invoice_number'] ?? item['no_invoice'] ?? ''}'
              .trim(),
      customerName: '${item['nama_pelanggan'] ?? ''}'.trim(),
      kopDate: '${item['tanggal_kop'] ?? ''}'.trim().isEmpty
          ? null
          : '${item['tanggal_kop'] ?? ''}'.trim(),
      kopLocation: '${item['lokasi_kop'] ?? ''}'.trim().isEmpty
          ? null
          : '${item['lokasi_kop'] ?? ''}'.trim(),
      status: '${item['status'] ?? 'Unpaid'}'.trim(),
      paidAt: '${item['paid_at'] ?? ''}'.trim().isEmpty
          ? null
          : '${item['paid_at'] ?? ''}'.trim(),
      createdAt:
          '${item['__batch_created_at'] ?? item['created_at'] ?? ''}'.trim(),
      updatedAt: '${item['__batch_updated_at'] ?? item['updated_at'] ?? ''}'
              .trim()
              .isEmpty
          ? null
          : '${item['__batch_updated_at'] ?? item['updated_at'] ?? ''}'.trim(),
      paymentDetails: _toFixedInvoicePaymentEntryList(
        item['__batch_payment_details'],
      ),
    );
  }

  _FixedInvoicePaymentSummary _resolvePaymentSummaryForItem(
    Map<String, dynamic> item, {
    _FixedInvoiceBatch? batchOverride,
  }) {
    return _summarizeFixedInvoicePayments(
      batch: batchOverride ?? _buildBatchSnapshotFromItem(item),
      sourceInvoices: _resolveBatchSourceItems(item),
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
    final sourceItems = _resolveBatchSourceItems(item);
    final batches = await _loadFixedBatches();
    final existingIndex =
        batches.indexWhere((batch) => batch.batchId == batchId);
    final localSnapshot = existingIndex >= 0
        ? batches[existingIndex].copyWith(
            paymentDetails: batches[existingIndex].paymentDetails.isNotEmpty
                ? batches[existingIndex].paymentDetails
                : _toFixedInvoicePaymentEntryList(
                    item['__batch_payment_details']),
            status: '${item['status'] ?? batches[existingIndex].status}'.trim(),
            paidAt: '${item['paid_at'] ?? batches[existingIndex].paidAt ?? ''}'
                    .trim()
                    .isEmpty
                ? null
                : '${item['paid_at'] ?? batches[existingIndex].paidAt ?? ''}'
                    .trim(),
          )
        : _buildBatchSnapshotFromItem(item);
    final latestRemoteBatch = await _loadRemoteFixedBatchById(batchId);
    final currentBatch = latestRemoteBatch == null
        ? localSnapshot
        : _mergeFixedInvoiceBatchesWithLocalFallback(
            remoteBatches: <_FixedInvoiceBatch>[latestRemoteBatch],
            localBatches: <_FixedInvoiceBatch>[localSnapshot],
            includeLocalOnly: false,
          ).first;
    final initialSummary = _summarizeFixedInvoicePayments(
      batch: currentBatch,
      sourceInvoices: sourceItems,
    );
    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        var selectedStatus = initialSummary.status;
        DateTime? selectedPaidDate =
            Formatters.parseDate(initialSummary.paidAt);
        final paymentEntries = initialSummary.entries
            .map(
              (entry) => entry.copyWith(
                paidAt: (entry.paidAt ?? '').trim().isEmpty
                    ? null
                    : _toDbDate(
                        Formatters.parseDate(entry.paidAt) ?? DateTime.now(),
                      ),
              ),
            )
            .toList(growable: true);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void recalculateStatus() {
              final anyPaid = paymentEntries.any((entry) => entry.paid);
              final allPaid = paymentEntries.isNotEmpty &&
                  paymentEntries.every((entry) => entry.paid);
              selectedStatus = allPaid
                  ? 'Paid'
                  : anyPaid
                      ? 'Partial'
                      : 'Unpaid';
              if (selectedStatus != 'Paid') {
                selectedPaidDate = null;
              } else {
                selectedPaidDate ??= paymentEntries
                        .map((entry) => Formatters.parseDate(entry.paidAt))
                        .whereType<DateTime>()
                        .fold<DateTime?>(null, (latest, current) {
                      if (latest == null || current.isAfter(latest)) {
                        return current;
                      }
                      return latest;
                    }) ??
                    DateTime.now();
              }
            }

            void applyBatchPaidDate(DateTime date) {
              final dbDate = _toDbDate(date);
              for (var i = 0; i < paymentEntries.length; i++) {
                if (!paymentEntries[i].paid) continue;
                paymentEntries[i] = paymentEntries[i].copyWith(paidAt: dbDate);
              }
            }

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
                if (selectedStatus == 'Paid') {
                  applyBatchPaidDate(picked);
                }
              });
            }

            String paidDateLabel() {
              if (selectedPaidDate == null) return '-';
              return Formatters.dmy(selectedPaidDate);
            }

            Future<void> pickRaidPaidDate(int index) async {
              final current =
                  Formatters.parseDate(paymentEntries[index].paidAt) ??
                      selectedPaidDate ??
                      DateTime.now();
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: current,
              );
              if (picked == null) return;
              setDialogState(() {
                paymentEntries[index] = paymentEntries[index].copyWith(
                  paid: true,
                  paidAt: _toDbDate(picked),
                );
                recalculateStatus();
              });
            }

            return AlertDialog(
              title: Text(_t('Edit Status Fix Invoice', 'Edit Fixed Invoice')),
              content: SizedBox(
                width: 620,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CvantDropdownField<String>(
                      key: ValueKey(selectedStatus),
                      initialValue: selectedStatus,
                      decoration: InputDecoration(
                        labelText: _t('Status', 'Status'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Unpaid',
                          child: Text('Unpaid'),
                        ),
                        DropdownMenuItem(
                          value: 'Partial',
                          child: Text(_t('Partial', 'Partial')),
                        ),
                        DropdownMenuItem(
                          value: 'Paid',
                          child: Text('Paid'),
                        ),
                      ],
                      onChanged: (value) => setDialogState(() {
                        selectedStatus = value ?? 'Unpaid';
                        if (selectedStatus == 'Unpaid') {
                          for (var i = 0; i < paymentEntries.length; i++) {
                            paymentEntries[i] = paymentEntries[i].copyWith(
                              paid: false,
                              paidAt: null,
                            );
                          }
                          selectedPaidDate = null;
                        } else if (selectedStatus == 'Paid') {
                          selectedPaidDate ??= DateTime.now();
                          final batchDate = _toDbDate(selectedPaidDate!);
                          for (var i = 0; i < paymentEntries.length; i++) {
                            paymentEntries[i] = paymentEntries[i].copyWith(
                              paid: true,
                              paidAt: batchDate,
                            );
                          }
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          _t('Pembayaran per raid', 'Per-raid payment'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setDialogState(() {
                            selectedStatus = 'Paid';
                            selectedPaidDate ??= DateTime.now();
                            final batchDate = _toDbDate(selectedPaidDate!);
                            for (var i = 0; i < paymentEntries.length; i++) {
                              paymentEntries[i] = paymentEntries[i].copyWith(
                                paid: true,
                                paidAt: batchDate,
                              );
                            }
                          }),
                          child: Text(_t('Bayar Semua', 'Pay All')),
                        ),
                        TextButton(
                          onPressed: () => setDialogState(() {
                            selectedStatus = 'Unpaid';
                            selectedPaidDate = null;
                            for (var i = 0; i < paymentEntries.length; i++) {
                              paymentEntries[i] = paymentEntries[i].copyWith(
                                paid: false,
                                paidAt: null,
                              );
                            }
                          }),
                          child: Text(_t('Kosongi', 'Clear')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 320,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: paymentEntries.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: AppColors.cardBorder(context),
                        ),
                        itemBuilder: (context, index) {
                          final entry = paymentEntries[index];
                          final paidDate = Formatters.parseDate(entry.paidAt);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: entry.paid,
                                  onChanged: (value) => setDialogState(() {
                                    paymentEntries[index] = entry.copyWith(
                                      paid: value ?? false,
                                      paidAt: value == true
                                          ? (entry.paidAt ??
                                              _toDbDate(DateTime.now()))
                                          : null,
                                    );
                                    recalculateStatus();
                                  }),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${index + 1}. ${entry.departureDate.isEmpty ? '-' : Formatters.dmy(entry.departureDate)} • ${entry.plate}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(entry.routeLabel),
                                      const SizedBox(height: 2),
                                      Text(
                                        Formatters.rupiah(entry.total),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: entry.paid
                                      ? () => pickRaidPaidDate(index)
                                      : null,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.cardBorder(context),
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      color: entry.paid
                                          ? AppColors.surfaceSoft(context)
                                          : AppColors.surface(context),
                                    ),
                                    child: Text(
                                      paidDate == null
                                          ? _t('Pilih Tanggal', 'Pick Date')
                                          : Formatters.dmy(paidDate),
                                      style: TextStyle(
                                        color: entry.paid
                                            ? AppColors.textPrimaryFor(context)
                                            : AppColors.textMutedFor(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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
                    recalculateStatus();
                    if (selectedStatus == 'Paid' && selectedPaidDate != null) {
                      applyBatchPaidDate(selectedPaidDate!);
                    }
                    final paidAt = selectedStatus == 'Paid'
                        ? _toDbDate(selectedPaidDate ?? DateTime.now())
                        : null;
                    Navigator.pop(context, {
                      'status': selectedStatus,
                      'paid_at': paidAt,
                      'payment_details': paymentEntries
                          .map((entry) => entry.toJson())
                          .toList(),
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
    final paymentDetails = _toFixedInvoicePaymentEntryList(
      result['payment_details'],
    );

    try {
      final index = batches.indexWhere((batch) => batch.batchId == batchId);
      final current = index >= 0 ? batches[index] : currentBatch;
      final nowIso = DateTime.now().toIso8601String();
      final updated = current.copyWith(
        status: newStatus.isEmpty ? 'Unpaid' : newStatus,
        paidAt: newPaidAt.isEmpty ? null : newPaidAt,
        updatedAt: nowIso,
        paymentDetails: paymentDetails,
      );
      await _upsertRemoteFixedBatch(updated);
      if (index >= 0) {
        batches[index] = updated;
      } else {
        batches.add(updated);
      }
      await _saveFixedBatches(batches);
      if (!mounted) return;
      _snack(
        _t('Status fix invoice diperbarui.', 'Fixed invoice status updated.'),
      );
      await _refreshFixedInvoices();
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
    final effectiveSourceItems = _resolveBatchSourceItems(item);
    final paymentSummary = _resolvePaymentSummaryForItem(item);
    final paymentEntryByKey = <String, _FixedInvoicePaymentEntry>{
      for (final entry in paymentSummary.entries) entry.detailKey: entry,
    };
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
                    '${_t('Status', 'Status')}: ${paymentSummary.status}',
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_t('Tanggal Pelunasan', 'Payment Date')}: ${((paymentSummary.paidAt ?? '').trim().isEmpty ? '-' : Formatters.dmy(paymentSummary.paidAt))}',
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_t('Bayar', 'Paid')}: ${Formatters.rupiah(paymentSummary.paidAmount)} • ${_t('Sisa', 'Remaining')}: ${Formatters.rupiah(paymentSummary.remainingAmount)}',
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
                              final detailKey = _fixedInvoicePaymentDetailKey(
                                invoiceId:
                                    '${source['id'] ?? sourceNumber}'.trim(),
                                detailIndex: index,
                              );
                              final paymentEntry = paymentEntryByKey[detailKey];
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
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        '${_t('Pembayaran', 'Payment')}: ${paymentEntry?.paid == true ? _t('Paid', 'Paid') : _t('Belum dibayar', 'Unpaid')}',
                                        '${_t('Tanggal Bayar', 'Paid Date')}: ${((paymentEntry?.paidAt ?? '').trim().isEmpty ? '-' : Formatters.dmy(paymentEntry?.paidAt))}',
                                      ].join(' • '),
                                      style: TextStyle(
                                        color: paymentEntry?.paid == true
                                            ? AppColors.success
                                            : AppColors.textMutedFor(context),
                                        fontWeight: FontWeight.w600,
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
      _loadMergedFixedBatches(),
    ]);
    final localIds = payload[0] as Set<String>;
    final batches = payload[1] as List<_FixedInvoiceBatch>;
    final rows = <Map<String, dynamic>>[];

    final invoiceIdsToFetch = <String>{
      ...localIds,
      for (final batch in batches) ...batch.invoiceIds,
    };
    final invoices =
        await widget.repository.fetchInvoicesByIds(invoiceIdsToFetch);
    final invoiceById = <String, Map<String, dynamic>>{
      for (final item in invoices)
        '${item['id'] ?? ''}'.trim(): Map<String, dynamic>.from(item),
    };

    if (batches.isEmpty) return <Map<String, dynamic>>[];

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
      final paymentSummary = _summarizeFixedInvoicePayments(
        batch: batch,
        sourceInvoices: batchItems,
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
        'status': paymentSummary.status,
        'paid_at': paymentSummary.paidAt,
        '__batch_payment_details':
            batch.paymentDetails.map((entry) => entry.toJson()).toList(),
        '__batch_paid_amount': paymentSummary.paidAmount,
        '__batch_remaining_amount': paymentSummary.remainingAmount,
        '__batch_id': batch.batchId,
        '__batch_invoice_ids': batch.invoiceIds,
        '__batch_invoice_number': batch.invoiceNumber,
        '__batch_items': batchItems,
        '__batch_created_at': batch.createdAt,
        '__batch_updated_at': batch.updatedAt,
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
                  Row(
                    children: [
                      Expanded(
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
                      const SizedBox(width: 8),
                      Tooltip(
                        message: _t(
                          'Refresh dari database',
                          'Refresh from database',
                        ),
                        child: OutlinedButton(
                          onPressed: _refreshingFixedInvoices
                              ? null
                              : () => unawaited(
                                    _refreshFixedInvoices(showMessage: true),
                                  ),
                          style: _mobileActionButtonStyle(
                            context: context,
                            color: AppColors.blue,
                          ),
                          child: _refreshingFixedInvoices
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh, size: 18),
                        ),
                      ),
                    ],
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
