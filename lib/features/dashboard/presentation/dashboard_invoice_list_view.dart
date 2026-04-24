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
  static const _fixedInvoiceRemotePromotionDoneKey =
      'fixed_invoice_remote_promotion_done_v1';
  static const _invoiceListColumns =
      'id,no_invoice,invoice_entity,tanggal,tanggal_kop,lokasi_kop,nama_pelanggan,email,no_telp,due_date,'
      'lokasi_muat,lokasi_bongkar,armada_start_date,armada_end_date,'
      'tonase,harga,muatan,nama_supir,status,paid_at,total_bayar,total_biaya,pph,diterima_oleh,'
      'customer_id,armada_id,order_id,rincian,created_at,updated_at,created_by,'
      'submission_role,approval_status,approval_requested_at,approval_requested_by,'
      'approved_at,approved_by,rejected_at,rejected_by,edit_request_status,'
      'edit_requested_at,edit_requested_by,edit_resolved_at,edit_resolved_by';
  static const _expenseListColumns =
      'id,no_expense,tanggal,kategori,keterangan,total_pengeluaran,'
      'status,dicatat_oleh,note,rincian,created_at,updated_at,created_by';
  late Future<List<dynamic>> _future;
  final _search = TextEditingController();
  final Set<String> _locallyRemovedRowIds = <String>{};
  String _limit = '10';
  bool _backfillRunning = false;
  bool _backgroundFixedInvoiceSyncRunning = false;
  bool _backgroundAutoSanguCleanupRunning = false;
  bool _backgroundIncomePricingBackfillRunning = false;
  bool _backgroundInvoiceNumberNormalizationRunning = false;
  bool _manualArmadaAutoSanguCleanupDone = false;
  bool _incomePricingBackfillDone = false;

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
          unawaited(_runInvoiceListBackgroundMaintenanceAndReloadOnce());
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
          ? _loadFixedInvoiceIds()
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

  Future<void> _runInvoiceListBackgroundMaintenanceAndReloadOnce() async {
    final hasVisibleChanges = await _runInvoiceListBackgroundMaintenance();
    if (!mounted || !hasVisibleChanges) return;
    setState(() {
      _future = _load();
    });
    await _future;
    if (widget.session.isBackofficeUser) {
      unawaited(
          PushNotificationService.instance.refreshMonthlyFinanceReminder());
    }
  }

  Future<bool> _runInvoiceListBackgroundMaintenance() async {
    var hasVisibleChanges = false;
    hasVisibleChanges =
        await _syncFixedInvoiceCacheInBackground() || hasVisibleChanges;
    hasVisibleChanges =
        await _backfillIncomePricingInBackground() || hasVisibleChanges;
    hasVisibleChanges =
        await _cleanupManualArmadaAutoSanguInBackground() || hasVisibleChanges;
    hasVisibleChanges =
        await _normalizeInvoiceNumbersInBackground() || hasVisibleChanges;
    return hasVisibleChanges;
  }

  Future<bool> _backfillIncomePricingInBackground() async {
    if (_incomePricingBackfillDone || _backgroundIncomePricingBackfillRunning) {
      return false;
    }
    _backgroundIncomePricingBackfillRunning = true;
    try {
      final report = await widget.repository
          .backfillSpecialIncomePricingForExistingInvoices();
      _incomePricingBackfillDone = true;
      return report.hasChanges;
    } catch (_) {
      // Best effort: update pricing invoice lama tidak boleh menghambat page.
      return false;
    } finally {
      _backgroundIncomePricingBackfillRunning = false;
    }
  }

  Future<bool> _normalizeInvoiceNumbersInBackground() async {
    if (_backgroundInvoiceNumberNormalizationRunning) return false;
    _backgroundInvoiceNumberNormalizationRunning = true;
    try {
      final report = await widget.repository.normalizeLegacyInvoiceNumbers();
      if (report.updatedInvoices <= 0 && report.updatedFixedBatches <= 0) {
        return false;
      }
      final remoteBatches = await _loadRemoteFixedInvoiceBatches();
      if (remoteBatches.isNotEmpty) {
        await _syncLocalFixedInvoiceCache(remoteBatches);
      }
      return true;
    } catch (_) {
      // Best effort: migrasi nomor invoice lama tidak boleh menghambat page.
      return false;
    } finally {
      _backgroundInvoiceNumberNormalizationRunning = false;
    }
  }

  Future<bool> _syncFixedInvoiceCacheInBackground() async {
    if (_backgroundFixedInvoiceSyncRunning) return false;
    _backgroundFixedInvoiceSyncRunning = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final remotePromotionDone =
          prefs.getBool(_fixedInvoiceRemotePromotionDoneKey) ?? false;
      final localIds = await _loadLocalFixedInvoiceIds();
      final localBatches = await _loadLocalFixedInvoiceBatches();
      if (!remotePromotionDone && localBatches.isNotEmpty) {
        await Future.wait<void>(
          _dedupeFixedInvoiceBatches(localBatches)
              .map(_upsertRemoteFixedInvoiceBatch),
        );
        await prefs.setBool(_fixedInvoiceRemotePromotionDoneKey, true);
      }

      final remoteBatches = await _loadRemoteFixedInvoiceBatches();
      if (remoteBatches.isEmpty) return false;
      final canonicalBatches = _dedupeFixedInvoiceBatches(remoteBatches);

      final remoteIds = canonicalBatches
          .expand((batch) => batch.invoiceIds)
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      await _syncLocalFixedInvoiceCache(canonicalBatches);

      return !setEquals(localIds, remoteIds);
    } catch (_) {
      // Best effort: page list tetap cepat walau sync fix invoice gagal.
      return false;
    } finally {
      _backgroundFixedInvoiceSyncRunning = false;
    }
  }

  Future<bool> _cleanupManualArmadaAutoSanguInBackground() async {
    if (_manualArmadaAutoSanguCleanupDone ||
        _backgroundAutoSanguCleanupRunning) {
      return false;
    }
    _backgroundAutoSanguCleanupRunning = true;
    try {
      final report = await widget.repository
          .backfillAutoSanguExpensesForExistingInvoices();
      _manualArmadaAutoSanguCleanupDone = true;
      final hasVisibleChange = report.createdExpenses > 0 ||
          report.updatedExpenses > 0 ||
          report.deletedExpenses > 0;
      return hasVisibleChange;
    } catch (_) {
      // Best effort: page list tetap cepat walau cleanup auto sangu gagal.
      return false;
    } finally {
      _backgroundAutoSanguCleanupRunning = false;
    }
  }

  Future<void> _refresh({bool runBackfill = false}) async {
    if (_isAdminOrOwner && runBackfill && !_backfillRunning) {
      _backfillRunning = true;
      try {
        final pricingReport = await widget.repository
            .backfillSpecialIncomePricingForExistingInvoices();
        final report = await widget.repository
            .backfillAutoSanguExpensesForExistingInvoices();
        if (mounted && (pricingReport.hasFailures || report.hasFailures)) {
          _snack(
            _t(
              'Sebagian update pricing invoice lama atau auto expense sangu sopir belum berhasil disinkronkan. Coba refresh sekali lagi.',
              'Some legacy invoice pricing updates or driver allowance auto expenses could not be synced yet. Please refresh once more.',
            ),
            error: true,
          );
        }
        _incomePricingBackfillDone = true;
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
    if (widget.session.isBackofficeUser) {
      unawaited(
          PushNotificationService.instance.refreshMonthlyFinanceReminder());
    }
    if (_isAdminOrOwner && runBackfill) {
      unawaited(_runInvoiceListBackgroundMaintenanceAndReloadOnce());
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
    for (final batchId in _duplicateFixedInvoiceBatchIds(batches)) {
      try {
        await widget.repository.deleteFixedInvoiceBatch(batchId);
      } catch (_) {
        // Best effort: tampilan tetap tidak dobel karena hasil fetch didedupe.
      }
    }
    return _dedupeFixedInvoiceBatches(batches);
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
      status: batch.status,
      paidAt: batch.paidAt,
      paymentDetails:
          batch.paymentDetails.map((entry) => entry.toJson()).toList(),
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

  Future<List<_FixedInvoiceBatch>> _loadMergedFixedInvoiceBatches() async {
    final prefs = await SharedPreferences.getInstance();
    final remotePromotionDone =
        prefs.getBool(_fixedInvoiceRemotePromotionDoneKey) ?? false;
    final localIds = await _loadLocalFixedInvoiceIds();
    final localBatches = await _loadLocalFixedInvoiceBatches();
    final remoteBatches = await _loadRemoteFixedInvoiceBatches();
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
      final merged = _mergeFixedInvoiceBatchesWithLocalFallback(
        remoteBatches: remoteBatches,
        localBatches: promotedLocalBatches,
        includeLocalOnly: false,
      );
      await _syncLocalFixedInvoiceCache(merged);
      return merged;
    }
    final merged = _mergeFixedInvoiceBatchesWithLocalFallback(
      remoteBatches: remoteBatches,
      localBatches: promotedLocalBatches,
    );
    if (merged.isNotEmpty) {
      await Future.wait(merged.map(_upsertRemoteFixedInvoiceBatch));
      await prefs.setBool(_fixedInvoiceRemotePromotionDoneKey, true);
    }
    final refreshedRemote = await _loadRemoteFixedInvoiceBatches();
    final finalBatches = _mergeFixedInvoiceBatchesWithLocalFallback(
      remoteBatches: refreshedRemote,
      localBatches: merged,
      includeLocalOnly: false,
    );
    await _syncLocalFixedInvoiceCache(finalBatches);
    return finalBatches;
  }

  Future<Set<String>> _loadFixedInvoiceIds() async {
    final batches = await _loadMergedFixedInvoiceBatches();
    return batches
        .expand((batch) => batch.invoiceIds)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
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
    return _loadMergedFixedInvoiceBatches();
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
    return 'fixed_$seed';
  }

  Future<_FixedInvoiceBatch?> _buildFixedInvoiceBatchFromInvoiceIds(
    Set<String> invoiceIds, {
    _FixedInvoiceBatch? preferredBatch,
  }) async {
    if (preferredBatch != null) return preferredBatch;
    if (invoiceIds.isEmpty) return null;
    final sourceInvoices =
        await widget.repository.fetchInvoicesByIds(invoiceIds);
    final generatedBatches = _buildLegacyFixedInvoiceBatchesFromInvoices(
      invoices: sourceInvoices,
      fixedIds: invoiceIds,
    );
    if (generatedBatches.isNotEmpty) {
      final nowIso = DateTime.now().toIso8601String();
      return generatedBatches.first.copyWith(
        batchId: _buildFixedInvoiceBatchId(invoiceIds),
        createdAt: nowIso,
        updatedAt: nowIso,
      );
    }
    final nowIso = DateTime.now().toIso8601String();
    return _FixedInvoiceBatch(
      batchId: _buildFixedInvoiceBatchId(invoiceIds),
      invoiceIds: invoiceIds.toList(growable: false),
      invoiceNumber: '',
      customerName: '',
      createdAt: nowIso,
      updatedAt: nowIso,
    );
  }

  Future<void> _markInvoicesAsFixed(
    Iterable<String> invoiceIds, {
    _FixedInvoiceBatch? batch,
  }) async {
    final cleaned =
        invoiceIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (cleaned.isEmpty) return;
    final effectiveBatch = await _buildFixedInvoiceBatchFromInvoiceIds(
      cleaned,
      preferredBatch: batch,
    );
    final existing = await _loadFixedInvoiceIds();
    existing.addAll(cleaned);
    await _saveFixedInvoiceIds(existing);
    if (effectiveBatch == null) return;
    final batches = await _loadLocalFixedInvoiceBatches();
    final overlappingBatchIds = batches
        .where(
          (existingBatch) =>
              existingBatch.batchId != effectiveBatch.batchId &&
              existingBatch.invoiceIds.any(cleaned.contains),
        )
        .map((existingBatch) => existingBatch.batchId)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    batches.removeWhere(
      (existingBatch) =>
          existingBatch.batchId == effectiveBatch.batchId ||
          existingBatch.invoiceIds.any(cleaned.contains),
    );
    batches.add(effectiveBatch);
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
    await _upsertRemoteFixedInvoiceBatch(effectiveBatch);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fixedInvoiceRemotePromotionDoneKey, true);
    final remoteBatches = await _loadRemoteFixedInvoiceBatches();
    final merged = _mergeFixedInvoiceBatchesWithLocalFallback(
      remoteBatches: remoteBatches,
      localBatches: batches,
      includeLocalOnly: false,
    );
    await _syncLocalFixedInvoiceCache(merged);
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
    List<Map<String, dynamic>> cloneMapRows(Iterable<dynamic> rows) {
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }

    final fixedIds = _isAdminOrOwner
        ? await _loadFixedInvoiceIds()
        : await _loadLocalFixedInvoiceIds();

    final allPrintableIncomes = await (() async {
      try {
        return cloneMapRows(await widget.repository.fetchInvoices());
      } catch (_) {
        try {
          final fetched = await widget.repository.fetchInvoicesSinceWithScope(
            DateTime(2000, 1, 1),
            columns: _invoiceListColumns,
            createdBy: _isPengurus ? _currentUserId : null,
          );
          return cloneMapRows(fetched as List);
        } catch (_) {
          return incomes
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false);
        }
      }
    })()
      ..removeWhere((item) {
        final id = '${item['id'] ?? ''}'.trim();
        if (id.isNotEmpty && _locallyRemovedRowIds.contains(id)) return true;
        if (id.isNotEmpty && fixedIds.contains(id)) return true;
        if (_isPengurus) return !_isOwnedByCurrentUser(item);
        if (_isAdminOrOwner) return !_isPengurusIncomeApproved(item);
        return false;
      });

    String keyword = '';
    final now = DateTime.now();
    int selectedMonth = now.month;
    int selectedYear = now.year;
    String customerKind = 'all';
    final selectedIds = <String>{};
    final searchController = TextEditingController();
    final fixedInvoiceBatches = await _loadFixedInvoiceBatches();

    List<DateTime> resolveDepartureDates(Map<String, dynamic> item) {
      final dates = <DateTime>[];

      void pushDate(dynamic raw) {
        final parsed = Formatters.parseDate(raw);
        if (parsed != null) {
          dates.add(parsed);
        }
      }

      final details = _toDetailList(item['rincian']);
      if (details.isNotEmpty) {
        for (final row in details) {
          pushDate(row['armada_start_date'] ?? row['tanggal']);
        }
      }
      if (dates.isEmpty) {
        pushDate(item['armada_start_date']);
        pushDate(item['tanggal']);
        pushDate(item['created_at']);
      }
      dates.sort();
      return dates;
    }

    DateTime resolveInvoiceDepartureSortDate(Map<String, dynamic> item) {
      final departureDates = resolveDepartureDates(item);
      if (departureDates.isNotEmpty) {
        return departureDates.first;
      }
      return Formatters.parseDate(
            item['armada_start_date'] ?? item['tanggal'] ?? item['created_at'],
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    bool matchesDepartureMonth(Map<String, dynamic> item) {
      final departureDates = resolveDepartureDates(item);
      if (departureDates.isEmpty) return false;
      return departureDates.every(
        (date) => date.year == selectedYear && date.month == selectedMonth,
      );
    }

    allPrintableIncomes.sort(
      (a, b) => resolveInvoiceDepartureSortDate(b)
          .compareTo(resolveInvoiceDepartureSortDate(a)),
    );

    if (allPrintableIncomes.isEmpty) {
      _snack(
        _t('Tidak ada invoice income untuk dicetak.',
            'No income invoices available to print.'),
        error: true,
      );
      return;
    }

    bool matchesCustomerKind(
      Map<String, dynamic> item,
      String selectedKind,
    ) {
      if (selectedKind == 'all') return true;
      final entity = _resolveInvoiceEntity(
        invoiceNumber: item['no_invoice'],
        customerName: item['nama_pelanggan'],
        invoiceEntity: item['invoice_entity'],
      );
      switch (selectedKind) {
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
            item['armada_start_date'] ?? item['tanggal'] ?? item['created_at'],
          );
        }
      } else {
        pushLine(
          item,
          item['armada_start_date'] ?? item['tanggal'] ?? item['created_at'],
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
                        final modeLabel = _resolveInvoiceEntityLabel(
                          invoiceEntity: item['invoice_entity'],
                          invoiceNumber: item['no_invoice'],
                          customerName: item['nama_pelanggan'],
                        );
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
      return allPrintableIncomes.where((item) {
        if (!matchesDepartureMonth(item)) return false;
        if (!matchesCustomerKind(item, customerKind)) return false;
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
          final aDate = resolveInvoiceDepartureSortDate(a);
          final bDate = resolveInvoiceDepartureSortDate(b);
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
                                () => customerKind =
                                    Formatters.invoiceEntityCvAnt,
                              ),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: customerKind ==
                                        Formatters.invoiceEntityCvAnt
                                    ? AppColors.success
                                    : AppColors.textMutedFor(context),
                                borderColor: customerKind ==
                                        Formatters.invoiceEntityCvAnt
                                    ? AppColors.success
                                    : AppColors.cardBorder(context),
                              ),
                              child: const Text('CV. ANT'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setDialogState(
                                () => customerKind =
                                    Formatters.invoiceEntityPtAnt,
                              ),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: customerKind ==
                                        Formatters.invoiceEntityPtAnt
                                    ? AppColors.cyan
                                    : AppColors.textMutedFor(context),
                                borderColor: customerKind ==
                                        Formatters.invoiceEntityPtAnt
                                    ? AppColors.cyan
                                    : AppColors.cardBorder(context),
                              ),
                              child: const Text('PT. ANT'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setDialogState(
                                () => customerKind =
                                    Formatters.invoiceEntityPersonal,
                              ),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: customerKind ==
                                        Formatters.invoiceEntityPersonal
                                    ? AppColors.warning
                                    : AppColors.textMutedFor(context),
                                borderColor: customerKind ==
                                        Formatters.invoiceEntityPersonal
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
                                  final kindLabel = _resolveInvoiceEntityLabel(
                                    invoiceEntity: item['invoice_entity'],
                                    invoiceNumber: item['no_invoice'],
                                    customerName: item['nama_pelanggan'],
                                  );
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
                        final fixedBatchTimestamp =
                            DateTime.now().toIso8601String();
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
                            createdAt: fixedBatchTimestamp,
                            updatedAt: fixedBatchTimestamp,
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
    required List<Map<String, dynamic>> expenses,
  }) async {
    final fixedInvoiceBatches = await _loadFixedInvoiceBatches();
    final fixedBatchByInvoiceId = <String, _FixedInvoiceBatch>{};
    for (final batch in fixedInvoiceBatches) {
      for (final invoiceId in batch.invoiceIds) {
        final cleanedId = invoiceId.trim();
        if (cleanedId.isEmpty) continue;
        fixedBatchByInvoiceId.putIfAbsent(cleanedId, () => batch);
      }
    }
    final reportFixedInvoiceIds = <String>{
      ...fixedBatchByInvoiceId.keys,
      ...await _loadLocalFixedInvoiceIds(),
    };
    final fixedIncomeInvoices = reportFixedInvoiceIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await widget.repository.fetchInvoicesByIds(reportFixedInvoiceIds);
    final reportIncomeInvoices = fixedIncomeInvoices.where((item) {
      final id = '${item['id'] ?? ''}'.trim();
      if (id.isNotEmpty && _locallyRemovedRowIds.contains(id)) return false;
      if (_isPengurus) return _isOwnedByCurrentUser(item);
      if (_isAdminOrOwner) return _isPengurusIncomeApproved(item);
      return true;
    }).toList();

    _FixedInvoiceBatch? resolveFixedBatch(Map<String, dynamic> invoice) {
      final invoiceId = '${invoice['id'] ?? ''}'.trim();
      if (invoiceId.isEmpty) return null;
      return fixedBatchByInvoiceId[invoiceId];
    }

    String resolveIncomeReportStatus(Map<String, dynamic> invoice) {
      final batch = resolveFixedBatch(invoice);
      final status = '${batch?.status ?? invoice['status'] ?? 'Unpaid'}'.trim();
      return status.isEmpty ? 'Unpaid' : status;
    }

    String resolveIncomeReportCustomerName(Map<String, dynamic> invoice) {
      final batch = resolveFixedBatch(invoice);
      final customerName =
          '${batch?.customerName ?? invoice['nama_pelanggan'] ?? '-'}'.trim();
      return customerName.isEmpty ? '-' : customerName;
    }

    dynamic resolveIncomeReportDate(Map<String, dynamic> invoice) {
      final batch = resolveFixedBatch(invoice);
      if ((batch?.kopDate ?? '').trim().isNotEmpty) {
        return batch!.kopDate;
      }
      return resolveIncomeReportInvoiceDate(invoice);
    }

    String resolveIncomeReportPaidAt(Map<String, dynamic> invoice) {
      final batch = resolveFixedBatch(invoice);
      return '${batch?.paidAt ?? invoice['paid_at'] ?? ''}'.trim();
    }

    String resolveIncomeReportInvoiceNumber(Map<String, dynamic> invoice) {
      final batch = resolveFixedBatch(invoice);
      if ((batch?.invoiceNumber ?? '').trim().isNotEmpty) {
        return batch!.invoiceNumber;
      }
      return Formatters.invoiceNumber(
        invoice['no_invoice'],
        resolveIncomeReportDate(invoice),
        customerName: resolveIncomeReportCustomerName(invoice),
      );
    }

    bool isIncomeReportPaid(Map<String, dynamic> invoice) {
      final status = resolveIncomeReportStatus(invoice).trim().toLowerCase();
      if (status.contains('partial')) return false;
      if (status.contains('paid') && !status.contains('unpaid')) return true;
      final paidAt = resolveIncomeReportPaidAt(invoice);
      return paidAt.isNotEmpty && !status.contains('unpaid');
    }

    double parseEditableReportAmount(dynamic value) {
      final raw = '${value ?? ''}'.trim();
      if (raw.isEmpty) return 0;
      final cleaned = raw
          .replaceAll(RegExp(r'[^0-9,.-]'), '')
          .replaceAll('.', '')
          .replaceAll(',', '.');
      return double.tryParse(cleaned) ?? 0;
    }

    String formatEditableReportAmount(num value) {
      final number = value.toDouble();
      if (!number.isFinite || number <= 0) return '';
      return Formatters.decimal(number, useGrouping: true);
    }

    double resolveSingleInvoiceJumlah(Map<String, dynamic> invoice) {
      final jumlah = _toNum(invoice['total_biaya']);
      if (jumlah > 0) return jumlah;
      final total = _toNum(invoice['total_bayar']);
      if (total > 0) return total;
      return 0;
    }

    double resolveSingleInvoicePph(Map<String, dynamic> invoice) {
      final isCompany = _resolveIsCompanyInvoice(
        invoiceNumber: resolveIncomeReportInvoiceNumber(invoice),
        customerName: resolveIncomeReportCustomerName(invoice),
      );
      if (!isCompany) return 0;
      return _toNum(invoice['pph']);
    }

    double resolveSingleInvoiceTotal(Map<String, dynamic> invoice) {
      final totalBayar = _toNum(invoice['total_bayar']);
      if (totalBayar > 0) return totalBayar;
      final jumlah = resolveSingleInvoiceJumlah(invoice);
      final pph = resolveSingleInvoicePph(invoice);
      final fallback = jumlah - pph;
      return fallback > 0 ? fallback : jumlah;
    }

    dynamic resolveSingleInvoiceDepartureDate(Map<String, dynamic> invoice) {
      final details = _toDetailList(invoice['rincian']);
      final detailDates = details
          .map((detail) => Formatters.parseDate(detail['armada_start_date']))
          .whereType<DateTime>()
          .toList(growable: false);
      if (detailDates.isNotEmpty) {
        detailDates.sort((a, b) => a.compareTo(b));
        return detailDates.first.toIso8601String();
      }
      return invoice['armada_start_date'] ??
          invoice['tanggal_kop'] ??
          invoice['tanggal'] ??
          invoice['created_at'];
    }

    String reportPaymentDateOnly(DateTime date) {
      final mm = date.month.toString().padLeft(2, '0');
      final dd = date.day.toString().padLeft(2, '0');
      return '${date.year}-$mm-$dd';
    }

    String latestReportPaidAt(Iterable<String?> values) {
      final dates = values
          .map((value) => Formatters.parseDate(value))
          .whereType<DateTime>()
          .toList(growable: false);
      if (dates.isEmpty) return '';
      dates.sort((a, b) => a.compareTo(b));
      return reportPaymentDateOnly(dates.last);
    }

    ({
      double paidAmount,
      double remainingAmount,
      String paidAt,
      String status,
      bool paidLocked,
    }) resolveFixedBatchReportPayment({
      required _FixedInvoiceBatch batch,
      required _FixedInvoicePaymentSummary paymentSummary,
      required double total,
    }) {
      final batchStatus = batch.status.trim();
      final statusLower = batchStatus.toLowerCase();
      final storedPaidEntries =
          batch.paymentDetails.where((entry) => entry.paid).toList();
      final storedBaseTotal = batch.paymentDetails.fold<double>(
        0,
        (sum, entry) => sum + entry.total,
      );
      final storedPaidBase = storedPaidEntries.fold<double>(
        0,
        (sum, entry) => sum + entry.total,
      );
      final summaryBaseTotal = paymentSummary.entries.fold<double>(
        0,
        (sum, entry) => sum + entry.total,
      );
      final paymentBaseTotal = max(
        max(paymentSummary.totalAmount, summaryBaseTotal),
        storedBaseTotal,
      );
      final paidBaseAmount = max(paymentSummary.paidAmount, storedPaidBase);
      final latestPaidAt = latestReportPaidAt([
        batch.paidAt,
        paymentSummary.paidAt,
        ...paymentSummary.entries.where((entry) => entry.paid).map(
              (entry) => entry.paidAt,
            ),
        ...storedPaidEntries.map((entry) => entry.paidAt),
      ]);

      final isExplicitPaid = statusLower == 'paid' ||
          (statusLower.contains('paid') &&
              !statusLower.contains('unpaid') &&
              !statusLower.contains('partial'));
      if (isExplicitPaid || paymentSummary.allPaid) {
        return (
          paidAmount: total,
          remainingAmount: 0.0,
          paidAt: latestPaidAt,
          status: 'Paid',
          paidLocked: true,
        );
      }

      final ratio = paymentBaseTotal > 0 ? total / paymentBaseTotal : 1.0;
      final paidAmount = min(total, max(0.0, paidBaseAmount * ratio));
      final remainingAmount = max(0.0, total - paidAmount);
      final hasPartialPayment = paidAmount > 0 || paymentSummary.anyPaid;
      final status = hasPartialPayment || statusLower.contains('partial')
          ? 'Partial'
          : (batchStatus.isEmpty ? 'Unpaid' : batchStatus);

      return (
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        paidAt: hasPartialPayment ? latestPaidAt : '',
        status: status,
        paidLocked: false,
      );
    }

    String summarizeInvoiceDestinations(List<Map<String, dynamic>> invoices) {
      final tujuan = <String>{};
      for (final invoice in invoices) {
        final details = _toDetailList(invoice['rincian']);
        for (final detail in details) {
          final destination = '${detail['lokasi_bongkar'] ?? ''}'.trim();
          if (destination.isNotEmpty) {
            tujuan.add(destination);
          }
        }
        final fallback = '${invoice['lokasi_bongkar'] ?? ''}'.trim();
        if (fallback.isNotEmpty) {
          tujuan.add(fallback);
        }
      }
      return tujuan.isEmpty ? '-' : tujuan.join(' | ');
    }

    final reportIncomeSources = <Map<String, dynamic>>[];
    final invoiceById = <String, Map<String, dynamic>>{
      for (final item in reportIncomeInvoices)
        '${item['id'] ?? ''}'.trim(): item,
    };
    final consumedInvoiceIds = <String>{};

    for (final batch in fixedInvoiceBatches) {
      final batchItems = batch.invoiceIds
          .map((id) => invoiceById[id.trim()])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      if (batchItems.isEmpty) continue;

      consumedInvoiceIds.addAll(
        batchItems
            .map((item) => '${item['id'] ?? ''}'.trim())
            .where((id) => id.isNotEmpty),
      );

      final customerName = batch.customerName.trim().isEmpty
          ? resolveIncomeReportCustomerName(batchItems.first)
          : batch.customerName.trim();
      final invoiceNumber = batch.invoiceNumber.trim().isEmpty
          ? resolveIncomeReportInvoiceNumber(batchItems.first)
          : batch.invoiceNumber.trim();
      final paymentSummary = _summarizeFixedInvoicePayments(
        batch: batch,
        sourceInvoices: batchItems,
      );
      final reportDate = (batch.kopDate ?? '').trim().isEmpty
          ? resolveIncomeReportDate(batchItems.first)
          : batch.kopDate;
      final jumlah = batchItems.fold<double>(
        0,
        (sum, item) => sum + resolveSingleInvoiceJumlah(item),
      );
      final pph = batchItems.fold<double>(
        0,
        (sum, item) => sum + resolveSingleInvoicePph(item),
      );
      final total = batchItems.fold<double>(
        0,
        (sum, item) => sum + resolveSingleInvoiceTotal(item),
      );
      final reportPayment = resolveFixedBatchReportPayment(
        batch: batch,
        paymentSummary: paymentSummary,
        total: total,
      );
      final departureDate = batchItems
          .map(resolveSingleInvoiceDepartureDate)
          .map(Formatters.parseDate)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (prev, current) {
        if (prev == null || current.isBefore(prev)) return current;
        return prev;
      });

      reportIncomeSources.add({
        'id': batch.batchId,
        'no_invoice': invoiceNumber,
        'invoice_entity': batchItems.first['invoice_entity'],
        'nama_pelanggan': customerName,
        'status': reportPayment.status,
        'tanggal_kop': reportDate,
        'paid_at': reportPayment.paidAt,
        'total_biaya': jumlah,
        'pph': pph,
        'total_bayar': total,
        'rincian': batchItems
            .expand((item) => _toDetailList(item['rincian']))
            .toList(),
        'lokasi_bongkar': summarizeInvoiceDestinations(batchItems),
        '__batch_items': batchItems,
        '__batch_invoice_ids': batch.invoiceIds,
        '__batch_id': batch.batchId,
        '__paid_amount': reportPayment.paidAmount,
        '__remaining_amount': reportPayment.remainingAmount,
        '__report_paid_locked': reportPayment.paidLocked,
        '__payment_details':
            paymentSummary.entries.map((entry) => entry.toJson()).toList(),
        '__departure_date': departureDate?.toIso8601String(),
      });
    }

    for (final item in reportIncomeInvoices) {
      final invoiceId = '${item['id'] ?? ''}'.trim();
      if (invoiceId.isNotEmpty && consumedInvoiceIds.contains(invoiceId)) {
        continue;
      }
      reportIncomeSources.add(Map<String, dynamic>.from(item));
    }

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

      bool incomeKindAllowed(Map<String, dynamic> source) {
        if (customerKind == 'all') return true;
        final customerName = resolveIncomeReportCustomerName(source);
        final invoiceNumber = resolveIncomeReportInvoiceNumber(source);
        final entity = _resolveInvoiceEntity(
          invoiceNumber: invoiceNumber,
          customerName: customerName,
          invoiceEntity: source['invoice_entity'],
        );
        switch (customerKind) {
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

      if (includeIncome) {
        for (final item in reportIncomeSources) {
          final status = resolveIncomeReportStatus(item);
          if (!statusAllowed(status)) continue;
          if (!incomeKindAllowed(item)) continue;
          final customerName = resolveIncomeReportCustomerName(item);
          final reportDate = resolveIncomeReportDate(item);
          final paidAt = resolveIncomeReportPaidAt(item);
          final invoiceNumber = resolveIncomeReportInvoiceNumber(item);
          final invoiceSortKey = buildIncomeReportInvoiceSortKey(
            invoiceNumber: invoiceNumber,
            invoiceDate: reportDate,
            customerName: customerName,
            invoiceEntity: item['invoice_entity'],
          );
          final rowSource = <String, dynamic>{
            ...item,
            'nama_pelanggan': customerName,
            'no_invoice': invoiceNumber,
            'status': status,
            'tanggal_kop': reportDate,
            'paid_at': paidAt,
          };
          if (!inRange(reportDate)) continue;
          if (!keywordAllowed(rowSource)) continue;
          final subtotal = resolveSingleInvoiceJumlah(item);
          final pph = resolveSingleInvoicePph(item);
          final total = resolveSingleInvoiceTotal(item);
          final paidAmount = _toNum(item['__paid_amount']);
          final remainingAmount = _toNum(item['__remaining_amount']);
          final paidLocked =
              item['__report_paid_locked'] == true || isIncomeReportPaid(item);
          final defaultBayar = paidLocked ? total : paidAmount;
          final defaultSisa = paidLocked
              ? 0.0
              : (remainingAmount > 0
                  ? remainingAmount
                  : max(0.0, total - paidAmount));

          rows.add({
            '__key':
                'income:${item['id'] ?? item['no_invoice'] ?? item['created_at'] ?? rows.length}',
            '__type': 'Income',
            '__number': invoiceNumber,
            '__invoice_sort': invoiceSortKey,
            '__date': reportDate,
            '__departure_date': item['__departure_date'] ??
                resolveSingleInvoiceDepartureDate(item),
            '__paid_at': paidAt,
            '__name': customerName,
            '__customer': customerName,
            '__status': status,
            '__amount': total,
            '__jumlah': subtotal,
            '__pph': pph,
            '__total': total,
            '__tujuan': '${item['lokasi_bongkar'] ?? '-'}'.trim(),
            '__paid_locked': paidLocked,
            '__bayar_default': defaultBayar,
            '__sisa_default': defaultSisa,
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
            '__paid_locked': false,
            '__bayar_default': 0.0,
            '__sisa_default': 0.0,
            '__income': 0.0,
            '__expense': amount,
          });
        }
      }

      if (includeIncome && !includeExpense) {
        return sortIncomeReportRowsByInvoice(
          rows.where((row) => '${row['__type']}' == 'Income').toList(),
        );
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

    Future<bool> printReportPdf({
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
      final incomeInvoiceReport = includeIncome && !includeExpense;

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
            'Laporan (Pemasukkan Fix Invoice dan Pengeluaran)',
            'Report (Fixed Invoice Income and Expense)',
          );
        }
        if (includeIncome) {
          if (incomeInvoiceReport) {
            if (customerKind == Formatters.invoiceEntityCvAnt) {
              return _t(
                'Laporan Pemasukkan Fix Invoice per Invoice (CV. ANT)',
                'Fixed Invoice Income Report by Invoice (CV. ANT)',
              );
            }
            if (customerKind == Formatters.invoiceEntityPtAnt) {
              return _t(
                'Laporan Pemasukkan Fix Invoice per Invoice (PT. ANT)',
                'Fixed Invoice Income Report by Invoice (PT. ANT)',
              );
            }
            if (customerKind == Formatters.invoiceEntityPersonal) {
              return _t(
                'Laporan Pemasukkan Fix Invoice per Invoice (Pribadi)',
                'Fixed Invoice Income Report by Invoice (Personal)',
              );
            }
            return _t(
              'Laporan Pemasukkan Fix Invoice per Invoice',
              'Fixed Invoice Income Report by Invoice',
            );
          }
          if (customerKind == Formatters.invoiceEntityCvAnt) {
            return _t(
              'Laporan Pemasukkan Fix Invoice (CV. ANT)',
              'Fixed Invoice Income Report (CV. ANT)',
            );
          }
          if (customerKind == Formatters.invoiceEntityPtAnt) {
            return _t(
              'Laporan Pemasukkan Fix Invoice (PT. ANT)',
              'Fixed Invoice Income Report (PT. ANT)',
            );
          }
          if (customerKind == Formatters.invoiceEntityPersonal) {
            return _t(
              'Laporan Pemasukkan Fix Invoice (Pribadi)',
              'Fixed Invoice Income Report (Personal)',
            );
          }
          return _t(
              'Laporan Pemasukkan Fix Invoice', 'Fixed Invoice Income Report');
        }
        if (customerKind == Formatters.invoiceEntityCvAnt) {
          return _t(
            'Laporan Pengeluaran (CV. ANT)',
            'Expense Report (CV. ANT)',
          );
        }
        if (customerKind == Formatters.invoiceEntityPtAnt) {
          return _t(
            'Laporan Pengeluaran (PT. ANT)',
            'Expense Report (PT. ANT)',
          );
        }
        if (customerKind == Formatters.invoiceEntityPersonal) {
          return _t(
            'Laporan Pengeluaran (Pribadi)',
            'Expense Report (Personal)',
          );
        }
        return _t('Laporan Pengeluaran', 'Expense Report');
      }();

      final reportScopeLabel = includeIncome && includeExpense
          ? _t('Income Fix Invoice + Expense', 'Fixed Invoice Income + Expense')
          : includeIncome
              ? incomeInvoiceReport
                  ? _t(
                      'Income Fix Invoice per Invoice',
                      'Fixed Invoice Income by Invoice',
                    )
                  : _t('Income Fix Invoice', 'Fixed Invoice Income')
              : _t('Expense', 'Expense');
      final orientationLabel = _t('Portrait', 'Portrait');
      final previewInfo =
          '$reportScopeLabel • ${_t('Periode', 'Period')}: $periodLabel • ${_t('Orientasi', 'Orientation')}: $orientationLabel • ${rows.length} ${_t(incomeInvoiceReport ? 'invoice' : 'data', incomeInvoiceReport ? 'invoices' : 'rows')}';

      Future<Uint8List> buildReportPdfBytes(PdfPageFormat format) async {
        final useIncomeInvoiceTable = includeIncome && !includeExpense;
        final companyMode = customerKind == Formatters.invoiceEntityCvAnt ||
            customerKind == Formatters.invoiceEntityPtAnt ||
            rows.any((row) => _toNum(row['__pph']) > 0);
        final showIncomePphColumn = useIncomeInvoiceTable
            ? customerKind == Formatters.invoiceEntityCvAnt ||
                customerKind == Formatters.invoiceEntityPtAnt ||
                (customerKind != Formatters.invoiceEntityPersonal &&
                    rows.any((row) => _toNum(row['__pph']) > 0))
            : companyMode;
        String formatReportDate(dynamic value) => Formatters.dMyShort(value);
        String formatReportAmount(num value) => _formatRupiahNoPrefix(value);
        String formatOptionalEditableAmount(
          Map<String, dynamic> row,
          String textKey,
          String valueKey,
        ) {
          final explicit = '${row[textKey] ?? ''}'.trim();
          final value = _toNum(row[valueKey]);
          if (explicit.isEmpty && value <= 0) return '';
          return formatReportAmount(value);
        }

        int textMeasure(String value) {
          final normalized = value.replaceAll('\r', '');
          return normalized
              .split('\n')
              .map((line) => line.trim().length)
              .fold<int>(0, (longest, len) => max(longest, len));
        }

        Map<int, pw.TableColumnWidth> buildDynamicColumnWidths({
          required List<String> headers,
          required List<List<String>> data,
          required Set<int> dateColumns,
          required Set<int> numericColumns,
          required Set<int> priorityTextColumns,
        }) {
          final widths = <int, pw.TableColumnWidth>{};
          for (var index = 0; index < headers.length; index++) {
            var longest = textMeasure(headers[index]).toDouble();
            for (final row in data) {
              if (index >= row.length) continue;
              longest = max(longest, textMeasure(row[index]).toDouble());
            }

            if (index == 0) {
              longest = max(longest, 3);
            } else if (dateColumns.contains(index)) {
              longest = max(longest, 9);
            } else if (numericColumns.contains(index)) {
              longest = max(longest, 9);
            } else {
              longest = max(longest, 7);
            }

            if (priorityTextColumns.contains(index)) {
              longest *= 1.2;
            } else if (!numericColumns.contains(index) &&
                !dateColumns.contains(index) &&
                index != 0) {
              longest *= 1.08;
            }

            final minWeight = index == 0
                ? 3.2
                : dateColumns.contains(index)
                    ? 8.5
                    : numericColumns.contains(index)
                        ? 8.5
                        : 7.0;
            final maxWeight = priorityTextColumns.contains(index)
                ? 34.0
                : numericColumns.contains(index)
                    ? 16.0
                    : dateColumns.contains(index)
                        ? 11.5
                        : 20.0;
            widths[index] = pw.FlexColumnWidth(
              longest.clamp(minWeight, maxWeight).toDouble(),
            );
          }
          return widths;
        }

        final maxNumberLen = rows
            .map((row) => '${row['__number'] ?? '-'}'.length)
            .fold<int>(0, (maxLen, len) => max(maxLen, len));
        final maxCustomerLen = rows
            .map((row) => '${row['__customer'] ?? row['__name'] ?? '-'}'.length)
            .fold<int>(0, (maxLen, len) => max(maxLen, len));
        final maxPaidAtLen = rows.map((row) {
          final paidAt = '${row['__paid_at'] ?? ''}'.trim();
          return paidAt.isEmpty ? 0 : formatReportDate(paidAt).length;
        }).fold<int>(0, (maxLen, len) => max(maxLen, len));

        double headerFont = 8.0;
        double cellFont = 7.0;
        if (maxNumberLen > 28 || maxCustomerLen > 24 || rows.length > 24) {
          headerFont -= 0.5;
          cellFont -= 0.5;
        }
        if (maxNumberLen > 40 || maxPaidAtLen > 12 || rows.length > 36) {
          headerFont -= 0.5;
          cellFont -= 0.5;
        }
        if (useIncomeInvoiceTable) {
          headerFont -= 0.4;
          cellFont -= 0.4;
        }
        headerFont = headerFont.clamp(7.0, 8.5).toDouble();
        cellFont = cellFont.clamp(6.2, 7.5).toDouble();

        final pageFormat = format;
        final pdfFonts = await _loadDashboardPdfFontBundle();
        late final pw.Font reportTitleFont;
        try {
          reportTitleFont = await PdfGoogleFonts.archivoBlack();
        } catch (_) {
          reportTitleFont = pw.Font.helveticaBold();
        }

        pw.MemoryImage? reportLogo;
        try {
          final logoBytes = await _loadBinaryAssetWithFileFallback(
              'assets/images/iconapk.png');
          reportLogo = pw.MemoryImage(logoBytes);
        } catch (_) {
          reportLogo = null;
        }

        final headers = useIncomeInvoiceTable
            ? showIncomePphColumn
                ? const [
                    'NO',
                    'TANGGAL',
                    'CUSTOMER',
                    'JUMLAH',
                    'PPH',
                    'TOTAL',
                    'BAYAR',
                    'SISA',
                    'TGL BAYAR',
                  ]
                : const [
                    'NO',
                    'TANGGAL',
                    'CUSTOMER',
                    'JUMLAH',
                    'TOTAL',
                    'BAYAR',
                    'SISA',
                    'TGL BAYAR',
                  ]
            : companyMode
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
        final tableData = List<List<String>>.generate(rows.length, (index) {
          final row = rows[index];
          if (useIncomeInvoiceTable) {
            final paidAt = '${row['__paid_at'] ?? ''}'.trim();
            if (showIncomePphColumn) {
              return [
                '${index + 1}',
                formatReportDate(row['__date']),
                '${row['__customer'] ?? row['__name'] ?? '-'}'.trim(),
                formatReportAmount(_toNum(row['__jumlah'])),
                formatReportAmount(_toNum(row['__pph'])),
                formatReportAmount(_toNum(row['__total'])),
                formatOptionalEditableAmount(row, '__bayar_text', '__bayar'),
                formatOptionalEditableAmount(row, '__sisa_text', '__sisa'),
                paidAt.isEmpty ? '' : formatReportDate(paidAt),
              ];
            }
            return [
              '${index + 1}',
              formatReportDate(row['__date']),
              '${row['__customer'] ?? row['__name'] ?? '-'}'.trim(),
              formatReportAmount(_toNum(row['__jumlah'])),
              formatReportAmount(_toNum(row['__total'])),
              formatOptionalEditableAmount(row, '__bayar_text', '__bayar'),
              formatOptionalEditableAmount(row, '__sisa_text', '__sisa'),
              paidAt.isEmpty ? '' : formatReportDate(paidAt),
            ];
          }
          if (companyMode) {
            return [
              '${index + 1}',
              formatReportDate(row['__date']),
              '${row['__customer'] ?? row['__name'] ?? '-'}'.trim(),
              formatReportAmount(_toNum(row['__jumlah'])),
              formatReportAmount(_toNum(row['__pph'])),
              formatReportAmount(_toNum(row['__total'])),
              '${row['__tujuan'] ?? '-'}'.trim(),
            ];
          }
          return [
            '${index + 1}',
            formatReportDate(row['__date']),
            '${row['__customer'] ?? row['__name'] ?? '-'}'.trim(),
            formatReportAmount(_toNum(row['__jumlah'])),
            formatReportAmount(_toNum(row['__total'])),
            '${row['__tujuan'] ?? '-'}'.trim(),
          ];
        });
        final reportTableData = <List<String>>[...tableData];
        if (useIncomeInvoiceTable) {
          final totalJumlah =
              rows.fold<double>(0, (sum, row) => sum + _toNum(row['__jumlah']));
          final totalPph =
              rows.fold<double>(0, (sum, row) => sum + _toNum(row['__pph']));
          final totalNilai =
              rows.fold<double>(0, (sum, row) => sum + _toNum(row['__total']));
          final totalBayar =
              rows.fold<double>(0, (sum, row) => sum + _toNum(row['__bayar']));
          final totalSisa =
              rows.fold<double>(0, (sum, row) => sum + _toNum(row['__sisa']));
          reportTableData.add(
            showIncomePphColumn
                ? [
                    '',
                    '',
                    'TOTAL',
                    formatReportAmount(totalJumlah),
                    formatReportAmount(totalPph),
                    formatReportAmount(totalNilai),
                    formatReportAmount(totalBayar),
                    formatReportAmount(totalSisa),
                    '',
                  ]
                : [
                    '',
                    '',
                    'TOTAL',
                    formatReportAmount(totalJumlah),
                    formatReportAmount(totalNilai),
                    formatReportAmount(totalBayar),
                    formatReportAmount(totalSisa),
                    '',
                  ],
          );
        }
        final numericColumns = useIncomeInvoiceTable
            ? showIncomePphColumn
                ? <int>{3, 4, 5, 6, 7}
                : <int>{3, 4, 5, 6}
            : companyMode
                ? <int>{3, 4, 5}
                : <int>{3, 4};
        final dateColumns = useIncomeInvoiceTable
            ? showIncomePphColumn
                ? <int>{1, 8}
                : <int>{1, 7}
            : <int>{1};
        final priorityTextColumns =
            useIncomeInvoiceTable ? <int>{2} : <int>{2, headers.length - 1};
        final columnWidths = buildDynamicColumnWidths(
          headers: headers,
          data: reportTableData,
          dateColumns: dateColumns,
          numericColumns: numericColumns,
          priorityTextColumns: priorityTextColumns,
        );
        double flexValue(pw.TableColumnWidth? width, double fallback) {
          if (width is pw.FlexColumnWidth) return width.flex;
          if (width is pw.FixedColumnWidth) return width.width;
          return fallback;
        }

        if (useIncomeInvoiceTable) {
          final customerIndex = 2;
          final bayarIndex = showIncomePphColumn ? 6 : 5;
          final sisaIndex = showIncomePphColumn ? 7 : 6;
          final paidDateIndex = headers.length - 1;
          columnWidths[customerIndex] = pw.FlexColumnWidth(
            min(
              flexValue(columnWidths[customerIndex], 16.0),
              showIncomePphColumn ? 15.2 : 16.4,
            ),
          );
          columnWidths[bayarIndex] = pw.FlexColumnWidth(
            max(flexValue(columnWidths[bayarIndex], 9.0), 9.0),
          );
          columnWidths[sisaIndex] = pw.FlexColumnWidth(
            max(flexValue(columnWidths[sisaIndex], 9.4), 9.4),
          );
          columnWidths[paidDateIndex] = pw.FlexColumnWidth(
            max(flexValue(columnWidths[paidDateIndex], 10.5), 10.5),
          );
        }
        final cellAlignments = <int, pw.Alignment>{
          for (int i = 0; i < headers.length; i++) i: pw.Alignment.center,
        };
        final totalRowNumber = reportTableData.length;

        pw.Widget buildReportHeader() {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (reportLogo != null)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Image(
                        reportLogo,
                        height: 38,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  if (reportLogo != null) pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CV AS NUSA TRANS',
                          style: pw.TextStyle(
                            font: pw.Font.helveticaBold(),
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 1.5),
                        pw.Text(
                          reportHeader,
                          style: pw.TextStyle(
                            font: pw.Font.helveticaBold(),
                            fontSize: 10.2,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 1.5),
                        pw.Text(
                          '${_t('Periode', 'Period')}: $periodLabel',
                          style: const pw.TextStyle(fontSize: 8.1),
                        ),
                        pw.Text(
                          '${_t('Ruang Lingkup', 'Scope')}: $reportScopeLabel',
                          style: const pw.TextStyle(fontSize: 8.1),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'L  A  P  O  R  A  N',
                        style: pw.TextStyle(
                          font: reportTitleFont,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2.2,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${_t('Dicetak', 'Printed')}: ${Formatters.dMyShort(DateTime.now())}',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 7.9),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Container(height: 1.0, color: PdfColors.black),
              pw.SizedBox(height: 1.2),
              pw.Container(height: 0.8, color: PdfColors.black),
            ],
          );
        }

        pw.Widget buildSummaryBox() {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 212,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.9),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  if (includeIncome && includeExpense) ...[
                    pw.Text(
                      '${_t('Total Income', 'Total Income')}: ${Formatters.rupiah(totalIncome)}',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 8.5),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${_t('Total Expense', 'Total Expense')}: ${Formatters.rupiah(totalExpense)}',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 8.5),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${_t('Selisih', 'Difference')}: ${Formatters.rupiah(totalIncome - totalExpense)}',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ] else if (includeIncome) ...[
                    pw.Text(
                      '${_t('Total Income', 'Total Income')}: ${Formatters.rupiah(totalIncome)}',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ] else if (includeExpense) ...[
                    pw.Text(
                      '${_t('Total Expense', 'Total Expense')}: ${Formatters.rupiah(totalExpense)}',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        final doc = pw.Document(theme: _dashboardPdfTheme(pdfFonts));
        doc.addPage(
          pw.MultiPage(
            pageFormat: pageFormat,
            margin: const pw.EdgeInsets.all(20),
            build: (context) => [
              buildReportHeader(),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(
                  color: PdfColors.black,
                  width: 0.8,
                ),
                cellPadding:
                    const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                headerHeight: 16,
                headerDecoration: const pw.BoxDecoration(),
                headerStyle: pw.TextStyle(
                  font: pw.Font.helveticaBold(),
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                  fontSize: headerFont,
                ),
                cellStyle: pw.TextStyle(fontSize: cellFont),
                cellAlignments: cellAlignments,
                columnWidths: columnWidths,
                headers: headers,
                data: reportTableData,
                cellDecoration: useIncomeInvoiceTable
                    ? (index, data, rowNum) => rowNum == totalRowNumber
                        ? const pw.BoxDecoration(color: PdfColors.grey200)
                        : const pw.BoxDecoration()
                    : null,
                textStyleBuilder: useIncomeInvoiceTable
                    ? (index, data, rowNum) => rowNum == totalRowNumber
                        ? pw.TextStyle(
                            font: pw.Font.helveticaBold(),
                            fontWeight: pw.FontWeight.bold,
                            fontSize: cellFont,
                          )
                        : null
                    : null,
              ),
              pw.SizedBox(height: 12),
              buildSummaryBox(),
            ],
          ),
        );
        return doc.save();
      }

      final pdfBytes = await buildReportPdfBytes(PdfPageFormat.a4);
      final shouldPrint = await _showPdfPreviewDialog(
        bytes: pdfBytes,
        title: reportHeader,
        renderInfo: previewInfo,
      );
      if (!shouldPrint || !mounted) return false;

      final pdfName = _safePdfFileName(
        '${reportHeader.replaceAll(' ', '_')}_${periodLabel.replaceAll(' ', '_')}.pdf',
      );
      await _dispatchPdfBytesToPrinter(
        bytes: pdfBytes,
        name: pdfName,
      );
      return true;
    }

    final allStatuses = <String>{
      ...reportIncomeInvoices.map(resolveIncomeReportStatus),
      ...expenses.map((item) => '${item['status'] ?? 'Recorded'}'),
    }.where((status) => status.trim().isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    String range = 'month';
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
      ...reportIncomeInvoices
          .map((item) =>
              Formatters.parseDate(resolveIncomeReportDate(item))?.year)
          .whereType<int>(),
      ...expenses
          .map((item) =>
              Formatters.parseDate(item['tanggal'] ?? item['created_at'])?.year)
          .whereType<int>(),
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final reportBayarControllers = <String, TextEditingController>{};
    final reportSisaControllers = <String, TextEditingController>{};
    final reportSisaEdited = <String, bool>{};

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

    void syncReportPaymentControllers(
      List<Map<String, dynamic>> previewRows,
      bool incomeInvoiceReport,
    ) {
      final validKeys = previewRows.map((row) => '${row['__key']}').toSet();
      final staleKeys = <String>{
        ...reportBayarControllers.keys,
        ...reportSisaControllers.keys,
      }.difference(validKeys);
      for (final key in staleKeys) {
        reportBayarControllers.remove(key)?.dispose();
        reportSisaControllers.remove(key)?.dispose();
        reportSisaEdited.remove(key);
      }
      if (!incomeInvoiceReport) return;

      for (final row in previewRows) {
        final key = '${row['__key']}';
        final paidLocked = row['__paid_locked'] == true;
        final total = _toNum(row['__total']);
        final defaultBayar = formatEditableReportAmount(
          paidLocked ? total : _toNum(row['__bayar_default']),
        );
        final defaultSisa = paidLocked
            ? ''
            : formatEditableReportAmount(_toNum(row['__sisa_default']));
        final bayarController = reportBayarControllers.putIfAbsent(
          key,
          () => TextEditingController(text: defaultBayar),
        );
        final sisaController = reportSisaControllers.putIfAbsent(
          key,
          () => TextEditingController(text: defaultSisa),
        );
        if (paidLocked) {
          if (bayarController.text != defaultBayar) {
            bayarController.text = defaultBayar;
          }
          if (sisaController.text.isNotEmpty) {
            sisaController.clear();
          }
          reportSisaEdited[key] = true;
        } else {
          if (bayarController.text.trim().isEmpty && defaultBayar.isNotEmpty) {
            bayarController.text = defaultBayar;
          }
          if (sisaController.text.trim().isEmpty && defaultSisa.isNotEmpty) {
            sisaController.text = defaultSisa;
          }
          reportSisaEdited.putIfAbsent(key, () => false);
        }
      }
    }

    if (!mounted) return;
    Map<String, dynamic>? selection;
    try {
      selection = await showDialog<Map<String, dynamic>>(
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
              rowSelections
                  .removeWhere((key, _) => !availableKeys.contains(key));
              for (final key in availableKeys) {
                rowSelections.putIfAbsent(key, () => true);
              }
              final incomeInvoiceReport = includeIncome && !includeExpense;
              syncReportPaymentControllers(previewRows, incomeInvoiceReport);
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
                                  () => customerKind =
                                      Formatters.invoiceEntityCvAnt,
                                ),
                                style: CvantButtonStyles.outlined(
                                  context,
                                  color: customerKind ==
                                          Formatters.invoiceEntityCvAnt
                                      ? AppColors.success
                                      : AppColors.textMutedFor(context),
                                  borderColor: customerKind ==
                                          Formatters.invoiceEntityCvAnt
                                      ? AppColors.success
                                      : AppColors.cardBorder(context),
                                ),
                                child: const Text('CV. ANT'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setDialogState(
                                  () => customerKind =
                                      Formatters.invoiceEntityPtAnt,
                                ),
                                style: CvantButtonStyles.outlined(
                                  context,
                                  color: customerKind ==
                                          Formatters.invoiceEntityPtAnt
                                      ? AppColors.cyan
                                      : AppColors.textMutedFor(context),
                                  borderColor: customerKind ==
                                          Formatters.invoiceEntityPtAnt
                                      ? AppColors.cyan
                                      : AppColors.cardBorder(context),
                                ),
                                child: const Text('PT. ANT'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setDialogState(
                                  () => customerKind =
                                      Formatters.invoiceEntityPersonal,
                                ),
                                style: CvantButtonStyles.outlined(
                                  context,
                                  color: customerKind ==
                                          Formatters.invoiceEntityPersonal
                                      ? AppColors.warning
                                      : AppColors.textMutedFor(context),
                                  borderColor: customerKind ==
                                          Formatters.invoiceEntityPersonal
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
                          onChanged: (value) => setDialogState(
                              () => includeIncome = value ?? true),
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
                            style: TextStyle(
                                color: AppColors.textMutedFor(context)),
                          )
                        else
                          SizedBox(
                            height:
                                max(60, min(180, 36.0 * allStatuses.length)),
                            child: ListView.builder(
                              itemCount: allStatuses.length,
                              itemBuilder: (context, index) {
                                final status = allStatuses[index];
                                final checked =
                                    selectedStatuses.contains(status);
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
                            includeIncome && !includeExpense
                                ? 'Hasil filter: ${previewRows.length} invoice • Dipilih: $selectedCount'
                                : 'Hasil filter: ${previewRows.length} data • Dipilih: $selectedCount',
                            includeIncome && !includeExpense
                                ? 'Filtered result: ${previewRows.length} invoices • Selected: $selectedCount'
                                : 'Filtered result: ${previewRows.length} rows • Selected: $selectedCount',
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
                              _t(
                                includeIncome && !includeExpense
                                    ? 'Pilih Invoice Manual'
                                    : 'Pilih Data Manual',
                                includeIncome && !includeExpense
                                    ? 'Manual Invoice Selection'
                                    : 'Manual Data Selection',
                              ),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: previewRows.isEmpty
                                  ? null
                                  : () => setDialogState(() {
                                        for (final row in previewRows) {
                                          rowSelections['${row['__key']}'] =
                                              true;
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
                              child:
                                  Text(_t('Hapus Pilihan', 'Clear Selection')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (previewRows.isEmpty)
                          Text(
                            _t('Tidak ada data pada filter ini.',
                                'No data for this filter.'),
                            style: TextStyle(
                                color: AppColors.textMutedFor(context)),
                          )
                        else
                          SizedBox(
                            height: incomeInvoiceReport ? 320 : 220,
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
                                final showIncomePph = incomeInvoiceReport &&
                                    (customerKind ==
                                            Formatters.invoiceEntityCvAnt ||
                                        customerKind ==
                                            Formatters.invoiceEntityPtAnt ||
                                        (customerKind !=
                                                Formatters
                                                    .invoiceEntityPersonal &&
                                            previewRows.any((item) =>
                                                _toNum(item['__pph']) > 0)));
                                final paidAt =
                                    '${row['__paid_at'] ?? ''}'.trim();
                                final tujuanLabel =
                                    '${row['__tujuan'] ?? '-'}'.trim();
                                final title = incomeInvoiceReport
                                    ? '${row['__number'] ?? '-'} • ${row['__customer'] ?? row['__name'] ?? '-'}'
                                    : '${row['__number'] ?? '-'} • ${Formatters.dmy(row['__date'])}';
                                final subtitle = incomeInvoiceReport
                                    ? [
                                        '${_t('Tanggal', 'Date')}: ${Formatters.dmy(row['__date'])}',
                                        '${_t('Jumlah', 'Amount')}: ${Formatters.rupiah(_toNum(row['__jumlah']))}',
                                        if (showIncomePph)
                                          '${_t('PPH', 'PPH')}: ${Formatters.rupiah(_toNum(row['__pph']))}',
                                        '${_t('Total', 'Total')}: ${Formatters.rupiah(_toNum(row['__total']))}',
                                        if (paidAt.isNotEmpty)
                                          '${_t('Tgl Bayar', 'Paid Date')}: ${Formatters.dmy(paidAt)}',
                                      ].join(' • ')
                                    : income > 0
                                        ? [
                                            '${_t('Income', 'Income')}: ${Formatters.rupiah(income)}',
                                            if (tujuanLabel.isNotEmpty &&
                                                tujuanLabel != '-')
                                              tujuanLabel,
                                          ].join(' • ')
                                        : '${_t('Expense', 'Expense')}: ${Formatters.rupiah(expense)}';
                                final bayarController =
                                    reportBayarControllers[key];
                                final sisaController =
                                    reportSisaControllers[key];
                                final paidLocked = row['__paid_locked'] == true;
                                final total = _toNum(row['__total']);

                                if (!incomeInvoiceReport ||
                                    bayarController == null ||
                                    sisaController == null) {
                                  return CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    value: checked,
                                    onChanged: (value) => setDialogState(
                                      () => rowSelections[key] = value ?? false,
                                    ),
                                    title: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  );
                                }

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        value: checked,
                                        onChanged: (value) => setDialogState(
                                          () => rowSelections[key] =
                                              value ?? false,
                                        ),
                                        title: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 42,
                                          right: 4,
                                          bottom: 6,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: bayarController,
                                                enabled: checked,
                                                readOnly: paidLocked,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  labelText:
                                                      _t('Bayar', 'Paid'),
                                                  hintText: '0',
                                                ),
                                                onChanged: paidLocked
                                                    ? null
                                                    : (value) {
                                                        if (reportSisaEdited[
                                                                key] ==
                                                            true) {
                                                          return;
                                                        }
                                                        final remaining = max(
                                                          0,
                                                          total -
                                                              parseEditableReportAmount(
                                                                value,
                                                              ),
                                                        );
                                                        final text =
                                                            formatEditableReportAmount(
                                                          remaining,
                                                        );
                                                        if (sisaController
                                                                .text !=
                                                            text) {
                                                          sisaController.value =
                                                              TextEditingValue(
                                                            text: text,
                                                            selection:
                                                                TextSelection
                                                                    .collapsed(
                                                              offset:
                                                                  text.length,
                                                            ),
                                                          );
                                                        }
                                                      },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: TextField(
                                                controller: sisaController,
                                                enabled: checked,
                                                readOnly: paidLocked,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  labelText:
                                                      _t('Sisa', 'Remaining'),
                                                  hintText:
                                                      paidLocked ? '' : '0',
                                                ),
                                                onChanged: paidLocked
                                                    ? null
                                                    : (value) {
                                                        reportSisaEdited[key] =
                                                            value
                                                                .trim()
                                                                .isNotEmpty;
                                                      },
                                              ),
                                            ),
                                          ],
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
                        'customerKind': customerKind,
                        'month': selectedMonth,
                        'year': selectedYear,
                        'statuses': selectedStatuses.toList(),
                        'keyword': keywordText.trim(),
                        'selectedKeys': rowSelections.entries
                            .where((entry) => entry.value)
                            .map((entry) => entry.key)
                            .toList(),
                        'bayarInputs': reportBayarControllers.map(
                          (key, controller) => MapEntry(key, controller.text),
                        ),
                        'sisaInputs': reportSisaControllers.map(
                          (key, controller) => MapEntry(key, controller.text),
                        ),
                      });
                    },
                    style: CvantButtonStyles.filled(context,
                        color: AppColors.success),
                    icon: const Icon(Icons.preview_outlined),
                    label: Text(_t('Preview PDF', 'Preview PDF')),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      for (final controller in reportBayarControllers.values) {
        controller.dispose();
      }
      for (final controller in reportSisaControllers.values) {
        controller.dispose();
      }
    }
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
    const selectedOrientation = 'portrait';
    final statusFilters =
        (selection['statuses'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => '$item')
            .toSet();
    final selectedKeys =
        (selection['selectedKeys'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => '$item')
            .toSet();
    final bayarInputs = ((selection['bayarInputs'] as Map?)?.map(
          (key, value) => MapEntry('$key', '$value'),
        ) ??
        const <String, String>{});
    final sisaInputs = ((selection['sisaInputs'] as Map?)?.map(
          (key, value) => MapEntry('$key', '$value'),
        ) ??
        const <String, String>{});
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
            .map((row) {
            if (!(includeIncomeSelected && !includeExpenseSelected) ||
                '${row['__type']}' != 'Income') {
              return row;
            }
            final key = '${row['__key']}';
            final total = _toNum(row['__total']);
            final paidLocked = row['__paid_locked'] == true;
            final bayarText = paidLocked
                ? formatEditableReportAmount(total)
                : (bayarInputs[key] ?? '').toString().trim();
            final sisaText =
                paidLocked ? '' : (sisaInputs[key] ?? '').toString().trim();
            final bayar =
                paidLocked ? total : parseEditableReportAmount(bayarText);
            final sisa = paidLocked ? 0.0 : parseEditableReportAmount(sisaText);
            return {
              ...row,
              '__bayar': bayar,
              '__sisa': sisa,
              '__bayar_text': bayarText,
              '__sisa_text': sisaText,
            };
          }).toList();

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
      final incomeInvoiceReport =
          includeIncomeSelected && !includeExpenseSelected;
      final printed = await printReportPdf(
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
      if (!printed || !mounted) return;
      _snack(
        _t(
          incomeInvoiceReport
              ? 'Report PDF berhasil dibuat (${rows.length} invoice).'
              : 'Report PDF berhasil dibuat (${rows.length} data).',
          incomeInvoiceReport
              ? 'PDF report generated successfully (${rows.length} invoices).'
              : 'PDF report generated successfully (${rows.length} rows).',
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

  String? _pengurusIncomeStatusMessage({
    required bool isIncome,
    required String approvalStatus,
    required String editRequestStatus,
  }) {
    if (!(_isPengurus && isIncome)) return null;
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
  }

  Color? _pengurusIncomeStatusColor({
    required bool isIncome,
    required String approvalStatus,
    required String editRequestStatus,
  }) {
    if (!(_isPengurus && isIncome)) return null;
    if (editRequestStatus == 'approved') {
      return AppColors.success;
    }
    if (approvalStatus == 'rejected') {
      return AppColors.danger;
    }
    return AppColors.textMutedFor(context);
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
          final invoiceTypeLabel = isIncome
              ? _resolveInvoiceEntityLabel(
                  invoiceEntity: item['invoice_entity'],
                  invoiceNumber: item['no_invoice'] ?? item['__number'],
                  customerName: item['__name'],
                )
              : (isEn ? 'Personal' : 'Pribadi');
          final invoiceTypeColor = isIncome
              ? _invoiceEntityAccentColor(
                  invoiceEntity: item['invoice_entity'],
                  invoiceNumber: item['no_invoice'] ?? item['__number'],
                  customerName: item['__name'],
                )
              : AppColors.blue;
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
          final pengurusStatusMessage = _pengurusIncomeStatusMessage(
            isIncome: isIncome,
            approvalStatus: approvalStatus,
            editRequestStatus: editRequestStatus,
          );
          final pengurusStatusColor = _pengurusIncomeStatusColor(
            isIncome: isIncome,
            approvalStatus: approvalStatus,
            editRequestStatus: editRequestStatus,
          );
          return _AdminInvoiceListRowCard(
            item: item,
            isIncome: isIncome,
            translate: _t,
            invoiceTypeLabel: invoiceTypeLabel,
            invoiceTypeColor: invoiceTypeColor,
            pengurusStatusMessage: pengurusStatusMessage,
            pengurusStatusColor: pengurusStatusColor,
            mobileActionButtonStyle: (color) => _mobileActionButtonStyle(
              context: context,
              color: color,
            ),
            onPrimaryAction: isIncome && _isPengurus
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
            primaryActionIcon: isIncome && _isPengurus
                ? (canOpenPengurusEdit
                    ? Icons.edit_outlined
                    : Icons.how_to_reg_outlined)
                : Icons.edit_outlined,
            primaryActionColor: isIncome && _isPengurus
                ? ((canOpenPengurusEdit || canRequestPengurusEdit)
                    ? AppColors.blue
                    : AppColors.neutralOutline)
                : AppColors.blue,
            onPreview: () => isIncome
                ? _openInvoicePreview(item)
                : _openExpensePreview(item),
            onSend: isIncome && !_isPengurus ? () => _sendInvoice(item) : null,
            onDelete: !(isIncome && _isPengurus && approvalStatus == 'approved')
                ? () => _confirmDelete(
                      id: '${item['id']}',
                      isIncome: isIncome,
                    )
                : null,
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
