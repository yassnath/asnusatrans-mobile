part of 'dashboard_page.dart';

class _AdminInvoiceListView extends StatefulWidget {
  const _AdminInvoiceListView({
    required this.repository,
    required this.session,
    required this.onQuickMenuSelect,
    this.isOwner = false,
    this.onDataChanged,
  });

  final DashboardRepository repository;
  final AuthSession session;
  final ValueChanged<int> onQuickMenuSelect;
  final bool isOwner;
  final VoidCallback? onDataChanged;

  @override
  State<_AdminInvoiceListView> createState() => _AdminInvoiceListViewState();
}

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

class _AdminInvoiceListViewState extends State<_AdminInvoiceListView>
    implements _DashboardInvoicePrintHost {
  static const _manualArmadaOptionId = '__other_manual_armada__';
  static const _manualDriverOptionId = '__other_manual_driver__';
  static const List<String> _defaultMuatOptions = [
    'Depo',
    'T. Langon',
    'Maspion',
    'Betoyo',
    'Oso',
    'Legundi',
  ];
  static const List<String> _defaultDriverOptions = [
    'Ami',
    'Candra',
    'Yusak',
    'Chrisjohn',
    'Sulkan',
    'Gambit',
    'Victor',
    'Rio',
    'Taman',
    'Matius',
    'Batok',
  ];
  static const Map<String, String> _defaultDriverByPlate = {
    'B 9613 TIT': 'Ami',
    'B 9615 TIT': 'Candra',
    'W 8045 UD': 'Yusak',
    'L 8465 UDD': 'Chrisjohn',
    'L 8581 UH': 'Sulkan',
    'L 8607 UJ': 'Gambit',
    'B 9593 UVW': 'Victor',
    'B 9591 UVW': 'Rio',
    'B 9064 TIU': 'Taman',
    'L 9548 UI': 'Matius',
  };
  static const _fixedInvoicePrefsKey = 'fixed_invoice_ids_v1';
  static const _fixedInvoiceBatchPrefsKey = 'fixed_invoice_batches_v1';
  static const _invoiceListColumns =
      'id,no_invoice,tanggal,tanggal_kop,lokasi_kop,nama_pelanggan,email,no_telp,due_date,'
      'lokasi_muat,lokasi_bongkar,armada_start_date,armada_end_date,'
      'tonase,harga,muatan,nama_supir,status,total_bayar,total_biaya,pph,diterima_oleh,'
      'customer_id,armada_id,order_id,rincian,created_at,updated_at,created_by,'
      'submission_role,approval_status,approval_requested_at,approval_requested_by,'
      'approved_at,approved_by,rejected_at,rejected_by,edit_request_status,'
      'edit_requested_at,edit_requested_by,edit_resolved_at,edit_resolved_by';
  static const _expenseListColumns =
      'id,no_expense,tanggal,kategori,keterangan,total_pengeluaran,'
      'status,dicatat_oleh,note,rincian,created_at,updated_at,created_by';
  static const _companyKeywords = <String>[
    r'\bcv\b',
    r'\bpt\b',
    r'\bfa\b',
    r'\bud\b',
    r'\bpo\b',
    r'\byayasan\b',
    r'\bbumn\b',
    r'\bbumd\b',
    r'\bperum\b',
    r'\bkoperasi\b',
    r'\bpersekutuan\s+perdata\b',
    r'\bmaatschap\b',
  ];
  late Future<List<dynamic>> _future;
  final _search = TextEditingController();
  final Set<String> _locallyRemovedRowIds = <String>{};
  String _limit = '10';
  bool _backfillRunning = false;
  bool _backgroundFixedInvoiceSyncRunning = false;
  bool _backgroundAutoSanguCleanupRunning = false;
  bool _backgroundInvoiceNumberNormalizationRunning = false;
  bool _manualArmadaAutoSanguCleanupDone = false;

  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  bool get _isPengurus => widget.session.isPengurus;
  bool get _isAdminOrOwner => widget.session.isAdminOrOwner;
  String get _currentUserId => widget.session.userId?.trim() ?? '';

  int? get _invoiceListFetchLimit {
    if (_limit == 'all') return null;
    final visibleRows = int.tryParse(_limit) ?? 10;
    return max(80, min(1500, visibleRows * 8));
  }

  String _t(String id, String en) => _isEn ? en : id;

  bool _isPengurusIncome(Map<String, dynamic> row) {
    return '${row['submission_role'] ?? ''}'.trim().toLowerCase() == 'pengurus';
  }

  String _resolvePengurusApprovalStatus(Map<String, dynamic> row) {
    final status = '${row['approval_status'] ?? ''}'.trim().toLowerCase();
    if (status.isNotEmpty) return status;
    if (Formatters.parseDate(row['rejected_at']) != null) {
      return 'rejected';
    }
    if (Formatters.parseDate(row['approved_at']) != null) {
      return 'approved';
    }
    if (Formatters.parseDate(row['approval_requested_at']) != null) {
      return 'pending';
    }
    return _isPengurusIncome(row) ? 'pending' : 'approved';
  }

  bool _isPengurusIncomeApproved(Map<String, dynamic> row) {
    final approvalStatus = _resolvePengurusApprovalStatus(row);
    return !_isPengurusIncome(row) || approvalStatus == 'approved';
  }

  bool _isOwnedByCurrentUser(Map<String, dynamic> row) {
    if (_currentUserId.isEmpty) return false;
    return '${row['created_by'] ?? ''}'.trim() == _currentUserId;
  }

  @override
  DashboardRepository get invoicePrintRepository => widget.repository;

  @override
  String translatePrintText(String id, String en) => _t(id, en);

  @override
  void showPrintSnack(String msg, {bool error = false}) {
    _snack(msg, error: error);
  }

  @override
  Future<void> markInvoicesFixed(
    Iterable<String> ids, {
    _FixedInvoiceBatch? batch,
  }) {
    return _markInvoicesAsFixed(ids, batch: batch);
  }

  bool _matchesKeywordInAnyColumn(
    Map<String, dynamic> row,
    String keyword,
  ) {
    if (keyword.trim().isEmpty) return true;
    final haystack = _flattenSearchText(row).toLowerCase();
    return haystack.contains(keyword.toLowerCase());
  }

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

  Color _armadaStatusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('full')) return AppColors.warning;
    if (lower.contains('ready')) return AppColors.success;
    if (lower.contains('inactive') ||
        lower.contains('non active') ||
        lower.contains('non-active')) {
      return AppColors.neutralOutline;
    }
    return AppColors.textMutedFor(context);
  }

  String _normalizePlateText(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeArmadaNameKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _extractPlateFromText(String value) {
    final match = RegExp(
      r'[A-Z]{1,2}\s?[0-9]{1,4}\s?[A-Z]{1,3}',
    ).firstMatch(value.toUpperCase());
    if (match == null) return null;
    final plate = _normalizePlateText(match.group(0) ?? '');
    return plate.isEmpty ? null : plate;
  }

  void _normalizeDetailPlateFields(Map<String, dynamic> row) {
    final directPlate =
        _normalizePlateText('${row['plat_nomor'] ?? row['no_polisi'] ?? ''}');
    if (directPlate.isNotEmpty && directPlate != '-') {
      row['plat_nomor'] = directPlate;
      row['no_polisi'] = directPlate;
      return;
    }

    for (final candidate in <String>[
      '${row['armada_manual'] ?? ''}'.trim(),
      '${row['armada_label'] ?? ''}'.trim(),
      '${row['armada'] ?? ''}'.trim(),
    ]) {
      if (candidate.isEmpty) continue;
      final parsed = _extractPlateFromText(candidate);
      if (parsed == null || parsed.isEmpty || parsed == '-') continue;
      row['plat_nomor'] = parsed;
      row['no_polisi'] = parsed;
      return;
    }
  }

  String _resolveDetailPlateText(
    Map<String, dynamic> row, {
    Map<String, String>? armadaPlateById,
    Map<String, String>? armadaPlateByName,
    String? fallbackArmadaId,
  }) {
    final rowArmadaId = '${row['armada_id'] ?? ''}'.trim();
    if (rowArmadaId.isNotEmpty && armadaPlateById != null) {
      final byArmada = armadaPlateById[rowArmadaId];
      if (byArmada != null && byArmada.trim().isNotEmpty && byArmada != '-') {
        return _normalizePlateText(byArmada);
      }
    }

    final direct = _normalizePlateText(
      '${row['plat_nomor'] ?? row['no_polisi'] ?? ''}',
    );
    if (direct.isNotEmpty && direct != '-') return direct;

    final manualCandidates = <String>[
      '${row['armada_manual'] ?? ''}'.trim(),
      '${row['armada_label'] ?? ''}'.trim(),
      '${row['armada'] ?? ''}'.trim(),
    ];
    for (final candidate in manualCandidates) {
      if (candidate.isEmpty) continue;
      final parsed = _extractPlateFromText(candidate);
      if (parsed != null && parsed.isNotEmpty && parsed != '-') {
        return parsed;
      }
      if (armadaPlateByName != null) {
        final byName = armadaPlateByName[_normalizeArmadaNameKey(candidate)];
        if (byName != null && byName.trim().isNotEmpty && byName != '-') {
          return _normalizePlateText(byName);
        }
      }
    }

    final invoiceArmadaId = (fallbackArmadaId ?? '').trim();
    if (invoiceArmadaId.isNotEmpty && armadaPlateById != null) {
      final byFallbackArmada = armadaPlateById[invoiceArmadaId];
      if (byFallbackArmada != null &&
          byFallbackArmada.trim().isNotEmpty &&
          byFallbackArmada != '-') {
        return _normalizePlateText(byFallbackArmada);
      }
    }

    return '-';
  }

  Map<String, String> _buildArmadaIdByPlate(
    List<Map<String, dynamic>> armadas,
  ) {
    final map = <String, String>{};
    for (final armada in armadas) {
      final id = '${armada['id'] ?? ''}'.trim();
      final plate = _normalizePlateText('${armada['plat_nomor'] ?? ''}');
      if (id.isEmpty || plate.isEmpty) continue;
      map[plate] = id;
    }
    return map;
  }

  String _resolveArmadaIdFromInput({
    required String armadaId,
    required String armadaManual,
    required Map<String, String> armadaIdByPlate,
  }) {
    final direct = armadaId.trim();
    if (direct.isNotEmpty) return direct;
    final manual = armadaManual.trim();
    if (manual.isEmpty) return '';
    final extracted = _extractPlateFromText(manual);
    final normalized = _normalizePlateText(manual);
    return armadaIdByPlate[extracted ?? normalized] ?? '';
  }

  String _normalizeText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isKnownDriverOption(String value) {
    final normalized = _normalizeText(value);
    if (normalized.isEmpty) return false;
    return _defaultDriverOptions
        .any((option) => _normalizeText(option) == normalized);
  }

  String? _resolveDefaultDriverForRow(
    Map<String, dynamic> row, {
    required List<Map<String, dynamic>> armadas,
  }) {
    var plate = '';
    final armadaId = '${row['armada_id'] ?? ''}'.trim();
    if (armadaId.isNotEmpty) {
      Map<String, dynamic>? selected;
      for (final armada in armadas) {
        if ('${armada['id'] ?? ''}'.trim() == armadaId) {
          selected = armada;
          break;
        }
      }
      plate = _normalizePlateText('${selected?['plat_nomor'] ?? ''}');
    }
    if (plate.isEmpty) {
      final manual = '${row['armada_manual'] ?? ''}'.trim();
      if (manual.isNotEmpty) {
        plate = _extractPlateFromText(manual) ?? _normalizePlateText(manual);
      }
    }
    if (plate.isEmpty) return null;
    for (final entry in _defaultDriverByPlate.entries) {
      if (_normalizePlateText(entry.key) == plate) {
        return entry.value;
      }
    }
    return null;
  }

  void _applyDefaultDriverForRow(
    Map<String, dynamic> row, {
    required List<Map<String, dynamic>> armadas,
    bool force = false,
  }) {
    final defaultDriver = _resolveDefaultDriverForRow(row, armadas: armadas);
    if (defaultDriver == null || defaultDriver.trim().isEmpty) return;

    final currentDriver = '${row['nama_supir'] ?? ''}'.trim();
    final isDriverManual = row['nama_supir_is_manual'] == true;
    final isDriverAuto = row['nama_supir_auto'] == true;
    if (!force &&
        currentDriver.isNotEmpty &&
        (isDriverManual || !isDriverAuto)) {
      return;
    }

    row['nama_supir'] = defaultDriver;
    row['nama_supir_manual'] = '';
    row['nama_supir_is_manual'] = false;
    row['nama_supir_auto'] = true;
  }

  void _syncDriverWithArmadaSelection(
    Map<String, dynamic> row, {
    required List<Map<String, dynamic>> armadas,
    bool overrideManualDriver = false,
  }) {
    final defaultDriver =
        _resolveDefaultDriverForRow(row, armadas: armadas)?.trim() ?? '';
    if (row['nama_supir_is_manual'] == true && !overrideManualDriver) {
      return;
    }
    if (defaultDriver.isNotEmpty) {
      _applyDefaultDriverForRow(row, armadas: armadas, force: true);
      return;
    }

    final currentDriver = '${row['nama_supir'] ?? ''}'.trim();
    if (currentDriver.isEmpty ||
        row['nama_supir_auto'] == true ||
        _isKnownDriverOption(currentDriver)) {
      row['nama_supir'] = '';
      row['nama_supir_manual'] = '';
      row['nama_supir_is_manual'] = false;
      row['nama_supir_auto'] = false;
    }
  }

  void _enableManualDriverInput(Map<String, dynamic> row) {
    final currentDriver = '${row['nama_supir'] ?? ''}'.trim();
    final currentManual = '${row['nama_supir_manual'] ?? ''}'.trim();
    final seed = currentManual.isNotEmpty ? currentManual : currentDriver;
    row['nama_supir_is_manual'] = true;
    row['nama_supir_manual'] = !_isKnownDriverOption(seed) ? seed : '';
    row['nama_supir'] = '${row['nama_supir_manual'] ?? ''}';
    row['nama_supir_auto'] = false;
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
    if (_isAdminOrOwner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (!mounted || !_isAdminOrOwner) return;
          unawaited(_runInvoiceListBackgroundMaintenance());
        });
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _load() async {
    if (_isPengurus && _currentUserId.isEmpty) {
      return const [<Map<String, dynamic>>[], <Map<String, dynamic>>[]];
    }
    final since = DateTime.now().subtract(const Duration(days: 30));
    final scopedUserId = _isPengurus ? _currentUserId : null;
    final fetchLimit = _invoiceListFetchLimit;
    final response = await Future.wait<dynamic>([
      widget.repository.fetchInvoicesSinceWithScope(
        since,
        columns: _invoiceListColumns,
        createdBy: scopedUserId,
        limit: fetchLimit,
      ),
      widget.repository.fetchExpensesSinceWithScope(
        since,
        _expenseListColumns,
        createdBy: scopedUserId,
        limit: fetchLimit == null ? null : max(80, fetchLimit * 2),
      ),
      _isAdminOrOwner
          ? _loadLocalFixedInvoiceIds()
          : Future<Set<String>>.value(<String>{}),
    ]);

    final rawIncomes =
        (response[0] as List).cast<Map<String, dynamic>>().toList();
    final rawExpenses =
        (response[1] as List).cast<Map<String, dynamic>>().toList();
    final scopedIncomes = rawIncomes.where((item) {
      final id = '${item['id'] ?? ''}'.trim();
      if (id.isNotEmpty && _locallyRemovedRowIds.contains(id)) return false;
      if (_isPengurus) return _isOwnedByCurrentUser(item);
      if (_isAdminOrOwner) return _isPengurusIncomeApproved(item);
      return true;
    }).toList();
    final scopedExpenses = rawExpenses.where((item) {
      final id = '${item['id'] ?? ''}'.trim();
      if (id.isNotEmpty && _locallyRemovedRowIds.contains(id)) return false;
      if (_isPengurus) return _isOwnedByCurrentUser(item);
      return true;
    }).toList();
    final fixedIds = (response[2] as Set<String>)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (fixedIds.isEmpty) {
      return [scopedIncomes, scopedExpenses];
    }

    final filteredIncomes = scopedIncomes.where((item) {
      final id = '${item['id'] ?? ''}'.trim();
      return id.isEmpty || !fixedIds.contains(id);
    }).toList();

    return [filteredIncomes, scopedExpenses];
  }

  Future<void> _runInvoiceListBackgroundMaintenance() async {
    await Future.wait<void>([
      _syncFixedInvoiceCacheInBackground(),
      _cleanupManualArmadaAutoSanguInBackground(),
      _normalizeInvoiceNumbersInBackground(),
    ]);
  }

  Future<void> _normalizeInvoiceNumbersInBackground() async {
    if (_backgroundInvoiceNumberNormalizationRunning) return;
    _backgroundInvoiceNumberNormalizationRunning = true;
    try {
      final report = await widget.repository.normalizeLegacyInvoiceNumbers();
      if (report.updatedInvoices <= 0 && report.updatedFixedBatches <= 0) {
        return;
      }
      final remoteBatches = await _loadRemoteFixedInvoiceBatches();
      if (remoteBatches.isNotEmpty) {
        await _syncLocalFixedInvoiceCache(remoteBatches);
      }
      if (!mounted) return;
      setState(() {
        _future = _load();
      });
    } catch (_) {
      // Best effort: migrasi nomor invoice lama tidak boleh menghambat page.
    } finally {
      _backgroundInvoiceNumberNormalizationRunning = false;
    }
  }

  Future<void> _syncFixedInvoiceCacheInBackground() async {
    if (_backgroundFixedInvoiceSyncRunning) return;
    _backgroundFixedInvoiceSyncRunning = true;
    try {
      final localIds = await _loadLocalFixedInvoiceIds();
      final localBatches = await _loadLocalFixedInvoiceBatches();
      if (localBatches.isNotEmpty) {
        await Future.wait<void>(
          localBatches.map(_upsertRemoteFixedInvoiceBatch),
        );
      }

      final remoteBatches = await _loadRemoteFixedInvoiceBatches();
      if (remoteBatches.isEmpty) return;

      final remoteIds = remoteBatches
          .expand((batch) => batch.invoiceIds)
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      await _syncLocalFixedInvoiceCache(remoteBatches);

      if (!mounted || setEquals(localIds, remoteIds)) return;
      setState(() {
        _future = _load();
      });
    } catch (_) {
      // Best effort: page list tetap cepat walau sync fix invoice gagal.
    } finally {
      _backgroundFixedInvoiceSyncRunning = false;
    }
  }

  Future<void> _cleanupManualArmadaAutoSanguInBackground() async {
    if (_manualArmadaAutoSanguCleanupDone ||
        _backgroundAutoSanguCleanupRunning) {
      return;
    }
    _backgroundAutoSanguCleanupRunning = true;
    try {
      final report = await widget.repository
          .backfillAutoSanguExpensesForExistingInvoices();
      _manualArmadaAutoSanguCleanupDone = true;
      if (!mounted) return;
      final hasVisibleChange = report.createdExpenses > 0 ||
          report.updatedExpenses > 0 ||
          report.deletedExpenses > 0;
      if (!hasVisibleChange) return;
      setState(() {
        _future = _load();
      });
    } catch (_) {
      // Best effort: page list tetap cepat walau cleanup auto sangu gagal.
    } finally {
      _backgroundAutoSanguCleanupRunning = false;
    }
  }

  Future<void> _refresh({bool runBackfill = false}) async {
    if (_isAdminOrOwner && runBackfill && !_backfillRunning) {
      _backfillRunning = true;
      try {
        final report = await widget.repository
            .backfillAutoSanguExpensesForExistingInvoices();
        if (mounted && report.hasFailures) {
          _snack(
            _t(
              'Sebagian auto expense sangu sopir belum berhasil disinkronkan. Coba refresh sekali lagi.',
              'Some driver allowance auto expenses could not be synced yet. Please refresh once more.',
            ),
            error: true,
          );
        }
      } catch (_) {
        // Best effort: tetap lanjut reload data list.
      } finally {
        _backfillRunning = false;
      }
    }
    setState(() {
      _future = _load();
    });
    await _future;
    if (_isAdminOrOwner) {
      unawaited(_runInvoiceListBackgroundMaintenance());
    }
  }

  void _notifyDataChanged() {
    widget.onDataChanged?.call();
  }

  Future<void> _deleteInvoice(String id) async {
    try {
      await widget.repository.deleteInvoice(id);
      final cleanedId = id.trim();
      if (!mounted) return;
      setState(() {
        if (cleanedId.isNotEmpty) {
          _locallyRemovedRowIds.add(cleanedId);
        }
      });
      _snack(_t('Invoice berhasil dihapus.', 'Invoice deleted successfully.'));
      await _refresh();
      _notifyDataChanged();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _deleteExpense(String id) async {
    try {
      await widget.repository.deleteExpense(id);
      final cleanedId = id.trim();
      if (!mounted) return;
      setState(() {
        if (cleanedId.isNotEmpty) {
          _locallyRemovedRowIds.add(cleanedId);
        }
      });
      _snack(_t('Expense berhasil dihapus.', 'Expense deleted successfully.'));
      await _refresh();
      _notifyDataChanged();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _confirmDelete({
    required String id,
    required bool isIncome,
  }) async {
    final ok = await showCvantConfirmPopup(
      context: context,
      title: isIncome
          ? _t('Hapus Invoice', 'Delete Invoice')
          : _t('Hapus Expense', 'Delete Expense'),
      message: _t(
        'Data yang dihapus tidak bisa dikembalikan.',
        'Deleted data cannot be restored.',
      ),
      type: CvantPopupType.error,
      cancelLabel: _t('Batal', 'Cancel'),
      confirmLabel: _t('Hapus', 'Delete'),
    );
    if (!ok) return;
    if (isIncome) {
      await _deleteInvoice(id);
    } else {
      await _deleteExpense(id);
    }
  }

  Future<void> _sendInvoice(Map<String, dynamic> item) async {
    final invoiceId = '${item['id'] ?? ''}'.trim();
    final invoiceNumber =
        '${item['__number'] ?? item['no_invoice'] ?? item['id'] ?? '-'}';
    final customerName =
        '${item['__name'] ?? item['nama_pelanggan'] ?? 'customer'}';
    final ok = await showCvantConfirmPopup(
      context: context,
      type: CvantPopupType.info,
      title: _t('Kirim Invoice', 'Send Invoice'),
      message: _t(
        'Kirim invoice $invoiceNumber ke $customerName?',
        'Send invoice $invoiceNumber to $customerName?',
      ),
      cancelLabel: _t('Batal', 'Cancel'),
      confirmLabel: _t('Kirim', 'Send'),
    );
    if (!ok) return;

    try {
      if (invoiceId.isEmpty) {
        throw Exception(
          _t('ID invoice tidak ditemukan.', 'Invoice ID not found.'),
        );
      }

      final orderId = '${item['order_id'] ?? ''}'.trim();
      final invoiceStatus =
          '${item['status'] ?? item['__status'] ?? ''}'.trim().toLowerCase();
      if (orderId.isNotEmpty && !invoiceStatus.contains('paid')) {
        await widget.repository.updateOrderStatus(
          orderId: orderId,
          status: 'Pending Payment',
        );
      }

      final delivery = await widget.repository.dispatchInvoiceDelivery(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        customerName: customerName,
        customerId: item['customer_id']?.toString(),
        customerEmail: item['email']?.toString(),
      );

      if (!mounted) return;
      if (delivery.target == InvoiceDeliveryTarget.customerNotification) {
        _snack(
          _t(
            'Invoice berhasil dikirim ke notifikasi akun customer.',
            'Invoice sent to customer account notification.',
          ),
        );
      } else {
        final email = (delivery.email ?? '').trim();
        if (email.isEmpty) {
          throw Exception(
            _t(
              'Email customer tidak tersedia. Lengkapi email invoice terlebih dahulu.',
              'Customer email is missing. Complete the invoice email first.',
            ),
          );
        }
        final uri = Uri(
          scheme: 'mailto',
          path: email,
          queryParameters: {
            'subject': 'Invoice $invoiceNumber - CV ANT',
            'body':
                'Halo $customerName,\n\nInvoice $invoiceNumber sudah tersedia dari CV ANT.\nSilakan cek detail invoice dan lanjutkan proses pembayaran.\n\nTerima kasih.',
          },
        );
        if (!AppSecurity.isAllowedExternalUri(uri)) {
          throw Exception(
            _t(
              'Tautan email tidak valid atau tidak diizinkan.',
              'The email link is invalid or not allowed.',
            ),
          );
        }
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          throw Exception(
            _t(
              'Aplikasi email tidak ditemukan di perangkat ini.',
              'No email app found on this device.',
            ),
          );
        }
        _snack(
          _t(
            'Invoice diarahkan ke email $email.',
            'Invoice has been directed to email $email.',
          ),
        );
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<List<_FixedInvoiceBatch>> _loadRemoteFixedInvoiceBatches() async {
    final rows = await widget.repository.fetchFixedInvoiceBatches();
    final batches = <_FixedInvoiceBatch>[];
    for (final row in rows) {
      final batch = _FixedInvoiceBatch.fromJson(row);
      if (batch == null) continue;
      batches.add(batch);
      final rawInvoiceNumber = '${row['invoice_number'] ?? ''}'.trim();
      if (rawInvoiceNumber.isNotEmpty &&
          rawInvoiceNumber != batch.invoiceNumber) {
        await _upsertRemoteFixedInvoiceBatch(batch);
      }
    }
    return batches;
  }

  Future<void> _upsertRemoteFixedInvoiceBatch(_FixedInvoiceBatch batch) {
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

  Future<void> _syncLocalFixedInvoiceCache(
    List<_FixedInvoiceBatch> batches,
  ) async {
    final ids = batches
        .expand((batch) => batch.invoiceIds)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    await _saveFixedInvoiceIds(ids);
    await _saveFixedInvoiceBatches(batches);
  }

  Future<Set<String>> _loadFixedInvoiceIds() async {
    final localIds = await _loadLocalFixedInvoiceIds();
    final localBatches = await _loadLocalFixedInvoiceBatches();
    if (localBatches.isNotEmpty) {
      for (final batch in localBatches) {
        await _upsertRemoteFixedInvoiceBatch(batch);
      }
    }

    final remoteBatches = await _loadRemoteFixedInvoiceBatches();
    if (remoteBatches.isNotEmpty) {
      await _syncLocalFixedInvoiceCache(remoteBatches);
      return remoteBatches
          .expand((batch) => batch.invoiceIds)
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    }

    return localIds;
  }

  Future<Set<String>> _loadLocalFixedInvoiceIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_fixedInvoicePrefsKey) ?? const <String>[];
    return ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
  }

  Future<void> _saveFixedInvoiceIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final values = ids.toList()..sort();
    await prefs.setStringList(_fixedInvoicePrefsKey, values);
  }

  Future<List<_FixedInvoiceBatch>> _loadFixedInvoiceBatches() async {
    final localBatches = await _loadLocalFixedInvoiceBatches();
    if (localBatches.isNotEmpty) {
      for (final batch in localBatches) {
        await _upsertRemoteFixedInvoiceBatch(batch);
      }
    }

    final remoteBatches = await _loadRemoteFixedInvoiceBatches();
    if (remoteBatches.isNotEmpty) {
      await _syncLocalFixedInvoiceCache(remoteBatches);
      return remoteBatches;
    }

    return localBatches;
  }

  Future<List<_FixedInvoiceBatch>> _loadLocalFixedInvoiceBatches() async {
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
        // Ignore malformed legacy values and continue.
      }
    }
    return batches;
  }

  Future<void> _saveFixedInvoiceBatches(
      List<_FixedInvoiceBatch> batches) async {
    final prefs = await SharedPreferences.getInstance();
    final values = batches
        .map((batch) => jsonEncode(batch.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_fixedInvoiceBatchPrefsKey, values);
  }

  String _buildFixedInvoiceBatchId(Iterable<String> invoiceIds) {
    final ids = invoiceIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort();
    final seed = ids.isEmpty ? 'batch' : ids.join('_');
    return '${DateTime.now().microsecondsSinceEpoch}_$seed';
  }

  Future<void> _markInvoicesAsFixed(
    Iterable<String> invoiceIds, {
    _FixedInvoiceBatch? batch,
  }) async {
    final cleaned =
        invoiceIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (cleaned.isEmpty) return;
    final existing = await _loadFixedInvoiceIds();
    existing.addAll(cleaned);
    await _saveFixedInvoiceIds(existing);
    if (batch == null) return;
    final batches = await _loadFixedInvoiceBatches();
    final overlappingBatchIds = batches
        .where(
          (existingBatch) =>
              existingBatch.batchId != batch.batchId &&
              existingBatch.invoiceIds.any(cleaned.contains),
        )
        .map((existingBatch) => existingBatch.batchId)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    batches.removeWhere(
      (existingBatch) =>
          existingBatch.batchId == batch.batchId ||
          existingBatch.invoiceIds.any(cleaned.contains),
    );
    batches.add(batch);
    batches.sort((a, b) {
      final aDate = DateTime.tryParse(a.createdAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b.createdAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    await _saveFixedInvoiceBatches(batches);
    for (final batchId in overlappingBatchIds) {
      await widget.repository.deleteFixedInvoiceBatch(batchId);
    }
    await _upsertRemoteFixedInvoiceBatch(batch);
  }

  String _normalizeInvoicePrintCustomerKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Map<String, dynamic> _fallbackIncomeDetailRow(Map<String, dynamic> item) {
    return <String, dynamic>{
      'lokasi_muat': item['lokasi_muat'],
      'lokasi_bongkar': item['lokasi_bongkar'],
      'muatan': item['muatan'],
      'nama_supir': item['nama_supir'],
      'armada_id': item['armada_id'],
      'armada_manual': item['armada_manual'],
      'armada_label': item['armada_label'],
      'plat_nomor': item['plat_nomor'] ?? item['no_polisi'],
      'no_polisi': item['no_polisi'] ?? item['plat_nomor'],
      'armada_start_date': item['armada_start_date'] ?? item['tanggal'],
      'armada_end_date': item['armada_end_date'],
      'tanggal': item['tanggal'],
      'tonase': item['tonase'],
      'harga': item['harga'],
      'subtotal': item['subtotal'] ?? item['total_biaya'],
    };
  }

  List<Map<String, dynamic>> _expandInvoicePrintDetails(
    Iterable<Map<String, dynamic>> items,
  ) {
    final details = <Map<String, dynamic>>[];
    for (final item in items) {
      final rows = _toDetailList(item['rincian']);
      if (rows.isNotEmpty) {
        details.addAll(rows.map((row) => Map<String, dynamic>.from(row)));
      } else {
        details.add(_fallbackIncomeDetailRow(item));
      }
    }
    details.sort((a, b) {
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
      final aPlate = _resolveDetailPlateText(a);
      final bPlate = _resolveDetailPlateText(b);
      return aPlate.compareTo(bPlate);
    });
    return details;
  }

  List<_InvoicePrintGroup> _buildInvoicePrintGroups(
    List<Map<String, dynamic>> items,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final customerName =
          _normalizeInvoicePrintCustomerKey('${item['nama_pelanggan'] ?? ''}');
      final key = '${_resolveIsCompanyInvoice(
        invoiceNumber: item['no_invoice'],
        customerName: item['nama_pelanggan'],
      ) ? 'company' : 'personal'}|$customerName';
      groups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
    }
    return groups.entries
        .map(
          (entry) => _InvoicePrintGroup(
            id: entry.key,
            items: entry.value
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
          ),
        )
        .toList();
  }

  ({
    Map<String, dynamic> item,
    List<Map<String, dynamic>> details,
  }) _mergeInvoicePrintGroup(
    _InvoicePrintGroup group, {
    String? invoiceNumberOverride,
    String? kopDateOverride,
    String? kopLocationOverride,
  }) {
    final baseItem = Map<String, dynamic>.from(group.baseItem);
    final mergedDetails = _expandInvoicePrintDetails(group.items);
    final customerName = '${baseItem['nama_pelanggan'] ?? ''}';
    final isCompanyInvoice = _resolveIsCompanyInvoice(
      invoiceNumber: baseItem['no_invoice'],
      customerName: customerName,
    );
    double detailSubtotal(Map<String, dynamic> row) {
      final explicit = _toNum(row['subtotal']);
      if (explicit > 0) return explicit;
      return _toNum(row['tonase']) * _toNum(row['harga']);
    }

    final subtotal = mergedDetails.fold<double>(
      0,
      (sum, row) => sum + detailSubtotal(row),
    );
    final pph = isCompanyInvoice
        ? group.items.fold<double>(0, (sum, item) => sum + _toNum(item['pph']))
        : 0.0;
    final total = isCompanyInvoice
        ? group.items.fold<double>(
            0,
            (sum, item) =>
                sum + _toNum(item['total_bayar'] ?? item['total_biaya']),
          )
        : subtotal;
    final firstDate = mergedDetails
        .map((row) =>
            Formatters.parseDate(row['armada_start_date'] ?? row['tanggal']))
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (prev, current) =>
              prev == null || current.isBefore(prev) ? current : prev,
        );

    baseItem['rincian'] = mergedDetails;
    baseItem['total_biaya'] = subtotal;
    baseItem['pph'] = pph;
    baseItem['total_bayar'] = total;
    if (firstDate != null) {
      final mm = firstDate.month.toString().padLeft(2, '0');
      final dd = firstDate.day.toString().padLeft(2, '0');
      baseItem['tanggal'] = '${firstDate.year}-$mm-$dd';
    }
    if ((invoiceNumberOverride ?? '').trim().isNotEmpty) {
      baseItem['no_invoice'] = invoiceNumberOverride!.trim();
    }
    if ((kopDateOverride ?? '').trim().isNotEmpty) {
      baseItem['tanggal_kop'] = kopDateOverride!.trim();
    }
    if ((kopLocationOverride ?? '').trim().isNotEmpty) {
      baseItem['lokasi_kop'] = kopLocationOverride!.trim();
    }
    return (item: baseItem, details: mergedDetails);
  }

  String _toInvoicePrintDisplayDate(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    return '$dd-$mm-${value.year}';
  }

  String _toInvoicePrintDbDate(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '${value.year}-$mm-$dd';
  }

  Map<String, String> _buildGeneratedInvoiceNumbersForGroups({
    required List<Map<String, dynamic>> incomes,
    required List<_InvoicePrintGroup> groups,
    required List<_FixedInvoiceBatch> fixedInvoiceBatches,
  }) {
    final now = DateTime.now();
    final maxSeqByBucket = <String, int>{};

    bool isCompany(Map<String, dynamic> item) {
      return _resolveIsCompanyInvoice(
        invoiceNumber: item['no_invoice'],
        customerName: item['nama_pelanggan'],
      );
    }

    String bucketKey({
      required DateTime issuedDate,
      required bool isCompany,
    }) {
      final localDate = issuedDate.toLocal();
      final kind = isCompany ? 'company' : 'personal';
      return '$kind|${localDate.year % 100}|${localDate.month}';
    }

    void consumeExistingInvoiceNumber({
      required String invoiceNumber,
      required DateTime issuedDate,
      required bool isCompany,
      DateTime? referenceDate,
    }) {
      final localDate = issuedDate.toLocal();
      final seq = _extractPrintInvoiceSequence(
        invoiceNumber: invoiceNumber,
        month: localDate.month,
        yearTwoDigits: localDate.year % 100,
        isCompany: isCompany,
        referenceDate: referenceDate ?? localDate,
      );
      if (seq <= 0) return;
      final key = bucketKey(
        issuedDate: localDate,
        isCompany: isCompany,
      );
      final currentMax = maxSeqByBucket[key] ?? 0;
      if (seq > currentMax) {
        maxSeqByBucket[key] = seq;
      }
    }

    for (final income in incomes) {
      final rawNumber = '${income['no_invoice'] ?? ''}'.trim();
      if (rawNumber.isEmpty) continue;
      final issuedDate = Formatters.parseDate(
            income['tanggal_kop'] ?? income['tanggal'] ?? income['created_at'],
          ) ??
          now;
      consumeExistingInvoiceNumber(
        invoiceNumber: rawNumber,
        issuedDate: issuedDate,
        isCompany: isCompany(income),
        referenceDate: issuedDate,
      );
    }

    for (final batch in fixedInvoiceBatches) {
      final rawNumber = batch.invoiceNumber.trim();
      if (rawNumber.isEmpty) continue;
      final referenceDate =
          Formatters.parseDate(batch.kopDate ?? batch.createdAt) ?? now;
      consumeExistingInvoiceNumber(
        invoiceNumber: rawNumber,
        issuedDate: referenceDate,
        isCompany: _resolveIsCompanyInvoice(
          invoiceNumber: batch.invoiceNumber,
          customerName: batch.customerName,
        ),
        referenceDate: referenceDate,
      );
    }

    final generatedById = <String, String>{};
    final sortedGroups = groups.toList()
      ..sort((a, b) {
        final aDate = Formatters.parseDate(
              a.baseItem['tanggal_kop'] ??
                  a.baseItem['tanggal'] ??
                  a.baseItem['created_at'],
            ) ??
            now;
        final bDate = Formatters.parseDate(
              b.baseItem['tanggal_kop'] ??
                  b.baseItem['tanggal'] ??
                  b.baseItem['created_at'],
            ) ??
            now;
        final byDate = aDate.compareTo(bDate);
        if (byDate != 0) return byDate;
        final byCompany = (isCompany(a.baseItem) ? 1 : 0)
            .compareTo(isCompany(b.baseItem) ? 1 : 0);
        if (byCompany != 0) return byCompany;
        final aName = '${a.baseItem['nama_pelanggan'] ?? ''}'.trim();
        final bName = '${b.baseItem['nama_pelanggan'] ?? ''}'.trim();
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });

    for (final group in sortedGroups) {
      final item = group.baseItem;
      final existingIssuedDate = Formatters.parseDate(
            item['tanggal_kop'] ?? item['tanggal'] ?? item['created_at'],
          ) ??
          now;
      final generatedIssuedDate = now;
      final companyMode = isCompany(item);
      final normalizedExisting = Formatters.invoiceNumber(
        item['no_invoice'],
        item['tanggal_kop'] ?? item['tanggal'],
        customerName: item['nama_pelanggan'],
        isCompany: companyMode,
      );

      if (normalizedExisting != '-') {
        generatedById[group.id] = normalizedExisting;
        consumeExistingInvoiceNumber(
          invoiceNumber: normalizedExisting,
          issuedDate: existingIssuedDate,
          isCompany: companyMode,
          referenceDate: existingIssuedDate,
        );
        continue;
      }

      final key = bucketKey(
        issuedDate: generatedIssuedDate,
        isCompany: companyMode,
      );
      final nextSeq = (maxSeqByBucket[key] ?? 0) + 1;
      maxSeqByBucket[key] = nextSeq;
      generatedById[group.id] = _buildPrintInvoiceNumber(
        sequence: nextSeq,
        issuedDate: generatedIssuedDate,
        isCompany: companyMode,
      );
    }

    return generatedById;
  }

  Future<_InvoicePrintOverrides?> _openSingleInvoicePrintEditor(
    _InvoicePrintGroup group, {
    required String generatedInvoiceNumber,
  }) async {
    if (!mounted) return null;
    final item = group.baseItem;
    final customer = '${item['nama_pelanggan'] ?? '-'}';
    final modeLabel = _resolveIsCompanyInvoice(
      invoiceNumber: item['no_invoice'],
      customerName: item['nama_pelanggan'],
    )
        ? _t('Perusahaan', 'Company')
        : _t('Pribadi', 'Personal');
    final now = DateTime.now();
    final defaultKopLocation = '${item['lokasi_kop'] ?? ''}'.trim();
    final detailRows = _expandInvoicePrintDetails(group.items);
    final firstDetail = detailRows.isEmpty ? null : detailRows.first;
    final departureDate = Formatters.dmy(
      firstDetail?['armada_start_date'] ??
          firstDetail?['tanggal'] ??
          item['tanggal_kop'] ??
          item['tanggal'],
    );
    final routeLabel =
        '${firstDetail?['lokasi_muat'] ?? item['lokasi_muat'] ?? '-'} - ${firstDetail?['lokasi_bongkar'] ?? item['lokasi_bongkar'] ?? '-'}';
    final invoiceController =
        TextEditingController(text: generatedInvoiceNumber);
    final kopDateController = TextEditingController(
      text: _toInvoicePrintDisplayDate(now),
    );
    final kopLocationController =
        TextEditingController(text: defaultKopLocation);

    final result = await showDialog<_InvoicePrintOverrides>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickKopDate() async {
              final initial =
                  Formatters.parseDate(kopDateController.text) ?? now;
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: initial,
              );
              if (picked == null) return;
              setDialogState(() {
                kopDateController.text = _toInvoicePrintDisplayDate(picked);
              });
            }

            return AlertDialog(
              title: Text(_t('Edit KOP Invoice', 'Edit Invoice Header')),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.cardBorder(context),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$customer • $modeLabel',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (departureDate.trim().isNotEmpty &&
                            departureDate.trim() != '-') ...[
                          const SizedBox(height: 2),
                          Text(
                            departureDate,
                            style: TextStyle(
                              color: AppColors.textMutedFor(context),
                            ),
                          ),
                        ],
                        if (routeLabel.trim().isNotEmpty &&
                            routeLabel.trim() != '- -') ...[
                          const SizedBox(height: 2),
                          Text(
                            routeLabel,
                            style: TextStyle(
                              color: AppColors.textMutedFor(context),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextField(
                          controller: invoiceController,
                          decoration: InputDecoration(
                            labelText: _t('Nomor Invoice', 'Invoice Number'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: pickKopDate,
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: _t(
                                'Tanggal Kop Invoice',
                                'Invoice Header Date',
                              ),
                            ),
                            child: Text(
                              kopDateController.text.trim().isEmpty
                                  ? '-'
                                  : Formatters.dmy(kopDateController.text),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: kopLocationController,
                          decoration: InputDecoration(
                            labelText: _t(
                              'Lokasi Kop Invoice',
                              'Invoice Header Location',
                            ),
                          ),
                        ),
                      ],
                    ),
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
                  child: Text(_t('Batal', 'Cancel')),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final typedKopDateRaw = kopDateController.text.trim();
                    final parsed = Formatters.parseDate(typedKopDateRaw);
                    if (parsed == null) {
                      _snack(
                        _t(
                          'Format Tanggal KOP tidak valid. Gunakan dd-mm-yyyy.',
                          'Invalid invoice header date format. Use dd-mm-yyyy.',
                        ),
                        error: true,
                      );
                      return;
                    }
                    Navigator.pop(
                      context,
                      _InvoicePrintOverrides(
                        invoiceNumber: invoiceController.text.trim().isEmpty
                            ? generatedInvoiceNumber
                            : invoiceController.text.trim(),
                        kopDate: _toInvoicePrintDbDate(parsed),
                        kopLocation: kopLocationController.text.trim().isEmpty
                            ? defaultKopLocation
                            : kopLocationController.text.trim(),
                      ),
                    );
                  },
                  style: CvantButtonStyles.filled(
                    context,
                    color: AppColors.success,
                  ),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(_t('Cetak Invoice', 'Print Invoice')),
                ),
              ],
            );
          },
        );
      },
    );

    invoiceController.dispose();
    kopDateController.dispose();
    kopLocationController.dispose();
    return result;
  }

  Future<Map<String, dynamic>> _resolveLatestInvoiceItem(
    Map<String, dynamic> item,
  ) async {
    final invoiceId = '${item['id'] ?? ''}'.trim();
    if (invoiceId.isEmpty) return item;
    try {
      final latest = await widget.repository.fetchInvoiceById(invoiceId);
      if (latest == null || latest.isEmpty) return item;
      return <String, dynamic>{
        ...item,
        ...latest,
      };
    } catch (_) {
      return item;
    }
  }

  Future<List<Map<String, dynamic>>> _resolveLatestInvoiceItems(
    Iterable<Map<String, dynamic>> items,
  ) async {
    final itemList = items.toList();
    if (itemList.isEmpty) return const [];
    return Future.wait(
      itemList.map(_resolveLatestInvoiceItem),
    );
  }

  Future<void> _printSingleInvoiceFromPreview(
    Map<String, dynamic> item,
  ) async {
    final latestItem = await _resolveLatestInvoiceItem(item);
    final selectedGroups = _buildInvoicePrintGroups([latestItem]);
    if (selectedGroups.isEmpty) return;
    final group = selectedGroups.first;

    try {
      final since = DateTime.now().subtract(const Duration(days: 30));
      final incomes = await widget.repository.fetchInvoicesSince(since);
      final fixedInvoiceBatches = await _loadFixedInvoiceBatches();
      final generatedNumbersByGroupId = _buildGeneratedInvoiceNumbersForGroups(
        incomes: incomes.cast<Map<String, dynamic>>().toList(),
        groups: selectedGroups,
        fixedInvoiceBatches: fixedInvoiceBatches,
      );
      final generatedInvoiceNo = generatedNumbersByGroupId[group.id] ?? '-';
      final edited = await _openSingleInvoicePrintEditor(
        group,
        generatedInvoiceNumber: generatedInvoiceNo,
      );
      if (edited == null) return;

      final baseItem = group.baseItem;
      final effectiveInvoiceNo = edited.invoiceNumber.trim().isNotEmpty
          ? edited.invoiceNumber.trim()
          : generatedInvoiceNo;
      final effectiveKopDate = (edited.kopDate ?? '').trim();
      final effectiveKopLocation = (edited.kopLocation ?? '').trim();
      final fixedInvoiceIds = group.items
          .map((row) => '${row['id'] ?? ''}'.trim())
          .where((id) => id.isNotEmpty)
          .toList();
      final printMetaUpdates = <Map<String, String?>>[];

      for (var index = 0; index < group.items.length; index++) {
        final row = group.items[index];
        final id = '${row['id'] ?? ''}'.trim();
        if (id.isEmpty) continue;
        printMetaUpdates.add({
          'id': id,
          'no_invoice': index == 0
              ? effectiveInvoiceNo
              : '${row['no_invoice'] ?? ''}'.trim(),
          'kop_date': effectiveKopDate,
          'kop_location': effectiveKopLocation,
        });
      }

      final merged = _mergeInvoicePrintGroup(
        group,
        invoiceNumberOverride: effectiveInvoiceNo,
        kopDateOverride: effectiveKopDate.isEmpty ? null : effectiveKopDate,
        kopLocationOverride:
            effectiveKopLocation.isEmpty ? null : effectiveKopLocation,
      );
      final printed = await _printInvoicePdf(
        merged.item,
        merged.details,
        markAsFixed: true,
        showSuccessPopup: false,
        invoiceNumberOverride: effectiveInvoiceNo,
        kopDateOverride: effectiveKopDate.isEmpty ? null : effectiveKopDate,
        kopLocationOverride:
            effectiveKopLocation.isEmpty ? null : effectiveKopLocation,
        fixedInvoiceIds: fixedInvoiceIds,
        fixedBatch: _FixedInvoiceBatch(
          batchId: _buildFixedInvoiceBatchId(fixedInvoiceIds),
          invoiceIds: fixedInvoiceIds,
          invoiceNumber: effectiveInvoiceNo,
          customerName: '${baseItem['nama_pelanggan'] ?? ''}'.trim(),
          kopDate: effectiveKopDate.isEmpty ? null : effectiveKopDate,
          kopLocation:
              effectiveKopLocation.isEmpty ? null : effectiveKopLocation,
          status: '${baseItem['status'] ?? 'Unpaid'}'.trim().isEmpty
              ? 'Unpaid'
              : '${baseItem['status'] ?? 'Unpaid'}'.trim(),
          paidAt: '${baseItem['paid_at'] ?? ''}'.trim().isEmpty
              ? null
              : '${baseItem['paid_at'] ?? ''}'.trim(),
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      if (!printed) {
        if (mounted) {
          _snack(
            _t(
              'Belum ada invoice yang dicetak.',
              'No invoices were printed yet.',
            ),
          );
        }
        return;
      }

      await widget.repository.updateInvoicesPrintMetaBulk(
        updates: printMetaUpdates,
      );
      if (!mounted) return;
      _snack(
        _t(
          '1 invoice selesai diproses menjadi 1 dokumen cetak.',
          '1 invoice has been processed into 1 printable document.',
        ),
      );
      await _refresh();
      _notifyDataChanged();
    } catch (e) {
      if (!mounted) return;
      _snack(
        e.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  Future<void> _requestPengurusInvoiceEdit(Map<String, dynamic> item) async {
    final invoiceId = '${item['id'] ?? ''}'.trim();
    if (invoiceId.isEmpty) {
      _snack(
        _t('ID invoice tidak ditemukan.', 'Invoice ID not found.'),
        error: true,
      );
      return;
    }
    final editStatus =
        '${item['edit_request_status'] ?? 'none'}'.trim().toLowerCase();
    if (editStatus == 'pending') {
      _snack(
        _t(
          'Request edit sudah dikirim. Tunggu ACC admin/owner.',
          'Edit request has already been sent. Please wait for admin/owner approval.',
        ),
        error: true,
      );
      return;
    }
    final ok = await showCvantConfirmPopup(
      context: context,
      title: _t('Request Edit Income', 'Request Income Edit'),
      message: _t(
        'Pengurus perlu ACC admin/owner sebelum merevisi income ini. Kirim request edit sekarang?',
        'Pengurus needs admin/owner approval before revising this income. Send the edit request now?',
      ),
      type: CvantPopupType.warning,
      cancelLabel: _t('Batal', 'Cancel'),
      confirmLabel: _t('Kirim Request', 'Send Request'),
    );
    if (!ok) return;
    try {
      await widget.repository.requestPengurusInvoiceEdit(invoiceId);
      if (!mounted) return;
      _snack(
        _t(
          'Request edit berhasil dikirim ke admin/owner.',
          'The edit request was sent to admin/owner successfully.',
        ),
      );
      await _refresh();
      _notifyDataChanged();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _openInvoicePrintSelector({
    required List<Map<String, dynamic>> incomes,
  }) async {
    final allPrintableIncomes = await (() async {
      try {
        final fixedIds = _isAdminOrOwner
            ? await _loadFixedInvoiceIds()
            : await _loadLocalFixedInvoiceIds();
        final fetched = await widget.repository.fetchInvoices();
        final scoped = fetched.where((item) {
          final id = '${item['id'] ?? ''}'.trim();
          if (id.isNotEmpty && _locallyRemovedRowIds.contains(id)) return false;
          if (id.isNotEmpty && fixedIds.contains(id)) return false;
          if (_isPengurus) return _isOwnedByCurrentUser(item);
          if (_isAdminOrOwner) return _isPengurusIncomeApproved(item);
          return true;
        }).toList()
          ..sort((a, b) {
            final aDate = Formatters.parseDate(
                  a['tanggal_kop'] ?? a['tanggal'] ?? a['created_at'],
                ) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = Formatters.parseDate(
                  b['tanggal_kop'] ?? b['tanggal'] ?? b['created_at'],
                ) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
        return scoped;
      } catch (_) {
        return incomes;
      }
    })();

    if (allPrintableIncomes.isEmpty) {
      _snack(
        _t('Tidak ada invoice income untuk dicetak.',
            'No income invoices available to print.'),
        error: true,
      );
      return;
    }

    String keyword = '';
    final now = DateTime.now();
    int selectedMonth = now.month;
    int selectedYear = now.year;
    String customerKind = 'all';
    final selectedIds = <String>{};
    final searchController = TextEditingController();
    final fixedInvoiceBatches = await _loadFixedInvoiceBatches();

    bool isCompany(Map<String, dynamic> item) {
      return _resolveIsCompanyInvoice(
        invoiceNumber: item['no_invoice'],
        customerName: item['nama_pelanggan'],
      );
    }

    Map<String, String> buildGeneratedNumbersForGroups(
      List<_InvoicePrintGroup> groups,
    ) {
      return _buildGeneratedInvoiceNumbersForGroups(
        incomes: allPrintableIncomes,
        groups: groups,
        fixedInvoiceBatches: fixedInvoiceBatches,
      );
    }

    String extractPlate(Map<String, dynamic> row) {
      return _resolveDetailPlateText(row);
    }

    String buildRouteSummary(Map<String, dynamic> item) {
      final details = _toDetailList(item['rincian']);
      String route(dynamic muatValue, dynamic bongkarValue) {
        final muat = '${muatValue ?? ''}'.trim();
        final bongkar = '${bongkarValue ?? ''}'.trim();
        if (muat.isEmpty && bongkar.isEmpty) return '-';
        return '${muat.isEmpty ? '-' : muat} - ${bongkar.isEmpty ? '-' : bongkar}';
      }

      final routes = <String>{};
      for (final row in details) {
        final value = route(row['lokasi_muat'], row['lokasi_bongkar']);
        if (value != '-') routes.add(value);
      }
      if (routes.isNotEmpty) return routes.join(' | ');
      return route(item['lokasi_muat'], item['lokasi_bongkar']);
    }

    String buildDepartureSummary(Map<String, dynamic> item) {
      final details = _toDetailList(item['rincian']);
      final lines = <String>[];
      final seen = <String>{};

      void pushLine(Map<String, dynamic> row, dynamic fallbackDate) {
        final date = row['armada_start_date'] ?? fallbackDate ?? '';
        final dateLabel = Formatters.dmy(date);
        final plate = extractPlate(row);
        final key = '$dateLabel|$plate'.toUpperCase();
        if (seen.contains(key)) return;
        seen.add(key);
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

      if (lines.isEmpty) {
        return _t(
          'Keberangkatan armada tidak tersedia.',
          'Armada departure detail is unavailable.',
        );
      }
      if (lines.length <= 4) return lines.join('\n');
      final others = lines.length - 4;
      return '${lines.take(4).join('\n')}\n+$others ${_t('detail lainnya', 'other details')}';
    }

    String buildDepartureSummaryForItems(List<Map<String, dynamic>> items) {
      final lines = <String>[];
      final seen = <String>{};
      for (final item in items) {
        final detailLines = buildDepartureSummary(item)
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty);
        for (final line in detailLines) {
          final key = line.toUpperCase();
          if (seen.add(key)) {
            lines.add(line);
          }
        }
      }
      if (lines.isEmpty) {
        return _t(
          'Keberangkatan armada tidak tersedia.',
          'Armada departure detail is unavailable.',
        );
      }
      if (lines.length <= 4) return lines.join('\n');
      final others = lines.length - 4;
      return '${lines.take(4).join('\n')}\n+$others ${_t('detail lainnya', 'other details')}';
    }

    Future<Map<String, _InvoicePrintOverrides>?> openNumberEditor(
      List<_InvoicePrintGroup> selectedGroups,
    ) async {
      if (!mounted) return null;
      final generatedById = buildGeneratedNumbersForGroups(selectedGroups);
      final defaultKopDateById = <String, String>{};
      final defaultKopLocationById = <String, String>{};
      final noInvoiceControllers = <String, TextEditingController>{};
      final kopDateControllers = <String, TextEditingController>{};
      final kopLocationControllers = <String, TextEditingController>{};

      String toDisplayDate(dynamic raw) {
        final parsed = Formatters.parseDate(raw);
        if (parsed == null) return '';
        final dd = parsed.day.toString().padLeft(2, '0');
        final mm = parsed.month.toString().padLeft(2, '0');
        return '$dd-$mm-${parsed.year}';
      }

      String toDbDate(dynamic raw) {
        final parsed = Formatters.parseDate(raw);
        if (parsed == null) return '';
        final mm = parsed.month.toString().padLeft(2, '0');
        final dd = parsed.day.toString().padLeft(2, '0');
        return '${parsed.year}-$mm-$dd';
      }

      for (final group in selectedGroups) {
        final item = group.baseItem;
        final id = group.id;
        final generated = generatedById[id] ?? '-';
        final defaultKopDate = toDisplayDate(now);
        final defaultKopLocation = '${item['lokasi_kop'] ?? ''}'.trim();
        defaultKopDateById[id] = toDbDate(now);
        defaultKopLocationById[id] = defaultKopLocation;
        noInvoiceControllers[id] = TextEditingController(text: generated);
        kopDateControllers[id] = TextEditingController(text: defaultKopDate);
        kopLocationControllers[id] =
            TextEditingController(text: defaultKopLocation);
      }
      if (noInvoiceControllers.isEmpty) return null;

      final result = await showDialog<Map<String, _InvoicePrintOverrides>>(
        context: context,
        barrierColor: AppColors.popupOverlay,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> pickKopDate(String id) async {
                final initial =
                    Formatters.parseDate(kopDateControllers[id]?.text) ??
                        Formatters.parseDate(defaultKopDateById[id]) ??
                        DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDate: initial,
                );
                if (picked == null) return;
                setDialogState(() {
                  kopDateControllers[id]?.text = toDisplayDate(picked);
                });
              }

              return AlertDialog(
                title: Text(_t('Edit KOP Invoice', 'Edit Invoice Header')),
                content: SizedBox(
                  width: 640,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: selectedGroups.map((group) {
                        final item = group.baseItem;
                        final id = group.id;
                        final noInvoiceController = noInvoiceControllers[id];
                        final kopDateController = kopDateControllers[id];
                        final kopLocationController =
                            kopLocationControllers[id];
                        if (noInvoiceController == null ||
                            kopDateController == null ||
                            kopLocationController == null) {
                          return const SizedBox.shrink();
                        }
                        final customer = '${item['nama_pelanggan'] ?? '-'}';
                        final modeLabel = isCompany(item)
                            ? _t('Perusahaan', 'Company')
                            : _t('Pribadi', 'Personal');
                        final departureLines =
                            buildDepartureSummaryForItems(group.items)
                                .split('\n')
                                .where((line) => line.trim().isNotEmpty)
                                .toList();
                        final departureFirst = departureLines.isEmpty
                            ? null
                            : departureLines.first;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.cardBorder(context),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$customer • $modeLabel${group.items.length > 1 ? ' • ${group.items.length} ${_t('data', 'records')}' : ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if ((departureFirst ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    departureFirst!,
                                    style: TextStyle(
                                      color: AppColors.textMutedFor(context),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                TextField(
                                  controller: noInvoiceController,
                                  decoration: InputDecoration(
                                    labelText:
                                        _t('Nomor Invoice', 'Invoice Number'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => pickKopDate(id),
                                  borderRadius: BorderRadius.circular(10),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: _t(
                                        'Tanggal Kop Invoice',
                                        'Invoice Header Date',
                                      ),
                                    ),
                                    child: Text(
                                      kopDateController.text.trim().isEmpty
                                          ? '-'
                                          : Formatters.dmy(
                                              kopDateController.text,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: kopLocationController,
                                  decoration: InputDecoration(
                                    labelText: _t(
                                      'Lokasi Kop Invoice',
                                      'Invoice Header Location',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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
                    child: Text(_t('Batal', 'Cancel')),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      final values = <String, _InvoicePrintOverrides>{};
                      for (final entry in noInvoiceControllers.entries) {
                        final id = entry.key;
                        final typed = entry.value.text.trim();
                        final typedKopDateRaw =
                            kopDateControllers[id]?.text.trim();
                        final typedKopLocation =
                            kopLocationControllers[id]?.text.trim();
                        String? normalizedKopDate;
                        if ((typedKopDateRaw ?? '').isNotEmpty) {
                          final parsed = Formatters.parseDate(typedKopDateRaw);
                          if (parsed == null) {
                            _snack(
                              _t(
                                'Format Tanggal KOP tidak valid. Gunakan dd-mm-yyyy.',
                                'Invalid invoice header date format. Use dd-mm-yyyy.',
                              ),
                              error: true,
                            );
                            return;
                          }
                          normalizedKopDate = toDbDate(parsed);
                        }
                        values[id] = _InvoicePrintOverrides(
                          invoiceNumber: typed.isEmpty
                              ? (generatedById[id] ?? '-')
                              : typed,
                          kopDate: (normalizedKopDate ?? '').isEmpty
                              ? defaultKopDateById[id]
                              : normalizedKopDate,
                          kopLocation: (typedKopLocation ?? '').isEmpty
                              ? defaultKopLocationById[id]
                              : typedKopLocation,
                        );
                      }
                      Navigator.pop(context, values);
                    },
                    style: CvantButtonStyles.filled(
                      context,
                      color: AppColors.success,
                    ),
                    icon: const Icon(Icons.print_outlined),
                    label: Text(_t('Cetak Invoice', 'Print Invoice')),
                  ),
                ],
              );
            },
          );
        },
      );

      for (final controller in noInvoiceControllers.values) {
        controller.dispose();
      }
      for (final controller in kopDateControllers.values) {
        controller.dispose();
      }
      for (final controller in kopLocationControllers.values) {
        controller.dispose();
      }
      return result;
    }

    List<Map<String, dynamic>> filterRows() {
      bool inMonthYear(Map<String, dynamic> item) {
        final date = Formatters.parseDate(
          item['tanggal_kop'] ?? item['tanggal'] ?? item['created_at'],
        );
        if (date == null) return false;
        return date.year == selectedYear && date.month == selectedMonth;
      }

      return allPrintableIncomes.where((item) {
        if (!inMonthYear(item)) return false;
        if (customerKind == 'company' && !isCompany(item)) return false;
        if (customerKind == 'personal' && isCompany(item)) return false;
        if (keyword.trim().isEmpty) return true;
        return _matchesKeywordInAnyColumn(
          {
            ...item,
            '__route_summary': buildRouteSummary(item),
            '__departure_summary': buildDepartureSummary(item),
          },
          keyword,
        );
      }).toList()
        ..sort((a, b) {
          final aDate = Formatters.parseDate(
                a['tanggal_kop'] ?? a['tanggal'] ?? a['created_at'],
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = Formatters.parseDate(
                b['tanggal_kop'] ?? b['tanggal'] ?? b['created_at'],
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final rows = filterRows();
            return AlertDialog(
              title: Text(_t('Cetak Invoice', 'Print Invoice')),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('Filter Invoice', 'Invoice Filter'),
                        style:
                            TextStyle(color: AppColors.textMutedFor(context)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setDialogState(
                                  () => customerKind = 'company'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: customerKind == 'company'
                                    ? AppColors.success
                                    : AppColors.textMutedFor(context),
                                borderColor: customerKind == 'company'
                                    ? AppColors.success
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Perusahaan', 'Company')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setDialogState(
                                  () => customerKind = 'personal'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: customerKind == 'personal'
                                    ? AppColors.warning
                                    : AppColors.textMutedFor(context),
                                borderColor: customerKind == 'personal'
                                    ? AppColors.warning
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Pribadi', 'Personal')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CvantDropdownField<int>(
                              initialValue: selectedMonth,
                              decoration: InputDecoration(
                                labelText: _t('Bulan', 'Month'),
                              ),
                              items: List.generate(
                                12,
                                (index) => DropdownMenuItem<int>(
                                  value: index + 1,
                                  child: Text(
                                    _t(
                                      [
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
                                        'Desember'
                                      ][index],
                                      [
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
                                        'December'
                                      ][index],
                                    ),
                                  ),
                                ),
                              ),
                              onChanged: (value) => setDialogState(
                                () => selectedMonth = value ?? now.month,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: CvantDropdownField<int>(
                              initialValue: selectedYear,
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
                              onChanged: (value) => setDialogState(
                                () => selectedYear = value ?? now.year,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setDialogState(() => customerKind = 'all'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: customerKind == 'all'
                                    ? AppColors.blue
                                    : AppColors.textMutedFor(context),
                                borderColor: customerKind == 'all'
                                    ? AppColors.blue
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Semua', 'All')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: _t(
                            'Cari invoice (semua kolom)...',
                            'Search invoice (all columns)...',
                          ),
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (value) => setDialogState(() {
                          keyword = value;
                        }),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 340),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: AppColors.cardBorder(context)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: rows.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  _t(
                                    'Tidak ada invoice sesuai filter.',
                                    'No invoices match this filter.',
                                  ),
                                  style: TextStyle(
                                    color: AppColors.textMutedFor(context),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: rows.length,
                                separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: AppColors.divider(context)),
                                itemBuilder: (context, index) {
                                  final item = rows[index];
                                  final id = '${item['id'] ?? ''}'.trim();
                                  final checked = selectedIds.contains(id);
                                  final customer =
                                      '${item['nama_pelanggan'] ?? '-'}';
                                  final detailLabel =
                                      buildDepartureSummary(item);
                                  final routeLabel = buildRouteSummary(item);
                                  final kindLabel = isCompany(item)
                                      ? _t('Perusahaan', 'Company')
                                      : _t('Pribadi', 'Personal');
                                  return CheckboxListTile(
                                    value: checked,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        if (value == true) {
                                          selectedIds.add(id);
                                        } else {
                                          selectedIds.remove(id);
                                        }
                                      });
                                    },
                                    title: Text('$customer • $kindLabel'),
                                    subtitle: Text(
                                      '$detailLabel\n$routeLabel',
                                      maxLines: 5,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                  );
                                },
                              ),
                      ),
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
                  child: Text(_t('Batal', 'Cancel')),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    if (selectedIds.isEmpty) {
                      _snack(
                        _t('Pilih minimal 1 invoice.',
                            'Select at least 1 invoice.'),
                        error: true,
                      );
                      return;
                    }
                    final selected = await _resolveLatestInvoiceItems(
                      allPrintableIncomes
                          .where((item) =>
                              selectedIds.contains('${item['id'] ?? ''}'))
                          .cast<Map<String, dynamic>>(),
                    );
                    final selectedGroups = _buildInvoicePrintGroups(selected);
                    final generatedNumbersByGroupId =
                        buildGeneratedNumbersForGroups(selectedGroups);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    if (!mounted) return;

                    final editedOverridesById =
                        await openNumberEditor(selectedGroups);
                    if (editedOverridesById == null ||
                        editedOverridesById.isEmpty) {
                      return;
                    }

                    try {
                      final printQueue = <Map<String, dynamic>>[];
                      for (final group in selectedGroups) {
                        final baseItem = group.baseItem;
                        final edited = editedOverridesById[group.id];
                        final editedInvoiceNo =
                            (edited?.invoiceNumber ?? '').trim();
                        final editedKopDate = (edited?.kopDate ?? '').trim();
                        final editedKopLocation =
                            (edited?.kopLocation ?? '').trim();
                        final generatedInvoiceNo =
                            generatedNumbersByGroupId[group.id] ?? '-';
                        final effectiveInvoiceNo = editedInvoiceNo.isNotEmpty
                            ? editedInvoiceNo
                            : generatedInvoiceNo;
                        final effectiveKopDate = editedKopDate.isNotEmpty
                            ? editedKopDate
                            : '${baseItem['tanggal_kop'] ?? baseItem['tanggal'] ?? ''}'
                                .trim();
                        final effectiveKopLocation =
                            editedKopLocation.isNotEmpty
                                ? editedKopLocation
                                : '${baseItem['lokasi_kop'] ?? ''}'.trim();
                        final fixedInvoiceIds = group.items
                            .map((item) => '${item['id'] ?? ''}'.trim())
                            .where((id) => id.isNotEmpty)
                            .toList();
                        final groupPrintMetaUpdates = <Map<String, String?>>[];

                        for (var index = 0;
                            index < group.items.length;
                            index++) {
                          final item = group.items[index];
                          final id = '${item['id'] ?? ''}'.trim();
                          if (id.isEmpty) continue;
                          groupPrintMetaUpdates.add({
                            'id': id,
                            // Keep secondary invoices unique in DB to avoid
                            // violating the unique no_invoice constraint.
                            'no_invoice': index == 0
                                ? effectiveInvoiceNo
                                : '${item['no_invoice'] ?? ''}'.trim(),
                            'kop_date': editedKopDate,
                            'kop_location': editedKopLocation,
                          });
                        }

                        final merged = _mergeInvoicePrintGroup(
                          group,
                          invoiceNumberOverride: effectiveInvoiceNo,
                          kopDateOverride:
                              editedKopDate.isEmpty ? null : editedKopDate,
                          kopLocationOverride: editedKopLocation.isEmpty
                              ? null
                              : editedKopLocation,
                        );
                        printQueue.add({
                          'item': merged.item,
                          'details': merged.details,
                          'invoice_no': effectiveInvoiceNo,
                          'kop_date': effectiveKopDate,
                          'kop_location': effectiveKopLocation,
                          'print_meta_updates': groupPrintMetaUpdates,
                          'fixed_invoice_ids': fixedInvoiceIds,
                          'fixed_batch': _FixedInvoiceBatch(
                            batchId: _buildFixedInvoiceBatchId(fixedInvoiceIds),
                            invoiceIds: fixedInvoiceIds,
                            invoiceNumber: effectiveInvoiceNo,
                            customerName:
                                '${baseItem['nama_pelanggan'] ?? ''}'.trim(),
                            kopDate: effectiveKopDate.isEmpty
                                ? null
                                : effectiveKopDate,
                            kopLocation: effectiveKopLocation.isEmpty
                                ? null
                                : effectiveKopLocation,
                            status: '${baseItem['status'] ?? 'Unpaid'}'
                                    .trim()
                                    .isEmpty
                                ? 'Unpaid'
                                : '${baseItem['status'] ?? 'Unpaid'}'.trim(),
                            paidAt:
                                '${baseItem['paid_at'] ?? ''}'.trim().isEmpty
                                    ? null
                                    : '${baseItem['paid_at'] ?? ''}'.trim(),
                            createdAt: DateTime.now().toIso8601String(),
                          ),
                        });
                      }

                      var printedGroupCount = 0;
                      var printedInvoiceCount = 0;
                      for (final queued in printQueue) {
                        final printItem =
                            Map<String, dynamic>.from(queued['item'] as Map);
                        final printDetails =
                            (queued['details'] as List<dynamic>? ?? const [])
                                .whereType<Map>()
                                .map((row) => Map<String, dynamic>.from(row))
                                .toList();
                        final invoiceNo =
                            '${queued['invoice_no'] ?? ''}'.trim();
                        final kopDate = '${queued['kop_date'] ?? ''}'.trim();
                        final kopLocation =
                            '${queued['kop_location'] ?? ''}'.trim();
                        final printed = await _printInvoicePdf(
                          printItem,
                          printDetails,
                          markAsFixed: true,
                          showSuccessPopup: false,
                          invoiceNumberOverride: invoiceNo,
                          kopDateOverride: kopDate.isEmpty ? null : kopDate,
                          kopLocationOverride:
                              kopLocation.isEmpty ? null : kopLocation,
                          fixedInvoiceIds:
                              (queued['fixed_invoice_ids'] as List<dynamic>? ??
                                      const <dynamic>[])
                                  .map((id) => '$id')
                                  .toList(),
                          fixedBatch:
                              queued['fixed_batch'] as _FixedInvoiceBatch?,
                        );
                        if (!printed) continue;
                        await widget.repository.updateInvoicesPrintMetaBulk(
                          updates:
                              (queued['print_meta_updates'] as List<dynamic>? ??
                                      const <dynamic>[])
                                  .whereType<Map>()
                                  .map(
                                    (row) => Map<String, String?>.from(
                                      row.map(
                                        (key, value) =>
                                            MapEntry('$key', value as String?),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        );
                        printedGroupCount++;
                        printedInvoiceCount +=
                            (queued['fixed_invoice_ids'] as List<dynamic>? ??
                                    const <dynamic>[])
                                .length;
                      }
                      if (printedGroupCount <= 0) {
                        _snack(
                          _t(
                            'Belum ada invoice yang dicetak.',
                            'No invoices were printed yet.',
                          ),
                        );
                        return;
                      }
                      if (!mounted) return;
                      _snack(
                        _t(
                          '$printedInvoiceCount invoice selesai diproses menjadi $printedGroupCount dokumen cetak.',
                          '$printedInvoiceCount invoices have been grouped into $printedGroupCount printable documents.',
                        ),
                      );
                      await _refresh();
                      _notifyDataChanged();
                    } catch (e) {
                      if (!mounted) return;
                      _snack(
                        e.toString().replaceFirst('Exception: ', ''),
                        error: true,
                      );
                      return;
                    }
                  },
                  style: CvantButtonStyles.filled(
                    context,
                    color: AppColors.success,
                  ),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(_t('Cetak Invoice', 'Print Invoice')),
                ),
              ],
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  Future<void> _openReportSummary({
    required List<Map<String, dynamic>> incomes,
    required List<Map<String, dynamic>> expenses,
  }) async {
    List<Map<String, dynamic>> buildRows({
      required DateTime start,
      required DateTime end,
      required bool includeIncome,
      required bool includeExpense,
      required String customerKind,
      required Set<String> allowedStatuses,
      required String keyword,
    }) {
      final rows = <Map<String, dynamic>>[];

      bool inRange(dynamic value) {
        final date = Formatters.parseDate(value);
        if (date == null) return false;
        return !date.isBefore(start) && date.isBefore(end);
      }

      bool statusAllowed(String status) {
        if (allowedStatuses.isEmpty) return true;
        return allowedStatuses.contains(status);
      }

      bool keywordAllowed(Map<String, dynamic> source) {
        final q = keyword.trim();
        if (q.isEmpty) return true;
        return _matchesKeywordInAnyColumn(source, q);
      }

      String resolveTujuan(
        Map<String, dynamic> source, {
        Map<String, dynamic>? detail,
      }) {
        final detailDestination = '${detail?['lokasi_bongkar'] ?? ''}'.trim();
        if (detailDestination.isNotEmpty) {
          return detailDestination;
        }

        final details = _toDetailList(source['rincian']);
        final tujuan = <String>{};
        for (final row in details) {
          final destination = '${row['lokasi_bongkar'] ?? ''}'.trim();
          if (destination.isNotEmpty) {
            tujuan.add(destination);
          }
        }
        if (tujuan.isNotEmpty) {
          return tujuan.join(' | ');
        }
        final fallback = '${source['lokasi_bongkar'] ?? ''}'.trim();
        return fallback.isEmpty ? '-' : fallback;
      }

      dynamic resolveKeberangkatanDate(
        Map<String, dynamic> source, {
        Map<String, dynamic>? detail,
      }) {
        return detail?['armada_start_date'] ??
            source['armada_start_date'] ??
            source['tanggal_kop'] ??
            source['tanggal'] ??
            source['created_at'];
      }

      double resolveDetailSubtotal(
        Map<String, dynamic> source, {
        Map<String, dynamic>? detail,
        int detailCount = 1,
      }) {
        final subtotalFromDetail = _toNum(detail?['subtotal']);
        if (subtotalFromDetail > 0) return subtotalFromDetail;
        final tonase = _toNum(detail?['tonase'] ?? source['tonase']);
        final harga = _toNum(detail?['harga'] ?? source['harga']);
        final computed = tonase * harga;
        if (computed > 0) return computed;
        final invoiceSubtotal = _toNum(source['total_biaya']);
        if (invoiceSubtotal <= 0) return 0;
        if (detailCount <= 1) return invoiceSubtotal;
        return invoiceSubtotal / detailCount;
      }

      bool incomeKindAllowed(Map<String, dynamic> source) {
        if (customerKind == 'all') return true;
        final customerName = '${source['nama_pelanggan'] ?? ''}'.trim();
        final invoiceNumber = '${source['no_invoice'] ?? ''}'.trim();
        final isCompany = _resolveIsCompanyInvoice(
          invoiceNumber: invoiceNumber,
          customerName: customerName,
        );
        return customerKind == 'company' ? isCompany : !isCompany;
      }

      if (includeIncome) {
        for (final item in incomes) {
          final status = '${item['status'] ?? 'Waiting'}';
          if (!statusAllowed(status)) continue;
          if (!incomeKindAllowed(item)) continue;
          final customerName = '${item['nama_pelanggan'] ?? '-'}';
          final invoiceNumber = Formatters.invoiceNumber(
            item['no_invoice'],
            item['tanggal_kop'] ?? item['tanggal'],
            customerName: customerName,
          );
          final isCompanyInvoice = _resolveIsCompanyInvoice(
            invoiceNumber: item['no_invoice'],
            customerName: customerName,
          );

          final detailRows = _toDetailList(item['rincian']);
          if (detailRows.isNotEmpty) {
            for (var i = 0; i < detailRows.length; i++) {
              final detail = detailRows[i];
              final rowSource = <String, dynamic>{...item, ...detail};
              final rowDate = resolveKeberangkatanDate(item, detail: detail);
              if (!inRange(rowDate)) continue;
              if (!keywordAllowed(rowSource)) continue;

              final subtotal = resolveDetailSubtotal(
                item,
                detail: detail,
                detailCount: detailRows.length,
              );
              final pph = isCompanyInvoice
                  ? max(0.0, (subtotal * 0.02).floorToDouble())
                  : 0.0;
              final total =
                  isCompanyInvoice ? max(0.0, subtotal - pph) : subtotal;

              rows.add({
                '__key':
                    'income:${item['id'] ?? item['no_invoice'] ?? item['created_at'] ?? rows.length}:$i',
                '__type': 'Income',
                '__number': invoiceNumber,
                '__date': rowDate,
                '__name': customerName,
                '__customer': customerName,
                '__status': status,
                '__amount': total,
                '__jumlah': subtotal,
                '__pph': pph,
                '__total': total,
                '__tujuan': resolveTujuan(item, detail: detail),
                '__income': total,
                '__expense': 0.0,
              });
            }
            continue;
          }

          final rowDate = resolveKeberangkatanDate(item);
          if (!inRange(rowDate)) continue;
          if (!keywordAllowed(item)) continue;

          final subtotal = _toNum(item['total_biaya']);
          final pph = isCompanyInvoice ? _toNum(item['pph']) : 0.0;
          final total = isCompanyInvoice
              ? _toNum(item['total_bayar'] ?? item['total_biaya'])
              : subtotal;

          rows.add({
            '__key':
                'income:${item['id'] ?? item['no_invoice'] ?? item['created_at'] ?? rows.length}',
            '__type': 'Income',
            '__number': invoiceNumber,
            '__date': rowDate,
            '__name': customerName,
            '__customer': customerName,
            '__status': status,
            '__amount': total,
            '__jumlah': subtotal,
            '__pph': pph,
            '__total': total,
            '__tujuan': resolveTujuan(item),
            '__income': total,
            '__expense': 0.0,
          });
        }
      }

      if (includeExpense && customerKind == 'all') {
        for (final item in expenses) {
          final status = '${item['status'] ?? 'Recorded'}';
          final amount = _toNum(item['total_pengeluaran']);
          if (!inRange(item['tanggal'] ?? item['created_at'])) continue;
          if (!statusAllowed(status)) continue;
          if (!keywordAllowed(item)) continue;
          rows.add({
            '__key':
                'expense:${item['id'] ?? item['no_expense'] ?? item['created_at'] ?? rows.length}',
            '__type': 'Expense',
            '__number': item['no_expense'] ?? '-',
            '__date': item['tanggal'] ?? item['created_at'],
            '__name':
                item['kategori'] ?? item['keterangan'] ?? item['note'] ?? '-',
            '__customer':
                item['kategori'] ?? item['keterangan'] ?? item['note'] ?? '-',
            '__status': status,
            '__amount': amount,
            '__jumlah': amount,
            '__pph': 0.0,
            '__total': amount,
            '__tujuan': '-',
            '__income': 0.0,
            '__expense': amount,
          });
        }
      }

      rows.sort((a, b) {
        final aDate = Formatters.parseDate(a['__date']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = Formatters.parseDate(b['__date']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return rows;
    }

    Future<void> printReportPdf({
      required DateTime start,
      required DateTime end,
      required List<Map<String, dynamic>> rows,
      required double totalIncome,
      required double totalExpense,
      required bool includeIncome,
      required bool includeExpense,
      required String customerKind,
      required String orientation,
    }) async {
      String monthName(int month) {
        const id = [
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
        ];
        const en = [
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
        ];
        return _t(id[month - 1], en[month - 1]);
      }

      final isYearPeriod = start.month == 1 &&
          start.day == 1 &&
          end.year == start.year + 1 &&
          end.month == 1 &&
          end.day == 1;
      final periodLabel = isYearPeriod
          ? '${start.year}'
          : '${monthName(start.month)} ${start.year}';

      final reportHeader = () {
        if (includeIncome && includeExpense) {
          return _t(
            'Laporan (Pemasukkan dan Pengeluaran)',
            'Report (Income and Expense)',
          );
        }
        if (includeIncome) {
          if (customerKind == 'company') {
            return _t(
              'Laporan Pemasukkan (Perusahaan)',
              'Income Report (Company)',
            );
          }
          if (customerKind == 'personal') {
            return _t(
              'Laporan Pemasukkan (Pribadi)',
              'Income Report (Personal)',
            );
          }
          return _t('Laporan Pemasukkan', 'Income Report');
        }
        if (customerKind == 'company') {
          return _t(
            'Laporan Pengeluaran (Perusahaan)',
            'Expense Report (Company)',
          );
        }
        if (customerKind == 'personal') {
          return _t(
            'Laporan Pengeluaran (Pribadi)',
            'Expense Report (Personal)',
          );
        }
        return _t('Laporan Pengeluaran', 'Expense Report');
      }();

      await Printing.layoutPdf(
        onLayout: (format) async {
          final companyMode = customerKind == 'company';
          final maxNumberLen = rows
              .map((row) => '${row['__number'] ?? '-'}'.length)
              .fold<int>(0, (maxLen, len) => max(maxLen, len));
          final maxCustomerLen = rows
              .map((row) =>
                  '${row['__customer'] ?? row['__name'] ?? '-'}'.length)
              .fold<int>(0, (maxLen, len) => max(maxLen, len));
          final maxTujuanLen = rows
              .map((row) => '${row['__tujuan'] ?? '-'}'.length)
              .fold<int>(0, (maxLen, len) => max(maxLen, len));

          final autoLandscape = rows.length > 18 ||
              maxNumberLen > 24 ||
              maxCustomerLen > 18 ||
              maxTujuanLen > 14;
          final isLandscape = orientation == 'landscape'
              ? true
              : orientation == 'portrait'
                  ? false
                  : autoLandscape;

          double headerFont = isLandscape ? 9 : 8.5;
          double cellFont = isLandscape ? 8 : 7.5;
          if (maxNumberLen > 34 || rows.length > 28) {
            headerFont -= 0.5;
            cellFont -= 0.5;
          }
          if (maxNumberLen > 48 || rows.length > 44) {
            headerFont -= 0.5;
            cellFont -= 0.5;
          }
          headerFont = headerFont.clamp(7.0, 10.0).toDouble();
          cellFont = cellFont.clamp(6.5, 9.0).toDouble();

          final pageFormat = isLandscape ? format.landscape : format;

          String fitCell(String value, int maxLen) {
            final text = value.trim();
            if (text.length <= maxLen) return text;
            return '${text.substring(0, maxLen - 1)}...';
          }

          final customerMaxLen = isLandscape ? 26 : 18;
          final tujuanMaxLen = isLandscape ? 22 : 16;

          final headers = companyMode
              ? const [
                  'NO',
                  'TANGGAL',
                  'CUSTOMER',
                  'JUMLAH',
                  'PPH',
                  'TOTAL',
                  'TUJUAN'
                ]
              : const [
                  'NO',
                  'TANGGAL',
                  'CUSTOMER',
                  'JUMLAH',
                  'TOTAL',
                  'TUJUAN'
                ];
          final columnWidths = companyMode
              ? <int, pw.TableColumnWidth>{
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(0.95),
                  2: const pw.FlexColumnWidth(1.55),
                  3: const pw.FlexColumnWidth(1.05),
                  4: const pw.FlexColumnWidth(0.9),
                  5: const pw.FlexColumnWidth(1.05),
                  6: const pw.FlexColumnWidth(1.4),
                }
              : <int, pw.TableColumnWidth>{
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(0.95),
                  2: const pw.FlexColumnWidth(1.7),
                  3: const pw.FlexColumnWidth(1.15),
                  4: const pw.FlexColumnWidth(1.15),
                  5: const pw.FlexColumnWidth(1.55),
                };
          final cellAlignments = <int, pw.Alignment>{
            for (int i = 0; i < headers.length; i++) i: pw.Alignment.center,
          };
          final tableData = List<List<String>>.generate(rows.length, (index) {
            final row = rows[index];
            if (companyMode) {
              return [
                '${index + 1}',
                Formatters.dmy(row['__date']),
                fitCell('${row['__customer'] ?? row['__name'] ?? '-'}',
                    customerMaxLen),
                Formatters.rupiah(_toNum(row['__jumlah'])),
                Formatters.rupiah(_toNum(row['__pph'])),
                Formatters.rupiah(_toNum(row['__total'])),
                fitCell('${row['__tujuan'] ?? '-'}', tujuanMaxLen),
              ];
            }
            return [
              '${index + 1}',
              Formatters.dmy(row['__date']),
              fitCell('${row['__customer'] ?? row['__name'] ?? '-'}',
                  customerMaxLen),
              Formatters.rupiah(_toNum(row['__jumlah'])),
              Formatters.rupiah(_toNum(row['__total'])),
              fitCell('${row['__tujuan'] ?? '-'}', tujuanMaxLen),
            ];
          });

          final doc = pw.Document();
          doc.addPage(
            pw.MultiPage(
              pageFormat: pageFormat,
              margin: const pw.EdgeInsets.all(20),
              build: (context) => [
                pw.Text(
                  'CV ANT - $reportHeader',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('${_t('Periode', 'Period')}: $periodLabel'),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  cellPadding:
                      const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  cellHeight: 16,
                  headerHeight: 16,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                    fontSize: headerFont,
                  ),
                  cellStyle: pw.TextStyle(fontSize: cellFont),
                  cellAlignments: cellAlignments,
                  columnWidths: columnWidths,
                  headers: headers,
                  data: tableData,
                ),
                pw.SizedBox(height: 12),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (includeIncome && includeExpense) ...[
                        pw.Text(
                          '${_t('Total Income', 'Total Income')}: ${Formatters.rupiah(totalIncome)}',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                        pw.Text(
                          '${_t('Total Expense', 'Total Expense')}: ${Formatters.rupiah(totalExpense)}',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                        pw.Text(
                          '${_t('Selisih', 'Difference')}: ${Formatters.rupiah(totalIncome - totalExpense)}',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ] else if (includeIncome) ...[
                        pw.Text(
                          '${_t('Total Income', 'Total Income')}: ${Formatters.rupiah(totalIncome)}',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ] else if (includeExpense) ...[
                        pw.Text(
                          '${_t('Total Expense', 'Total Expense')}: ${Formatters.rupiah(totalExpense)}',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
          return doc.save();
        },
      );
    }

    final allStatuses = <String>{
      ...incomes.map((item) => '${item['status'] ?? 'Waiting'}'),
      ...expenses.map((item) => '${item['status'] ?? 'Recorded'}'),
    }.where((status) => status.trim().isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    String range = 'month';
    String orientation = 'auto';
    String customerKind = 'all';
    bool includeIncome = true;
    bool includeExpense = true;
    final selectedStatuses = <String>{...allStatuses};
    final rowSelections = <String, bool>{};
    String keywordText = '';
    final currentYear = DateTime.now().year;
    int selectedYear = currentYear;
    int selectedMonth = DateTime.now().month;
    final availableYears = <int>{
      currentYear,
      ...incomes
          .map((item) =>
              Formatters.parseDate(item['tanggal'] ?? item['created_at'])?.year)
          .whereType<int>(),
      ...expenses
          .map((item) =>
              Formatters.parseDate(item['tanggal'] ?? item['created_at'])?.year)
          .whereType<int>(),
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    String monthLabel(int month) {
      const id = [
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
      ];
      const en = [
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
      ];
      return _t(id[month - 1], en[month - 1]);
    }

    final selection = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final start = range == 'year'
                ? DateTime(selectedYear, 1, 1)
                : DateTime(selectedYear, selectedMonth, 1);
            final end = range == 'year'
                ? DateTime(selectedYear + 1, 1, 1)
                : DateTime(selectedYear, selectedMonth + 1, 1);
            final previewRows = buildRows(
              start: start,
              end: end,
              includeIncome: includeIncome,
              includeExpense: includeExpense,
              customerKind: customerKind,
              allowedStatuses: selectedStatuses,
              keyword: keywordText.trim(),
            );
            final availableKeys =
                previewRows.map((row) => '${row['__key']}').toSet();
            rowSelections.removeWhere((key, _) => !availableKeys.contains(key));
            for (final key in availableKeys) {
              rowSelections.putIfAbsent(key, () => true);
            }
            final selectedCount = previewRows
                .where((row) => rowSelections['${row['__key']}'] == true)
                .length;

            return AlertDialog(
              title: Text(_t('Buat Laporan PDF', 'Generate PDF Report')),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('Range Report', 'Report Range'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setDialogState(() => range = 'month'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: range == 'month'
                                    ? AppColors.blue
                                    : AppColors.textMutedFor(context),
                                borderColor: range == 'month'
                                    ? AppColors.blue
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Bulanan', 'Monthly')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setDialogState(() => range = 'year'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: range == 'year'
                                    ? AppColors.success
                                    : AppColors.textMutedFor(context),
                                borderColor: range == 'year'
                                    ? AppColors.success
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Tahunan', 'Yearly')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _t('Orientasi Kertas', 'Page Orientation'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setDialogState(() => orientation = 'auto'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: orientation == 'auto'
                                    ? AppColors.blue
                                    : AppColors.textMutedFor(context),
                                borderColor: orientation == 'auto'
                                    ? AppColors.blue
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Otomatis', 'Auto')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setDialogState(
                                  () => orientation = 'landscape'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: orientation == 'landscape'
                                    ? AppColors.blue
                                    : AppColors.textMutedFor(context),
                                borderColor: orientation == 'landscape'
                                    ? AppColors.blue
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Landscape', 'Landscape')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setDialogState(
                                  () => orientation = 'portrait'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: orientation == 'portrait'
                                    ? AppColors.blue
                                    : AppColors.textMutedFor(context),
                                borderColor: orientation == 'portrait'
                                    ? AppColors.blue
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Portrait', 'Portrait')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (value) =>
                            setDialogState(() => keywordText = value),
                        decoration: InputDecoration(
                          hintText: _t(
                            'Cari data report (semua kolom)...',
                            'Search report data (all columns)...',
                          ),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t('Jenis Customer', 'Customer Type'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setDialogState(() => customerKind = 'all'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: customerKind == 'all'
                                    ? AppColors.blue
                                    : AppColors.textMutedFor(context),
                                borderColor: customerKind == 'all'
                                    ? AppColors.blue
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Semua', 'All')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setDialogState(
                                  () => customerKind = 'company'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: customerKind == 'company'
                                    ? AppColors.success
                                    : AppColors.textMutedFor(context),
                                borderColor: customerKind == 'company'
                                    ? AppColors.success
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Perusahaan', 'Company')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setDialogState(
                                  () => customerKind = 'personal'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: customerKind == 'personal'
                                    ? AppColors.warning
                                    : AppColors.textMutedFor(context),
                                borderColor: customerKind == 'personal'
                                    ? AppColors.warning
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Pribadi', 'Personal')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t('Periode Manual', 'Manual Period'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (range == 'month') ...[
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<int>(
                                initialValue: selectedMonth,
                                decoration: InputDecoration(
                                  labelText: _t('Bulan', 'Month'),
                                ),
                                items: List.generate(
                                  12,
                                  (index) => DropdownMenuItem<int>(
                                    value: index + 1,
                                    child: Text(monthLabel(index + 1)),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setDialogState(() => selectedMonth = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue:
                                  availableYears.contains(selectedYear)
                                      ? selectedYear
                                      : availableYears.first,
                              decoration: InputDecoration(
                                labelText: _t('Tahun', 'Year'),
                              ),
                              items: availableYears
                                  .map(
                                    (year) => DropdownMenuItem<int>(
                                      value: year,
                                      child: Text('$year'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() => selectedYear = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: includeIncome,
                        onChanged: (value) =>
                            setDialogState(() => includeIncome = value ?? true),
                        title: Text(_t('Income', 'Income')),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: includeExpense,
                        onChanged: (value) => setDialogState(
                            () => includeExpense = value ?? true),
                        title: Text(_t('Expense', 'Expense')),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t('Checklist Status', 'Status Checklist'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      if (allStatuses.isEmpty)
                        Text(
                          _t('Tidak ada status tersedia.',
                              'No status available.'),
                          style:
                              TextStyle(color: AppColors.textMutedFor(context)),
                        )
                      else
                        SizedBox(
                          height: max(60, min(180, 36.0 * allStatuses.length)),
                          child: ListView.builder(
                            itemCount: allStatuses.length,
                            itemBuilder: (context, index) {
                              final status = allStatuses[index];
                              final checked = selectedStatuses.contains(status);
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                value: checked,
                                onChanged: (value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      selectedStatuses.add(status);
                                    } else {
                                      selectedStatuses.remove(status);
                                    }
                                  });
                                },
                                title: Text(status),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'Hasil filter: ${previewRows.length} data • Dipilih: $selectedCount',
                          'Filtered result: ${previewRows.length} rows • Selected: $selectedCount',
                        ),
                        style: TextStyle(
                          color: AppColors.textMutedFor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            _t('Pilih Invoice Manual',
                                'Manual Invoice Selection'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: previewRows.isEmpty
                                ? null
                                : () => setDialogState(() {
                                      for (final row in previewRows) {
                                        rowSelections['${row['__key']}'] = true;
                                      }
                                    }),
                            child: Text(_t('Pilih Semua', 'Select All')),
                          ),
                          TextButton(
                            onPressed: previewRows.isEmpty
                                ? null
                                : () => setDialogState(() {
                                      for (final row in previewRows) {
                                        rowSelections['${row['__key']}'] =
                                            false;
                                      }
                                    }),
                            child: Text(_t('Hapus Pilihan', 'Clear Selection')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (previewRows.isEmpty)
                        Text(
                          _t('Tidak ada invoice pada filter ini.',
                              'No invoices in this filter.'),
                          style:
                              TextStyle(color: AppColors.textMutedFor(context)),
                        )
                      else
                        SizedBox(
                          height: 220,
                          child: ListView.separated(
                            itemCount: previewRows.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: AppColors.cardBorder(context),
                            ),
                            itemBuilder: (context, index) {
                              final row = previewRows[index];
                              final key = '${row['__key']}';
                              final checked = rowSelections[key] == true;
                              final income = _toNum(row['__income']);
                              final expense = _toNum(row['__expense']);
                              final amountLabel = income > 0
                                  ? '${_t('Income', 'Income')}: ${Formatters.rupiah(income)}'
                                  : '${_t('Expense', 'Expense')}: ${Formatters.rupiah(expense)}';
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                value: checked,
                                onChanged: (value) => setDialogState(
                                  () => rowSelections[key] = value ?? false,
                                ),
                                title: Text(
                                  '${row['__number'] ?? '-'} • ${Formatters.dmy(row['__date'])}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  amountLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            },
                          ),
                        ),
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
                  child: Text(_t('Batal', 'Cancel')),
                ),
                FilledButton.icon(
                  onPressed: () {
                    if (!includeIncome && !includeExpense) return;
                    Navigator.pop(context, {
                      'range': range,
                      'includeIncome': includeIncome,
                      'includeExpense': includeExpense,
                      'orientation': orientation,
                      'customerKind': customerKind,
                      'month': selectedMonth,
                      'year': selectedYear,
                      'statuses': selectedStatuses.toList(),
                      'keyword': keywordText.trim(),
                      'selectedKeys': rowSelections.entries
                          .where((entry) => entry.value)
                          .map((entry) => entry.key)
                          .toList(),
                    });
                  },
                  style: CvantButtonStyles.filled(context,
                      color: AppColors.success),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(_t('Cetak PDF', 'Print PDF')),
                ),
              ],
            );
          },
        );
      },
    );
    if (selection == null) return;

    final selectedRange = '${selection['range'] ?? 'month'}';
    final selectedCustomerKind = '${selection['customerKind'] ?? 'all'}';
    final reportMonth =
        (((selection['month'] as num?)?.toInt() ?? DateTime.now().month)
                .clamp(1, 12))
            .toInt();
    final reportYear =
        ((selection['year'] as num?)?.toInt() ?? DateTime.now().year);
    final start = selectedRange == 'year'
        ? DateTime(reportYear, 1, 1)
        : DateTime(reportYear, reportMonth, 1);
    final end = selectedRange == 'year'
        ? DateTime(reportYear + 1, 1, 1)
        : DateTime(reportYear, reportMonth + 1, 1);
    final includeIncomeSelected = selection['includeIncome'] == true;
    final includeExpenseSelected = selection['includeExpense'] == true;
    final selectedOrientation = '${selection['orientation'] ?? 'auto'}';
    final statusFilters =
        (selection['statuses'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => '$item')
            .toSet();
    final selectedKeys =
        (selection['selectedKeys'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => '$item')
            .toSet();
    final keyword = '${selection['keyword'] ?? ''}';

    if (!includeIncomeSelected && !includeExpenseSelected) {
      _snack(
        _t(
          'Pilih minimal satu jenis data (Income/Expense).',
          'Select at least one data type (Income/Expense).',
        ),
        error: true,
      );
      return;
    }

    final allRows = buildRows(
      start: start,
      end: end,
      includeIncome: includeIncomeSelected,
      includeExpense: includeExpenseSelected,
      customerKind: selectedCustomerKind,
      allowedStatuses: statusFilters,
      keyword: keyword,
    );
    final rows = selectedKeys.isEmpty
        ? <Map<String, dynamic>>[]
        : allRows
            .where((row) => selectedKeys.contains('${row['__key']}'))
            .toList();

    if (rows.isEmpty) {
      _snack(
        _t(
          'Tidak ada data sesuai filter report.',
          'No data matches the report filters.',
        ),
        error: true,
      );
      return;
    }

    final totalIncome = rows
        .where((row) => '${row['__type']}' == 'Income')
        .fold<double>(0, (sum, row) => sum + _toNum(row['__income']));
    final totalExpense = rows
        .where((row) => '${row['__type']}' == 'Expense')
        .fold<double>(0, (sum, row) => sum + _toNum(row['__expense']));

    try {
      await printReportPdf(
        start: start,
        end: end,
        rows: rows,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        includeIncome: includeIncomeSelected,
        includeExpense: includeExpenseSelected,
        customerKind: selectedCustomerKind,
        orientation: selectedOrientation,
      );
      if (!mounted) return;
      _snack(
        _t(
          'Report PDF berhasil dibuat (${rows.length} data).',
          'PDF report generated successfully (${rows.length} rows).',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack(
        _t(
          'Gagal membuat report PDF: ${e.toString().replaceFirst('Exception: ', '')}',
          'Failed to generate PDF report: ${e.toString().replaceFirst('Exception: ', '')}',
        ),
        error: true,
      );
    }
  }

  Future<void> _openInvoicePreview(Map<String, dynamic> item) async {
    final previewItem = await _resolveLatestInvoiceItem(item);
    final armadas = await widget.repository.fetchArmadas();
    final armadaPlateById = <String, String>{
      for (final armada in armadas)
        '${armada['id'] ?? ''}'.trim():
            '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
    };
    final armadaPlateByName = <String, String>{
      for (final armada in armadas)
        _normalizeArmadaNameKey('${armada['nama_truk'] ?? ''}'):
            '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
    };
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        final detailList = _toDetailList(previewItem['rincian']);
        final customerName = '${previewItem['nama_pelanggan'] ?? ''}'.trim();
        final isCompanyInvoice = _resolveIsCompanyInvoice(
          invoiceNumber: previewItem['no_invoice'],
          customerName: customerName,
        );
        final subtotal = _toNum(previewItem['total_biaya']);
        final pph = isCompanyInvoice ? _toNum(previewItem['pph']) : 0.0;
        final total = isCompanyInvoice ? max(0.0, subtotal - pph) : subtotal;
        return AlertDialog(
          title: Text(_t('Preview Invoice', 'Invoice Preview')),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${_t('Customer', 'Customer')}: ${previewItem['nama_pelanggan'] ?? '-'}'),
                  Text(
                      '${_t('Email', 'Email')}: ${previewItem['email'] ?? '-'}'),
                  Text(
                      '${_t('Tanggal', 'Date')}: ${Formatters.dmy(previewItem['tanggal'] ?? previewItem['armada_start_date'])}'),
                  Text(
                      '${_t('Status', 'Status')}: ${previewItem['status'] ?? '-'}'),
                  const SizedBox(height: 8),
                  Text(
                    '${_t('Total', 'Total')}: ${Formatters.rupiah(total)}',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (detailList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _t('Rincian Invoice', 'Invoice Details'),
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ...detailList.asMap().entries.map((entry) {
                      final index = entry.key;
                      final row = entry.value;
                      final tonase = _toNum(row['tonase']);
                      final harga = _toNum(row['harga']);
                      final subtotalDetail = tonase * harga;
                      final driver = '${row['nama_supir'] ?? ''}'.trim();
                      final muatan = '${row['muatan'] ?? ''}'.trim();
                      final plate = _resolveDetailPlateText(
                        row,
                        armadaPlateById: armadaPlateById,
                        armadaPlateByName: armadaPlateByName,
                        fallbackArmadaId: '${previewItem['armada_id'] ?? ''}',
                      );
                      final departureDate = Formatters.dmy(
                        row['armada_start_date'] ??
                            previewItem['armada_start_date'],
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
                              '${_t('Rincian', 'Detail')} ${index + 1}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_t('Keberangkatan', 'Departure')}: $departureDate',
                            ),
                            Text(
                              '${_t('Rute', 'Route')}: ${row['lokasi_muat'] ?? '-'} - ${row['lokasi_bongkar'] ?? '-'}',
                            ),
                            if (plate.isNotEmpty)
                              Text('${_t('Plat', 'Plate')}: $plate'),
                            if (muatan.isNotEmpty)
                              Text('${_t('Muatan', 'Cargo')}: $muatan'),
                            if (driver.isNotEmpty)
                              Text('${_t('Nama Supir', 'Driver')}: $driver'),
                            Text(
                              '${_t('Tonase', 'Tonnage')}: ${formatInvoiceTonase(tonase)}',
                            ),
                            Text(
                              '${_t('Harga / Ton', 'Price / Ton')}: ${formatInvoiceHargaPerTon(harga)}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_t('Subtotal', 'Subtotal')}: ${Formatters.rupiah(subtotalDetail)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (!_isPengurus)
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _printSingleInvoiceFromPreview(previewItem);
                },
                style: CvantButtonStyles.outlined(
                  context,
                  color: AppColors.blue,
                  borderColor: AppColors.blue,
                  minimumSize: const Size(96, 40),
                ),
                icon: const Icon(Icons.print_outlined, size: 16),
                label: Text(_t('Print', 'Print')),
              ),
            FilledButton(
              style: CvantButtonStyles.filled(
                context,
                color: AppColors.blue,
                minimumSize: const Size(96, 40),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Tutup', 'Close')),
            ),
          ],
        );
      },
    );
  }

  String _normalizeCompanyText(String value) {
    return value
        .toLowerCase()
        .replaceAll('.', ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isCompanyCustomerName(String value) {
    final normalized = _normalizeCompanyText(value);
    if (normalized.isEmpty) return false;
    for (final keyword in _companyKeywords) {
      if (RegExp(keyword).hasMatch(normalized)) {
        return true;
      }
    }
    return false;
  }

  bool? _companyModeFromInvoiceNumber(String number) {
    final compact = number.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return null;
    if (compact.contains('CV.ANT') || compact.contains('/CV.ANT/')) {
      return true;
    }
    if (compact.contains('/BS/') ||
        compact.contains('/ANT/') ||
        compact.startsWith('BS')) {
      return false;
    }
    return null;
  }

  bool _resolveIsCompanyInvoice({
    dynamic invoiceNumber,
    dynamic customerName,
    bool fallback = true,
  }) {
    final fromNumber =
        _companyModeFromInvoiceNumber('${invoiceNumber ?? ''}'.trim());
    if (fromNumber != null) return fromNumber;
    final name = '${customerName ?? ''}'.trim();
    if (name.isNotEmpty) return _isCompanyCustomerName(name);
    return fallback;
  }

  String _displayInvoiceNumber(String number) {
    return number.trim().isEmpty ? '-' : number.trim();
  }

  int _printInvoiceRomanToMonth(String roman) {
    const monthByRoman = <String, int>{
      'I': 1,
      'II': 2,
      'III': 3,
      'IV': 4,
      'V': 5,
      'VI': 6,
      'VII': 7,
      'VIII': 8,
      'IX': 9,
      'X': 10,
      'XI': 11,
      'XII': 12,
    };
    return monthByRoman[roman.trim().toUpperCase()] ?? 0;
  }

  String _buildPrintInvoiceNumber({
    required int sequence,
    required DateTime issuedDate,
    required bool isCompany,
  }) {
    final seq = sequence.toString().padLeft(2, '0');
    final mm = issuedDate.toLocal().month.toString().padLeft(2, '0');
    final yy = (issuedDate.toLocal().year % 100).toString().padLeft(2, '0');
    final code = isCompany ? 'CV.ANT' : 'BS';
    return '$code$yy$mm$seq';
  }

  int _extractPrintInvoiceSequence({
    required String invoiceNumber,
    required int month,
    required int yearTwoDigits,
    required bool isCompany,
    DateTime? referenceDate,
  }) {
    final cleaned = invoiceNumber
        .replaceFirst(RegExp(r'^\s*NO\s*:\s*', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) return 0;

    final compactPattern = RegExp(
      r'^(CV\.ANT|BS)(\d{2})(\d{2})(\d{2,})$',
      caseSensitive: false,
    );
    final compactMatch = compactPattern.firstMatch(cleaned);
    if (compactMatch != null) {
      final prefix = (compactMatch.group(1) ?? '').toUpperCase().trim();
      final rowYear = int.tryParse(compactMatch.group(2) ?? '') ?? -1;
      final rowMonth = int.tryParse(compactMatch.group(3) ?? '') ?? 0;
      final seq = int.tryParse(compactMatch.group(4) ?? '') ?? 0;
      final sameType = isCompany ? prefix == 'CV.ANT' : prefix == 'BS';
      if (sameType && rowMonth == month && rowYear == yearTwoDigits) {
        return seq;
      }
      return 0;
    }

    final newPattern = RegExp(
      r'^(\d{1,4})\s*\/\s*(CV\.ANT|BS|ANT)\s*\/\s*([IVX]+)\s*\/\s*(\d{2})\s*$',
      caseSensitive: false,
    );
    final newMatch = newPattern.firstMatch(cleaned);
    if (newMatch != null) {
      final seq = int.tryParse(newMatch.group(1) ?? '') ?? 0;
      final prefix = (newMatch.group(2) ?? '').toUpperCase().trim();
      final rowMonth = _printInvoiceRomanToMonth(newMatch.group(3) ?? '');
      final rowYear = int.tryParse(newMatch.group(4) ?? '') ?? -1;
      final sameType =
          isCompany ? prefix == 'CV.ANT' : (prefix == 'BS' || prefix == 'ANT');
      if (sameType && rowMonth == month && rowYear == yearTwoDigits) {
        return seq;
      }
      return 0;
    }

    final legacyPattern = RegExp(
      r'^(480\s*\/\s*CV\.ANT|268\s*\/\s*ANT)\s*\/\s*([IVX]+)\s*\/\s*(\d+)\s*$',
      caseSensitive: false,
    );
    final legacyMatch = legacyPattern.firstMatch(cleaned);
    if (legacyMatch != null) {
      final prefix =
          (legacyMatch.group(1) ?? '').toUpperCase().replaceAll(' ', '');
      final sameType = isCompany
          ? prefix.startsWith('480/CV.ANT')
          : prefix.startsWith('268/ANT');
      if (!sameType) return 0;

      final rowMonth = _printInvoiceRomanToMonth(legacyMatch.group(2) ?? '');
      if (rowMonth != month) return 0;
      final rowYear =
          referenceDate == null ? yearTwoDigits : (referenceDate.year % 100);
      if (rowYear != yearTwoDigits) return 0;
      return int.tryParse(legacyMatch.group(3) ?? '') ?? 0;
    }

    final oldInc =
        RegExp(r'^INC-(\d{2})-(\d{4})-(\d{1,})$', caseSensitive: false)
            .firstMatch(cleaned.toUpperCase());
    if (oldInc != null) {
      final rowMonth = int.tryParse(oldInc.group(1) ?? '') ?? 0;
      final rowYear = (int.tryParse(oldInc.group(2) ?? '') ?? 0) % 100;
      if (rowMonth != month || rowYear != yearTwoDigits) return 0;
      return int.tryParse(oldInc.group(3) ?? '') ?? 0;
    }

    return 0;
  }

  Future<bool> _printInvoicePdf(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> detailList, {
    bool markAsFixed = false,
    bool showSuccessPopup = false,
    String? invoiceNumberOverride,
    String? kopDateOverride,
    String? kopLocationOverride,
    Iterable<String>? fixedInvoiceIds,
    _FixedInvoiceBatch? fixedBatch,
  }) async {
    try {
      final invoiceDetailList =
          detailList.isNotEmpty ? detailList : _toDetailList(item['rincian']);
      // <= 16 detail rows: print in half-sheet layout (50:50 on portrait paper).
      // > 16 detail rows: switch to full-sheet portrait layout.
      final usePortrait = invoiceDetailList.length > 16;
      final invoiceRawNumber = '${item['no_invoice'] ?? '-'}';
      final customerName = '${item['nama_pelanggan'] ?? ''}';
      final isCompanyInvoice = _resolveIsCompanyInvoice(
        invoiceNumber: invoiceRawNumber,
        customerName: customerName,
      );
      final subtotal = _toNum(item['total_biaya']);
      final pph = isCompanyInvoice ? _toNum(item['pph']) : 0.0;
      final total = isCompanyInvoice
          ? _toNum(item['total_bayar'] ?? item['total_biaya'])
          : subtotal;
      final effectiveKopDateRaw = (kopDateOverride ?? '').trim().isNotEmpty
          ? kopDateOverride!.trim()
          : '${item['tanggal_kop'] ?? item['tanggal'] ?? ''}'.trim();
      final effectiveKopLocationRaw =
          (kopLocationOverride ?? '').trim().isNotEmpty
              ? kopLocationOverride!.trim()
              : '${item['lokasi_kop'] ?? ''}'.trim();
      final invoiceNumber = _displayInvoiceNumber(
        (invoiceNumberOverride ?? '').trim().isNotEmpty
            ? invoiceNumberOverride!.trim()
            : Formatters.invoiceNumber(
                invoiceRawNumber,
                effectiveKopDateRaw,
                customerName: customerName,
                isCompany: isCompanyInvoice,
              ),
      );
      pw.MemoryImage? kopLogo;
      try {
        final logoBytes = await rootBundle.load('assets/images/iconapk.png');
        kopLogo = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {
        kopLogo = null;
      }
      pw.MemoryImage? companyKopImage;
      try {
        final kopBytes = await rootBundle.load('assets/images/kopsurat.jpeg');
        companyKopImage = pw.MemoryImage(kopBytes.buffer.asUint8List());
      } catch (_) {
        companyKopImage = null;
      }
      final armadas = await widget.repository.fetchArmadas();
      final armadaPlateById = <String, String>{
        for (final armada in armadas)
          '${armada['id'] ?? ''}':
              '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
      };
      final armadaPlateByName = <String, String>{
        for (final armada in armadas)
          _normalizeArmadaNameKey('${armada['nama_truk'] ?? ''}'):
              '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
      };

      String resolveNoPolisi(Map<String, dynamic> row) {
        return _resolveDetailPlateText(
          row,
          armadaPlateById: armadaPlateById,
          armadaPlateByName: armadaPlateByName,
          fallbackArmadaId: '${item['armada_id'] ?? ''}',
        );
      }

      String formatTonase(dynamic value) {
        return formatInvoiceTonase(value);
      }

      String formatHargaPerTon(dynamic value) {
        return formatInvoiceHargaPerTon(value);
      }

      int extraBlankRowsForMultiSheet({
        required int dataRows,
        required int baseRowsPerSheet,
      }) {
        // Request: when invoice spans multiple sheets, add 7 blank rows
        // on each sheet while keeping row height consistent.
        if (dataRows <= baseRowsPerSheet) return 0;
        const extraPerSheet = 7;
        var sheetCount = (dataRows / baseRowsPerSheet).ceil();
        var totalRowsWithPadding = dataRows + (sheetCount * extraPerSheet);
        while ((totalRowsWithPadding / baseRowsPerSheet).ceil() != sheetCount) {
          sheetCount = (totalRowsWithPadding / baseRowsPerSheet).ceil();
          totalRowsWithPadding = dataRows + (sheetCount * extraPerSheet);
        }
        return totalRowsWithPadding - dataRows;
      }

      List<Map<String, dynamic>> buildPrintableRows({
        required bool compact,
      }) {
        final baseRowsPerSheet = compact
            ? (isCompanyInvoice ? 18 : 21)
            : (isCompanyInvoice ? 40 : 43);
        final extraRows = extraBlankRowsForMultiSheet(
          dataRows: invoiceDetailList.length,
          baseRowsPerSheet: baseRowsPerSheet,
        );
        final minRows =
            max(baseRowsPerSheet, invoiceDetailList.length + extraRows);
        return invoiceDetailList.length >= minRows
            ? invoiceDetailList
            : <Map<String, dynamic>>[
                ...invoiceDetailList,
                ...List<Map<String, dynamic>>.generate(
                  minRows - invoiceDetailList.length,
                  (_) => <String, dynamic>{},
                ),
              ];
      }

      Future<_InvoiceTableRenderResult?> buildExcelTableImage({
        required bool compact,
        String renderMode = 'table',
      }) async {
        final printableRows = buildPrintableRows(compact: compact);
        final summaryValues = renderMode == 'table_with_summary' ||
                renderMode == 'table_with_total'
            ? <String, String>{
                'subtotal': formatRupiahNoPrefix(subtotal),
                'pph': formatRupiahNoPrefix(pph),
                'total': formatRupiahNoPrefix(total),
              }
            : null;
        final payloadRows = <Map<String, String>>[];
        for (var index = 0; index < printableRows.length; index++) {
          final row = printableRows[index];
          final hasData = index < invoiceDetailList.length;
          final tonase = hasData ? _toNum(row['tonase']) : 0;
          final harga = hasData ? _toNum(row['harga']) : 0;
          final rowSubtotal = tonase * harga;
          final armadaStartSource = row['armada_start_date'] ??
              item['armada_start_date'] ??
              row['tanggal'] ??
              item['tanggal'];
          payloadRows.add({
            'no': hasData ? '${index + 1}' : '',
            'tanggal':
                hasData ? _formatInvoiceTableDate(armadaStartSource) : '',
            'plat': hasData ? resolveNoPolisi(row) : '',
            'muatan': hasData ? '${row['muatan'] ?? '-'}' : '',
            'muat': hasData
                ? _normalizeInvoicePrintLocationLabel(row['lokasi_muat'])
                : '',
            'bongkar': hasData
                ? _normalizeInvoicePrintLocationLabel(row['lokasi_bongkar'])
                : '',
            'tonase': hasData ? formatTonase(tonase) : '',
            'harga': hasData ? formatHargaPerTon(harga) : '',
            'total': hasData ? formatRupiahNoPrefix(rowSubtotal) : '',
          });
        }
        Uint8List? bytes;
        var renderSource = 'Excel template renderer';
        bytes = await _renderInvoiceTableImageWithExcel(
          rows: payloadRows,
          rowCount: printableRows.length,
          renderMode: renderMode,
          summaryValues: summaryValues,
        );
        if (bytes != null) {
          renderSource = 'Excel local (Windows)';
        } else {
          final cloudBytes = await _renderInvoiceTableImageViaCloudService(
            rows: payloadRows,
            rowCount: printableRows.length,
            renderMode: renderMode,
            summaryValues: summaryValues,
          );
          if (cloudBytes != null) {
            bytes = cloudBytes;
            renderSource = 'Excel cloud service';
          } else {
            bytes = await _renderInvoiceTableImagePortable(
              rows: payloadRows,
              rowCount: printableRows.length,
              renderMode: renderMode,
              summaryValues: summaryValues,
            );
          }
        }
        if (bytes == null) return null;
        final decodedImage = img.decodeImage(bytes);
        final aspectRatio = decodedImage == null || decodedImage.height == 0
            ? 1.0
            : decodedImage.width / decodedImage.height;
        return _InvoiceTableRenderResult(
          image: pw.MemoryImage(bytes),
          aspectRatio: aspectRatio,
          renderSource: renderSource,
        );
      }

      late final pw.Font invoiceTitleFont;
      try {
        invoiceTitleFont = await PdfGoogleFonts.archivoBlack();
      } catch (_) {
        invoiceTitleFont = pw.Font.helveticaBold();
      }

      pw.Widget buildInvoiceContent({
        required bool compact,
        _InvoiceTableRenderResult? excelTableRender,
        _InvoiceTableRenderResult? excelSummaryRender,
        bool excelTableHasEmbeddedSummary = false,
      }) {
        const infoFont = 9.5;
        final summaryValueGap = compact ? 8.0 : 10.0;
        final summaryBoxGap = 2.0;
        final signatureLeftOffset = compact ? 72.0 : 86.0;
        final signatureNameOffset = compact ? 5.0 : 6.0;
        const signatureTextFontSize = 11.0;
        final printableRows = buildPrintableRows(compact: compact);
        String? printable(dynamic value) {
          final raw = value?.toString().trim() ?? '';
          if (raw.isEmpty || raw == '-' || raw.toLowerCase() == 'null') {
            return null;
          }
          return raw;
        }

        final customerName = printable(item['nama_pelanggan']) ?? '-';
        final tanggalKop = effectiveKopDateRaw.isEmpty
            ? item['tanggal_kop'] ?? item['tanggal']
            : effectiveKopDateRaw;
        final kopLocation = printable(effectiveKopLocationRaw);
        String toTitleCase(String value) {
          final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
          if (normalized.isEmpty) return normalized;
          return normalized.split(' ').map((word) {
            if (word.isEmpty) return word;
            final lower = word.toLowerCase();
            return lower.substring(0, 1).toUpperCase() + lower.substring(1);
          }).join(' ');
        }

        final kopLocationTitle =
            kopLocation == null ? null : toTitleCase(kopLocation);
        final kopLocationUpper = kopLocation?.toUpperCase();
        String formatLongDateId(dynamic value) {
          final date = Formatters.parseDate(value);
          if (date == null) return '-';
          const monthNames = <String>[
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
          ];
          return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
        }

        final tanggalLong = formatLongDateId(tanggalKop);
        final tanggalRow = kopLocationTitle == null || kopLocationTitle.isEmpty
            ? tanggalLong
            : '$kopLocationTitle, $tanggalLong';
        final logoHeight = compact ? 39.0 : 52.0;
        final companyKopHeight = compact ? 50.0 : 65.0;
        final recipientBaseLineWidth = compact
            ? (isCompanyInvoice ? 168.0 : 122.0)
            : (isCompanyInvoice ? 242.0 : 158.0);
        final recipientMaxLineWidth = compact
            ? (isCompanyInvoice ? 258.0 : 206.0)
            : (isCompanyInvoice ? 358.0 : 270.0);
        final recipientShiftLeft = compact ? 1.0 : 5.0;
        double recipientLineWidthFor(String text) {
          final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
          final lengthBased =
              (normalized.length * (compact ? 6.9 : 6.4)) + (compact ? 20 : 24);
          return max(
            recipientBaseLineWidth,
            min(recipientMaxLineWidth, lengthBased),
          );
        }

        final recipientLineWidth = max(
          recipientLineWidthFor(customerName),
          recipientLineWidthFor(kopLocationUpper ?? '-'),
        );
        const tableRowVPadding = 2.4;
        const tableBodyRowHeight = 16.0;
        final tableHorizontalBleedLeft =
            isCompanyInvoice ? (compact ? 1.1 : 0.7) : (compact ? 11.2 : 7.2);
        final tableHorizontalBleedRight =
            isCompanyInvoice ? (compact ? 1.5 : 1.0) : (compact ? 12.0 : 7.8);
        final incomeColumnWidths = _buildIncomeTableColumnWidths(printableRows);
        final excelTableImage = excelTableRender?.image;
        final excelTableIncludesSummary =
            excelTableHasEmbeddedSummary && excelTableRender != null;
        final compactExcelRenderHeight = isCompanyInvoice
            ? (excelTableIncludesSummary ? 309.0 : 256.0)
            : (excelTableIncludesSummary ? 323.0 : 271.0);
        final kopWordStyle = pw.TextStyle(
          fontSize: compact ? 34.0 : 47.0,
          fontWeight: pw.FontWeight.bold,
          fontStyle: pw.FontStyle.italic,
          letterSpacing: 5.0,
          wordSpacing: 1.15,
          color: PdfColors.blue900,
        );
        pw.Widget buildUltraBoldKop(String text) {
          // Keep boldness very strong while avoiding vertical clipping.
          // We bias thickness to the right (X) and keep Y spread thinner.
          final maxX = compact ? 3.2 : 4.8;
          final maxY = compact ? 0.62 : 0.90;
          final stepX = compact ? 0.14 : 0.20;
          final stepY = compact ? 0.14 : 0.20;
          final layers = <pw.Widget>[
            // Non-positioned base text keeps Stack intrinsic size valid.
            pw.Text(text, style: kopWordStyle),
          ];
          for (double dx = 0; dx <= maxX + 0.0001; dx += stepX) {
            for (double dy = 0; dy <= maxY + 0.0001; dy += stepY) {
              if (dx.abs() < 0.0001 && dy.abs() < 0.0001) continue;
              final ellipseNorm =
                  ((dx * dx) / (maxX * maxX)) + ((dy * dy) / (maxY * maxY));
              if (ellipseNorm > 1.0) continue;
              layers.add(
                pw.Positioned(
                  left: dx,
                  top: dy,
                  child: pw.Text(text, style: kopWordStyle),
                ),
              );
            }
          }
          return pw.Padding(
            // Extra right/bottom room so ultra-bold layers never get clipped.
            padding: pw.EdgeInsets.only(right: maxX + 0.8, bottom: maxY + 0.4),
            child: pw.Stack(
              children: layers,
            ),
          );
        }

        double fixedColWidth(int index) {
          final width = incomeColumnWidths[index];
          return width is pw.FixedColumnWidth ? width.width : 0;
        }

        double flexColWeight(int index) {
          final width = incomeColumnWidths[index];
          return width is pw.FlexColumnWidth ? width.flex : 0;
        }

        double invoiceDividerWidthFor(double availableWidth) {
          final fallbackWidth = compact ? 146.0 : 186.0;
          if (availableWidth <= 0) {
            return fallbackWidth;
          }

          final fixedWidthTotal = List<double>.generate(
            incomeColumnWidths.length,
            (i) => fixedColWidth(i),
          ).fold(0.0, (sum, width) => sum + width);
          final flexWeightTotal = List<double>.generate(
            incomeColumnWidths.length,
            (i) => flexColWeight(i),
          ).fold(0.0, (sum, width) => sum + width);
          final usableFlexWidth = max(0.0, availableWidth - fixedWidthTotal);

          double colWidth(int index) {
            final fixed = fixedColWidth(index);
            if (fixed > 0) return fixed;
            final flex = flexColWeight(index);
            if (flexWeightTotal <= 0 || flex <= 0) return 0;
            return usableFlexWidth * (flex / flexWeightTotal);
          }

          final logicalTableWidth = fixedWidthTotal + usableFlexWidth <= 0
              ? availableWidth
              : fixedWidthTotal + usableFlexWidth;
          final renderedTableWidth = compact &&
                  excelTableRender != null &&
                  excelTableRender.aspectRatio > 0
              ? compactExcelRenderHeight * excelTableRender.aspectRatio
              : availableWidth +
                  tableHorizontalBleedLeft +
                  tableHorizontalBleedRight;
          final expandedWidth = availableWidth +
              tableHorizontalBleedLeft +
              tableHorizontalBleedRight;
          final renderedLeft = -tableHorizontalBleedLeft +
              ((expandedWidth - renderedTableWidth) / 2);
          final tableScale = logicalTableWidth <= 0
              ? 1.0
              : renderedTableWidth / logicalTableWidth;
          final muatanRightBoundary = renderedLeft +
              ((colWidth(0) + colWidth(1) + colWidth(2) + colWidth(3)) *
                  tableScale);
          final safeRightBoundary =
              max(0.0, muatanRightBoundary - (compact ? 20.0 : 24.0));
          if (safeRightBoundary > 0) {
            return min(safeRightBoundary, availableWidth);
          }
          return min(fallbackWidth, availableWidth);
        }

        pw.Widget buildCompanySummaryRow(
          String label,
          String value, {
          required double leadPrefixWidth,
          required double leftMergeWidth,
          required double middleGapWidth,
          required double mergedLabelWidth,
          required double totalWidth,
          String? leftText,
          bool bold = true,
        }) {
          final textStyle = pw.TextStyle(
            fontSize: infoFont,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          );
          return pw.SizedBox(
            height: tableBodyRowHeight,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.SizedBox(width: leadPrefixWidth),
                pw.Container(
                  width: leftMergeWidth,
                  alignment: pw.Alignment.center,
                  child: leftText == null
                      ? pw.SizedBox()
                      : pw.FittedBox(
                          fit: pw.BoxFit.scaleDown,
                          child: pw.Text(
                            leftText.replaceAll(' ', '\u00A0'),
                            maxLines: 1,
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(
                              fontSize: signatureTextFontSize,
                              decoration: pw.TextDecoration.none,
                            ),
                          ),
                        ),
                ),
                pw.SizedBox(width: middleGapWidth),
                pw.Expanded(
                  child: pw.Container(
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.only(right: 2),
                    child: pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        label.replaceAll(' ', '\u00A0'),
                        textAlign: pw.TextAlign.right,
                        maxLines: 1,
                        style: textStyle,
                      ),
                    ),
                  ),
                ),
                pw.Container(
                  width: totalWidth,
                  alignment: pw.Alignment.centerRight,
                  margin: pw.EdgeInsets.zero,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColors.black,
                      width: 0.55,
                    ),
                  ),
                  child: pw.Text(
                    value,
                    textAlign: pw.TextAlign.right,
                    maxLines: 1,
                    style: textStyle,
                  ),
                ),
              ],
            ),
          );
        }

        pw.Widget buildCompanySummaryBlock({
          required double leadPrefixWidth,
          required double leftMergeWidth,
          required double middleGapWidth,
          required double mergedLabelWidth,
          required double totalWidth,
          required String subtotalValue,
          required String pphValue,
          required String totalValue,
          String? leftText,
        }) {
          final labelStyle = pw.TextStyle(
            fontSize: infoFont,
            fontWeight: pw.FontWeight.bold,
          );
          final summaryImage = excelSummaryRender?.image;
          final totalBlockHeight = tableBodyRowHeight * 3;

          if (summaryImage == null) {
            return pw.Column(
              children: [
                buildCompanySummaryRow(
                  'SUBTOTAL Rp.',
                  subtotalValue,
                  leadPrefixWidth: leadPrefixWidth,
                  leftMergeWidth: leftMergeWidth,
                  middleGapWidth: middleGapWidth,
                  mergedLabelWidth: mergedLabelWidth,
                  totalWidth: totalWidth,
                  leftText: leftText,
                ),
                buildCompanySummaryRow(
                  'PPH 2% Rp.',
                  pphValue,
                  leadPrefixWidth: leadPrefixWidth,
                  leftMergeWidth: leftMergeWidth,
                  middleGapWidth: middleGapWidth,
                  mergedLabelWidth: mergedLabelWidth,
                  totalWidth: totalWidth,
                ),
                buildCompanySummaryRow(
                  'TOTAL BAYAR Rp.',
                  totalValue,
                  leadPrefixWidth: leadPrefixWidth,
                  leftMergeWidth: leftMergeWidth,
                  middleGapWidth: middleGapWidth,
                  mergedLabelWidth: mergedLabelWidth,
                  totalWidth: totalWidth,
                ),
              ],
            );
          }

          pw.Widget buildLabel(String text) => pw.Container(
                height: tableBodyRowHeight,
                alignment: pw.Alignment.centerRight,
                child: pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    text.replaceAll(' ', '\u00A0'),
                    textAlign: pw.TextAlign.right,
                    maxLines: 1,
                    style: labelStyle,
                  ),
                ),
              );

          pw.Widget buildLeftCell() => pw.Container(
                height: totalBlockHeight,
                width: leftMergeWidth,
                alignment: pw.Alignment.topCenter,
                child: leftText == null
                    ? pw.SizedBox()
                    : pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 1),
                        child: pw.FittedBox(
                          fit: pw.BoxFit.scaleDown,
                          child: pw.Text(
                            leftText.replaceAll(' ', '\u00A0'),
                            maxLines: 1,
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(
                              fontSize: signatureTextFontSize,
                              decoration: pw.TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
              );

          return pw.SizedBox(
            height: totalBlockHeight,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: leadPrefixWidth),
                buildLeftCell(),
                pw.SizedBox(width: middleGapWidth),
                pw.Container(
                  width: mergedLabelWidth,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      buildLabel('SUBTOTAL Rp.'),
                      buildLabel('PPH 2% Rp.'),
                      buildLabel('TOTAL BAYAR Rp.'),
                    ],
                  ),
                ),
                pw.Container(
                  width: totalWidth,
                  height: totalBlockHeight,
                  child: pw.Image(
                    summaryImage,
                    fit: pw.BoxFit.fill,
                    alignment: pw.Alignment.topRight,
                  ),
                ),
              ],
            ),
          );
        }

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (isCompanyInvoice) ...[
              if (companyKopImage != null)
                pw.Container(
                  margin: const pw.EdgeInsets.only(
                    left: -5.8,
                    right: -6.8,
                    top: 0,
                  ),
                  width: double.infinity,
                  height: companyKopHeight,
                  child: pw.Image(
                    companyKopImage,
                    fit: pw.BoxFit.fitWidth,
                    alignment: pw.Alignment.center,
                  ),
                )
              else ...[
                pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (kopLogo != null)
                        pw.Image(
                          kopLogo,
                          height: logoHeight,
                          width: logoHeight,
                          fit: pw.BoxFit.contain,
                        )
                      else
                        pw.SizedBox(
                          height: logoHeight,
                          width: logoHeight,
                        ),
                      pw.SizedBox(width: 4),
                      pw.Expanded(
                        child: pw.Container(
                          height: logoHeight,
                          alignment: pw.Alignment.topLeft,
                          child: buildUltraBoldKop('CV AS NUSA TRANS'),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 1.5),
                pw.Container(
                  width: double.infinity,
                  height: 1.2,
                  color: PdfColors.black,
                ),
              ],
              pw.SizedBox(height: 0.5),
            ],
            pw.LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints?.maxWidth ?? 0;
                final invoiceDividerWidth =
                    invoiceDividerWidthFor(availableWidth);
                return pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(
                          width: invoiceDividerWidth,
                          child: pw.Center(
                            child: pw.Text(
                              'I  N  V  O  I  C  E',
                              style: pw.TextStyle(
                                font: invoiceTitleFont,
                                fontSize: compact ? 24 : 29,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 1.0),
                        pw.Container(
                          width: invoiceDividerWidth,
                          height: 0.8,
                          color: PdfColors.black,
                        ),
                        pw.SizedBox(height: 0.8),
                        pw.Container(
                          width: invoiceDividerWidth,
                          height: 0.8,
                          color: PdfColors.black,
                        ),
                        pw.SizedBox(height: 2.5),
                        pw.SizedBox(
                          width: invoiceDividerWidth,
                          child: pw.Center(
                            child: pw.Text(
                              'NO : $invoiceNumber',
                              style: pw.TextStyle(
                                fontSize: compact ? 10 : 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.Spacer(),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          tanggalRow,
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: infoFont),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Padding(
                          padding:
                              pw.EdgeInsets.only(right: recipientShiftLeft),
                          child: pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'Kepada Yth: ',
                                textAlign: pw.TextAlign.right,
                                style: const pw.TextStyle(fontSize: infoFont),
                              ),
                              pw.Container(
                                width: recipientLineWidth,
                                alignment: pw.Alignment.center,
                                padding: const pw.EdgeInsets.only(bottom: 1),
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                    bottom: pw.BorderSide(
                                      color: PdfColors.black,
                                      width: 0.9,
                                    ),
                                  ),
                                ),
                                child: pw.FittedBox(
                                  fit: pw.BoxFit.scaleDown,
                                  child: pw.Text(
                                    customerName.replaceAll(' ', '\u00A0'),
                                    maxLines: 1,
                                    textAlign: pw.TextAlign.center,
                                    style: pw.TextStyle(
                                      fontSize: infoFont,
                                      fontWeight: pw.FontWeight.bold,
                                      fontStyle: pw.FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Padding(
                          padding:
                              pw.EdgeInsets.only(right: recipientShiftLeft),
                          child: pw.Container(
                            width: recipientLineWidth,
                            alignment: pw.Alignment.center,
                            padding: const pw.EdgeInsets.only(bottom: 1),
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(
                                  color: PdfColors.black,
                                  width: 0.9,
                                ),
                              ),
                            ),
                            child: pw.FittedBox(
                              fit: pw.BoxFit.scaleDown,
                              child: pw.Text(
                                (kopLocationUpper ?? '-')
                                    .replaceAll(' ', '\u00A0'),
                                maxLines: 1,
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: infoFont,
                                  fontWeight: pw.FontWeight.bold,
                                  fontStyle: pw.FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            pw.SizedBox(height: 5),
            if (excelTableImage != null)
              compact
                  ? pw.Container(
                      margin: pw.EdgeInsets.only(
                        left: -tableHorizontalBleedLeft,
                        right: -tableHorizontalBleedRight,
                      ),
                      width: double.infinity,
                      alignment: pw.Alignment.topCenter,
                      child: pw.Image(
                        excelTableImage,
                        height: compactExcelRenderHeight,
                        fit: pw.BoxFit.fitHeight,
                        alignment: pw.Alignment.topCenter,
                      ),
                    )
                  : pw.Container(
                      margin: pw.EdgeInsets.only(
                        left: -tableHorizontalBleedLeft,
                        right: -tableHorizontalBleedRight,
                      ),
                      width: double.infinity,
                      child: pw.Image(
                        excelTableImage,
                        fit: pw.BoxFit.fitWidth,
                        alignment: pw.Alignment.topCenter,
                      ),
                    )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                columnWidths: incomeColumnWidths,
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(),
                    children: [
                      _pdfCell(
                        'NO',
                        bold: true,
                        alignCenter: true,
                        textColor: PdfColors.black,
                        fontSize: 9,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        singleLineAutoShrink: true,
                        softLimitChars: 3,
                        minFontSize: 7,
                      ),
                      _pdfCell(
                        'TANGGAL',
                        bold: true,
                        alignCenter: true,
                        textColor: PdfColors.black,
                        fontSize: 9,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        singleLineAutoShrink: true,
                        softLimitChars: 8,
                      ),
                      _pdfCell(
                        'PLAT',
                        bold: true,
                        alignCenter: true,
                        textColor: PdfColors.black,
                        fontSize: 9,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        singleLineAutoShrink: true,
                        softLimitChars: 6,
                        minFontSize: 6.8,
                      ),
                      _pdfCell(
                        'MUATAN',
                        bold: true,
                        alignCenter: true,
                        textColor: PdfColors.black,
                        fontSize: 9,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        singleLineAutoShrink: true,
                        softLimitChars: 8,
                        minFontSize: 6.8,
                      ),
                      _pdfCell(
                        'MUAT',
                        bold: true,
                        alignCenter: true,
                        textColor: PdfColors.black,
                        fontSize: 9,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        singleLineAutoShrink: true,
                        softLimitChars: 6,
                        minFontSize: 6.8,
                      ),
                      _pdfCell(
                        'BONGKAR',
                        bold: true,
                        alignCenter: true,
                        textColor: PdfColors.black,
                        fontSize: 9,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        singleLineAutoShrink: true,
                        softLimitChars: 8,
                        minFontSize: 6.8,
                      ),
                      _pdfCell(
                        'TONASE',
                        bold: true,
                        alignCenter: true,
                        textColor: PdfColors.black,
                        fontSize: 9,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        singleLineAutoShrink: true,
                        softLimitChars: 8,
                        minFontSize: 6.8,
                      ),
                      _pdfCell(
                        'HARGA',
                        bold: true,
                        alignCenter: true,
                        textColor: PdfColors.black,
                        fontSize: 9,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        singleLineAutoShrink: true,
                        softLimitChars: 7,
                        minFontSize: 6.8,
                      ),
                      _pdfCell(
                        'TOTAL',
                        bold: true,
                        alignCenter: true,
                        textColor: PdfColors.black,
                        fontSize: 9,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        singleLineAutoShrink: true,
                        softLimitChars: 7,
                        minFontSize: 6.8,
                      ),
                    ],
                  ),
                  ...List<pw.TableRow>.generate(printableRows.length, (index) {
                    final row = printableRows[index];
                    final hasData = index < invoiceDetailList.length;
                    const blankCell = '\u00A0';
                    final tonase = hasData ? _toNum(row['tonase']) : 0;
                    final harga = hasData ? _toNum(row['harga']) : 0;
                    final rowSubtotal = tonase * harga;
                    final armadaStartSource = row['armada_start_date'] ??
                        item['armada_start_date'] ??
                        row['tanggal'] ??
                        item['tanggal'];
                    final tanggal = hasData
                        ? _formatInvoiceTableDate(armadaStartSource)
                        : blankCell;
                    return pw.TableRow(
                      children: [
                        _pdfCell(
                          hasData ? '${index + 1}' : blankCell,
                          alignCenter: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 2,
                          minFontSize: 7,
                        ),
                        _pdfCell(
                          tanggal,
                          alignCenter: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 10,
                        ),
                        _pdfCell(
                          hasData ? resolveNoPolisi(row) : blankCell,
                          alignCenter: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 12,
                        ),
                        _pdfCell(
                          hasData ? '${row['muatan'] ?? '-'}' : blankCell,
                          alignCenter: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 14,
                          minFontSize: 6.5,
                        ),
                        _pdfCell(
                          hasData
                              ? _normalizeInvoicePrintLocationLabel(
                                  row['lokasi_muat'],
                                )
                              : blankCell,
                          alignCenter: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 32,
                          minFontSize: 6.5,
                        ),
                        _pdfCell(
                          hasData
                              ? _normalizeInvoicePrintLocationLabel(
                                  row['lokasi_bongkar'],
                                )
                              : blankCell,
                          alignCenter: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 32,
                          minFontSize: 6.5,
                        ),
                        _pdfCell(
                          hasData ? formatTonase(tonase) : blankCell,
                          alignCenter: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 8,
                        ),
                        _pdfCell(
                          hasData ? formatHargaPerTon(harga) : blankCell,
                          alignRight: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 10,
                          minFontSize: 6.2,
                        ),
                        _pdfCell(
                          hasData
                              ? formatRupiahNoPrefix(rowSubtotal)
                              : blankCell,
                          alignRight: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 12,
                          minFontSize: 6.8,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            if (isCompanyInvoice && !excelTableIncludesSummary) ...[
              pw.LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth = constraints?.maxWidth ?? 0;
                  final fixedWidthTotal = List<double>.generate(
                    incomeColumnWidths.length,
                    (i) => fixedColWidth(i),
                  ).fold(0.0, (sum, w) => sum + w);
                  final flexWeightTotal = List<double>.generate(
                    incomeColumnWidths.length,
                    (i) => flexColWeight(i),
                  ).fold(0.0, (sum, w) => sum + w);
                  final usableFlexWidth =
                      max(0.0, tableWidth - fixedWidthTotal);
                  double colWidth(int index) {
                    final fixed = fixedColWidth(index);
                    if (fixed > 0) return fixed;
                    final flex = flexColWeight(index);
                    if (flexWeightTotal <= 0 || flex <= 0) return 0;
                    return usableFlexWidth * (flex / flexWeightTotal);
                  }

                  final leadPrefixWidth = colWidth(0);
                  final leftMergeWidth = colWidth(1) + colWidth(2);
                  final middleGapWidth =
                      colWidth(3) + colWidth(4) + colWidth(5);
                  final mergedLabelWidth = colWidth(6) + colWidth(7);
                  final totalWidth = colWidth(8);
                  final compactRenderedTableWidth = compact &&
                          excelTableRender != null &&
                          tableWidth > 0 &&
                          excelTableRender.aspectRatio > 0
                      ? compactExcelRenderHeight * excelTableRender.aspectRatio
                      : tableWidth;
                  final totalWidthScale = compact &&
                          tableWidth > 0 &&
                          compactRenderedTableWidth > 0
                      ? (compactRenderedTableWidth / tableWidth).clamp(1.0, 1.4)
                      : 1.0;
                  final effectiveTotalWidth = totalWidth * totalWidthScale;
                  final summaryExtraWidth = compact ? 16.0 : 0.0;
                  final finalTotalWidth =
                      effectiveTotalWidth + summaryExtraWidth;
                  final effectiveMergedLabelWidth = max(
                    0.0,
                    mergedLabelWidth - (finalTotalWidth - totalWidth),
                  );

                  return buildCompanySummaryBlock(
                    leadPrefixWidth: leadPrefixWidth,
                    leftMergeWidth: leftMergeWidth,
                    middleGapWidth: middleGapWidth,
                    mergedLabelWidth: effectiveMergedLabelWidth,
                    totalWidth: finalTotalWidth,
                    subtotalValue: formatRupiahNoPrefix(subtotal),
                    pphValue: formatRupiahNoPrefix(pph),
                    totalValue: formatRupiahNoPrefix(total),
                    leftText: 'Hormat kami,',
                  );
                },
              ),
            ],
            pw.SizedBox(height: 0),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: isCompanyInvoice
                      ? pw.SizedBox()
                      : pw.Padding(
                          padding:
                              pw.EdgeInsets.only(left: signatureLeftOffset),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.SizedBox(height: signatureTextFontSize + 1),
                              pw.SizedBox(height: compact ? 58 : 84),
                              pw.Padding(
                                padding: pw.EdgeInsets.only(
                                  left: signatureNameOffset +
                                      (compact ? -11 : -16),
                                ),
                                child: pw.Text(
                                  'A N T O K',
                                  style: pw.TextStyle(
                                    fontSize: signatureTextFontSize,
                                    fontWeight: pw.FontWeight.bold,
                                    decoration: pw.TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                pw.SizedBox(width: 16),
                pw.SizedBox(
                  width: compact ? 280 : 320,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      if (!isCompanyInvoice && !excelTableIncludesSummary)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Text(
                              'TOTAL BAYAR Rp.',
                              style: pw.TextStyle(
                                fontSize: infoFont,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(width: summaryValueGap),
                            pw.Text(
                              formatRupiahNoPrefix(total),
                              style: pw.TextStyle(
                                fontSize: infoFont,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      pw.SizedBox(height: summaryBoxGap),
                      (isCompanyInvoice
                          ? pw.Transform.translate(
                              offset: const PdfPoint(-0.5, -5),
                              child: pw.Column(
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.stretch,
                                children: [
                                  pw.Container(
                                    alignment: pw.Alignment.center,
                                    padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: pw.BoxDecoration(
                                      border: pw.Border.all(
                                        color: const PdfColor(
                                          252 / 255,
                                          2 / 255,
                                          0,
                                        ),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: pw.Text(
                                      'Rekening BCA a/c 6155345601 a/n CV AS NUSA TRANS\nNPWP 096.775.534.9-617.000',
                                      textAlign: pw.TextAlign.center,
                                      style: pw.TextStyle(
                                        fontSize: infoFont,
                                        color: PdfColors.blue700,
                                        fontWeight: pw.FontWeight.bold,
                                        fontStyle: pw.FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : pw.Transform.translate(
                              offset: const PdfPoint(-1, -3),
                              child: pw.Container(
                                alignment: pw.Alignment.center,
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(
                                    color: PdfColors.blue700,
                                    width: 1.2,
                                  ),
                                ),
                                child: pw.Text(
                                  'Rekening BCA a/c 1730290001 a/n BUDI SUKAMTO',
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(
                                    fontSize: infoFont,
                                    color: PdfColors.blue700,
                                    fontWeight: pw.FontWeight.bold,
                                    fontStyle: pw.FontStyle.italic,
                                  ),
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
              ],
            ),
            if (isCompanyInvoice)
              pw.LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints?.maxWidth ?? 0;
                  final fixedWidthTotal = List<double>.generate(
                    incomeColumnWidths.length,
                    (i) => fixedColWidth(i),
                  ).fold(0.0, (sum, width) => sum + width);
                  final flexWeightTotal = List<double>.generate(
                    incomeColumnWidths.length,
                    (i) => flexColWeight(i),
                  ).fold(0.0, (sum, width) => sum + width);
                  final usableFlexWidth =
                      max(0.0, availableWidth - fixedWidthTotal);

                  double colWidth(int index) {
                    final fixed = fixedColWidth(index);
                    if (fixed > 0) return fixed;
                    final flex = flexColWeight(index);
                    if (flexWeightTotal <= 0 || flex <= 0) return 0;
                    return usableFlexWidth * (flex / flexWeightTotal);
                  }

                  final leadPrefixWidth = colWidth(0);
                  final leftMergeWidth = colWidth(1) + colWidth(2);
                  final renderedTableWidth = compact &&
                          excelTableRender != null &&
                          excelTableRender.aspectRatio > 0
                      ? compactExcelRenderHeight * excelTableRender.aspectRatio
                      : availableWidth +
                          tableHorizontalBleedLeft +
                          tableHorizontalBleedRight;
                  final expandedWidth = availableWidth +
                      tableHorizontalBleedLeft +
                      tableHorizontalBleedRight;
                  final renderedLeft = -tableHorizontalBleedLeft +
                      ((expandedWidth - renderedTableWidth) / 2);
                  final logicalTableWidth =
                      fixedWidthTotal + usableFlexWidth <= 0
                          ? availableWidth
                          : fixedWidthTotal + usableFlexWidth;
                  final tableScale = logicalTableWidth <= 0
                      ? 1.0
                      : renderedTableWidth / logicalTableWidth;
                  final hormatCenterX = renderedLeft +
                      ((leadPrefixWidth + (leftMergeWidth / 2)) * tableScale);
                  final antokWidth = compact ? 100.0 : 112.0;
                  final antokShiftLeft = compact ? 8.0 : 9.0;
                  final antokTopOffset = compact ? 2.0 : 3.0;
                  final antokLeft = max(
                    0.0,
                    min(
                      availableWidth - antokWidth,
                      hormatCenterX - (antokWidth / 2) - antokShiftLeft,
                    ),
                  );

                  return pw.Padding(
                    padding: pw.EdgeInsets.only(top: compact ? 3 : 5),
                    child: pw.SizedBox(
                      width: availableWidth,
                      height: signatureTextFontSize + 3,
                      child: pw.Stack(
                        children: [
                          pw.Positioned(
                            left: antokLeft,
                            top: antokTopOffset,
                            child: pw.SizedBox(
                              width: antokWidth,
                              child: pw.Text(
                                'A N T O K',
                                textAlign: pw.TextAlign.center,
                                maxLines: 1,
                                style: pw.TextStyle(
                                  fontSize: signatureTextFontSize,
                                  fontWeight: pw.FontWeight.bold,
                                  decoration: pw.TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      }

      final invoiceTableRenderMode =
          isCompanyInvoice ? 'table_with_summary' : 'table_with_total';
      final invoiceTableHasEmbeddedSummary = invoiceTableRenderMode != 'table';
      final compactExcelTableImage = !usePortrait
          ? await buildExcelTableImage(
              compact: true,
              renderMode: invoiceTableRenderMode,
            )
          : null;
      final fullExcelTableImage = usePortrait
          ? await buildExcelTableImage(
              compact: false,
              renderMode: invoiceTableRenderMode,
            )
          : null;
      final pdfName = 'invoice-${_safePdfFileName(invoiceNumber)}';
      final pdfPageFormat = PdfPageFormat(
        8.5 * PdfPageFormat.inch,
        13.0 * PdfPageFormat.inch,
      );
      final pdfMarginHorizontal = usePortrait ? 24.0 : 18.0;
      final pdfMarginTop = usePortrait ? 12.0 : 6.5;
      final pdfMarginBottom = usePortrait ? 15.0 : 9.0;
      final tableRenderInfo = usePortrait
          ? fullExcelTableImage?.renderSource
          : compactExcelTableImage?.renderSource;
      final doc = pw.Document();

      if (usePortrait) {
        doc.addPage(
          pw.MultiPage(
            pageFormat: pdfPageFormat,
            margin: pw.EdgeInsets.fromLTRB(
              pdfMarginHorizontal,
              pdfMarginTop,
              pdfMarginHorizontal,
              pdfMarginBottom,
            ),
            build: (_) => [
              buildInvoiceContent(
                compact: false,
                excelTableRender: fullExcelTableImage,
                excelTableHasEmbeddedSummary: invoiceTableHasEmbeddedSummary,
              ),
            ],
          ),
        );
      } else {
        final usableHeight =
            pdfPageFormat.height - pdfMarginTop - pdfMarginBottom;
        final halfHeight = usableHeight / 2;
        doc.addPage(
          pw.Page(
            pageFormat: pdfPageFormat,
            margin: pw.EdgeInsets.fromLTRB(
              pdfMarginHorizontal,
              pdfMarginTop,
              pdfMarginHorizontal,
              pdfMarginBottom,
            ),
            build: (_) {
              return pw.Column(
                children: [
                  pw.Container(
                    height: halfHeight,
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: buildInvoiceContent(
                      compact: true,
                      excelTableRender: compactExcelTableImage,
                      excelTableHasEmbeddedSummary:
                          invoiceTableHasEmbeddedSummary,
                    ),
                  ),
                  pw.SizedBox(
                    height: halfHeight,
                  ),
                ],
              );
            },
          ),
        );
      }
      final pdfBytes = await doc.save();
      final confirmed = await _showPdfPreviewDialog(
        bytes: pdfBytes,
        title: pdfName,
        renderInfo: tableRenderInfo,
      );
      if (!confirmed) return false;
      await Printing.layoutPdf(
        name: pdfName,
        onLayout: (_) async => pdfBytes,
      );
      if (markAsFixed) {
        await _markInvoicesAsFixed(
          fixedInvoiceIds ?? <String>['${item['id'] ?? ''}'],
          batch: fixedBatch,
        );
      }
      if (showSuccessPopup && mounted) {
        _snack(
          _t(
            'Invoice berhasil diproses untuk dicetak.',
            'Invoice has been prepared for printing.',
          ),
        );
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      _snack(
        'Gagal print invoice: ${e.toString().replaceFirst('Exception: ', '')}',
        error: true,
      );
      return false;
    }
  }

  Map<int, pw.TableColumnWidth> _buildIncomeTableColumnWidths(
    List<Map<String, dynamic>> detailList,
  ) {
    var maxMuat = 12;
    var maxBongkar = 12;
    var maxPlate = 8;
    var maxMuatan = 8;
    var maxHarga = 10;
    var maxTotal = 10;
    for (final row in detailList) {
      maxMuat = max(maxMuat, '${row['lokasi_muat'] ?? ''}'.trim().length);
      maxBongkar = max(
        maxBongkar,
        '${row['lokasi_bongkar'] ?? ''}'.trim().length,
      );
      maxMuatan = max(maxMuatan, '${row['muatan'] ?? ''}'.trim().length);
      final plate = '${row['plat_nomor'] ?? row['no_polisi'] ?? ''}'.trim();
      maxPlate = max(maxPlate, plate.length);
      final hargaText = Formatters.rupiah(_toNum(row['harga']));
      final totalText =
          Formatters.rupiah(_toNum(row['tonase']) * _toNum(row['harga']));
      maxHarga = max(maxHarga, hargaText.length);
      maxTotal = max(maxTotal, totalText.length);
    }

    final totalRouteChars = max(1, maxMuat + maxBongkar);
    final muatShare = maxMuat / totalRouteChars;
    final bongkarShare = maxBongkar / totalRouteChars;
    const routeBudgetFlex = 2.10;
    final muatFlex = (routeBudgetFlex * muatShare).clamp(1.0, 1.55).toDouble();
    final bongkarFlex =
        (routeBudgetFlex * bongkarShare).clamp(1.0, 1.55).toDouble();
    final plateFlex = (maxPlate / 9).clamp(1.0, 1.35).toDouble();
    final muatanFlex = (maxMuatan / 8.5).clamp(0.95, 1.45).toDouble();
    final hargaFlex = (maxHarga / 13).clamp(0.58, 0.82).toDouble();
    final totalFlex = (maxTotal / 8.6).clamp(1.30, 1.90).toDouble();

    return {
      0: const pw.FixedColumnWidth(30), // No
      1: const pw.FlexColumnWidth(1.05), // Tanggal
      2: pw.FlexColumnWidth(plateFlex), // Plat
      3: pw.FlexColumnWidth(muatanFlex), // Muatan
      4: pw.FlexColumnWidth(muatFlex), // Muat
      5: pw.FlexColumnWidth(bongkarFlex), // Bongkar
      6: const pw.FlexColumnWidth(0.72), // Tonase
      7: pw.FlexColumnWidth(hargaFlex), // Harga
      8: pw.FlexColumnWidth(totalFlex), // Total
    };
  }

  Map<int, pw.TableColumnWidth> _buildExpenseTableColumnWidths(
    List<Map<String, dynamic>> detailList,
  ) {
    var maxDesc = 14;
    for (final row in detailList) {
      maxDesc =
          max(maxDesc, '${row['nama'] ?? row['name'] ?? ''}'.trim().length);
    }
    final descFlex = (maxDesc / 8).clamp(2.4, 3.5).toDouble();
    return {
      0: const pw.FixedColumnWidth(24), // No
      1: const pw.FlexColumnWidth(0.95), // Tanggal
      2: pw.FlexColumnWidth(descFlex), // Keterangan
      3: const pw.FlexColumnWidth(1.2), // Total
    };
  }

  Future<void> _printExpensePdf(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> detailList,
  ) async {
    try {
      final rows = detailList.isNotEmpty
          ? detailList
          : <Map<String, dynamic>>[
              {
                'nama': '${item['kategori'] ?? item['keterangan'] ?? '-'}',
                'jumlah': _toNum(item['total_pengeluaran']),
              },
            ];

      final usePortrait = rows.length > 14;
      final totalExpense = _toNum(item['total_pengeluaran']);
      final expenseNumber = '${item['no_expense'] ?? '-'}';

      pw.Widget buildExpenseContent({required bool compact}) {
        const infoFont = 9.5;
        const tableBodyRowHeight = 16.0;
        final minRows = compact ? 14 : 36;
        final printableRows = rows.length >= minRows
            ? rows
            : <Map<String, dynamic>>[
                ...rows,
                ...List<Map<String, dynamic>>.generate(
                  minRows - rows.length,
                  (_) => <String, dynamic>{},
                ),
              ];
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CV ANT',
                          style: pw.TextStyle(
                            fontSize: compact ? 15 : 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'AS Nusa Trans',
                          style: pw.TextStyle(
                            fontSize: compact ? 10 : 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'EXPENSE',
                        style: pw.TextStyle(
                          fontSize: compact ? 15 : 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        expenseNumber,
                        style: pw.TextStyle(
                          fontSize: compact ? 10 : 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Tanggal: ${Formatters.dmy(item['tanggal'])}',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: infoFont),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Data Expense',
                          style: pw.TextStyle(
                            fontSize: infoFont,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Kategori: ${item['kategori'] ?? '-'}',
                          style: const pw.TextStyle(fontSize: infoFont),
                        ),
                        pw.Text(
                          'Keterangan: ${item['keterangan'] ?? item['note'] ?? '-'}',
                          style: const pw.TextStyle(fontSize: infoFont),
                        ),
                        pw.Text(
                          'Dicatat oleh: ${item['dicatat_oleh'] ?? '-'}',
                          style: const pw.TextStyle(fontSize: infoFont),
                        ),
                        pw.Text(
                          'Status: ${item['status'] ?? '-'}',
                          style: const pw.TextStyle(fontSize: infoFont),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.SizedBox(width: compact ? 130 : 160),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: _buildExpenseTableColumnWidths(printableRows),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor(0.12, 0.13, 0.15),
                  ),
                  children: [
                    _pdfCell('NO', bold: true, textColor: PdfColors.white),
                    _pdfCell(
                      'TANGGAL',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                    ),
                    _pdfCell(
                      'KETERANGAN',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                    ),
                    _pdfCell(
                      'TOTAL',
                      bold: true,
                      alignRight: true,
                      textColor: PdfColors.white,
                    ),
                  ],
                ),
                ...List<pw.TableRow>.generate(printableRows.length, (index) {
                  final row = printableRows[index];
                  final hasData = index < rows.length;
                  final amount =
                      hasData ? _toNum(row['jumlah'] ?? row['amount']) : 0;
                  final tanggal = hasData
                      ? Formatters.dmy(
                          row['tanggal'] ?? item['tanggal'],
                        )
                      : '';
                  final name =
                      hasData ? '${row['nama'] ?? row['name'] ?? '-'}' : '';
                  return pw.TableRow(
                    children: [
                      _pdfCell(
                        hasData ? '${index + 1}' : '',
                        alignCenter: true,
                        hPadding: 3,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 2,
                        minFontSize: 7,
                      ),
                      _pdfCell(
                        tanggal,
                        alignCenter: true,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 10,
                      ),
                      _pdfCell(
                        name,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 34,
                        minFontSize: 6.5,
                      ),
                      _pdfCell(
                        hasData ? Formatters.rupiah(amount) : '',
                        alignRight: true,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 14,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: compact ? 200 : 220,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Pengeluaran',
                      style: pw.TextStyle(
                        fontSize: infoFont,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      Formatters.rupiah(totalExpense),
                      style: pw.TextStyle(
                        fontSize: infoFont,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Hormat kami,'),
                  pw.SizedBox(height: compact ? 72 : 102),
                  pw.Text(
                    'A N T O K',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      await Printing.layoutPdf(
        name: 'expense-$expenseNumber',
        onLayout: (format) async {
          final doc = pw.Document();
          final portraitFormat =
              format.width <= format.height ? format : format.landscape;
          final margin = usePortrait ? 24.0 : 18.0;

          if (usePortrait) {
            doc.addPage(
              pw.MultiPage(
                pageFormat: portraitFormat,
                margin: pw.EdgeInsets.all(margin),
                build: (_) => [
                  buildExpenseContent(compact: false),
                ],
              ),
            );
          } else {
            final usableHeight = portraitFormat.height - (margin * 2);
            final halfHeight = usableHeight / 2;
            doc.addPage(
              pw.Page(
                pageFormat: portraitFormat,
                margin: pw.EdgeInsets.all(margin),
                build: (_) {
                  return pw.Column(
                    children: [
                      pw.Container(
                        height: halfHeight,
                        padding: const pw.EdgeInsets.only(bottom: 8),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                              color: PdfColors.grey400,
                              width: 0.7,
                            ),
                          ),
                        ),
                        child: buildExpenseContent(compact: true),
                      ),
                      pw.SizedBox(height: halfHeight),
                    ],
                  );
                },
              ),
            );
          }
          return doc.save();
        },
      );
    } catch (e) {
      if (!mounted) return;
      _snack(
        'Gagal print expense: ${e.toString().replaceFirst('Exception: ', '')}',
        error: true,
      );
    }
  }

  pw.Widget _pdfCell(
    String text, {
    bool bold = false,
    bool alignRight = false,
    bool alignCenter = false,
    PdfColor? textColor,
    double fontSize = 9.5,
    double minFontSize = 7.0,
    double hPadding = 6,
    double vPadding = 5,
    double? fixedHeight,
    bool singleLineAutoShrink = false,
    int softLimitChars = 24,
  }) {
    final textAlign = alignRight
        ? pw.TextAlign.right
        : alignCenter
            ? pw.TextAlign.center
            : pw.TextAlign.left;
    var resolvedFontSize = fontSize;
    if (singleLineAutoShrink) {
      final safeLimit = max(1, softLimitChars);
      final textLength = text.trim().length;
      if (textLength > safeLimit) {
        final ratio = safeLimit / textLength;
        resolvedFontSize = max(minFontSize, fontSize * ratio);
      }
    }
    return pw.Container(
      height: fixedHeight,
      alignment: alignCenter
          ? pw.Alignment.center
          : alignRight
              ? pw.Alignment.centerRight
              : pw.Alignment.centerLeft,
      child: pw.Padding(
        padding:
            pw.EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
        child: pw.Text(
          text,
          maxLines: singleLineAutoShrink ? 1 : null,
          textAlign: textAlign,
          style: pw.TextStyle(
            fontSize: resolvedFontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Future<void> _openExpensePreview(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        final detailList = _toDetailList(item['rincian']);
        return AlertDialog(
          title:
              Text('${_t('Preview', 'Preview')} ${item['no_expense'] ?? '-'}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${_t('Kategori', 'Category')}: ${item['kategori'] ?? '-'}'),
                  Text(
                      '${_t('Keterangan', 'Description')}: ${item['keterangan'] ?? item['note'] ?? '-'}'),
                  Text(
                      '${_t('Tanggal', 'Date')}: ${Formatters.dmy(item['tanggal'])}'),
                  Text('${_t('Status', 'Status')}: ${item['status'] ?? '-'}'),
                  Text(
                      '${_t('Dicatat oleh', 'Recorded by')}: ${item['dicatat_oleh'] ?? '-'}'),
                  const SizedBox(height: 8),
                  Text(
                    '${_t('Total', 'Total')}: ${Formatters.rupiah(_toNum(item['total_pengeluaran']))}',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (detailList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _t('Rincian', 'Details'),
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ...detailList.map((row) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '- ${row['nama'] ?? row['name'] ?? '-'}: ${Formatters.rupiah(_toNum(row['jumlah'] ?? row['amount']))}',
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () => _printExpensePdf(item, detailList),
              style: CvantButtonStyles.outlined(
                context,
                color: AppColors.blue,
                borderColor: AppColors.blue,
                minimumSize: const Size(96, 40),
              ),
              icon: const Icon(Icons.print_outlined, size: 16),
              label: Text(_t('Print', 'Print')),
            ),
            FilledButton(
              style: CvantButtonStyles.filled(
                context,
                color: AppColors.blue,
                minimumSize: const Size(96, 40),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Tutup', 'Close')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openInvoiceEdit(Map<String, dynamic> item) async {
    final customer =
        TextEditingController(text: '${item['nama_pelanggan'] ?? ''}');
    final email = TextEditingController(text: '${item['email'] ?? ''}');
    final phone = TextEditingController(text: '${item['no_telp'] ?? ''}');
    final kopDate = TextEditingController(
      text: _toInputDate(DateTime.now()),
    );
    final kopLocation =
        TextEditingController(text: '${item['lokasi_kop'] ?? ''}');
    final dueDate = TextEditingController(
      text: _toInputDate(item['due_date']),
    );
    String status = '${item['status'] ?? 'Unpaid'}';
    String acceptedBy = '${item['diterima_oleh'] ?? 'Admin'}';
    bool saving = false;
    bool isCompanyInvoiceMode = _resolveIsCompanyInvoice(
      invoiceNumber: item['no_invoice'],
      customerName: item['nama_pelanggan'],
    );

    List<Map<String, dynamic>> armadas = const <Map<String, dynamic>>[];
    List<Map<String, dynamic>> hargaPerTonRules =
        const <Map<String, dynamic>>[];
    int editDetailFieldRefreshToken = 0;
    int editHargaFieldRefreshToken = 0;
    try {
      armadas = await widget.repository.fetchArmadas();
      hargaPerTonRules = await widget.repository.fetchHargaPerTonRules();
    } catch (_) {}
    final armadaIdByPlate = _buildArmadaIdByPlate(armadas);

    String normalizeLokasiKey(String value) {
      return value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    bool lokasiKeyMatches(String inputKey, String ruleKey) {
      if (inputKey.isEmpty || ruleKey.isEmpty) return false;
      if (inputKey == ruleKey) return true;

      final inputList = inputKey
          .split(' ')
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      final ruleList = ruleKey
          .split(' ')
          .where((part) => part.isNotEmpty)
          .toList(growable: false);

      if (inputList.length < 2 || ruleList.isEmpty) {
        return false;
      }

      final shorter =
          inputList.length <= ruleList.length ? inputList : ruleList;
      final longer = inputList.length <= ruleList.length ? ruleList : inputList;
      return shorter.length >= 2 &&
          shorter.every((token) => longer.contains(token));
    }

    double? resolveHargaPerTon({
      required String lokasiMuat,
      required String lokasiBongkar,
    }) {
      if (hargaPerTonRules.isEmpty) return null;
      final bongkarKey = normalizeLokasiKey(lokasiBongkar);
      if (bongkarKey.isEmpty) return null;
      final muatKey = normalizeLokasiKey(lokasiMuat);

      Map<String, dynamic>? exactMatch;
      Map<String, dynamic>? fallbackMatch;
      for (final rule in hargaPerTonRules) {
        final ruleBongkar =
            normalizeLokasiKey('${rule['lokasi_bongkar'] ?? ''}'.trim());
        if (!lokasiKeyMatches(bongkarKey, ruleBongkar)) continue;
        final ruleMuat =
            normalizeLokasiKey('${rule['lokasi_muat'] ?? ''}'.trim());
        if (muatKey.isNotEmpty &&
            ruleMuat.isNotEmpty &&
            lokasiKeyMatches(muatKey, ruleMuat)) {
          exactMatch = rule;
          break;
        }
        fallbackMatch ??= rule;
      }

      final matched = exactMatch ?? fallbackMatch;
      if (matched == null) return null;
      final resolved = _toNum(matched['harga_per_ton'] ?? matched['harga']);
      return resolved > 0 ? resolved : null;
    }

    bool applyAutoHargaPerTon(
      Map<String, dynamic> row, {
      bool force = false,
    }) {
      final previousHarga = '${row['harga'] ?? ''}'.trim();
      final wasAuto = row['harga_auto'] == true;
      final harga = resolveHargaPerTon(
        lokasiMuat: '${row['lokasi_muat'] ?? ''}',
        lokasiBongkar: '${row['lokasi_bongkar'] ?? ''}',
      );
      if (harga == null || harga <= 0) {
        if (force && wasAuto && previousHarga.isNotEmpty) {
          row['harga'] = '';
          row['harga_auto'] = true;
          return true;
        }
        return false;
      }
      final currentHarga = _toNum(row['harga']);
      final isAuto = row['harga_auto'] == true;
      if (!force && currentHarga > 0 && !isAuto) {
        return false;
      }
      final nextHarga = harga.floor().toString();
      row['harga'] = nextHarga;
      row['harga_auto'] = true;
      return previousHarga != nextHarga || !wasAuto;
    }

    Map<String, dynamic> mapDetailRow(Map<String, dynamic> row) {
      final rawArmadaId = '${row['armada_id'] ?? ''}'.trim();
      final rawManual =
          '${row['armada_manual'] ?? row['armada_label'] ?? row['armada'] ?? ''}'
              .trim();
      final resolvedArmadaId = _resolveArmadaIdFromInput(
        armadaId: rawArmadaId,
        armadaManual: rawManual,
        armadaIdByPlate: armadaIdByPlate,
      );
      final useManual = resolvedArmadaId.isEmpty && rawManual.isNotEmpty;
      final muatText = '${row['lokasi_muat'] ?? ''}'.trim();
      final muatIsManual =
          muatText.isNotEmpty && !_defaultMuatOptions.contains(muatText);
      final hargaText = _formatEditableNumber(row['harga']);
      final driverText = '${row['nama_supir'] ?? ''}'.trim();
      final isDriverManual =
          driverText.isNotEmpty && !_isKnownDriverOption(driverText);
      final resolvedHarga = resolveHargaPerTon(
        lokasiMuat: muatText,
        lokasiBongkar: '${row['lokasi_bongkar'] ?? ''}',
      );
      final mappedRow = <String, dynamic>{
        'lokasi_muat': muatText,
        'lokasi_muat_manual': muatIsManual ? muatText : '',
        'lokasi_bongkar': '${row['lokasi_bongkar'] ?? ''}',
        'muatan': '${row['muatan'] ?? ''}',
        'nama_supir': driverText,
        'nama_supir_manual': isDriverManual ? driverText : '',
        'nama_supir_is_manual': isDriverManual,
        'nama_supir_auto': false,
        'armada_id': resolvedArmadaId,
        'armada_manual': useManual ? rawManual : '',
        'armada_is_manual': useManual,
        'armada_start_date': _toInputDate(row['armada_start_date']),
        'armada_end_date': _toInputDate(row['armada_end_date']),
        'tonase': _formatEditableNumber(row['tonase']),
        'harga': hargaText,
        'harga_auto': resolvedHarga != null &&
            resolvedHarga > 0 &&
            _toNum(hargaText) == resolvedHarga.floorToDouble(),
      };
      final defaultDriver =
          _resolveDefaultDriverForRow(mappedRow, armadas: armadas)?.trim() ??
              '';
      if (!isDriverManual && defaultDriver.isNotEmpty) {
        if (driverText.isEmpty ||
            _normalizeText(driverText) == _normalizeText(defaultDriver)) {
          mappedRow['nama_supir'] = defaultDriver;
          mappedRow['nama_supir_manual'] = '';
          mappedRow['nama_supir_is_manual'] = false;
          mappedRow['nama_supir_auto'] = true;
        }
      }
      return mappedRow;
    }

    final existingDetails = _toDetailList(item['rincian']);
    final details = existingDetails.isNotEmpty
        ? existingDetails.map(mapDetailRow).toList()
        : <Map<String, dynamic>>[
            mapDetailRow(item),
          ];

    double detailSubtotal(Map<String, dynamic> row) {
      return _toNum(row['tonase']) * _toNum(row['harga']);
    }

    if (!mounted) return;
    bool dialogClosed = false;

    try {
      await showDialog<void>(
        context: context,
        barrierColor: AppColors.popupOverlay,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final subtotal = details.fold<double>(
                0,
                (sum, row) => sum + detailSubtotal(row),
              );
              final pph = isCompanyInvoiceMode
                  ? (subtotal * 0.02).floorToDouble()
                  : 0.0;
              final totalBayar =
                  isCompanyInvoiceMode ? max(0.0, subtotal - pph) : subtotal;

              return AlertDialog(
                title: Text(_t('Edit Invoice', 'Edit Invoice')),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('Mode Invoice', 'Invoice Mode'),
                          style:
                              TextStyle(color: AppColors.textMutedFor(context)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _buildEditInvoiceModeTab(
                                label: _t('Pribadi', 'Personal'),
                                selected: !isCompanyInvoiceMode,
                                onTap: () => setDialogState(
                                  () => isCompanyInvoiceMode = false,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildEditInvoiceModeTab(
                                label: _t('Perusahaan', 'Company'),
                                selected: isCompanyInvoiceMode,
                                onTap: () => setDialogState(
                                  () => isCompanyInvoiceMode = true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _dialogField(
                            customer, _t('Nama Customer', 'Customer Name')),
                        const SizedBox(height: 8),
                        _dialogField(
                          email,
                          _t('Email Customer', 'Customer Email'),
                          type: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 8),
                        _dialogField(
                          phone,
                          _t('No. Telp', 'Phone Number'),
                          type: TextInputType.phone,
                        ),
                        const SizedBox(height: 8),
                        _dateSelect(
                          label: _t('Tanggal Pelunasan', 'Payment Date'),
                          value: dueDate.text,
                          onChanged: (v) =>
                              setDialogState(() => dueDate.text = v),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _t(
                            'Rincian Muat / Bongkar & Armada',
                            'Loading / Unloading & Fleet Details',
                          ),
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        ...details.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          final rowSubtotal = detailSubtotal(row);
                          final muatValue =
                              '${row['lokasi_muat'] ?? ''}'.trim();
                          final muatManual =
                              '${row['lokasi_muat_manual'] ?? ''}'.trim();
                          final isMuatManual = muatManual.isNotEmpty ||
                              (muatValue.isNotEmpty &&
                                  !_defaultMuatOptions.contains(muatValue));
                          return Container(
                            margin: EdgeInsets.only(
                              bottom: index == details.length - 1 ? 0 : 10,
                            ),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.cardBorder(context),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                CvantDropdownField<String>(
                                  initialValue: isMuatManual
                                      ? 'Other (Input Manual)'
                                      : (muatValue.isNotEmpty
                                          ? muatValue
                                          : null),
                                  decoration: InputDecoration(
                                    hintText:
                                        _t('Lokasi Muat', 'Loading Location'),
                                  ),
                                  items: [
                                    ..._defaultMuatOptions.map(
                                      (option) => DropdownMenuItem<String>(
                                        value: option,
                                        child: Text(option),
                                      ),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: 'Other (Input Manual)',
                                      child: Text(
                                        _t(
                                          'Other (Input Manual)',
                                          'Other (Manual Input)',
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value == 'Other (Input Manual)') {
                                        row['lokasi_muat'] = '';
                                        row['lokasi_muat_manual'] = '';
                                      } else {
                                        row['lokasi_muat'] = value ?? '';
                                        row['lokasi_muat_manual'] = '';
                                      }
                                      final hargaChanged = applyAutoHargaPerTon(
                                        row,
                                        force: row['harga_auto'] == true,
                                      );
                                      if (hargaChanged) {
                                        editHargaFieldRefreshToken++;
                                      }
                                    });
                                  },
                                ),
                                if (isMuatManual) ...[
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    key: ValueKey(
                                      'edit-lokasi-muat-manual-$index',
                                    ),
                                    initialValue: muatManual,
                                    decoration: InputDecoration(
                                      hintText: _t(
                                        'Lokasi Muat (Manual)',
                                        'Loading Location (Manual)',
                                      ),
                                    ),
                                    onChanged: (value) {
                                      row['lokasi_muat_manual'] = value;
                                      row['lokasi_muat'] = value;
                                      final hargaChanged = applyAutoHargaPerTon(
                                        row,
                                        force: row['harga_auto'] == true,
                                      );
                                      setDialogState(() {
                                        if (hargaChanged) {
                                          editHargaFieldRefreshToken++;
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                ] else
                                  const SizedBox(height: 8),
                                TextFormField(
                                  key: ValueKey(
                                    'edit-lokasi-bongkar-$index',
                                  ),
                                  initialValue: '${row['lokasi_bongkar']}',
                                  decoration: InputDecoration(
                                    hintText: _t(
                                        'Lokasi Bongkar', 'Unloading Location'),
                                  ),
                                  onChanged: (value) {
                                    row['lokasi_bongkar'] = value;
                                    final hargaChanged =
                                        applyAutoHargaPerTon(row, force: true);
                                    setDialogState(() {
                                      if (hargaChanged) {
                                        editHargaFieldRefreshToken++;
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  key: ValueKey(
                                    'edit-muatan-$index-$editDetailFieldRefreshToken',
                                  ),
                                  initialValue: '${row['muatan'] ?? ''}',
                                  decoration: InputDecoration(
                                    hintText: _t('Muatan', 'Cargo'),
                                  ),
                                  onChanged: (value) => row['muatan'] = value,
                                ),
                                const SizedBox(height: 8),
                                CvantDropdownField<String>(
                                  key: ValueKey(
                                    'edit-armada-$index-${row['armada_id']}-${row['armada_manual']}-${row['armada_is_manual']}',
                                  ),
                                  initialValue: () {
                                    final armadaId =
                                        '${row['armada_id']}'.trim();
                                    final armadaManual =
                                        '${row['armada_manual'] ?? ''}'.trim();
                                    final isManual =
                                        row['armada_is_manual'] == true;
                                    if (armadaId.isNotEmpty) return armadaId;
                                    if (isManual || armadaManual.isNotEmpty) {
                                      return _manualArmadaOptionId;
                                    }
                                    return '';
                                  }(),
                                  decoration: InputDecoration(
                                    hintText:
                                        _t('Pilih Armada', 'Select Fleet'),
                                  ),
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: '',
                                      child: Text(_t('-- Pilih Armada --',
                                          '-- Select Fleet --')),
                                    ),
                                    ...armadas.map(
                                      (a) => DropdownMenuItem(
                                        value: '${a['id']}',
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text:
                                                    '${a['nama_truk'] ?? '-'} - ${a['plat_nomor'] ?? '-'} ',
                                              ),
                                              TextSpan(
                                                text:
                                                    '(${a['status'] ?? 'Ready'})',
                                                style: TextStyle(
                                                  color: _armadaStatusColor(
                                                    '${a['status'] ?? 'Ready'}',
                                                  ),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: _manualArmadaOptionId,
                                      child: Text(
                                        _t(
                                          'Other (Input Manual)',
                                          'Other (Manual Input)',
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value == _manualArmadaOptionId) {
                                        row['armada_id'] = '';
                                        row['armada_is_manual'] = true;
                                      } else {
                                        row['armada_id'] = value ?? '';
                                        row['armada_is_manual'] = false;
                                        if ('${row['armada_id']}'
                                            .trim()
                                            .isNotEmpty) {
                                          row['armada_manual'] = '';
                                        }
                                      }
                                      _syncDriverWithArmadaSelection(
                                        row,
                                        armadas: armadas,
                                        overrideManualDriver: value != null &&
                                            value.isNotEmpty &&
                                            value != _manualArmadaOptionId,
                                      );
                                      editDetailFieldRefreshToken++;
                                    });
                                  },
                                ),
                                if (row['armada_is_manual'] == true ||
                                    ('${row['armada_manual'] ?? ''}'
                                            .trim()
                                            .isNotEmpty &&
                                        '${row['armada_id']}'
                                            .trim()
                                            .isEmpty)) ...[
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    key: ValueKey(
                                      'edit-armada-manual-$index-$editDetailFieldRefreshToken',
                                    ),
                                    initialValue:
                                        '${row['armada_manual'] ?? ''}',
                                    decoration: InputDecoration(
                                      hintText: _t(
                                        'Plat Nomor Manual (Other/Gabungan)',
                                        'Manual Plate Number (Other/Combined)',
                                      ),
                                    ),
                                    onChanged: (value) => setDialogState(() {
                                      row['armada_manual'] = value;
                                      _syncDriverWithArmadaSelection(
                                        row,
                                        armadas: armadas,
                                      );
                                    }),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                CvantDropdownField<String>(
                                  key: ValueKey(
                                    'edit-driver-$index-${row['nama_supir']}-${row['nama_supir_manual']}-${row['nama_supir_is_manual']}-${row['nama_supir_auto']}',
                                  ),
                                  initialValue: () {
                                    final driver =
                                        '${row['nama_supir'] ?? ''}'.trim();
                                    final driverManual =
                                        '${row['nama_supir_manual'] ?? ''}'
                                            .trim();
                                    final isManual =
                                        row['nama_supir_is_manual'] == true;
                                    if (isManual ||
                                        driverManual.isNotEmpty ||
                                        (driver.isNotEmpty &&
                                            !_isKnownDriverOption(driver))) {
                                      return _manualDriverOptionId;
                                    }
                                    return driver;
                                  }(),
                                  decoration: InputDecoration(
                                    hintText: _t(
                                      'Pilih Nama Supir',
                                      'Select Driver Name',
                                    ),
                                  ),
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: '',
                                      child: Text(_t(
                                        '-- Pilih Nama Supir --',
                                        '-- Select Driver Name --',
                                      )),
                                    ),
                                    ..._defaultDriverOptions.map(
                                      (driver) => DropdownMenuItem<String>(
                                        value: driver,
                                        child: Text(driver),
                                      ),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: _manualDriverOptionId,
                                      child: Text(
                                        _t(
                                          'Other (Input Manual)',
                                          'Other (Manual Input)',
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value == _manualDriverOptionId) {
                                        _enableManualDriverInput(row);
                                      } else {
                                        row['nama_supir'] = value ?? '';
                                        row['nama_supir_manual'] = '';
                                        row['nama_supir_is_manual'] = false;
                                      }
                                      row['nama_supir_auto'] = false;
                                      editDetailFieldRefreshToken++;
                                    });
                                  },
                                ),
                                if (row['nama_supir_is_manual'] == true ||
                                    ('${row['nama_supir_manual'] ?? ''}'
                                            .trim()
                                            .isNotEmpty &&
                                        !_isKnownDriverOption(
                                          '${row['nama_supir'] ?? ''}',
                                        ))) ...[
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    key: ValueKey(
                                      'edit-driver-manual-$index-$editDetailFieldRefreshToken',
                                    ),
                                    initialValue:
                                        '${row['nama_supir_manual'] ?? ''}',
                                    decoration: InputDecoration(
                                      hintText: _t(
                                        'Nama Supir (Manual)',
                                        'Driver Name (Manual)',
                                      ),
                                    ),
                                    onChanged: (value) => setDialogState(() {
                                      row['nama_supir_manual'] = value;
                                      row['nama_supir'] = value;
                                      row['nama_supir_is_manual'] = true;
                                      row['nama_supir_auto'] = false;
                                    }),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _dateSelect(
                                        label:
                                            _t('Tanggal Mulai', 'Start Date'),
                                        value:
                                            '${row['armada_start_date'] ?? ''}',
                                        onChanged: (value) => setDialogState(
                                          () =>
                                              row['armada_start_date'] = value,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _dateSelect(
                                        label:
                                            _t('Tanggal Selesai', 'End Date'),
                                        value:
                                            '${row['armada_end_date'] ?? ''}',
                                        onChanged: (value) => setDialogState(
                                          () => row['armada_end_date'] = value,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        key: ValueKey(
                                          'edit-tonase-$index-$editDetailFieldRefreshToken',
                                        ),
                                        initialValue: '${row['tonase']}',
                                        keyboardType: const TextInputType
                                            .numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: _t('Tonase', 'Tonnage'),
                                        ),
                                        onChanged: (value) {
                                          row['tonase'] = value;
                                          setDialogState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        key: ValueKey(
                                          'edit-harga-$index-$editDetailFieldRefreshToken-$editHargaFieldRefreshToken',
                                        ),
                                        initialValue: '${row['harga']}',
                                        keyboardType: const TextInputType
                                            .numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              _t('Harga / Ton', 'Price / Ton'),
                                        ),
                                        onChanged: (value) {
                                          row['harga'] = value;
                                          row['harga_auto'] = false;
                                          setDialogState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      '${_t('Subtotal', 'Subtotal')}: ${Formatters.rupiah(rowSubtotal)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const Spacer(),
                                    if (details.length > 1)
                                      TextButton(
                                        onPressed: () => setDialogState(
                                          () => details.removeAt(index),
                                        ),
                                        style: CvantButtonStyles.text(
                                          context,
                                          color: AppColors.danger,
                                        ),
                                        child: Text(_t('Hapus', 'Delete')),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => setDialogState(() {
                            details.add(
                              <String, dynamic>{
                                'lokasi_muat': '',
                                'lokasi_muat_manual': '',
                                'lokasi_bongkar': '',
                                'muatan': '',
                                'nama_supir': '',
                                'nama_supir_manual': '',
                                'nama_supir_is_manual': false,
                                'nama_supir_auto': false,
                                'armada_id': '',
                                'armada_manual': '',
                                'armada_is_manual': false,
                                'armada_start_date': '',
                                'armada_end_date': '',
                                'tonase': '',
                                'harga': '',
                                'harga_auto': true,
                              },
                            );
                            editDetailFieldRefreshToken++;
                          }),
                          child: Text(_t('+ Tambah Rincian', '+ Add Detail')),
                        ),
                        const SizedBox(height: 10),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: _t('Subtotal', 'Subtotal'),
                          ),
                          child: Text(Formatters.rupiah(subtotal)),
                        ),
                        if (isCompanyInvoiceMode) ...[
                          const SizedBox(height: 8),
                          InputDecorator(
                            decoration:
                                const InputDecoration(labelText: 'PPH (2%)'),
                            child: Text(Formatters.rupiah(pph)),
                          ),
                        ],
                        const SizedBox(height: 8),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: _t('Total Bayar', 'Grand Total'),
                          ),
                          child: Text(Formatters.rupiah(totalBayar)),
                        ),
                        const SizedBox(height: 8),
                        CvantDropdownField<String>(
                          initialValue: status,
                          decoration: InputDecoration(
                            labelText: _t('Status', 'Status'),
                          ),
                          items: const ['Unpaid', 'Paid', 'Waiting']
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => status = value ?? status),
                        ),
                        const SizedBox(height: 8),
                        CvantDropdownField<String>(
                          initialValue: acceptedBy,
                          decoration: InputDecoration(
                            labelText: _t('Diterima Oleh', 'Accepted By'),
                          ),
                          items: (widget.session.isPengurus
                                  ? const ['Pengurus']
                                  : const ['Admin', 'Owner'])
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setDialogState(
                            () => acceptedBy = value ?? acceptedBy,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 132,
                              child: OutlinedButton(
                                onPressed: saving
                                    ? null
                                    : () {
                                        dialogClosed = true;
                                        Navigator.of(context).pop();
                                      },
                                style: CvantButtonStyles.outlined(
                                  context,
                                  color: AppColors.isLight(context)
                                      ? AppColors.textSecondaryLight
                                      : const Color(0xFFE2E8F0),
                                  borderColor: AppColors.neutralOutline,
                                ),
                                child: Text(_t('Batal', 'Cancel')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 132,
                              child: FilledButton(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        final first = details.first;
                                        if (customer.text.trim().isEmpty ||
                                            subtotal <= 0) {
                                          _snack(
                                            _t(
                                              'Nama customer dan total wajib diisi.',
                                              'Customer name and total are required.',
                                            ),
                                            error: true,
                                          );
                                          return;
                                        }
                                        final hasEmptyMuatan = details.any(
                                          (row) => '${row['muatan'] ?? ''}'
                                              .trim()
                                              .isEmpty,
                                        );
                                        if (hasEmptyMuatan) {
                                          _snack(
                                            _t(
                                              'Muatan wajib diisi di setiap rincian.',
                                              'Cargo is required for every detail row.',
                                            ),
                                            error: true,
                                          );
                                          return;
                                        }
                                        final firstArmadaId =
                                            '${first['armada_id']}'.trim();
                                        final firstArmadaManual =
                                            '${first['armada_manual'] ?? ''}'
                                                .trim();
                                        final firstResolvedArmadaId =
                                            _resolveArmadaIdFromInput(
                                          armadaId: firstArmadaId,
                                          armadaManual: firstArmadaManual,
                                          armadaIdByPlate: armadaIdByPlate,
                                        );
                                        final hasArmadaSelection =
                                            firstResolvedArmadaId.isNotEmpty ||
                                                firstArmadaManual.isNotEmpty;
                                        if ('${first['lokasi_muat']}'
                                                .trim()
                                                .isEmpty ||
                                            '${first['lokasi_bongkar']}'
                                                .trim()
                                                .isEmpty ||
                                            !hasArmadaSelection) {
                                          _snack(
                                            _t(
                                              'Lokasi muat, lokasi bongkar, dan armada wajib diisi.',
                                              'Loading location, unloading location, and fleet are required.',
                                            ),
                                            error: true,
                                          );
                                          return;
                                        }

                                        String? normalizeNullable(
                                          dynamic value,
                                        ) {
                                          final raw =
                                              value?.toString().trim() ?? '';
                                          if (raw.isEmpty) return null;
                                          final lowered = raw.toLowerCase();
                                          if (lowered == 'null' ||
                                              lowered == 'undefined' ||
                                              lowered == '-') {
                                            return null;
                                          }
                                          return raw;
                                        }

                                        final detailsPayload =
                                            details.map((row) {
                                          final armadaId =
                                              '${row['armada_id']}'.trim();
                                          final armadaManualRaw =
                                              normalizeNullable(
                                                    row['armada_manual'],
                                                  ) ??
                                                  '';
                                          final resolvedArmadaId =
                                              _resolveArmadaIdFromInput(
                                            armadaId: armadaId,
                                            armadaManual: armadaManualRaw,
                                            armadaIdByPlate: armadaIdByPlate,
                                          );
                                          Map<String, dynamic>? selectedArmada;
                                          if (resolvedArmadaId.isNotEmpty) {
                                            for (final armada in armadas) {
                                              if ('${armada['id'] ?? ''}'
                                                      .trim() ==
                                                  resolvedArmadaId) {
                                                selectedArmada = armada;
                                                break;
                                              }
                                            }
                                          }
                                          final useManual =
                                              resolvedArmadaId.isEmpty &&
                                                  armadaManualRaw.isNotEmpty;
                                          final resolvedPlate =
                                              selectedArmada != null
                                                  ? _normalizePlateText(
                                                      '${selectedArmada['plat_nomor'] ?? ''}',
                                                    )
                                                  : (useManual
                                                      ? (_extractPlateFromText(
                                                            armadaManualRaw,
                                                          ) ??
                                                          _normalizePlateText(
                                                            armadaManualRaw,
                                                          ))
                                                      : '');
                                          return <String, dynamic>{
                                            'lokasi_muat':
                                                '${row['lokasi_muat']}'.trim(),
                                            'lokasi_bongkar':
                                                '${row['lokasi_bongkar']}'
                                                    .trim(),
                                            'muatan': normalizeNullable(
                                              row['muatan'],
                                            ),
                                            'nama_supir': normalizeNullable(
                                              row['nama_supir'],
                                            ),
                                            'armada_id':
                                                resolvedArmadaId.isEmpty
                                                    ? null
                                                    : resolvedArmadaId,
                                            'armada_manual': useManual
                                                ? armadaManualRaw
                                                : null,
                                            'armada_label': useManual
                                                ? armadaManualRaw
                                                : null,
                                            'plat_nomor': resolvedPlate.isEmpty
                                                ? null
                                                : resolvedPlate,
                                            'no_polisi': resolvedPlate.isEmpty
                                                ? null
                                                : resolvedPlate,
                                            'armada_start_date':
                                                '${row['armada_start_date']}'
                                                        .trim()
                                                        .isEmpty
                                                    ? null
                                                    : _toDbDate(
                                                        '${row['armada_start_date']}',
                                                      ),
                                            'armada_end_date':
                                                '${row['armada_end_date']}'
                                                        .trim()
                                                        .isEmpty
                                                    ? null
                                                    : _toDbDate(
                                                        '${row['armada_end_date']}',
                                                      ),
                                            'tonase': _toNum(row['tonase']),
                                            'harga': _toNum(row['harga']),
                                          };
                                        }).toList();
                                        final driverNames = detailsPayload
                                            .map(
                                              (row) =>
                                                  '${row['nama_supir'] ?? ''}'
                                                      .trim(),
                                            )
                                            .where((value) => value.isNotEmpty)
                                            .expand(
                                              (value) => value
                                                  .split(RegExp(r'[,;/]'))
                                                  .map((part) => part.trim()),
                                            )
                                            .where((value) => value.isNotEmpty)
                                            .toSet()
                                            .join(', ');

                                        setDialogState(() => saving = true);
                                        try {
                                          final originalDate =
                                              Formatters.parseDate(
                                            item['tanggal'],
                                          );
                                          DateTime? resolveEditedIssueDate() {
                                            for (final row in detailsPayload) {
                                              final parsed =
                                                  Formatters.parseDate(
                                                row['armada_start_date'],
                                              );
                                              if (parsed != null) return parsed;
                                            }
                                            final primary =
                                                Formatters.parseDate(
                                              item['armada_start_date'],
                                            );
                                            if (primary != null) return primary;
                                            return originalDate;
                                          }

                                          final effectiveDate =
                                              resolveEditedIssueDate() ??
                                                  originalDate ??
                                                  DateTime.now();

                                          await widget.repository.updateInvoice(
                                            id: '${item['id']}',
                                            customerName: customer.text.trim(),
                                            date: _toDbDate(effectiveDate),
                                            status: status,
                                            totalBiaya: subtotal,
                                            pph: pph,
                                            totalBayar: totalBayar,
                                            email: email.text,
                                            noTelp: phone.text,
                                            kopDate: kopDate.text.trim().isEmpty
                                                ? null
                                                : _toDbDate(kopDate.text),
                                            kopLocation:
                                                kopLocation.text.trim(),
                                            dueDate: dueDate.text.trim().isEmpty
                                                ? null
                                                : _toDbDate(dueDate.text),
                                            pickup: '${first['lokasi_muat']}',
                                            destination:
                                                '${first['lokasi_bongkar']}',
                                            muatan: normalizeNullable(
                                              first['muatan'],
                                            ),
                                            armadaId:
                                                firstResolvedArmadaId.isEmpty
                                                    ? null
                                                    : firstResolvedArmadaId,
                                            armadaStartDate:
                                                '${first['armada_start_date']}'
                                                        .trim()
                                                        .isEmpty
                                                    ? null
                                                    : _toDbDate(
                                                        '${first['armada_start_date']}',
                                                      ),
                                            armadaEndDate:
                                                '${first['armada_end_date']}'
                                                        .trim()
                                                        .isEmpty
                                                    ? null
                                                    : _toDbDate(
                                                        '${first['armada_end_date']}',
                                                      ),
                                            tonase: _toNum(first['tonase']),
                                            harga: _toNum(first['harga']),
                                            namaSupir: driverNames.isEmpty
                                                ? null
                                                : driverNames,
                                            noInvoice: null,
                                            details: detailsPayload,
                                            acceptedBy: acceptedBy,
                                            generateAutoSangu:
                                                !widget.session.isPengurus,
                                            clearApprovedPengurusEditRequest:
                                                widget.session.isPengurus,
                                          );
                                          if (!mounted || !context.mounted) {
                                            return;
                                          }
                                          dialogClosed = true;
                                          Navigator.of(context).pop();
                                          _snack(_t(
                                              'Invoice berhasil diperbarui.',
                                              'Invoice updated successfully.'));
                                          await _refresh();
                                          _notifyDataChanged();
                                        } catch (e) {
                                          if (!mounted) return;
                                          _snack(
                                            e.toString().replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                ),
                                            error: true,
                                          );
                                        } finally {
                                          if (mounted && !dialogClosed) {
                                            setDialogState(
                                                () => saving = false);
                                          }
                                        }
                                      },
                                child: Text(
                                  saving
                                      ? _t('Menyimpan...', 'Saving...')
                                      : _t('Simpan', 'Save'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      customer.dispose();
      email.dispose();
      phone.dispose();
      kopDate.dispose();
      kopLocation.dispose();
      dueDate.dispose();
    }
  }

  Future<void> _openExpenseEdit(Map<String, dynamic> item) async {
    String status = '${item['status'] ?? 'Unpaid'}';
    const statusOptions = <String>['Unpaid', 'Paid', 'Waiting', 'Cancelled'];
    if (!statusOptions
        .any((option) => option.toLowerCase() == status.toLowerCase())) {
      status = 'Unpaid';
    }
    String recordedBy = '${item['dicatat_oleh'] ?? 'Admin'}';
    String tanggal = _toInputDate(item['tanggal']);
    bool saving = false;
    bool dialogClosed = false;

    final noExpense =
        TextEditingController(text: '${item['no_expense'] ?? ''}');
    final existingDetails = _toDetailList(item['rincian']);
    final details = existingDetails.isNotEmpty
        ? existingDetails
            .map(
              (row) => <String, dynamic>{
                'nama': '${row['nama'] ?? row['name'] ?? ''}',
                'jumlah': _formatEditableNumber(row['jumlah'] ?? row['amount']),
              },
            )
            .toList()
        : <Map<String, dynamic>>[
            {
              'nama': '${item['kategori'] ?? ''}',
              'jumlah': _formatEditableNumber(item['total_pengeluaran']),
            },
          ];

    double expenseTotal() {
      return details.fold<double>(0, (sum, row) => sum + _toNum(row['jumlah']));
    }

    try {
      await showDialog<void>(
        context: context,
        barrierColor: AppColors.popupOverlay,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final totalAmount = expenseTotal();
              return AlertDialog(
                title: Text(_t('Edit Expense', 'Edit Expense')),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogField(
                          noExpense,
                          _t('Nomor Expense', 'Expense Number'),
                          readOnly: true,
                        ),
                        const SizedBox(height: 8),
                        _dateSelect(
                          label: _t('Tanggal Expense', 'Expense Date'),
                          value: tanggal,
                          onChanged: (v) => setDialogState(() => tanggal = v),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _t('Rincian Pengeluaran', 'Expense Details'),
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        ...details.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          return Container(
                            margin: EdgeInsets.only(
                              bottom: index == details.length - 1 ? 0 : 10,
                            ),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.cardBorder(context),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                TextFormField(
                                  initialValue: '${row['nama']}',
                                  decoration: InputDecoration(
                                    hintText:
                                        _t('Nama Pengeluaran', 'Expense Name'),
                                  ),
                                  onChanged: (value) => row['nama'] = value,
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: '${row['jumlah']}',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _t('Jumlah', 'Amount'),
                                  ),
                                  onChanged: (value) {
                                    row['jumlah'] = value;
                                    setDialogState(() {});
                                  },
                                ),
                                if (details.length > 1) ...[
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => setDialogState(
                                        () => details.removeAt(index),
                                      ),
                                      style: CvantButtonStyles.text(
                                        context,
                                        color: AppColors.danger,
                                      ),
                                      child: Text(_t('Hapus', 'Delete')),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => setDialogState(() {
                            details.add(<String, dynamic>{
                              'nama': '',
                              'jumlah': '',
                            });
                          }),
                          child: Text(_t('+ Tambah Rincian', '+ Add Detail')),
                        ),
                        const SizedBox(height: 10),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: _t('Total Pengeluaran', 'Total Expense'),
                          ),
                          child: Text(Formatters.rupiah(totalAmount)),
                        ),
                        const SizedBox(height: 8),
                        CvantDropdownField<String>(
                          initialValue: status,
                          decoration: InputDecoration(
                            labelText: _t('Status', 'Status'),
                          ),
                          items:
                              const ['Unpaid', 'Paid', 'Waiting', 'Cancelled']
                                  .map(
                                    (item) => DropdownMenuItem<String>(
                                      value: item,
                                      child: Text(item),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) => setDialogState(
                            () => status = value ?? status,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CvantDropdownField<String>(
                          initialValue: recordedBy,
                          decoration: InputDecoration(
                            labelText: _t('Dicatat Oleh', 'Recorded By'),
                          ),
                          items: (widget.session.isPengurus
                                  ? const ['Pengurus']
                                  : const ['Admin', 'Owner'])
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setDialogState(
                            () => recordedBy = value ?? recordedBy,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: saving
                                    ? null
                                    : () {
                                        dialogClosed = true;
                                        Navigator.of(context).pop();
                                      },
                                style: CvantButtonStyles.outlined(
                                  context,
                                  color: AppColors.isLight(context)
                                      ? AppColors.textSecondaryLight
                                      : const Color(0xFFE2E8F0),
                                  borderColor: AppColors.neutralOutline,
                                ),
                                child: Text(_t('Batal', 'Cancel')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        final hasName = details.any(
                                          (row) => '${row['nama']}'
                                              .trim()
                                              .isNotEmpty,
                                        );
                                        if (!hasName ||
                                            totalAmount <= 0 ||
                                            tanggal.trim().isEmpty) {
                                          _snack(
                                            _t(
                                              'Tanggal dan rincian pengeluaran wajib diisi.',
                                              'Date and expense details are required.',
                                            ),
                                            error: true,
                                          );
                                          return;
                                        }

                                        final detailsPayload = details
                                            .map(
                                              (row) => <String, dynamic>{
                                                'nama': '${row['nama']}'.trim(),
                                                'jumlah': _toNum(row['jumlah']),
                                              },
                                            )
                                            .toList();

                                        final note = detailsPayload
                                            .where((row) => '${row['nama']}'
                                                .trim()
                                                .isNotEmpty)
                                            .map(
                                              (row) =>
                                                  '${row['nama']}: ${Formatters.rupiah(_toNum(row['jumlah']))}',
                                            )
                                            .join(', ');

                                        final firstNamedRow =
                                            detailsPayload.firstWhere(
                                          (row) => '${row['nama']}'
                                              .trim()
                                              .isNotEmpty,
                                          orElse: () => detailsPayload.first,
                                        );

                                        setDialogState(() => saving = true);
                                        try {
                                          String? regeneratedNoExpense;
                                          final editedDate =
                                              Formatters.parseDate(tanggal);
                                          final originalDate =
                                              Formatters.parseDate(
                                            item['tanggal'],
                                          );
                                          final monthChanged =
                                              editedDate != null &&
                                                  originalDate != null &&
                                                  (editedDate.year !=
                                                          originalDate.year ||
                                                      editedDate.month !=
                                                          originalDate.month);
                                          final currentNoExpense =
                                              '${item['no_expense'] ?? ''}'
                                                  .trim();
                                          final isNewExpensePattern = RegExp(
                                            r'^EXP-\d{2}-\d{4}-\d{4}$',
                                            caseSensitive: false,
                                          ).hasMatch(currentNoExpense);
                                          if (monthChanged ||
                                              !isNewExpensePattern) {
                                            final regeneratedDate =
                                                editedDate ??
                                                    Formatters.parseDate(
                                                        tanggal) ??
                                                    DateTime.now();
                                            regeneratedNoExpense = await widget
                                                .repository
                                                .generateExpenseNumberForDate(
                                              regeneratedDate,
                                              excludeExpenseId:
                                                  '${item['id'] ?? ''}',
                                            );
                                            noExpense.text =
                                                regeneratedNoExpense;
                                          }

                                          await widget.repository.updateExpense(
                                            id: '${item['id']}',
                                            date: _toDbDate(tanggal),
                                            status: status,
                                            total: totalAmount,
                                            noExpense: regeneratedNoExpense,
                                            kategori:
                                                '${firstNamedRow['nama']}',
                                            keterangan: note,
                                            note: note,
                                            recordedBy: recordedBy,
                                            details: detailsPayload,
                                          );
                                          if (!mounted || !context.mounted) {
                                            return;
                                          }
                                          dialogClosed = true;
                                          Navigator.of(context).pop();
                                          _snack(_t(
                                              'Expense berhasil diperbarui.',
                                              'Expense updated successfully.'));
                                          await _refresh();
                                          _notifyDataChanged();
                                        } catch (e) {
                                          if (!mounted) return;
                                          _snack(
                                            e.toString().replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                ),
                                            error: true,
                                          );
                                        } finally {
                                          if (mounted && !dialogClosed) {
                                            setDialogState(
                                                () => saving = false);
                                          }
                                        }
                                      },
                                child: Text(
                                  saving
                                      ? _t('Menyimpan...', 'Saving...')
                                      : _t('Simpan', 'Save'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      noExpense.dispose();
    }
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    TextInputType? type,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _buildEditInvoiceModeTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: selected ? AppColors.sidebarActiveGradient : null,
          color: selected ? null : AppColors.controlBackground(context),
          border: Border.all(
            color:
                selected ? Colors.transparent : AppColors.cardBorder(context),
          ),
          boxShadow: selected ? AppColors.sidebarActiveShadow : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color:
                  selected ? Colors.white : AppColors.textPrimaryFor(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateSelect({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final initial = Formatters.parseDate(value) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          initialDate: initial,
        );
        if (picked == null) return;
        onChanged(_toInputDate(picked));
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value.isEmpty ? '-' : Formatters.dmy(value)),
      ),
    );
  }

  List<Map<String, dynamic>> _toDetailList(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((item) {
        final row = Map<String, dynamic>.from(item);
        _normalizeDetailPlateFields(row);
        return row;
      }).toList();
    }
    return const <Map<String, dynamic>>[];
  }

  String _toInputDate(dynamic value) {
    final date = Formatters.parseDate(value);
    if (date == null) return '';
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd-$mm-${date.year}';
  }

  String _toDbDate(dynamic value) {
    final date = Formatters.parseDate(value);
    if (date == null) return '';
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  String _formatEditableNumber(dynamic value) {
    final number = _toNum(value);
    if (number == 0) return '';
    return number.floor().toString();
  }

  void _snack(String msg, {bool error = false}) {
    showCvantPopup(
      context: context,
      type: error ? CvantPopupType.error : CvantPopupType.success,
      title: error ? _t('Error', 'Error') : _t('Success', 'Success'),
      message: msg,
    );
  }

  List<Map<String, dynamic>> _buildCombinedRows(
    List<Map<String, dynamic>> incomes,
    List<Map<String, dynamic>> expenses,
  ) {
    String normalizeToken(dynamic value) {
      return (value ?? '')
          .toString()
          .toUpperCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    String resolveRoute(Map<String, dynamic> source) {
      final details = _toDetailList(source['rincian']);
      String build(dynamic muatValue, dynamic bongkarValue) {
        final muat = '${muatValue ?? ''}'.trim();
        final bongkar = '${bongkarValue ?? ''}'.trim();
        if (muat.isEmpty && bongkar.isEmpty) return '-';
        return '${muat.isEmpty ? '-' : muat}-${bongkar.isEmpty ? '-' : bongkar}';
      }

      for (final row in details) {
        final route = build(row['lokasi_muat'], row['lokasi_bongkar']);
        if (route != '-') return route;
      }
      return build(source['lokasi_muat'], source['lokasi_bongkar']);
    }

    dynamic resolveIncomeDisplayDate(Map<String, dynamic> source) {
      final details = _toDetailList(source['rincian']);
      for (final row in details) {
        final raw = row['armada_start_date'];
        if (Formatters.parseDate(raw) != null) return raw;
      }
      if (Formatters.parseDate(source['armada_start_date']) != null) {
        return source['armada_start_date'];
      }
      return source['tanggal_kop'] ?? source['tanggal'] ?? source['created_at'];
    }

    Map<String, String> buildIncomeSearchFields(Map<String, dynamic> source) {
      final details = _toDetailList(source['rincian']);
      final dates = <String>{};
      final plates = <String>{};
      final routes = <String>{};

      void absorb(Map<String, dynamic> row) {
        final rawDate = row['armada_start_date'] ??
            source['armada_start_date'] ??
            source['tanggal_kop'] ??
            source['tanggal'] ??
            source['created_at'];
        final parsedDate = Formatters.parseDate(rawDate);
        if (parsedDate != null) {
          final mm = parsedDate.month.toString().padLeft(2, '0');
          final dd = parsedDate.day.toString().padLeft(2, '0');
          dates.add('${parsedDate.year}-$mm-$dd');
          dates.add(Formatters.dmy(parsedDate));
        }

        final directPlate = '${row['plat_nomor'] ?? row['no_polisi'] ?? ''}'
            .toUpperCase()
            .trim();
        if (directPlate.isNotEmpty && directPlate != '-') {
          plates.add(directPlate);
        } else {
          final fromManual = '${row['armada_manual'] ?? ''}'.trim();
          if (fromManual.isNotEmpty) {
            final parsed = _extractPlateFromText(fromManual);
            if (parsed != null) plates.add(parsed);
          }
          final fromLabel =
              '${row['armada_label'] ?? row['armada'] ?? ''}'.trim();
          final parsedLabel = _extractPlateFromText(fromLabel);
          if (parsedLabel != null) plates.add(parsedLabel);
        }

        final muat =
            '${row['lokasi_muat'] ?? source['lokasi_muat'] ?? ''}'.trim();
        final bongkar =
            '${row['lokasi_bongkar'] ?? source['lokasi_bongkar'] ?? ''}'.trim();
        if (muat.isNotEmpty || bongkar.isNotEmpty) {
          routes.add(
            '${muat.isEmpty ? '-' : muat}-${bongkar.isEmpty ? '-' : bongkar}',
          );
        }
      }

      if (details.isNotEmpty) {
        for (final row in details) {
          absorb(row);
        }
      } else {
        absorb(source);
      }

      return {
        'dates': dates.join(' | '),
        'plates': plates.join(' | '),
        'routes': routes.join(' | '),
      };
    }

    bool isAutoSanguExpense(Map<String, dynamic> expense) {
      final note = '${expense['note'] ?? ''}'.trim().toUpperCase();
      if (note.startsWith('AUTO_SANGU:')) return true;
      final ket = '${expense['keterangan'] ?? ''}'.trim().toLowerCase();
      return ket.startsWith('auto sangu sopir -');
    }

    bool incomeUsesManualArmada(Map<String, dynamic>? income) {
      if (income == null) return false;
      final details = _toDetailList(income['rincian']);
      if (details.isNotEmpty) {
        return details
            .any((row) => '${row['armada_manual'] ?? ''}'.trim().isNotEmpty);
      }
      return false;
    }

    ({String muat, String bongkar, String driver}) extractRouteDriverFromDetail(
      Map<String, dynamic> detail, {
      Map<String, dynamic>? fallbackIncomeDetail,
    }) {
      String firstDriverPart(String value) {
        for (final part in value.split(RegExp(r'[,;/]'))) {
          final normalized = part.trim();
          final lowered = normalized.toLowerCase();
          if (normalized.isNotEmpty &&
              lowered != 'null' &&
              lowered != 'undefined' &&
              lowered != '-') {
            return normalized;
          }
        }
        return '';
      }

      String muat = '${detail['lokasi_muat'] ?? ''}'.trim();
      String bongkar = '${detail['lokasi_bongkar'] ?? ''}'.trim();
      if (muat.isEmpty || bongkar.isEmpty) {
        final rawName = '${detail['nama'] ?? detail['name'] ?? ''}'.trim();
        final routeRaw = RegExp(r'\(([^()]*)\)').firstMatch(rawName)?.group(1);
        if (routeRaw != null && routeRaw.trim().isNotEmpty) {
          final parts = routeRaw.split('-');
          if (parts.isNotEmpty && muat.isEmpty) {
            muat = parts.first.trim();
          }
          if (parts.length >= 2 && bongkar.isEmpty) {
            bongkar = parts.sublist(1).join('-').trim();
          }
        }
      }

      final detailDriver = '${detail['nama_supir'] ?? detail['supir'] ?? ''}';
      final fallbackDriver = fallbackIncomeDetail == null
          ? ''
          : '${fallbackIncomeDetail['nama_supir'] ?? fallbackIncomeDetail['supir'] ?? ''}';
      final driver = detailDriver.trim().isNotEmpty
          ? firstDriverPart(detailDriver.trim())
          : firstDriverPart(fallbackDriver.trim());
      return (muat: muat, bongkar: bongkar, driver: driver);
    }

    String buildAutoSanguRouteLabel(
      Map<String, dynamic> expense,
      Map<String, dynamic>? linkedIncome,
    ) {
      final expenseDetails = _toDetailList(expense['rincian']);
      final incomeDetails = linkedIncome == null
          ? const <Map<String, dynamic>>[]
          : _toDetailList(linkedIncome['rincian']);
      final entries = <String>[];
      final seen = <String>{};

      void pushEntry({
        required String muat,
        required String bongkar,
        required String driver,
      }) {
        if (muat.isEmpty && bongkar.isEmpty) return;
        final label =
            '${muat.isEmpty ? '-' : muat}-${bongkar.isEmpty ? '-' : bongkar}';
        final key = label.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
        if (seen.add(key)) entries.add(label);
      }

      if (expenseDetails.isNotEmpty) {
        for (var i = 0; i < expenseDetails.length; i++) {
          final fallback = i < incomeDetails.length ? incomeDetails[i] : null;
          final route = extractRouteDriverFromDetail(
            expenseDetails[i],
            fallbackIncomeDetail: fallback,
          );
          pushEntry(
            muat: route.muat,
            bongkar: route.bongkar,
            driver: route.driver,
          );
        }
      }

      if (entries.isEmpty && incomeDetails.isNotEmpty) {
        for (final row in incomeDetails) {
          final route = extractRouteDriverFromDetail(
            row,
            fallbackIncomeDetail: row,
          );
          pushEntry(
            muat: route.muat,
            bongkar: route.bongkar,
            driver: route.driver,
          );
        }
      }

      if (entries.isEmpty && linkedIncome != null) {
        final fallbackRoute = extractRouteDriverFromDetail(
          linkedIncome,
          fallbackIncomeDetail: linkedIncome,
        );
        pushEntry(
          muat: fallbackRoute.muat,
          bongkar: fallbackRoute.bongkar,
          driver: fallbackRoute.driver,
        );
      }

      if (entries.isEmpty) {
        return '${expense['keterangan'] ?? expense['kategori'] ?? '-'}';
      }
      return entries.join(' | ');
    }

    String buildAutoSanguDriverLabel(
      Map<String, dynamic> expense,
      Map<String, dynamic>? linkedIncome,
    ) {
      final expenseDetails = _toDetailList(expense['rincian']);
      final incomeDetails = linkedIncome == null
          ? const <Map<String, dynamic>>[]
          : _toDetailList(linkedIncome['rincian']);
      final drivers = <String>[];
      final seen = <String>{};

      void pushDriver(String value) {
        final normalized = value.trim();
        if (normalized.isEmpty) return;
        final key = normalized.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        if (seen.add(key)) drivers.add(normalized);
      }

      if (expenseDetails.isNotEmpty) {
        for (var i = 0; i < expenseDetails.length; i++) {
          final fallback = i < incomeDetails.length ? incomeDetails[i] : null;
          final route = extractRouteDriverFromDetail(
            expenseDetails[i],
            fallbackIncomeDetail: fallback,
          );
          pushDriver(route.driver);
        }
      }

      if (drivers.isEmpty && incomeDetails.isNotEmpty) {
        for (final row in incomeDetails) {
          final route = extractRouteDriverFromDetail(
            row,
            fallbackIncomeDetail: row,
          );
          pushDriver(route.driver);
        }
      }

      if (drivers.isEmpty && linkedIncome != null) {
        final fallbackRoute = extractRouteDriverFromDetail(
          linkedIncome,
          fallbackIncomeDetail: linkedIncome,
        );
        pushDriver(fallbackRoute.driver);
      }

      if (drivers.isEmpty) return '-';
      return drivers.join(' | ');
    }

    final incomeRows = incomes.map((item) {
      final invoiceNumber = Formatters.invoiceNumber(
        item['no_invoice'],
        item['tanggal_kop'] ?? item['tanggal'] ?? item['created_at'],
        customerName: item['nama_pelanggan'],
      );
      final customerName = '${item['nama_pelanggan'] ?? ''}'.trim();
      final isCompanyInvoice = _resolveIsCompanyInvoice(
        invoiceNumber: item['no_invoice'],
        customerName: customerName,
      );
      final subtotal = _toNum(item['total_biaya']);
      final pph = _toNum(item['pph']);
      final totalBayar = _toNum(item['total_bayar']);
      final effectiveTotal = isCompanyInvoice
          ? (totalBayar > 0 ? totalBayar : max(0.0, subtotal - pph))
          : subtotal;
      final searchFields = buildIncomeSearchFields(item);
      return {
        ...item,
        '__type': 'Income',
        '__number': invoiceNumber,
        '__name': item['nama_pelanggan'],
        '__total': effectiveTotal,
        '__date': resolveIncomeDisplayDate(item),
        '__status': item['status'],
        '__recorded_by': item['diterima_oleh'] ?? '-',
        '__route': resolveRoute(item),
        '__armada_start_dates': searchFields['dates'],
        '__armada_plates': searchFields['plates'],
        '__armada_routes': searchFields['routes'],
      };
    }).toList();

    incomeRows.sort((a, b) {
      final aDate = Formatters.parseDate(a['__date']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = Formatters.parseDate(b['__date']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    final incomeById = <String, Map<String, dynamic>>{};
    final incomeIdByInvoiceToken = <String, String>{};
    for (final income in incomeRows) {
      final id = '${income['id'] ?? ''}'.trim();
      if (id.isEmpty) continue;
      incomeById[normalizeToken(id)] = income;
      final rawInvoice = normalizeToken(income['no_invoice']);
      final formattedInvoice = normalizeToken(income['__number']);
      if (rawInvoice.isNotEmpty) {
        incomeIdByInvoiceToken[rawInvoice] = id;
      }
      if (formattedInvoice.isNotEmpty) {
        incomeIdByInvoiceToken[formattedInvoice] = id;
      }
    }

    final expenseByIncomeId = <String, List<Map<String, dynamic>>>{};
    for (final item in expenses) {
      var marker = '';
      final autoSangu = isAutoSanguExpense(item);
      final note = '${item['note'] ?? ''}'.trim();
      if (note.toUpperCase().startsWith('AUTO_SANGU:')) {
        marker = note.substring('AUTO_SANGU:'.length).trim();
      }
      if (marker.isEmpty) {
        final ket = '${item['keterangan'] ?? ''}'.trim();
        final lowerKet = ket.toLowerCase();
        const prefix = 'auto sangu sopir -';
        if (lowerKet.startsWith(prefix)) {
          marker = ket.substring(prefix.length).trim();
        }
      }

      final markerKey = normalizeToken(marker);
      if (markerKey.isEmpty) continue;

      String? linkedIncomeId;
      final incomeByMarkerId = incomeById[markerKey];
      if (incomeByMarkerId != null) {
        linkedIncomeId = '${incomeByMarkerId['id'] ?? ''}'.trim();
      } else {
        linkedIncomeId = incomeIdByInvoiceToken[markerKey];
      }
      if (linkedIncomeId == null || linkedIncomeId.isEmpty) continue;
      final linkedIncome = incomeById[normalizeToken(linkedIncomeId)];
      if (autoSangu && incomeUsesManualArmada(linkedIncome)) {
        continue;
      }
      final autoRouteLabel =
          autoSangu ? buildAutoSanguRouteLabel(item, linkedIncome) : '';
      final autoDriverLabel =
          autoSangu ? buildAutoSanguDriverLabel(item, linkedIncome) : '';

      final mapped = <String, dynamic>{
        ...item,
        '__type': 'Expense',
        '__number': item['no_expense'],
        '__name': autoSangu
            ? autoDriverLabel
            : (item['kategori'] ?? item['keterangan'] ?? '-'),
        '__total': item['total_pengeluaran'],
        '__date': item['tanggal'] ?? item['created_at'],
        '__status': item['status'],
        '__recorded_by': item['dicatat_oleh'] ?? '-',
        '__route': autoSangu
            ? autoRouteLabel
            : (item['keterangan'] ?? item['kategori'] ?? '-'),
        '__is_auto_sangu': autoSangu,
      };
      expenseByIncomeId
          .putIfAbsent(linkedIncomeId, () => <Map<String, dynamic>>[])
          .add(mapped);
    }

    for (final rows in expenseByIncomeId.values) {
      rows.sort((a, b) {
        final aDate = Formatters.parseDate(a['__date']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = Formatters.parseDate(b['__date']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    }

    final rows = <Map<String, dynamic>>[];
    for (final income in incomeRows) {
      rows.add(income);
      final id = '${income['id'] ?? ''}'.trim();
      final children = expenseByIncomeId[id];
      if (children != null && children.isNotEmpty) {
        rows.addAll(children);
      }
    }
    return rows;
  }

  List<Map<String, dynamic>> _applyFilterAndLimit(
      List<Map<String, dynamic>> rows) {
    final q = _search.text.trim().toLowerCase();
    final now = DateTime.now();
    final oneMonthBack = now.subtract(const Duration(days: 30));
    final filtered = rows.where((item) {
      final date = Formatters.parseDate(
        item['__date'] ??
            item['tanggal_kop'] ??
            item['tanggal'] ??
            item['created_at'],
      );
      if (date == null) return false;
      if (date.isBefore(oneMonthBack) || date.isAfter(now)) return false;
      return _matchesKeywordInAnyColumn(item, q);
    }).toList();

    if (_limit == 'all') {
      return filtered;
    }
    final maxRows = int.tryParse(_limit) ?? 10;
    if (filtered.length <= maxRows) return filtered;
    return filtered.take(maxRows).toList();
  }

  Widget _buildCombinedList(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return _SimplePlaceholderView(
        title: _t('Data invoice kosong', 'No invoice data'),
        message: _t(
          'Belum ada data income atau expense.',
          'No income or expense data yet.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(runBackfill: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(10),
        itemCount: rows.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == rows.length) {
            return const _DashboardContentFooter();
          }
          final item = rows[index];
          final isIncome = '${item['__type']}' == 'Income';
          final isEn = LanguageController.language.value == AppLanguage.en;
          final isCompanyInvoice = isIncome
              ? _resolveIsCompanyInvoice(
                  invoiceNumber: item['no_invoice'] ?? item['__number'],
                  customerName: item['__name'],
                )
              : false;
          final invoiceTypeLabel = isCompanyInvoice
              ? (isEn ? 'Company' : 'Perusahaan')
              : (isEn ? 'Personal' : 'Pribadi');
          final invoiceTypeColor =
              isCompanyInvoice ? AppColors.success : AppColors.blue;
          final approvalStatus = _resolvePengurusApprovalStatus(item);
          final editRequestStatus =
              '${item['edit_request_status'] ?? 'none'}'.trim().toLowerCase();
          final canOpenPengurusEdit = isIncome &&
              _isPengurus &&
              editRequestStatus == 'approved' &&
              approvalStatus == 'approved';
          final canRequestPengurusEdit = isIncome &&
              _isPengurus &&
              editRequestStatus != 'approved' &&
              approvalStatus == 'approved';
          final total = _toNum(item['__total']);
          return _PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item['__type']} • ${Formatters.dmy(item['__date'])}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isIncome ? AppColors.blue : AppColors.danger,
                        ),
                      ),
                    ),
                    _StatusPill(label: '${item['__status'] ?? '-'}'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['__is_auto_sangu'] == true ? _t('Nama Sopir', 'Driver') : _t('Nama', 'Name')}: ${item['__name'] ?? '-'}',
                  style: TextStyle(color: AppColors.textMutedFor(context)),
                ),
                const SizedBox(height: 2),
                if (() {
                  final routeLabel = '${item['__route'] ?? '-'}'.trim();
                  final nameLabel = '${item['__name'] ?? ''}'.trim();
                  if (routeLabel.isEmpty || routeLabel == '-') return false;
                  return routeLabel.toLowerCase() != nameLabel.toLowerCase();
                }()) ...[
                  Text(
                    '${item['__route'] ?? '-'}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 6),
                ] else
                  const SizedBox(height: 6),
                if (_isPengurus && isIncome) ...[
                  Text(
                    () {
                      if (editRequestStatus == 'pending') {
                        return _t(
                          'Request edit: menunggu ACC admin/owner',
                          'Edit request: waiting for admin/owner approval',
                        );
                      }
                      if (editRequestStatus == 'approved') {
                        return _t(
                          'Request edit disetujui. Income bisa direvisi.',
                          'Edit request approved. The income can now be revised.',
                        );
                      }
                      if (approvalStatus == 'pending') {
                        return _t(
                          'Menunggu persetujuan dari admin/owner.',
                          'Waiting for admin/owner approval.',
                        );
                      }
                      if (approvalStatus == 'rejected') {
                        return _t(
                          'Income telah ditolak oleh admin/owner.',
                          'Income has been rejected by admin/owner.',
                        );
                      }
                      return _t(
                        'Income telah disetujui oleh admin/owner.',
                        'Income has been approved by admin/owner.',
                      );
                    }(),
                    style: TextStyle(
                      color: editRequestStatus == 'approved'
                          ? AppColors.success
                          : (approvalStatus == 'rejected'
                              ? AppColors.danger
                              : AppColors.textMutedFor(context)),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  Formatters.rupiah(total),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isIncome)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            invoiceTypeLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: invoiceTypeColor,
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: isIncome && _isPengurus
                              ? (canOpenPengurusEdit
                                  ? () => _openInvoiceEdit(item)
                                  : (canRequestPengurusEdit
                                      ? () => _requestPengurusInvoiceEdit(item)
                                      : null))
                              : () {
                                  if (isIncome) {
                                    _openInvoiceEdit(item);
                                    return;
                                  }
                                  _openExpenseEdit(item);
                                },
                          style: _mobileActionButtonStyle(
                            context: context,
                            color: isIncome && _isPengurus
                                ? ((canOpenPengurusEdit ||
                                        canRequestPengurusEdit)
                                    ? AppColors.blue
                                    : AppColors.neutralOutline)
                                : AppColors.blue,
                          ),
                          child: Icon(
                            isIncome && _isPengurus
                                ? (canOpenPengurusEdit
                                    ? Icons.edit_outlined
                                    : Icons.how_to_reg_outlined)
                                : Icons.edit_outlined,
                            size: 18,
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => isIncome
                              ? _openInvoicePreview(item)
                              : _openExpensePreview(item),
                          style: _mobileActionButtonStyle(
                            context: context,
                            color: AppColors.warning,
                          ),
                          child:
                              const Icon(Icons.visibility_outlined, size: 18),
                        ),
                        if (isIncome && !_isPengurus)
                          OutlinedButton(
                            onPressed: () => _sendInvoice(item),
                            style: _mobileActionButtonStyle(
                              context: context,
                              color: const Color(0xFF2563EB),
                            ),
                            child: const Icon(Icons.send_outlined, size: 18),
                          ),
                        if (!(isIncome &&
                            _isPengurus &&
                            approvalStatus == 'approved'))
                          OutlinedButton(
                            onPressed: () => _confirmDelete(
                              id: '${item['id']}',
                              isIncome: isIncome,
                            ),
                            style: _mobileActionButtonStyle(
                              context: context,
                              color: AppColors.danger,
                            ),
                            child: const Icon(Icons.delete_outline, size: 18),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _ErrorView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() {
              _future = _load();
            }),
          );
        }

        final incomes =
            (snapshot.data![0] as List).cast<Map<String, dynamic>>();
        final expenses =
            (snapshot.data![1] as List).cast<Map<String, dynamic>>();
        final rows =
            _applyFilterAndLimit(_buildCombinedRows(incomes, expenses));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(
                children: [
                  Text(
                    _t('Tampil', 'Show'),
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 86,
                    child: CvantDropdownField<String>(
                      initialValue: _limit,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.zero,
                      ),
                      items: const [
                        '10',
                        '20',
                        '50',
                        '100',
                        '200',
                        '500',
                        '1000',
                        'all'
                      ]
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item == 'all' ? _t('Semua', 'All') : item,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _limit = value;
                          _future = _load();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: _t(
                          'Cari income atau expense...',
                          'Search income or expense...',
                        ),
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isPengurus)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () => _openReportSummary(
                            incomes: incomes,
                            expenses: expenses,
                          ),
                          style: CvantButtonStyles.outlined(
                            context,
                            color: AppColors.success,
                            borderColor: AppColors.success,
                          ).copyWith(
                            alignment: const Alignment(0, 0),
                          ),
                          child: Center(
                            child: Text(
                              _t('Cetak Laporan', 'Print Report'),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () => _openInvoicePrintSelector(
                            incomes: incomes,
                          ),
                          style: CvantButtonStyles.outlined(
                            context,
                            color: AppColors.warning,
                            borderColor: AppColors.warning,
                          ).copyWith(
                            alignment: const Alignment(0, 0),
                          ),
                          child: Center(
                            child: Text(
                              _t('Cetak Invoice', 'Print Invoice'),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildCombinedList(rows)),
          ],
        );
      },
    );
  }
}
