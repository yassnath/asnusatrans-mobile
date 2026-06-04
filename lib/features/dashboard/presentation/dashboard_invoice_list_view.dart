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
  bool _backgroundInvoiceDateSyncRunning = false;
  bool _backgroundInvoiceNumberNormalizationRunning = false;
  bool _manualArmadaAutoSanguCleanupDone = false;
  bool _incomePricingBackfillDone = false;
  bool _invoiceDetailDateSyncDone = false;

  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  bool get _isPengurus => widget.session.isPengurus;
  bool get _isAdminOrOwner => widget.session.isAdminOrOwner;
  String get _currentUserId => widget.session.userId?.trim() ?? '';

  String _t(String id, String en) => _isEn ? en : id;

  double _resolveInvoiceJumlahWithSpecialRules(Map<String, dynamic> invoice) {
    final details = _toDetailList(invoice['rincian']);
    if (details.isNotEmpty) {
      final detailSubtotal = _resolveInvoiceDetailsExcelSubtotalShared(details);
      if (detailSubtotal > 0) return detailSubtotal;
    }
    final jumlah = _toNum(invoice['total_biaya']);
    if (jumlah > 0) return jumlah;
    final total = _toNum(invoice['total_bayar']);
    if (total > 0) return total;
    return 0;
  }

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
    if (isFullFleetStatus(status)) return AppColors.warning;
    if (isReadyFleetStatus(status)) return AppColors.success;
    if (isInactiveFleetStatus(status)) {
      return AppColors.neutralOutline;
    }
    return AppColors.textMutedFor(context);
  }

  String _normalizePlateText(String value) {
    return normalizeArmadaPlateText(value);
  }

  String _normalizeArmadaNameKey(String value) {
    return normalizeArmadaNameKey(value);
  }

  String? _extractPlateFromText(String value) {
    return extractArmadaPlateFromText(value);
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
    if (_isManualArmadaRow(row)) {
      for (final candidate in <String>[
        '${row['armada_manual'] ?? ''}'.trim(),
        '${row['armada_label'] ?? ''}'.trim(),
        '${row['armada'] ?? ''}'.trim(),
        '${row['plat_nomor'] ?? ''}'.trim(),
        '${row['no_polisi'] ?? ''}'.trim(),
      ]) {
        if (candidate.isEmpty || candidate == '-') continue;
        final parsed = _extractPlateFromText(candidate);
        return parsed == null || parsed.isEmpty || parsed == '-'
            ? candidate.toUpperCase()
            : parsed;
      }
      return '-';
    }

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

    final driverText = [
      row['nama_supir'],
      row['nama_sopir'],
      row['supir'],
      row['driver'],
    ].map((value) => '${value ?? ''}').join(' ');
    final driverKey = driverText
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (driverKey.isNotEmpty) {
      for (final entry in _defaultDriverByPlate.entries) {
        final mappedDriver = entry.value
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (mappedDriver.isEmpty) continue;
        if (driverKey == mappedDriver ||
            driverKey.contains(mappedDriver) ||
            mappedDriver.contains(driverKey)) {
          return _normalizePlateText(entry.key);
        }
      }
    }

    return '-';
  }

  Map<String, String> _buildArmadaIdByPlate(
    List<Map<String, dynamic>> armadas,
  ) {
    return buildArmadaIdByPlate(armadas);
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
    if (_isManualArmadaText(manual)) return '';
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
    if (_isManualArmadaRow(row)) return null;
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

  bool _isManualArmadaRow(Map<String, dynamic> row) {
    return rowUsesManualArmada(row);
  }

  bool _isManualArmadaText(dynamic value) {
    return isManualArmadaText(value);
  }

  void _clearDriverForManualArmadaIfNeeded(Map<String, dynamic> row) {
    if (!_isManualArmadaRow(row)) return;
    final manual = '${row['armada_manual'] ?? ''}'.trim();
    if (manual.isEmpty) {
      final detectedManual = manualArmadaLabelFromRow(row);
      if (detectedManual.isNotEmpty) {
        row['armada_manual'] = detectedManual;
        row['armada_label'] = detectedManual;
      }
    }
    row['armada_id'] = '';
    row['armada_is_manual'] = true;
    row['nama_supir'] = '';
    row['nama_supir_manual'] = '';
    row['nama_supir_is_manual'] = false;
    row['nama_supir_auto'] = false;
  }

  void _syncDriverWithArmadaSelection(
    Map<String, dynamic> row, {
    required List<Map<String, dynamic>> armadas,
    bool overrideManualDriver = false,
  }) {
    _clearDriverForManualArmadaIfNeeded(row);
    if (_isManualArmadaRow(row)) return;

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

  @override
  void reassemble() {
    super.reassemble();
    if (!kDebugMode || !mounted) return;
    setState(() {
      _future = _load();
    });
  }

  List<Map<String, dynamic>> _expandIncomeRowsForInvoiceList(
    List<Map<String, dynamic>> rows,
  ) {
    String? cleanText(dynamic value) {
      final text = '${value ?? ''}'.trim();
      if (text.isEmpty ||
          text.toLowerCase() == 'null' ||
          text.toLowerCase() == 'undefined') {
        return null;
      }
      return text;
    }

    dynamic detailValue(
      Map<String, dynamic> detail,
      Map<String, dynamic> row,
      String key,
    ) {
      final detailText = cleanText(detail[key]);
      if (detailText != null) return detail[key];
      return row[key];
    }

    double? positiveDetailNumber(
      Map<String, dynamic> detail,
      Map<String, dynamic> row,
      String key,
    ) {
      final detailNumber = _toNum(detail[key]);
      if (detailNumber > 0) return detailNumber;
      final rowNumber = _toNum(row[key]);
      return rowNumber > 0 ? rowNumber : null;
    }

    final expanded = <Map<String, dynamic>>[];
    for (final row in rows) {
      final details = _toDetailList(row['rincian']);
      if (details.length <= 1) {
        expanded.add(row);
        continue;
      }

      final entity = Formatters.normalizeInvoiceEntity(
        row['invoice_entity'],
        invoiceNumber: row['no_invoice'],
        customerName: row['nama_pelanggan'],
      );
      final includePph = Formatters.isCompanyInvoiceEntity(entity);

      for (var i = 0; i < details.length; i++) {
        final detail = Map<String, dynamic>.from(details[i]);
        final subtotal = _resolveInvoiceDetailExcelSubtotalShared(detail);
        final pph = includePph ? calculateInvoicePph2Percent(subtotal) : 0.0;
        final totalBayar =
            includePph ? calculateInvoiceTotalAfterPph(subtotal) : subtotal;
        final detailDate = cleanText(detail['armada_start_date']) ??
            cleanText(detail['tanggal']) ??
            cleanText(row['armada_start_date']) ??
            cleanText(row['tanggal']);
        final useManualArmada =
            _isManualArmadaRow(detail) || _isManualArmadaRow(row);
        final detailArmadaManual = cleanText(detail['armada_manual']) ??
            cleanText(detail['armada_label']) ??
            cleanText(detail['armada']) ??
            cleanText(row['armada_manual']) ??
            cleanText(row['armada_label']) ??
            cleanText(row['armada']);

        expanded.add({
          ...row,
          '__invoice_list_expanded_detail': true,
          '__source_invoice_id': row['id'],
          '__detail_index': i,
          'rincian': [detail],
          'tanggal': detailDate ?? row['tanggal'],
          'armada_start_date': detailDate ?? row['armada_start_date'],
          'armada_end_date': detailValue(detail, row, 'armada_end_date') ??
              row['armada_end_date'],
          'lokasi_muat': detailValue(detail, row, 'lokasi_muat'),
          'lokasi_bongkar': detailValue(detail, row, 'lokasi_bongkar'),
          'muatan': detailValue(detail, row, 'muatan'),
          'nama_supir':
              useManualArmada ? null : detailValue(detail, row, 'nama_supir'),
          'armada_id':
              useManualArmada ? null : detailValue(detail, row, 'armada_id'),
          'armada_manual': useManualArmada ? detailArmadaManual : null,
          'armada_label': useManualArmada ? detailArmadaManual : null,
          'tonase': positiveDetailNumber(detail, row, 'tonase'),
          'harga': positiveDetailNumber(detail, row, 'harga'),
          'total_biaya': subtotal,
          'pph': pph,
          'total_bayar': totalBayar,
        });
      }
    }
    return expanded;
  }

  Future<List<dynamic>> _load() async {
    if (_isPengurus && _currentUserId.isEmpty) {
      return const [<Map<String, dynamic>>[], <Map<String, dynamic>>[]];
    }
    final now = DateTime.now();
    final since = DateTime(now.year, now.month - 1, 1);
    final scopedUserId = _isPengurus ? _currentUserId : null;
    const int? fetchLimit = null;
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
    final expandedIncomes = _expandIncomeRowsForInvoiceList(scopedIncomes);
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
      return [expandedIncomes, scopedExpenses];
    }

    final filteredIncomes = expandedIncomes.where((item) {
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
        await _syncInvoiceDetailDatesInBackground() || hasVisibleChanges;
    hasVisibleChanges =
        await _backfillIncomePricingInBackground() || hasVisibleChanges;
    hasVisibleChanges =
        await _cleanupManualArmadaAutoSanguInBackground() || hasVisibleChanges;
    hasVisibleChanges =
        await _normalizeInvoiceNumbersInBackground() || hasVisibleChanges;
    return hasVisibleChanges;
  }

  Future<bool> _syncInvoiceDetailDatesInBackground() async {
    if (_invoiceDetailDateSyncDone || _backgroundInvoiceDateSyncRunning) {
      return false;
    }
    _backgroundInvoiceDateSyncRunning = true;
    try {
      final report =
          await widget.repository.syncSingleDetailInvoiceDepartureDates();
      _invoiceDetailDateSyncDone = true;
      return report.hasChanges;
    } catch (_) {
      // Best effort: sinkron tanggal detail tidak boleh menghambat list.
      return false;
    } finally {
      _backgroundInvoiceDateSyncRunning = false;
    }
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
        final dateSyncReport =
            await widget.repository.syncSingleDetailInvoiceDepartureDates();
        final pricingReport = await widget.repository
            .backfillSpecialIncomePricingForExistingInvoices();
        final report = await widget.repository
            .backfillAutoSanguExpensesForExistingInvoices();
        if (mounted &&
            (dateSyncReport.hasFailures ||
                pricingReport.hasFailures ||
                report.hasFailures)) {
          _snack(
            _t(
              'Sebagian sinkron tanggal invoice, pricing invoice lama, atau auto expense sangu/gabungan belum berhasil. Coba refresh sekali lagi.',
              'Some invoice date syncs, legacy pricing updates, or driver/manual-fleet auto expenses could not be synced yet. Please refresh once more.',
            ),
            error: true,
          );
        }
        _incomePricingBackfillDone = true;
        _invoiceDetailDateSyncDone = true;
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
          '${item['status'] ?? item['__status'] ?? ''}'.trim();
      if (orderId.isNotEmpty && !isPaidPaymentStatus(invoiceStatus)) {
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
      manualPaidAmount: batch.manualPaidAmount,
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
      final groupById = <String, _InvoicePrintGroup>{
        for (final group in selectedGroups) group.id: group,
      };

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
                  final group = groupById[id];
                  if (group != null) {
                    noInvoiceControllers[id]?.text =
                        _buildNextPrintInvoiceNumberForDate(
                      issuedDate: picked,
                      group: group,
                      incomes: allPrintableIncomes,
                      fixedInvoiceBatches: fixedInvoiceBatches,
                    );
                  }
                });
              }

              final mediaWidth = MediaQuery.sizeOf(context).width;
              final dialogWidth = min(640.0, max(300.0, mediaWidth - 32));
              return AlertDialog(
                title: Text(_t('Edit KOP Invoice', 'Edit Invoice Header')),
                content: SizedBox(
                  width: dialogWidth,
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
            final mediaWidth = MediaQuery.sizeOf(context).width;
            final dialogWidth = min(700.0, max(420.0, mediaWidth - 24));
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 20,
              ),
              title: Text(_t('Cetak Invoice', 'Print Invoice')),
              content: SizedBox(
                width: dialogWidth,
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
                              child: const Text('CV'),
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
                              child: const Text('PT'),
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
                              child: const Text('Pribadi'),
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
                                    reportMonthName(
                                      index + 1,
                                      isEnglish: _isEn,
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
    final invoiceListIncomeInvoices =
        (await widget.repository.fetchInvoices()).where((item) {
      final id = '${item['id'] ?? ''}'.trim();
      if (id.isNotEmpty && _locallyRemovedRowIds.contains(id)) {
        return false;
      }
      if (_isPengurus) return _isOwnedByCurrentUser(item);
      if (_isAdminOrOwner) return _isPengurusIncomeApproved(item);
      return true;
    }).toList();
    final reportExpenseSources = (await () async {
      try {
        return await widget.repository.fetchExpenses();
      } catch (_) {
        return expenses;
      }
    }())
        .where((item) {
      final id = '${item['id'] ?? ''}'.trim();
      if (id.isNotEmpty && _locallyRemovedRowIds.contains(id)) {
        return false;
      }
      if (_isPengurus) return _isOwnedByCurrentUser(item);
      return true;
    }).toList();
    final reportArmadas = await (() async {
      try {
        return await widget.repository.fetchArmadas();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    })();
    final reportArmadaPlateById = <String, String>{
      for (final armada in reportArmadas)
        '${armada['id'] ?? ''}'.trim():
            '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
    };
    final reportArmadaPlateByName = <String, String>{
      for (final armada in reportArmadas)
        _normalizeArmadaNameKey('${armada['nama_truk'] ?? ''}'):
            '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
    };
    final reportHargaPerTonRules = await (() async {
      try {
        return await widget.repository.fetchHargaPerTonRules();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    })();

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
      final status = resolveIncomeReportStatus(invoice);
      if (isPartialPaymentStatus(status)) return false;
      if (isPaidPaymentStatus(status)) return true;
      final paidAt = resolveIncomeReportPaidAt(invoice);
      return paidAt.isNotEmpty && !isUnpaidPaymentStatus(status);
    }

    double resolveSingleInvoiceJumlah(Map<String, dynamic> invoice) {
      return _resolveInvoiceJumlahWithSpecialRules(invoice);
    }

    double resolveSingleInvoicePph(Map<String, dynamic> invoice) {
      final isCompany = _resolveIsCompanyInvoice(
        invoiceNumber: resolveIncomeReportInvoiceNumber(invoice),
        customerName: resolveIncomeReportCustomerName(invoice),
      );
      if (!isCompany) return 0;
      return calculateInvoicePph2Percent(resolveSingleInvoiceJumlah(invoice));
    }

    double resolveSingleInvoiceTotal(Map<String, dynamic> invoice) {
      final jumlah = resolveSingleInvoiceJumlah(invoice);
      final isCompany = _resolveIsCompanyInvoice(
        invoiceNumber: resolveIncomeReportInvoiceNumber(invoice),
        customerName: resolveIncomeReportCustomerName(invoice),
      );
      if (isCompany) return calculateInvoiceTotalAfterPph(jumlah);
      final totalBayar = _toNum(invoice['total_bayar']);
      if (totalBayar > 0) return totalBayar;
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
      final summaryPaidAmount = max(0.0, paymentSummary.paidAmount);
      final manualPaidAmount = max(
        batch.manualPaidAmount,
        paymentSummary.manualPaidAmount,
      );
      final latestPaidAt = latestReportPaidAt([
        batch.paidAt,
        paymentSummary.paidAt,
        ...paymentSummary.entries.where((entry) => entry.paid).map(
              (entry) => entry.paidAt,
            ),
        ...storedPaidEntries.map((entry) => entry.paidAt),
      ]);

      if (manualPaidAmount > 0) {
        final paidAmount = min(total, manualPaidAmount);
        final remainingAmount = fixedInvoiceRoundedRemaining(
          total: total,
          paid: paidAmount,
        );
        return (
          paidAmount: paidAmount,
          remainingAmount: remainingAmount,
          paidAt: latestPaidAt,
          status: remainingAmount <= 0 ? 'Paid' : 'Partial',
          paidLocked: remainingAmount <= 0,
        );
      }

      if (isPaidPaymentStatus(batchStatus) || paymentSummary.allPaid) {
        return (
          paidAmount: total,
          remainingAmount: 0.0,
          paidAt: latestPaidAt,
          status: paymentStatusPaid,
          paidLocked: true,
        );
      }

      final paidAmount = summaryPaidAmount > 0
          ? min(total, summaryPaidAmount)
          : (() {
              final ratio =
                  paymentBaseTotal > 0 ? total / paymentBaseTotal : 1.0;
              return min(total, max(0.0, storedPaidBase * ratio));
            })();
      final remainingAmount = fixedInvoiceRoundedRemaining(
        total: total,
        paid: paidAmount,
      );
      final paidByRounding = paidAmount > 0 && remainingAmount <= 0;
      final hasPartialPayment = paidAmount > 0 || paymentSummary.anyPaid;
      final status = paidByRounding
          ? paymentStatusPaid
          : hasPartialPayment || isPartialPaymentStatus(batchStatus)
              ? paymentStatusPartial
              : (batchStatus.isEmpty ? paymentStatusUnpaid : batchStatus);

      return (
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        paidAt: hasPartialPayment ? latestPaidAt : '',
        status: status,
        paidLocked: paidByRounding,
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

    String normalizeReportClassifierText(dynamic value) {
      return normalizeExpenseClassifierText(value);
    }

    bool isReportAutoSanguExpense(Map<String, dynamic> expense) {
      return isAutoSanguExpense(expense);
    }

    bool isReportGabunganExpense(Map<String, dynamic> expense) {
      return isGabunganExpense(expense);
    }

    bool isReportSanguExpense(Map<String, dynamic> expense) {
      return isSanguExpense(expense);
    }

    String reportLinkToken(dynamic value) {
      return expenseLinkToken(value);
    }

    String extractReportExpenseMarker(Map<String, dynamic> expense) {
      return extractAutoExpenseMarker(expense);
    }

    bool isAntokTongkangMaspionLangonReportRow(
      Map<String, dynamic> detail,
      Map<String, dynamic> invoice, {
      String? resolvedMuat,
      String? resolvedBongkar,
    }) {
      final customerKey =
          normalizeReportClassifierText(invoice['nama_pelanggan']);
      if (!customerKey.contains('antok')) return false;
      final muatKey = normalizeReportClassifierText(
        resolvedMuat ?? detail['lokasi_muat'] ?? invoice['lokasi_muat'] ?? '',
      );
      final bongkarKey = normalizeReportClassifierText(
        resolvedBongkar ??
            detail['lokasi_bongkar'] ??
            invoice['lokasi_bongkar'] ??
            '',
      );
      final isLangon = bongkarKey == 't langon' ||
          bongkarKey == 'langon' ||
          bongkarKey == 'tlangon' ||
          bongkarKey.contains('langon');
      return muatKey.contains('maspion') && isLangon;
    }

    bool incomeUsesReportGabunganArmada(Map<String, dynamic> income) {
      final details = _toDetailList(income['rincian']);
      if (details.isNotEmpty) {
        return details.any(
          (row) =>
              _isManualArmadaRow(row) &&
              !isAntokTongkangMaspionLangonReportRow(row, income),
        );
      }
      return _isManualArmadaRow(income) &&
          !isAntokTongkangMaspionLangonReportRow(income, income);
    }

    List<String> reportIncomeSourceIds(Map<String, dynamic> income) {
      final batchIds =
          (income['__batch_invoice_ids'] as List<dynamic>? ?? const <dynamic>[])
              .map((id) => '$id'.trim())
              .where((id) => id.isNotEmpty)
              .toList(growable: false);
      if (batchIds.isNotEmpty) return batchIds;
      final id = '${income['id'] ?? ''}'.trim();
      return id.isEmpty ? const <String>[] : <String>[id];
    }

    double resolveReportGabunganIncomeAmount(
      Map<String, dynamic> income, {
      required double total,
    }) {
      final batchItems =
          (income['__batch_items'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false);
      if (batchItems.isNotEmpty) {
        return batchItems.fold<double>(
          0,
          (sum, item) => incomeUsesReportGabunganArmada(item)
              ? sum + resolveSingleInvoiceTotal(item)
              : sum,
        );
      }
      return incomeUsesReportGabunganArmada(income) ? total : 0.0;
    }

    double resolveReportDetailSubtotal(
      Map<String, dynamic> detail,
      Map<String, dynamic> invoice,
    ) {
      return resolveInvoiceDetailSubtotal(
        detail,
        fallback: invoice,
        fallbackSubtotal: resolveSingleInvoiceJumlah(invoice),
      );
    }

    String reportDestinationFromPaymentRoute(String routeLabel) {
      final text = routeLabel.trim();
      if (text.isEmpty || text == '-') return '';
      final separator = text.indexOf('-');
      final destination =
          separator >= 0 ? text.substring(separator + 1).trim() : text;
      return destination == '-' ? '' : destination;
    }

    String resolveHighestDestinationLabel(
      Iterable<({String destination, double total})> entries,
    ) {
      final totals = <String, double>{};
      final labels = <String, String>{};
      final order = <String, int>{};
      var index = 0;
      for (final entry in entries) {
        final destination = entry.destination.trim();
        if (destination.isEmpty || destination == '-') continue;
        final key = normalizeReportClassifierText(destination);
        if (key.isEmpty) continue;
        labels.putIfAbsent(key, () => destination);
        order.putIfAbsent(key, () => index++);
        totals[key] = (totals[key] ?? 0) + max(0.0, entry.total);
      }
      if (totals.isEmpty) return '';
      final bestKey = totals.keys.reduce((a, b) {
        final byTotal = (totals[b] ?? 0).compareTo(totals[a] ?? 0);
        if (byTotal != 0) return byTotal > 0 ? b : a;
        return (order[a] ?? 0) <= (order[b] ?? 0) ? a : b;
      });
      return labels[bestKey] ?? '';
    }

    String resolveIncomeReportOutstandingDestination(
      Map<String, dynamic> source,
    ) {
      final paymentEntries =
          _toFixedInvoicePaymentEntryList(source['__payment_details']);
      if (paymentEntries.isNotEmpty) {
        final destination = resolveHighestDestinationLabel(
          paymentEntries.where((entry) => !entry.paid).map(
                (entry) => (
                  destination:
                      reportDestinationFromPaymentRoute(entry.routeLabel),
                  total: entry.total,
                ),
              ),
        );
        if (destination.isNotEmpty) return destination;
        return '';
      }

      final batchItems =
          (source['__batch_items'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList(growable: false);
      final invoices =
          batchItems.isNotEmpty ? batchItems : <Map<String, dynamic>>[source];
      final destinations = <({String destination, double total})>[];
      for (final invoice in invoices) {
        final details = _toDetailList(invoice['rincian']);
        final detailRows = details.isEmpty
            ? <Map<String, dynamic>>[Map<String, dynamic>.from(invoice)]
            : details;
        for (final detail in detailRows) {
          final destination =
              '${detail['lokasi_bongkar'] ?? invoice['lokasi_bongkar'] ?? ''}'
                  .trim();
          destinations.add((
            destination: destination,
            total: resolveReportDetailSubtotal(detail, invoice),
          ));
        }
      }
      return resolveHighestDestinationLabel(destinations);
    }

    String resolveIncomeReportPaidColumnDisplay(
      Map<String, dynamic> source, {
      required String paidAt,
      required bool paidLocked,
    }) {
      if (paidLocked) return paidAt.trim();
      final destination = resolveIncomeReportOutstandingDestination(source);
      if (destination.isNotEmpty) return destination;
      return paidAt.trim();
    }

    String normalizeGabunganReportRouteKey(dynamic value) {
      return normalizeGabunganRouteKey(value);
    }

    double resolveGabunganReportHargaPerTon({
      required String muat,
      required String bongkar,
    }) {
      return resolveGabunganHargaPerKg(
        pickup: muat,
        destination: bongkar,
        rules: reportHargaPerTonRules,
      );
    }

    String gabunganReportRouteKey({
      required String muat,
      required String bongkar,
    }) {
      return gabunganRouteKey(pickup: muat, destination: bongkar);
    }

    final observedCompanyHargaByRoute = <String, double>{};
    final observedCompanyHargaByDestination = <String, double>{};

    String reportDetailTextForPrice(
      Map<String, dynamic> detail,
      Map<String, dynamic> invoice,
      String key,
    ) {
      final direct = '${detail[key] ?? ''}'.trim();
      if (direct.isNotEmpty && direct != '-') return direct;
      final fallback = '${invoice[key] ?? ''}'.trim();
      return fallback.isEmpty ? '-' : fallback;
    }

    void absorbObservedCompanyHarga(Map<String, dynamic> invoice) {
      final details = _toDetailList(invoice['rincian']);
      final effectiveDetails =
          details.isEmpty ? <Map<String, dynamic>>[invoice] : details;
      for (final detail in effectiveDetails) {
        if (_isManualArmadaRow(detail) || _isManualArmadaRow(invoice)) {
          continue;
        }
        final harga = _toNum(detail['harga'] ?? invoice['harga']);
        if (harga <= 0) continue;
        final muat = reportDetailTextForPrice(detail, invoice, 'lokasi_muat');
        final bongkar =
            reportDetailTextForPrice(detail, invoice, 'lokasi_bongkar');
        final routeKey = gabunganReportRouteKey(muat: muat, bongkar: bongkar);
        final destinationKey = normalizeGabunganReportRouteKey(bongkar);
        if (routeKey.trim().isNotEmpty) {
          observedCompanyHargaByRoute.putIfAbsent(routeKey, () => harga);
        }
        if (destinationKey.isNotEmpty) {
          observedCompanyHargaByDestination.putIfAbsent(
            destinationKey,
            () => harga,
          );
        }
      }
    }

    for (final invoice in [
      ...invoiceListIncomeInvoices,
      ...reportIncomeInvoices,
    ]) {
      absorbObservedCompanyHarga(invoice);
    }

    double resolveRuleCompanyHargaPerTon({
      required String customerName,
      required String muat,
      required String bongkar,
    }) {
      final pickupKey = normalizeIncomePricingRuleKey(muat);
      final destinationKey = normalizeIncomePricingRuleKey(bongkar);
      final candidates = <Map<String, dynamic>>[];
      for (final rule in reportHargaPerTonRules) {
        if (rule['is_active'] == false) continue;
        final harga = _toNum(rule['harga_per_ton']);
        if (harga <= 0) continue;
        final ruleBongkar =
            normalizeIncomePricingRuleKey('${rule['lokasi_bongkar'] ?? ''}');
        if (!incomePricingLocationKeyMatches(destinationKey, ruleBongkar)) {
          continue;
        }
        final ruleMuat =
            normalizeIncomePricingRuleKey('${rule['lokasi_muat'] ?? ''}');
        if (ruleMuat.isNotEmpty &&
            !incomePricingLocationKeyMatches(pickupKey, ruleMuat)) {
          continue;
        }
        final ruleCustomer =
            normalizeIncomePricingRuleKey('${rule['customer_name'] ?? ''}');
        if (ruleCustomer.isNotEmpty &&
            !incomePricingCustomerNameMatches(customerName, ruleCustomer)) {
          continue;
        }
        candidates.add(rule);
      }
      if (candidates.isEmpty) return 0.0;
      candidates.sort((a, b) {
        int score(Map<String, dynamic> rule) {
          final hasCustomer =
              normalizeIncomePricingRuleKey('${rule['customer_name'] ?? ''}')
                  .isNotEmpty;
          final hasPickup =
              normalizeIncomePricingRuleKey('${rule['lokasi_muat'] ?? ''}')
                  .isNotEmpty;
          return (hasCustomer ? 10000 : 0) +
              (hasPickup ? 1000 : 0) +
              _toNum(rule['priority']).round();
        }

        return score(b).compareTo(score(a));
      });
      return _toNum(candidates.first['harga_per_ton']);
    }

    double resolveGabunganReportLaba({
      required Map<String, dynamic> detail,
      required Map<String, dynamic> invoice,
      required String muat,
      required String bongkar,
    }) {
      final gabunganHarga = resolveGabunganReportHargaPerTon(
        muat: muat,
        bongkar: bongkar,
      );
      final tonase = _toNum(detail['tonase'] ?? invoice['tonase']);
      if (gabunganHarga <= 0 || tonase <= 0) return 0.0;

      double resolveCompanyHargaPerTon() {
        final routeKey = gabunganReportRouteKey(muat: muat, bongkar: bongkar);
        final observedRouteHarga = observedCompanyHargaByRoute[routeKey] ?? 0.0;
        if (observedRouteHarga > 0) return observedRouteHarga;

        final destinationKey = normalizeGabunganReportRouteKey(bongkar);
        final observedDestinationHarga =
            observedCompanyHargaByDestination[destinationKey] ?? 0.0;
        if (observedDestinationHarga > 0) return observedDestinationHarga;

        final ruleHarga = resolveRuleCompanyHargaPerTon(
          customerName: '${invoice['nama_pelanggan'] ?? ''}',
          muat: muat,
          bongkar: bongkar,
        );
        if (ruleHarga > 0) return ruleHarga;

        final rule = resolveBuiltInIncomePricingRule(
          customerName: '${invoice['nama_pelanggan'] ?? ''}',
          pickup: muat,
          destination: bongkar,
        );
        final builtInHarga = _toNum(rule?['harga_per_ton']);
        if (builtInHarga > 0) return builtInHarga;

        final storedHarga = _toNum(detail['harga'] ?? invoice['harga']);
        if (storedHarga > gabunganHarga) return storedHarga;

        if (destinationKey == 'semarang') return 165.0;
        return 0.0;
      }

      final companyHarga = resolveCompanyHargaPerTon();
      if (companyHarga <= 0) return 0.0;

      final gabunganTotal = tonase * gabunganHarga;
      final companyTotal = tonase * companyHarga;
      return roundInvoiceRupiah(companyTotal - gabunganTotal);
    }

    String resolveReportDetailText(
      Map<String, dynamic> detail,
      Map<String, dynamic> invoice,
      String key,
    ) {
      final direct = '${detail[key] ?? ''}'.trim();
      if (direct.isNotEmpty && direct != '-') return direct;
      final fallback = '${invoice[key] ?? ''}'.trim();
      return fallback.isEmpty ? '-' : fallback;
    }

    final reportSanguByIncomeId = <String, double>{};
    final reportSanguExpensesByIncomeId =
        <String, List<Map<String, dynamic>>>{};
    final mergedReportExpenseIds = <String>{};

    String resolveReportDetailPlate(
      Map<String, dynamic> detail,
      Map<String, dynamic> invoice,
    ) {
      String dateKey(dynamic value) {
        final date = Formatters.parseDate(value);
        if (date == null) return '${value ?? ''}'.trim();
        final month = date.month.toString().padLeft(2, '0');
        final day = date.day.toString().padLeft(2, '0');
        return '${date.year}-$month-$day';
      }

      String? plateFromDriverText(String text) {
        final driverKey = normalizeReportClassifierText(text);
        if (driverKey.isEmpty) return null;
        for (final entry in _defaultDriverByPlate.entries) {
          final mappedDriver = normalizeReportClassifierText(entry.value);
          if (mappedDriver.isEmpty) continue;
          if (driverKey == mappedDriver ||
              driverKey.contains(mappedDriver) ||
              mappedDriver.contains(driverKey)) {
            return _normalizePlateText(entry.key);
          }
        }
        return null;
      }

      String? plateFromExpenseRow(Map<String, dynamic> row) {
        final direct = _resolveDetailPlateText(
          row,
          armadaPlateById: reportArmadaPlateById,
          armadaPlateByName: reportArmadaPlateByName,
        );
        if (direct.trim().isNotEmpty && direct != '-') return direct;
        for (final value in [
          row['nama'],
          row['name'],
          row['keterangan'],
          row['note'],
          row['armada_manual'],
          row['armada_label'],
          row['armada'],
        ]) {
          final plate = _extractPlateFromText('${value ?? ''}');
          if (plate != null && plate.trim().isNotEmpty && plate != '-') {
            return _normalizePlateText(plate);
          }
        }
        return plateFromDriverText([
          row['nama_supir'],
          row['nama_sopir'],
          row['supir'],
          row['driver'],
        ].map((value) => '${value ?? ''}').join(' '));
      }

      final detailPlate = _resolveDetailPlateText(
        detail,
        armadaPlateById: reportArmadaPlateById,
        armadaPlateByName: reportArmadaPlateByName,
        fallbackArmadaId: '${invoice['armada_id'] ?? ''}',
      );
      if (detailPlate.trim().isNotEmpty && detailPlate != '-') {
        return detailPlate;
      }
      final invoicePlate = _resolveDetailPlateText(
        invoice,
        armadaPlateById: reportArmadaPlateById,
        armadaPlateByName: reportArmadaPlateByName,
      );
      if (invoicePlate.trim().isNotEmpty && invoicePlate != '-') {
        return invoicePlate;
      }

      final invoiceId = '${invoice['id'] ?? ''}'.trim();
      final linkedExpenses = reportSanguExpensesByIncomeId[invoiceId];
      if (linkedExpenses != null && linkedExpenses.isNotEmpty) {
        final detailDate = dateKey(
          detail['armada_start_date'] ??
              detail['tanggal'] ??
              invoice['armada_start_date'] ??
              invoice['tanggal'] ??
              invoice['tanggal_kop'] ??
              invoice['created_at'],
        );
        final detailMuat = normalizeReportClassifierText(
          resolveReportDetailText(detail, invoice, 'lokasi_muat'),
        );
        final detailBongkar = normalizeReportClassifierText(
          resolveReportDetailText(detail, invoice, 'lokasi_bongkar'),
        );
        String? firstLinkedPlate;
        for (final expense in linkedExpenses) {
          final expenseDetails = _toDetailList(expense['rincian']);
          final effectiveExpenseRows = expenseDetails.isEmpty
              ? <Map<String, dynamic>>[expense]
              : expenseDetails;
          for (final expenseDetail in effectiveExpenseRows) {
            final expenseRow = <String, dynamic>{
              ...expense,
              ...expenseDetail,
            };
            final plate = plateFromExpenseRow(expenseRow);
            if (plate == null || plate.isEmpty || plate == '-') continue;
            firstLinkedPlate ??= plate;
            final expenseDate = dateKey(
              expenseRow['armada_start_date'] ??
                  expenseRow['tanggal'] ??
                  expense['tanggal'] ??
                  expense['created_at'],
            );
            final expenseMuat = normalizeReportClassifierText(
              '${expenseRow['lokasi_muat'] ?? expense['lokasi_muat'] ?? ''}',
            );
            final expenseBongkar = normalizeReportClassifierText(
              '${expenseRow['lokasi_bongkar'] ?? expense['lokasi_bongkar'] ?? ''}',
            );
            final routeMatches =
                (expenseMuat.isEmpty || expenseMuat == detailMuat) &&
                    (expenseBongkar.isEmpty || expenseBongkar == detailBongkar);
            final dateMatches = expenseDate.isEmpty ||
                detailDate.isEmpty ||
                expenseDate == detailDate;
            if (routeMatches && dateMatches) return plate;
          }
        }
        if (firstLinkedPlate != null) return firstLinkedPlate;
      }

      final driverText = [
        detail['nama_supir'],
        detail['nama_sopir'],
        detail['driver'],
        invoice['nama_supir'],
        invoice['nama_sopir'],
        invoice['driver'],
      ].map((value) => '${value ?? ''}').join(' ');
      return plateFromDriverText(driverText) ?? '-';
    }

    dynamic resolveReportDetailDate(
      Map<String, dynamic> detail,
      Map<String, dynamic> invoice,
    ) {
      for (final value in [
        detail['armada_start_date'],
        detail['tanggal'],
        invoice['armada_start_date'],
        invoice['tanggal'],
        invoice['tanggal_kop'],
        invoice['created_at'],
      ]) {
        if (Formatters.parseDate(value) != null) return value;
      }
      return invoice['tanggal_kop'] ??
          invoice['tanggal'] ??
          invoice['created_at'];
    }

    String reportDateGroupKey(dynamic value) {
      final date = Formatters.parseDate(value);
      if (date == null) return '${value ?? ''}'.trim();
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '${date.year}-$month-$day';
    }

    String? resolveTokenLinkedReportIncomeId({
      required Map<String, dynamic> expense,
      required Map<String, String> incomeIdByToken,
    }) {
      final markerToken = reportLinkToken(extractReportExpenseMarker(expense));
      if (markerToken.isNotEmpty && incomeIdByToken[markerToken] != null) {
        return incomeIdByToken[markerToken];
      }

      final textToken = reportLinkToken([
        expense['note'],
        expense['keterangan'],
        expense['kategori'],
        expense['no_expense'],
      ].map((value) => '${value ?? ''}').join(' '));
      if (textToken.isEmpty) return null;
      for (final entry in incomeIdByToken.entries) {
        if (entry.key.length < 5) continue;
        if (textToken.contains(entry.key)) return entry.value;
      }
      return null;
    }

    String? parseRoutePartFromText(String text, int index) {
      final match = RegExp(r'\(([^()]+)\)').firstMatch(text);
      if (match == null) return null;
      final parts = (match.group(1) ?? '')
          .split(RegExp(r'\s*[-–—]\s*'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      if (parts.length <= index) return null;
      return parts[index];
    }

    String reportRouteMatchKey({
      required dynamic date,
      required dynamic plate,
      required dynamic muat,
      required dynamic bongkar,
    }) {
      final dateKey = reportDateGroupKey(date);
      final plateKey = _normalizePlateText('${plate ?? ''}');
      final muatKey = normalizeReportClassifierText(muat);
      final bongkarKey = normalizeReportClassifierText(bongkar);
      if (dateKey.isEmpty ||
          plateKey.isEmpty ||
          plateKey == '-' ||
          muatKey.isEmpty ||
          muatKey == '-' ||
          bongkarKey.isEmpty ||
          bongkarKey == '-') {
        return '';
      }
      return '$dateKey|$plateKey|$muatKey|$bongkarKey';
    }

    List<String> reportExpenseRouteMatchKeys(Map<String, dynamic> expense) {
      final details = _toDetailList(expense['rincian']);
      final effectiveRows =
          details.isEmpty ? <Map<String, dynamic>>[expense] : details;
      final keys = <String>[];
      for (final detail in effectiveRows) {
        final row = <String, dynamic>{...expense, ...detail};
        final text = [
          row['nama'],
          row['name'],
          row['keterangan'],
          row['note'],
        ].map((value) => '${value ?? ''}').join(' ');
        final muat = '${row['lokasi_muat'] ?? ''}'.trim().isNotEmpty
            ? row['lokasi_muat']
            : parseRoutePartFromText(text, 0);
        final bongkar = '${row['lokasi_bongkar'] ?? ''}'.trim().isNotEmpty
            ? row['lokasi_bongkar']
            : parseRoutePartFromText(text, 1);
        final plate = _resolveDetailPlateText(
          row,
          armadaPlateById: reportArmadaPlateById,
          armadaPlateByName: reportArmadaPlateByName,
        );
        final key = reportRouteMatchKey(
          date: row['armada_start_date'] ??
              row['tanggal'] ??
              expense['tanggal'] ??
              expense['created_at'],
          plate: plate,
          muat: muat,
          bongkar: bongkar,
        );
        if (key.isNotEmpty) keys.add(key);
      }
      return keys;
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
      final isCompanyBatch = _resolveIsCompanyInvoice(
        invoiceEntity: batchItems.first['invoice_entity'],
        invoiceNumber: invoiceNumber,
        customerName: customerName,
      );
      final pph = isCompanyBatch ? calculateInvoicePph2Percent(jumlah) : 0.0;
      final total =
          isCompanyBatch ? calculateInvoiceTotalAfterPph(jumlah) : jumlah;
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

    final fixedInvoiceSourceIds = <String>{
      ...reportIncomeSources.expand((item) {
        final ids =
            (item['__batch_invoice_ids'] as List<dynamic>? ?? const <dynamic>[])
                .map((id) => '$id'.trim())
                .where((id) => id.isNotEmpty)
                .toList(growable: false);
        if (ids.isNotEmpty) return ids;
        final directId = '${item['id'] ?? ''}'.trim();
        return directId.isEmpty ? const <String>[] : <String>[directId];
      }),
    };
    final detailIncomeReportSources = <Map<String, dynamic>>[
      ...reportIncomeSources,
      ...invoiceListIncomeInvoices.where((item) {
        final id = '${item['id'] ?? ''}'.trim();
        return id.isEmpty || !fixedInvoiceSourceIds.contains(id);
      }),
    ];

    final invoiceListIncomeById = <String, Map<String, dynamic>>{};
    final invoiceListIncomeIdByToken = <String, String>{};
    final invoiceListIncomeIdByRouteMatchKey = <String, String>{};
    final ambiguousRouteMatchKeys = <String>{};

    void indexUniqueRouteMatchKey(String key, String id) {
      if (key.isEmpty || id.isEmpty || ambiguousRouteMatchKeys.contains(key)) {
        return;
      }
      final existing = invoiceListIncomeIdByRouteMatchKey[key];
      if (existing == null || existing == id) {
        invoiceListIncomeIdByRouteMatchKey[key] = id;
        return;
      }
      invoiceListIncomeIdByRouteMatchKey.remove(key);
      ambiguousRouteMatchKeys.add(key);
    }

    for (final income in invoiceListIncomeInvoices) {
      final id = '${income['id'] ?? ''}'.trim();
      if (id.isEmpty) continue;
      invoiceListIncomeById[id] = income;
      void indexToken(dynamic value) {
        final token = reportLinkToken(value);
        if (token.isNotEmpty) {
          invoiceListIncomeIdByToken.putIfAbsent(token, () => id);
        }
      }

      indexToken(id);
      indexToken(income['no_invoice']);
      indexToken(
        Formatters.invoiceNumber(
          income['no_invoice'],
          resolveIncomeReportInvoiceDate(income),
          customerName: income['nama_pelanggan'],
          invoiceEntity: income['invoice_entity'],
        ),
      );

      final details = _toDetailList(income['rincian']);
      final effectiveDetails =
          details.isEmpty ? <Map<String, dynamic>>[income] : details;
      for (final detail in effectiveDetails) {
        final muat = resolveReportDetailText(detail, income, 'lokasi_muat');
        final bongkar =
            resolveReportDetailText(detail, income, 'lokasi_bongkar');
        final plate = resolveReportDetailPlate(detail, income);
        final key = reportRouteMatchKey(
          date: resolveReportDetailDate(detail, income),
          plate: plate,
          muat: muat,
          bongkar: bongkar,
        );
        indexUniqueRouteMatchKey(key, id);
      }
    }

    String? resolveRouteLinkedReportIncomeId(Map<String, dynamic> expense) {
      final matchedIds = <String>{};
      for (final key in reportExpenseRouteMatchKeys(expense)) {
        final id = invoiceListIncomeIdByRouteMatchKey[key];
        if (id != null && id.isNotEmpty) matchedIds.add(id);
      }
      return matchedIds.length == 1 ? matchedIds.single : null;
    }

    final tokenLinkedSanguIncomeIds = <String>{};
    for (final expense in reportExpenseSources) {
      final amount = _toNum(expense['total_pengeluaran']);
      if (amount <= 0) continue;
      final linkedIncomeId = resolveTokenLinkedReportIncomeId(
        expense: expense,
        incomeIdByToken: invoiceListIncomeIdByToken,
      );
      if (linkedIncomeId == null || linkedIncomeId.isEmpty) continue;
      final linkedIncome = invoiceListIncomeById[linkedIncomeId];
      final linkedUsesGabungan =
          linkedIncome != null && incomeUsesReportGabunganArmada(linkedIncome);
      final isGabungan = linkedUsesGabungan || isReportGabunganExpense(expense);
      if (!isGabungan && isReportSanguExpense(expense)) {
        tokenLinkedSanguIncomeIds.add(linkedIncomeId);
      }
    }

    for (final expense in reportExpenseSources) {
      final amount = _toNum(expense['total_pengeluaran']);
      if (amount <= 0) continue;
      final tokenLinkedIncomeId = resolveTokenLinkedReportIncomeId(
        expense: expense,
        incomeIdByToken: invoiceListIncomeIdByToken,
      );
      final fallbackLinkedIncomeId = tokenLinkedIncomeId == null
          ? resolveRouteLinkedReportIncomeId(expense)
          : null;
      final linkedIncomeId = tokenLinkedIncomeId ?? fallbackLinkedIncomeId;
      if (linkedIncomeId == null || linkedIncomeId.isEmpty) continue;
      final linkedByRouteFallback = tokenLinkedIncomeId == null;
      final linkedIncome = invoiceListIncomeById[linkedIncomeId];
      final linkedUsesGabungan =
          linkedIncome != null && incomeUsesReportGabunganArmada(linkedIncome);
      final isGabungan = linkedUsesGabungan || isReportGabunganExpense(expense);
      final isSangu = !isGabungan && isReportSanguExpense(expense);
      if (!isGabungan && !isSangu) continue;

      if (isSangu) {
        final duplicateLegacySangu = linkedByRouteFallback &&
            tokenLinkedSanguIncomeIds.contains(linkedIncomeId);
        if (!duplicateLegacySangu) {
          reportSanguByIncomeId.update(
            linkedIncomeId,
            (value) => value + amount,
            ifAbsent: () => amount,
          );
          reportSanguExpensesByIncomeId
              .putIfAbsent(linkedIncomeId, () => <Map<String, dynamic>>[])
              .add(expense);
        }
      }
      final expenseId = '${expense['id'] ?? ''}'.trim();
      if (expenseId.isNotEmpty) mergedReportExpenseIds.add(expenseId);
    }

    List<Map<String, dynamic>> buildRows({
      required DateTime start,
      required DateTime end,
      required bool includeIncome,
      required bool includeExpense,
      required bool useInvoiceListDetail,
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
        final customerName = useInvoiceListDetail
            ? '${source['nama_pelanggan'] ?? ''}'.trim()
            : resolveIncomeReportCustomerName(source);
        final invoiceNumber = useInvoiceListDetail
            ? source['no_invoice']
            : resolveIncomeReportInvoiceNumber(source);
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

      double detailExpenseAmount(Map<String, dynamic> detail) {
        for (final key in const [
          'jumlah',
          'subtotal',
          'total',
          'total_pengeluaran',
          'nominal',
        ]) {
          final amount = _toNum(detail[key]);
          if (amount > 0) return amount;
        }
        return 0;
      }

      double resolveDetailSanguAmount({
        required Map<String, dynamic> invoice,
        required Map<String, dynamic> detail,
        required int detailIndex,
        required int detailCount,
      }) {
        final invoiceId = '${invoice['id'] ?? ''}'.trim();
        if (invoiceId.isEmpty) return 0;
        final linkedExpenses = reportSanguExpensesByIncomeId[invoiceId];
        if (linkedExpenses == null || linkedExpenses.isEmpty) return 0;

        final detailDate = reportDateGroupKey(
          resolveReportDetailDate(detail, invoice),
        );
        final detailMuat = normalizeReportClassifierText(
          resolveReportDetailText(detail, invoice, 'lokasi_muat'),
        );
        final detailBongkar = normalizeReportClassifierText(
          resolveReportDetailText(detail, invoice, 'lokasi_bongkar'),
        );

        var total = 0.0;
        for (final expense in linkedExpenses) {
          final expenseDetails = _toDetailList(expense['rincian']);
          if (expenseDetails.isEmpty) {
            if (detailCount == 1) total += _toNum(expense['total_pengeluaran']);
            continue;
          }

          if (detailIndex < expenseDetails.length) {
            final indexedAmount =
                detailExpenseAmount(expenseDetails[detailIndex]);
            if (indexedAmount > 0) {
              total += indexedAmount;
              continue;
            }
          }

          var matched = 0.0;
          for (final expenseDetail in expenseDetails) {
            final expenseDate = reportDateGroupKey(
              expenseDetail['armada_start_date'] ??
                  expenseDetail['tanggal'] ??
                  expense['tanggal'] ??
                  expense['created_at'],
            );
            final expenseMuat = normalizeReportClassifierText(
              '${expenseDetail['lokasi_muat'] ?? ''}',
            );
            final expenseBongkar = normalizeReportClassifierText(
              '${expenseDetail['lokasi_bongkar'] ?? ''}',
            );
            final routeMatches =
                (expenseMuat.isEmpty || expenseMuat == detailMuat) &&
                    (expenseBongkar.isEmpty || expenseBongkar == detailBongkar);
            final dateMatches = expenseDate.isEmpty ||
                detailDate.isEmpty ||
                expenseDate == detailDate;
            if (routeMatches && dateMatches) {
              matched += detailExpenseAmount(expenseDetail);
            }
          }
          if (matched > 0) {
            total += matched;
          } else if (detailCount == 1) {
            total += _toNum(expense['total_pengeluaran']);
          }
        }
        return total;
      }

      void addIncomeDetailRows({
        required Map<String, dynamic> invoice,
        required String status,
        required String paidAt,
        required String parentInvoiceNumber,
        required String parentSortKey,
        required String sourceKey,
      }) {
        if (!incomeKindAllowed(invoice)) return;
        final details = _toDetailList(invoice['rincian']);
        final detailRows = details.isEmpty
            ? <Map<String, dynamic>>[Map<String, dynamic>.from(invoice)]
            : details;
        final customerName =
            '${invoice['nama_pelanggan'] ?? '-'}'.trim().isEmpty
                ? '-'
                : '${invoice['nama_pelanggan'] ?? '-'}'.trim();
        final invoiceNumber = Formatters.invoiceNumber(
          invoice['no_invoice'] ?? parentInvoiceNumber,
          resolveIncomeReportInvoiceDate(invoice),
          customerName: customerName,
          invoiceEntity: invoice['invoice_entity'],
        );
        final invoiceSubtotal = resolveSingleInvoiceJumlah(invoice);
        final invoicePph = _resolveIsCompanyInvoice(
          invoiceEntity: invoice['invoice_entity'],
          invoiceNumber: invoiceNumber,
          customerName: customerName,
          fallback: false,
        )
            ? calculateInvoicePph2Percent(invoiceSubtotal)
            : 0.0;
        var remainingPph = invoicePph;

        for (var detailIndex = 0;
            detailIndex < detailRows.length;
            detailIndex++) {
          final detail = detailRows[detailIndex];
          final reportDate = resolveReportDetailDate(detail, invoice);
          if (!inRange(reportDate)) continue;

          final detailSubtotal = resolveReportDetailSubtotal(detail, invoice);
          final isLastDetail = detailIndex == detailRows.length - 1;
          final detailPph = invoicePph <= 0
              ? 0.0
              : isLastDetail
                  ? remainingPph.clamp(0.0, invoicePph).toDouble()
                  : min(
                      remainingPph,
                      invoiceSubtotal > 0
                          ? (detailSubtotal * invoicePph / invoiceSubtotal)
                              .floorToDouble()
                          : calculateInvoicePph2Percent(detailSubtotal),
                    );
          remainingPph = max(0.0, remainingPph - detailPph);
          final detailTotal = max(0.0, detailSubtotal - detailPph);
          final muat = resolveReportDetailText(detail, invoice, 'lokasi_muat');
          final bongkar =
              resolveReportDetailText(detail, invoice, 'lokasi_bongkar');
          final platNomor = resolveReportDetailPlate(detail, invoice);
          final rowSource = <String, dynamic>{
            ...invoice,
            ...detail,
            'nama_pelanggan': customerName,
            'no_invoice': invoiceNumber,
            'status': status,
            'tanggal_kop': reportDate,
            'paid_at': paidAt,
            'lokasi_muat': muat,
            'lokasi_bongkar': bongkar,
          };
          if (!keywordAllowed(rowSource)) continue;

          final sanguAmount = resolveDetailSanguAmount(
            invoice: invoice,
            detail: detail,
            detailIndex: detailIndex,
            detailCount: detailRows.length,
          );
          final usesGabunganArmada =
              (_isManualArmadaRow(detail) || _isManualArmadaRow(invoice)) &&
                  !isAntokTongkangMaspionLangonReportRow(
                    detail,
                    invoice,
                    resolvedMuat: muat,
                    resolvedBongkar: bongkar,
                  );
          final gabunganAmount = usesGabunganArmada ? detailTotal : 0.0;
          final gabunganLaba = usesGabunganArmada
              ? resolveGabunganReportLaba(
                  detail: detail,
                  invoice: invoice,
                  muat: muat,
                  bongkar: bongkar,
                )
              : 0.0;
          final laba = usesGabunganArmada
              ? gabunganLaba
              : detailTotal - sanguAmount - gabunganAmount;

          rows.add({
            '__key': 'income-detail:$sourceKey:$detailIndex',
            '__type': 'Income',
            '__number': parentInvoiceNumber.isNotEmpty
                ? parentInvoiceNumber
                : invoiceNumber,
            '__invoice_sort': parentSortKey,
            '__date': reportDate,
            '__departure_date': reportDate,
            '__paid_at': paidAt,
            '__name': customerName,
            '__customer': customerName,
            '__status': status,
            '__amount': detailTotal,
            '__jumlah': detailSubtotal,
            '__pph': detailPph,
            '__total': detailTotal,
            '__plat_nomor': platNomor,
            '__muat': muat,
            '__bongkar': bongkar,
            '__tujuan': bongkar,
            '__paid_locked': false,
            '__bayar_default': 0.0,
            '__sisa_default': 0.0,
            '__income': detailTotal,
            '__expense': 0.0,
            '__sangu_sopir': sanguAmount,
            '__gabungan': gabunganAmount,
            '__laba': laba,
          });
        }
      }

      if (includeIncome) {
        final incomeSources = useInvoiceListDetail
            ? detailIncomeReportSources
            : reportIncomeSources;
        for (final item in incomeSources) {
          final status = useInvoiceListDetail
              ? '${item['status'] ?? 'Unpaid'}'.trim()
              : resolveIncomeReportStatus(item);
          if (!statusAllowed(status)) continue;
          final customerName = useInvoiceListDetail
              ? ('${item['nama_pelanggan'] ?? '-'}'.trim().isEmpty
                  ? '-'
                  : '${item['nama_pelanggan'] ?? '-'}'.trim())
              : resolveIncomeReportCustomerName(item);
          final reportDate = useInvoiceListDetail
              ? resolveIncomeReportInvoiceDate(item)
              : resolveIncomeReportDate(item);
          final paidAt = useInvoiceListDetail
              ? '${item['paid_at'] ?? ''}'.trim()
              : resolveIncomeReportPaidAt(item);
          final invoiceNumber = useInvoiceListDetail
              ? Formatters.invoiceNumber(
                  item['no_invoice'],
                  reportDate,
                  customerName: customerName,
                  invoiceEntity: item['invoice_entity'],
                )
              : resolveIncomeReportInvoiceNumber(item);
          final invoiceSortKey = buildIncomeReportInvoiceSortKey(
            invoiceNumber: invoiceNumber,
            invoiceDate: reportDate,
            customerName: customerName,
            invoiceEntity: item['invoice_entity'],
          );

          if (useInvoiceListDetail) {
            final batchItems =
                (item['__batch_items'] as List<dynamic>? ?? const <dynamic>[])
                    .whereType<Map>()
                    .map((entry) => Map<String, dynamic>.from(entry))
                    .toList(growable: false);
            if (batchItems.isNotEmpty) {
              for (var i = 0; i < batchItems.length; i++) {
                addIncomeDetailRows(
                  invoice: batchItems[i],
                  status: status,
                  paidAt: paidAt,
                  parentInvoiceNumber: invoiceNumber,
                  parentSortKey: invoiceSortKey,
                  sourceKey:
                      '${item['__batch_id'] ?? item['id'] ?? invoiceNumber}:$i',
                );
              }
            } else {
              addIncomeDetailRows(
                invoice: item,
                status: status,
                paidAt: paidAt,
                parentInvoiceNumber: invoiceNumber,
                parentSortKey: invoiceSortKey,
                sourceKey:
                    '${item['id'] ?? item['no_invoice'] ?? item['created_at'] ?? rows.length}',
              );
            }
            continue;
          }

          if (!incomeKindAllowed(item)) continue;
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
          final pph = useInvoiceListDetail
              ? (_resolveIsCompanyInvoice(
                  invoiceEntity: item['invoice_entity'],
                  invoiceNumber: invoiceNumber,
                  customerName: customerName,
                  fallback: false,
                )
                  ? calculateInvoicePph2Percent(subtotal)
                  : 0.0)
              : resolveSingleInvoicePph(item);
          final total = useInvoiceListDetail
              ? (() {
                  final fallback = subtotal - pph;
                  return fallback > 0 ? fallback : subtotal;
                })()
              : resolveSingleInvoiceTotal(item);
          final paidAmount = _toNum(item['__paid_amount']);
          final remainingAmount = _toNum(item['__remaining_amount']);
          final paidLocked = !useInvoiceListDetail &&
              (item['__report_paid_locked'] == true ||
                  isIncomeReportPaid(item));
          final lockedPaidAmount = paidAmount > 0 ? paidAmount : total;
          final defaultBayar = paidLocked ? lockedPaidAmount : paidAmount;
          final defaultSisa = paidLocked
              ? 0.0
              : (remainingAmount > 0
                  ? remainingAmount
                  : max(0.0, total - paidAmount));
          final paidColumnDisplay = resolveIncomeReportPaidColumnDisplay(
            item,
            paidAt: paidAt,
            paidLocked: paidLocked,
          );
          final incomeIds = reportIncomeSourceIds(item);
          final linkedSanguAmount = incomeIds.fold<double>(
            0,
            (sum, id) => sum + (reportSanguByIncomeId[id] ?? 0.0),
          );
          final reportGabunganAmount = useInvoiceListDetail
              ? resolveReportGabunganIncomeAmount(item, total: total)
              : 0.0;

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
            '__paid_at_display': paidColumnDisplay,
            '__plat_nomor': _resolveDetailPlateText(
              item,
              armadaPlateById: reportArmadaPlateById,
              armadaPlateByName: reportArmadaPlateByName,
            ),
            '__muat': '${item['lokasi_muat'] ?? '-'}'.trim().isEmpty
                ? '-'
                : '${item['lokasi_muat'] ?? '-'}'.trim(),
            '__bongkar': '${item['lokasi_bongkar'] ?? '-'}'.trim().isEmpty
                ? '-'
                : '${item['lokasi_bongkar'] ?? '-'}'.trim(),
            '__tujuan': useInvoiceListDetail
                ? summarizeInvoiceDestinations([item])
                : '${item['lokasi_bongkar'] ?? '-'}'.trim(),
            '__paid_locked': paidLocked,
            '__bayar_default': defaultBayar,
            '__sisa_default': defaultSisa,
            '__income': total,
            '__expense': 0.0,
            '__sangu_sopir': useInvoiceListDetail ? linkedSanguAmount : 0.0,
            '__gabungan': useInvoiceListDetail ? reportGabunganAmount : 0.0,
            '__laba': total - linkedSanguAmount - reportGabunganAmount,
          });
        }
      }

      if (includeExpense && customerKind == 'all') {
        for (final item in reportExpenseSources) {
          final expenseId = '${item['id'] ?? ''}'.trim();
          if (useInvoiceListDetail &&
              expenseId.isNotEmpty &&
              mergedReportExpenseIds.contains(expenseId)) {
            continue;
          }
          final status = '${item['status'] ?? 'Recorded'}';
          final amount = _toNum(item['total_pengeluaran']);
          if (!inRange(item['tanggal'] ?? item['created_at'])) continue;
          if (!statusAllowed(status)) continue;
          if (!keywordAllowed(item)) continue;
          final sanguAmount = isReportSanguExpense(item) ? amount : 0.0;
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
            '__plat_nomor': '-',
            '__muat': '-',
            '__bongkar': '-',
            '__tujuan': '-',
            '__paid_locked': false,
            '__bayar_default': 0.0,
            '__sisa_default': 0.0,
            '__income': 0.0,
            '__expense': amount,
            '__sangu_sopir': sanguAmount,
            '__gabungan': 0.0,
            '__laba': -amount,
            '__is_auto_sangu': isReportAutoSanguExpense(item),
          });
        }
      }

      final outputRows = rows;

      if (includeIncome && !includeExpense) {
        return sortIncomeReportRowsByInvoice(
          outputRows.where((row) => '${row['__type']}' == 'Income').toList(),
        );
      }

      outputRows.sort((a, b) {
        final aDate = Formatters.parseDate(a['__date']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = Formatters.parseDate(b['__date']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateCompare = aDate.compareTo(bDate);
        if (dateCompare != 0) return dateCompare;
        int typeRank(Map<String, dynamic> row) =>
            '${row['__type']}' == 'Income' ? 0 : 1;
        final typeCompare = typeRank(a).compareTo(typeRank(b));
        if (typeCompare != 0) return typeCompare;
        final aKey =
            '${a['__invoice_sort'] ?? a['__number'] ?? a['__key'] ?? ''}';
        final bKey =
            '${b['__invoice_sort'] ?? b['__number'] ?? b['__key'] ?? ''}';
        return aKey.compareTo(bKey);
      });

      return outputRows;
    }

    Future<bool> printReportPdf({
      required DateTime start,
      required DateTime end,
      required List<Map<String, dynamic>> rows,
      required double totalIncome,
      required double totalExpense,
      required bool includeIncome,
      required bool includeExpense,
      required bool includeDriverCostColumns,
      required String customerKind,
      required String orientation,
    }) async {
      final incomeInvoiceReport = includeIncome && !includeExpense;
      final periodLabel = reportPeriodLabel(
        start: start,
        end: end,
        isEnglish: _isEn,
      );
      final reportHeader = buildReportHeaderLabel(
        includeIncome: includeIncome,
        includeExpense: includeExpense,
        customerKind: customerKind,
        incomeByInvoice: incomeInvoiceReport,
        isEnglish: _isEn,
      );
      final reportScopeLabel = buildReportScopeLabel(
        includeIncome: includeIncome,
        includeExpense: includeExpense,
        incomeByInvoice: incomeInvoiceReport,
        isEnglish: _isEn,
      );
      final previewInfo = buildReportPreviewInfo(
        scopeLabel: reportScopeLabel,
        periodLabel: periodLabel,
        includeIncome: includeIncome,
        includeExpense: includeExpense,
        includeDriverCostColumns: includeDriverCostColumns,
        incomeByInvoice: incomeInvoiceReport,
        rowCount: rows.length,
        isEnglish: _isEn,
      );

      Future<Uint8List> buildReportPdfBytes(PdfPageFormat format) async {
        final tableMode = resolveReportTableMode(
          includeIncome: includeIncome,
          includeExpense: includeExpense,
          includeDriverCostColumns: includeDriverCostColumns,
          customerKind: customerKind,
          rows: rows,
        );
        final useIncomeInvoiceTable = tableMode.incomeInvoiceTable;
        final useCombinedDriverCostColumns =
            tableMode.combinedDriverCostColumns;
        final showCombinedPphColumn = tableMode.showCombinedPphColumn;
        final companyMode = tableMode.companyMode;
        final showIncomePphColumn = tableMode.showIncomePphColumn;
        String formatReportDate(dynamic value) => Formatters.dMyShort(value);
        String formatReportAmount(num value) => _formatRupiahNoPrefix(value);
        String formatPaidAtOrDestination(Map<String, dynamic> row) {
          final value =
              '${row['__paid_at_display'] ?? row['__paid_at'] ?? ''}'.trim();
          if (value.isEmpty) return '';
          return Formatters.parseDate(value) == null
              ? value
              : formatReportDate(value);
        }

        final reportFontSizing = buildReportTableFontSizing(
          rows: rows,
          paidAtDisplay: formatPaidAtOrDestination,
          incomeInvoiceTable: useIncomeInvoiceTable,
          combinedDriverCostColumns: useCombinedDriverCostColumns,
        );
        final headerFont = reportFontSizing.headerFont;
        final cellFont = reportFontSizing.cellFont;

        bool reportDecorationsEnabled() => false;

        final pageFormat = format;
        final showReportHeader = reportDecorationsEnabled();
        final showSummaryBox = reportDecorationsEnabled();
        final pdfFonts = await _loadDashboardPdfFontBundle();
        late final pw.Font reportTitleFont;
        pw.MemoryImage? reportLogo;
        if (showReportHeader) {
          try {
            reportTitleFont = await PdfGoogleFonts.archivoBlack();
          } catch (_) {
            reportTitleFont = pw.Font.helveticaBold();
          }
          try {
            final logoBytes = await _loadBinaryAssetWithFileFallback(
                'assets/images/iconapk.png');
            reportLogo = pw.MemoryImage(logoBytes);
          } catch (_) {
            reportLogo = null;
          }
        }

        final tableLayout = buildReportTableLayout(
          incomeInvoiceTable: useIncomeInvoiceTable,
          showIncomePphColumn: showIncomePphColumn,
          combinedDriverCostColumns: useCombinedDriverCostColumns,
          showCombinedPphColumn: showCombinedPphColumn,
          companyMode: companyMode,
        );
        final headers = tableLayout.headers;
        final tableData = List<List<String>>.generate(rows.length, (index) {
          final row = rows[index];
          return buildReportTableDataRow(
            row: row,
            rowNumber: index + 1,
            incomeInvoiceTable: useIncomeInvoiceTable,
            showIncomePphColumn: showIncomePphColumn,
            combinedDriverCostColumns: useCombinedDriverCostColumns,
            showCombinedPphColumn: showCombinedPphColumn,
            companyMode: companyMode,
            formatDate: formatReportDate,
            formatAmount: formatReportAmount,
            paidAtDisplay: formatPaidAtOrDestination(row),
          );
        });
        final reportTableData = <List<String>>[...tableData];
        reportTableData.add(
          buildReportTableTotalRow(
            rows: rows,
            incomeInvoiceTable: useIncomeInvoiceTable,
            showIncomePphColumn: showIncomePphColumn,
            combinedDriverCostColumns: useCombinedDriverCostColumns,
            showCombinedPphColumn: showCombinedPphColumn,
            companyMode: companyMode,
            formatAmount: formatReportAmount,
          ),
        );
        final numericColumns = tableLayout.numericColumns;
        final dateColumns = tableLayout.dateColumns;
        final priorityTextColumns = tableLayout.priorityTextColumns;
        final columnFlexes = buildReportColumnWidthFlexes(
          headers: headers,
          data: reportTableData,
          dateColumns: dateColumns,
          numericColumns: numericColumns,
          priorityTextColumns: priorityTextColumns,
          incomeInvoiceTable: useIncomeInvoiceTable,
          showIncomePphColumn: showIncomePphColumn,
          combinedDriverCostColumns: useCombinedDriverCostColumns,
          showCombinedPphColumn: showCombinedPphColumn,
          companyMode: companyMode,
        );
        final columnWidths = columnFlexes.map(
          (index, flex) => MapEntry(index, pw.FlexColumnWidth(flex)),
        );
        final cellAlignments = <int, pw.Alignment>{
          for (int i = 0; i < headers.length; i++) i: pw.Alignment.center,
        };
        final totalRowNumber = reportTableData.length;

        pw.Widget buildOneLineReportText(
          String value, {
          required int index,
          required bool header,
          bool totalRow = false,
        }) {
          final text = value.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
          final fontSize = resolveReportOneLineFontSize(
            index: index,
            text: text,
            header: header,
            totalRow: totalRow,
            numericColumn: numericColumns.contains(index),
            sizing: reportFontSizing,
          );
          final bold = header || totalRow;
          if (text.isEmpty) {
            return pw.SizedBox(width: 1, height: fontSize + 1);
          }
          return pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.center,
            child: pw.Text(
              text,
              maxLines: 1,
              softWrap: false,
              overflow: pw.TextOverflow.clip,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: bold ? pw.Font.helveticaBold() : null,
                fontWeight: bold ? pw.FontWeight.bold : null,
                color: PdfColors.black,
                fontSize: fontSize,
              ),
            ),
          );
        }

        final headerWidgets = <pw.Widget>[
          for (var index = 0; index < headers.length; index++)
            buildOneLineReportText(
              headers[index],
              index: index,
              header: true,
            ),
        ];

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
              if (showReportHeader) ...[
                buildReportHeader(),
                pw.SizedBox(height: 10),
              ],
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
                headers: headerWidgets,
                data: reportTableData,
                cellDecoration: (index, data, rowNum) {
                  if (rowNum == totalRowNumber) {
                    return const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    );
                  }
                  if (useIncomeInvoiceTable &&
                      index == 0 &&
                      rowNum > 0 &&
                      rowNum <= rows.length &&
                      shouldHighlightPaidIncomeNumber(
                        row: rows[rowNum - 1],
                        incomeInvoiceTable: useIncomeInvoiceTable,
                      )) {
                    return const pw.BoxDecoration(
                      color: PdfColors.yellow100,
                    );
                  }
                  return const pw.BoxDecoration();
                },
                cellBuilder: (index, data, rowNum) => buildOneLineReportText(
                  '$data',
                  index: index,
                  header: false,
                  totalRow: rowNum == totalRowNumber,
                ),
              ),
              if (showSummaryBox) ...[
                pw.SizedBox(height: 12),
                buildSummaryBox(),
              ],
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
      ...reportIncomeSources.map((item) => '${item['status'] ?? ''}'),
      ...invoiceListIncomeInvoices.map((item) => '${item['status'] ?? ''}'),
      ...reportExpenseSources.map((item) => '${item['status'] ?? 'Recorded'}'),
    }.where((status) => status.trim().isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    String range = 'month';
    String customerKind = 'all';
    bool includeIncome = true;
    bool includeExpense = true;
    bool includeDriverCostColumns = true;
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
      ...reportIncomeSources
          .map((item) =>
              Formatters.parseDate(resolveIncomeReportDate(item))?.year)
          .whereType<int>(),
      ...invoiceListIncomeInvoices
          .map((item) =>
              Formatters.parseDate(resolveIncomeReportInvoiceDate(item))?.year)
          .whereType<int>(),
      ...reportExpenseSources
          .map((item) =>
              Formatters.parseDate(item['tanggal'] ?? item['created_at'])?.year)
          .whereType<int>(),
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final reportBayarControllers = <String, TextEditingController>{};
    final reportSisaControllers = <String, TextEditingController>{};
    final reportSisaEdited = <String, bool>{};

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
        final paymentDefaults = resolveReportPaymentDefaults(row);
        final paidLocked = paymentDefaults.paidLocked;
        final defaultBayar = formatEditableReportAmount(
          paymentDefaults.defaultBayar,
        );
        final defaultSisa = paidLocked
            ? ''
            : formatEditableReportAmount(paymentDefaults.defaultSisa);
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
              final period = buildReportPeriodRange(
                year: selectedYear,
                month: selectedMonth,
                fullYear: range == 'year',
              );
              final start = period.start;
              final end = period.end;
              final previewRows = buildRows(
                start: start,
                end: end,
                includeIncome: includeIncome,
                includeExpense: includeExpense,
                useInvoiceListDetail:
                    includeIncome && includeExpense && includeDriverCostColumns,
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
              final dialogWidth = min(
                700.0,
                max(420.0, MediaQuery.sizeOf(context).width - 24),
              );

              return AlertDialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 20,
                ),
                title: Text(_t('Buat Laporan PDF', 'Generate PDF Report')),
                content: SizedBox(
                  width: dialogWidth,
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
                                child: const Text('CV'),
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
                                child: const Text('PT'),
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
                                child: const Text('Pribadi'),
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
                                child: DropdownButtonFormField<int>(
                                  initialValue: selectedMonth,
                                  decoration: InputDecoration(
                                    labelText: _t('Bulan', 'Month'),
                                  ),
                                  items: List.generate(
                                    12,
                                    (index) => DropdownMenuItem<int>(
                                      value: index + 1,
                                      child: Text(
                                        reportMonthName(
                                          index + 1,
                                          isEnglish: _isEn,
                                        ),
                                      ),
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
                        if (includeIncome && includeExpense)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: includeDriverCostColumns,
                            onChanged: (value) => setDialogState(
                                () => includeDriverCostColumns = value ?? true),
                            title: Text(
                              _t(
                                'Tampilkan kolom Sangu Sopir & Gabungan',
                                'Show Driver Allowance & Combined columns',
                              ),
                            ),
                            subtitle: Text(
                              _t(
                                'Detail diambil dari Fix Invoice khusus laporan keseluruhan.',
                                'Details are taken from Fixed Invoice for the combined report.',
                              ),
                            ),
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
                            Expanded(
                              child: Text(
                                _t(
                                  includeIncome && !includeExpense
                                      ? 'Pilih Invoice Manual'
                                      : 'Pilih Data Manual',
                                  includeIncome && !includeExpense
                                      ? 'Manual Invoice Selection'
                                      : 'Manual Data Selection',
                                ),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
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
                                final sanguSopir = _toNum(row['__sangu_sopir']);
                                final gabungan = _toNum(row['__gabungan']);
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
                                final paidAtDisplay =
                                    '${row['__paid_at_display'] ?? row['__paid_at'] ?? ''}'
                                        .trim();
                                final paidAtDisplayDate =
                                    Formatters.parseDate(paidAtDisplay);
                                final paidAtDisplayText = paidAtDisplay.isEmpty
                                    ? ''
                                    : paidAtDisplayDate == null
                                        ? paidAtDisplay
                                        : Formatters.dmy(paidAtDisplay);
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
                                        if (paidAtDisplayText.isNotEmpty)
                                          '${_t('Tgl Bayar', 'Paid Date')}: $paidAtDisplayText',
                                      ].join(' • ')
                                    : income > 0
                                        ? [
                                            '${_t('Income', 'Income')}: ${Formatters.rupiah(income)}',
                                            if (includeIncome &&
                                                includeExpense &&
                                                includeDriverCostColumns &&
                                                sanguSopir > 0)
                                              '${_t('Sangu Sopir', 'Driver Allowance')}: ${Formatters.rupiah(sanguSopir)}',
                                            if (includeIncome &&
                                                includeExpense &&
                                                includeDriverCostColumns &&
                                                gabungan > 0)
                                              '${_t('Gabungan', 'Combined')}: ${Formatters.rupiah(gabungan)}',
                                            if (tujuanLabel.isNotEmpty &&
                                                tujuanLabel != '-')
                                              tujuanLabel,
                                          ].join(' • ')
                                        : [
                                            '${_t('Expense', 'Expense')}: ${Formatters.rupiah(expense)}',
                                            if (includeIncome &&
                                                includeExpense &&
                                                includeDriverCostColumns &&
                                                sanguSopir > 0)
                                              '${_t('Sangu Sopir', 'Driver Allowance')}: ${Formatters.rupiah(sanguSopir)}',
                                            if (includeIncome &&
                                                includeExpense &&
                                                includeDriverCostColumns &&
                                                gabungan > 0)
                                              '${_t('Gabungan', 'Combined')}: ${Formatters.rupiah(gabungan)}',
                                          ].join(' • ');
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
                        'includeDriverCostColumns': includeDriverCostColumns,
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
    final includeDriverCostColumnsSelected =
        selection['includeDriverCostColumns'] == true;
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
      useInvoiceListDetail: includeIncomeSelected &&
          includeExpenseSelected &&
          includeDriverCostColumnsSelected,
      customerKind: selectedCustomerKind,
      allowedStatuses: statusFilters,
      keyword: keyword,
    );
    final incomeInvoiceReport =
        includeIncomeSelected && !includeExpenseSelected;
    final rows = buildSelectedReportRowsForPrint(
      allRows: allRows,
      selectedKeys: selectedKeys,
      incomeInvoiceReport: incomeInvoiceReport,
      bayarInputs: bayarInputs,
      sisaInputs: sisaInputs,
      formatAmount: formatEditableReportAmount,
      parseAmount: parseEditableReportAmount,
    );

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

    final reportTotals = calculateReportPrintTotals(rows);

    try {
      final printed = await printReportPdf(
        start: start,
        end: end,
        rows: rows,
        totalIncome: reportTotals.income,
        totalExpense: reportTotals.expense,
        includeIncome: includeIncomeSelected,
        includeExpense: includeExpenseSelected,
        includeDriverCostColumns: includeDriverCostColumnsSelected,
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

    bool incomeUsesManualArmada(Map<String, dynamic>? income) {
      if (income == null) return false;
      final details = _toDetailList(income['rincian']);
      if (details.isNotEmpty) {
        return details.any(_isManualArmadaRow);
      }
      return _isManualArmadaRow(income);
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
      final subtotal = _resolveInvoiceJumlahWithSpecialRules(item);
      final effectiveTotal =
          isCompanyInvoice ? calculateInvoiceTotalAfterPph(subtotal) : subtotal;
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
      final autoSangu = isAutoSanguExpense(item);
      final autoGabungan = isAutoGabunganExpense(item);
      final marker = extractAutoExpenseMarker(item);

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
      final autoRouteLabel = (autoSangu || autoGabungan)
          ? buildAutoSanguRouteLabel(item, linkedIncome)
          : '';
      final autoDriverLabel =
          autoSangu ? buildAutoSanguDriverLabel(item, linkedIncome) : '';

      final mapped = <String, dynamic>{
        ...item,
        '__type': 'Expense',
        '__number': item['no_expense'],
        '__name': autoSangu
            ? autoDriverLabel
            : autoGabungan
                ? 'Gabungan'
                : (item['kategori'] ?? item['keterangan'] ?? '-'),
        '__total': item['total_pengeluaran'],
        '__date': item['tanggal'] ?? item['created_at'],
        '__status': item['status'],
        '__recorded_by': item['dicatat_oleh'] ?? '-',
        '__route': (autoSangu || autoGabungan)
            ? autoRouteLabel
            : (item['keterangan'] ?? item['kategori'] ?? '-'),
        '__is_auto_sangu': autoSangu,
        '__is_auto_gabungan': autoGabungan,
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
    final attachedExpenseIncomeIds = <String>{};
    for (final income in incomeRows) {
      rows.add(income);
      final id = '${income['id'] ?? ''}'.trim();
      final children = expenseByIncomeId[id];
      if (id.isNotEmpty &&
          attachedExpenseIncomeIds.add(id) &&
          children != null &&
          children.isNotEmpty) {
        rows.addAll(children);
      }
    }
    return rows;
  }

  List<Map<String, dynamic>> _applyFilterAndLimit(
      List<Map<String, dynamic>> rows) {
    final q = _search.text.trim().toLowerCase();
    final now = DateTime.now();
    final visibleSince = DateTime(now.year, now.month - 1, 1);
    final filtered = rows.where((item) {
      final date = Formatters.parseDate(
        item['__date'] ??
            item['tanggal_kop'] ??
            item['tanggal'] ??
            item['created_at'],
      );
      if (date == null) return false;
      if (date.isBefore(visibleSince) || date.isAfter(now)) return false;
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
          final isExpandedIncomeDetail =
              item['__invoice_list_expanded_detail'] == true;
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
            onPrimaryAction: isExpandedIncomeDetail
                ? null
                : isIncome && _isPengurus
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
            onDelete: !isExpandedIncomeDetail &&
                    !(isIncome && _isPengurus && approvalStatus == 'approved')
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

        final limitPicker = Row(
          mainAxisSize: MainAxisSize.min,
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
                items:
                    const ['10', '20', '50', '100', '200', '500', '1000', 'all']
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
          ],
        );

        final searchField = TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: _t(
              'Cari income atau expense...',
              'Search income or expense...',
            ),
            prefixIcon: const Icon(Icons.search),
          ),
        );

        Widget printActionButton({
          required String label,
          required Color color,
          required VoidCallback onPressed,
        }) {
          return SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: onPressed,
              style: CvantButtonStyles.outlined(
                context,
                color: color,
                borderColor: color,
              ).copyWith(
                alignment: const Alignment(0, 0),
              ),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(
                children: [
                  limitPicker,
                  const SizedBox(width: 8),
                  Expanded(child: searchField),
                ],
              ),
            ),
            if (!_isPengurus)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: printActionButton(
                        label: _t('Cetak Laporan', 'Print Report'),
                        color: AppColors.success,
                        onPressed: () => _openReportSummary(
                          expenses: expenses,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: printActionButton(
                        label: _t('Cetak Invoice', 'Print Invoice'),
                        color: AppColors.warning,
                        onPressed: () => _openInvoicePrintSelector(
                          incomes: incomes,
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
