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
  static const _returnedFixedInvoicePrefsKey = 'returned_fixed_invoice_ids_v1';
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
  final Set<String> _returnedFixedInvoiceIds = <String>{};
  String _limit = '10';
  bool _backgroundFixedInvoiceSyncRunning = false;
  bool _backgroundAutoSanguCleanupRunning = false;
  bool _backgroundIncomePricingBackfillRunning = false;
  bool _backgroundInvoiceDateSyncRunning = false;
  bool _backgroundInvoiceNumberNormalizationRunning = false;
  bool _manualArmadaAutoSanguCleanupDone = false;
  bool _incomePricingBackfillDone = false;
  bool _invoiceDetailDateSyncDone = false;
  final Set<String> _loadedInvoiceIdsForAutoExpenseSync = <String>{};
  final List<Map<String, dynamic>> _invoiceListAutoExpenseArmadas =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _invoiceListAutoExpenseHargaRules =
      <Map<String, dynamic>>[];

  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  bool get _isPengurus => widget.session.isPengurus;
  bool get _isAdminOrOwner => widget.session.isAdminOrOwner;
  String get _currentUserId => widget.session.userId?.trim() ?? '';

  String _t(String id, String en) => _isEn ? en : id;

  DateTime _invoiceListIncomeHistoryStart(DateTime now) {
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    return DateTime(startYear, 4, 1);
  }

  Future<Set<String>> _loadReturnedFixedInvoiceIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_returnedFixedInvoicePrefsKey) ??
            const <String>[])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> _forgetReturnedFixedInvoiceIds(Iterable<String> ids) async {
    final cleaned =
        ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (cleaned.isEmpty) return;
    final existing = await _loadReturnedFixedInvoiceIds();
    existing.removeAll(cleaned);
    final prefs = await SharedPreferences.getInstance();
    final values = existing.toList()..sort();
    await prefs.setStringList(_returnedFixedInvoicePrefsKey, values);
    _returnedFixedInvoiceIds.removeAll(cleaned);
  }

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
    return resolveArmadaIdFromPlateInput(
      armadaId: armadaId,
      armadaInput: armadaManual,
      armadaIdByPlate: armadaIdByPlate,
    );
  }

  bool _usesEffectiveManualArmada(
    Map<String, dynamic> row, {
    required List<Map<String, dynamic>> armadas,
  }) {
    if (!_isManualArmadaRow(row)) return false;
    return resolveListedArmadaIdFromRow(
      row,
      armadaIdByPlate: _buildArmadaIdByPlate(armadas),
    ).isEmpty;
  }

  bool _promoteManualPlateToListedArmada(
    Map<String, dynamic> row, {
    required List<Map<String, dynamic>> armadas,
  }) {
    if (!_isManualArmadaRow(row) || armadas.isEmpty) return false;
    final resolvedArmadaId = resolveListedArmadaIdFromRow(
      row,
      armadaIdByPlate: _buildArmadaIdByPlate(armadas),
    );
    if (resolvedArmadaId.isEmpty) return false;
    applyListedArmadaSelection(row, resolvedArmadaId);
    return true;
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
    if (_usesEffectiveManualArmada(row, armadas: armadas)) return null;
    var plate = '';
    final armadaId = resolveListedArmadaIdFromRow(
      row,
      armadaIdByPlate: _buildArmadaIdByPlate(armadas),
    );
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
    _promoteManualPlateToListedArmada(row, armadas: armadas);
    _clearDriverForManualArmadaIfNeeded(row);
    if (_usesEffectiveManualArmada(row, armadas: armadas)) return;

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
      final sourceRow = _isSpecialNumberedPersonalInvoice(
        row,
        details: details,
      )
          ? <String, dynamic>{
              ...row,
              'invoice_entity': Formatters.invoiceEntityPersonal,
              'pph': 0.0,
              'total_bayar': (() {
                final totalBiaya = _toNum(row['total_biaya']);
                if (totalBiaya > 0) return totalBiaya;
                return _toNum(row['total_bayar']);
              })(),
            }
          : row;
      if (details.length <= 1) {
        expanded.add(sourceRow);
        continue;
      }

      final entity = Formatters.normalizeInvoiceEntity(
        sourceRow['invoice_entity'],
        invoiceNumber: sourceRow['no_invoice'],
        customerName: sourceRow['nama_pelanggan'],
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
            cleanText(sourceRow['armada_start_date']) ??
            cleanText(sourceRow['tanggal']);
        final useManualArmada =
            _isManualArmadaRow(detail) || _isManualArmadaRow(sourceRow);
        final detailArmadaManual = cleanText(detail['armada_manual']) ??
            cleanText(detail['armada_label']) ??
            cleanText(detail['armada']) ??
            cleanText(sourceRow['armada_manual']) ??
            cleanText(sourceRow['armada_label']) ??
            cleanText(sourceRow['armada']);

        expanded.add({
          ...sourceRow,
          '__invoice_list_expanded_detail': true,
          '__source_invoice_id': sourceRow['id'],
          '__detail_index': i,
          'rincian': [detail],
          'tanggal': detailDate ?? sourceRow['tanggal'],
          'armada_start_date': detailDate ?? sourceRow['armada_start_date'],
          'armada_end_date':
              detailValue(detail, sourceRow, 'armada_end_date') ??
                  sourceRow['armada_end_date'],
          'lokasi_muat': detailValue(detail, sourceRow, 'lokasi_muat'),
          'lokasi_bongkar': detailValue(detail, sourceRow, 'lokasi_bongkar'),
          'muatan': detailValue(detail, sourceRow, 'muatan'),
          'nama_supir': useManualArmada
              ? null
              : detailValue(detail, sourceRow, 'nama_supir'),
          'armada_id': useManualArmada
              ? null
              : detailValue(detail, sourceRow, 'armada_id'),
          'armada_manual': useManualArmada ? detailArmadaManual : null,
          'armada_label': useManualArmada ? detailArmadaManual : null,
          'tonase': positiveDetailNumber(detail, sourceRow, 'tonase'),
          'harga': positiveDetailNumber(detail, sourceRow, 'harga'),
          'total_biaya': subtotal,
          'pph': pph,
          'total_bayar': totalBayar,
        });
      }
    }
    return expanded;
  }

  Map<String, dynamic> _applyEffectivePricingForInvoiceList(
    Map<String, dynamic> row, {
    required List<Map<String, dynamic>> hargaPerTonRules,
  }) {
    final details = _toDetailList(row['rincian']);
    if (details.isEmpty) return row;
    final regularRules =
        hargaPerTonRules.where(isRegularIncomeHargaRule).toList(
              growable: false,
            );

    String firstText(Iterable<dynamic> values) {
      for (final value in values) {
        final text = '${value ?? ''}'.trim();
        if (text.isNotEmpty && text != '-') return text;
      }
      return '';
    }

    Map<String, dynamic> applyDetail(Map<String, dynamic> detail) {
      final pickup = firstText([detail['lokasi_muat'], row['lokasi_muat']]);
      final destination =
          firstText([detail['lokasi_bongkar'], row['lokasi_bongkar']]);
      final cargo = firstText([detail['muatan'], row['muatan']]);
      final regularRule = _resolveHargaRuleShared(
        rules: regularRules,
        customerName: '${row['nama_pelanggan'] ?? ''}'.trim(),
        lokasiMuat: pickup,
        lokasiBongkar: destination,
        muatan: cargo,
      );
      final regularHarga = _resolveHargaPerTonValueShared(
        regularRule,
        muatan: cargo,
      );
      final incomeHarga = resolveIncomeRegularHargaForRoute(
        regularRule: regularRule,
        adjustedRegularHarga: regularHarga,
        pickup: pickup,
        destination: destination,
      );
      final effectiveHarga = (incomeHarga ?? 0) > 0
          ? incomeHarga!
          : _toNum(detail['harga'] ?? row['harga']);
      final tonase = _toNum(detail['tonase'] ?? row['tonase']);
      final currentHarga = _toNum(detail['harga'] ?? row['harga']);
      final currentAutoSubtotal = currentHarga > 0 && tonase > 0
          ? roundInvoiceRupiah(currentHarga * tonase)
          : 0.0;
      final manualSubtotal =
          _toNum(detail['manual_subtotal'] ?? detail['subtotal_manual']);
      final hasProtectedManualSubtotal = manualSubtotal > 0 &&
          (currentAutoSubtotal <= 0 ||
              (manualSubtotal - currentAutoSubtotal).abs() > 1);
      if (hasProtectedManualSubtotal || effectiveHarga <= 0 || tonase <= 0) {
        return detail;
      }

      final next = Map<String, dynamic>.from(detail);
      next['harga'] = effectiveHarga;
      next['subtotal_auto'] = true;
      for (final key in const [
        'manual_subtotal',
        'subtotal_manual',
        'subtotal',
        'total',
        'total_biaya',
        'jumlah',
      ]) {
        next.remove(key);
      }
      return next;
    }

    final nextDetails = details.map(applyDetail).toList(growable: false);
    final subtotal = _resolveInvoiceDetailsExcelSubtotalShared(nextDetails);
    if (subtotal <= 0) return row;

    final normalizedEntity = Formatters.normalizeInvoiceEntity(
      row['invoice_entity'],
      invoiceNumber: row['no_invoice'],
      customerName: row['nama_pelanggan'],
    );
    final includePph = Formatters.isCompanyInvoiceEntity(normalizedEntity);
    final pph = includePph ? calculateInvoicePph2Percent(subtotal) : 0.0;
    final totalBayar =
        includePph ? calculateInvoiceTotalAfterPph(subtotal) : subtotal;

    return {
      ...row,
      'rincian': nextDetails,
      'total_biaya': subtotal,
      'pph': pph,
      'total_bayar': totalBayar,
    };
  }

  Future<List<dynamic>> _load() async {
    if (_isPengurus && _currentUserId.isEmpty) {
      return const [<Map<String, dynamic>>[], <Map<String, dynamic>>[]];
    }
    final now = DateTime.now();
    final incomeSince = _invoiceListIncomeHistoryStart(now);
    final expenseSince = DateTime(now.year, now.month - 1, 1);
    final scopedUserId = _isPengurus ? _currentUserId : null;
    const int? fetchLimit = null;
    final response = await Future.wait<dynamic>([
      widget.repository.fetchInvoicesSinceWithScope(
        incomeSince,
        columns: _invoiceListColumns,
        createdBy: scopedUserId,
        limit: fetchLimit,
      ),
      widget.repository.fetchExpensesSinceWithScope(
        expenseSince,
        _expenseListColumns,
        createdBy: scopedUserId,
        limit: fetchLimit == null ? null : max(80, fetchLimit * 2),
      ),
      _isAdminOrOwner
          ? _loadLocalFixedInvoiceIds()
          : Future<Set<String>>.value(<String>{}),
      _loadReturnedFixedInvoiceIds(),
      (() async {
        try {
          return await widget.repository.fetchArmadas();
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      })(),
      (() async {
        try {
          return await widget.repository.fetchHargaPerTonRules();
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      })(),
    ]);

    final rawIncomes =
        (response[0] as List).cast<Map<String, dynamic>>().toList();
    final rawExpenses =
        (response[1] as List).cast<Map<String, dynamic>>().toList();
    final fixedIds = (response[2] as Set<String>)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final returnedIds = (response[3] as Set<String>)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final rawIncomeIds = rawIncomes
        .map((item) => '${item['id'] ?? ''}'.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final returnedSourceIds = returnedIds
        .map(invoiceFixedSourceId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final missingReturnedIds = returnedSourceIds.difference(rawIncomeIds);
    if (missingReturnedIds.isNotEmpty) {
      rawIncomes.addAll(
        await widget.repository.fetchInvoicesByIds(missingReturnedIds),
      );
    }
    _returnedFixedInvoiceIds
      ..clear()
      ..addAll(returnedIds.difference(fixedIds));
    final scopedIncomes = rawIncomes.where((item) {
      final id = '${item['id'] ?? ''}'.trim();
      if (id.isNotEmpty && _locallyRemovedRowIds.contains(id)) return false;
      if (_isPengurus) return _isOwnedByCurrentUser(item);
      if (_isAdminOrOwner) return _isPengurusIncomeApproved(item);
      return true;
    }).toList();
    final armadas = (response[4] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final hargaPerTonRules = (response[5] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    _invoiceListAutoExpenseArmadas
      ..clear()
      ..addAll(armadas);
    _invoiceListAutoExpenseHargaRules
      ..clear()
      ..addAll(hargaPerTonRules);
    final pricedScopedIncomes = scopedIncomes
        .map(
          (item) => _applyEffectivePricingForInvoiceList(
            item,
            hargaPerTonRules: hargaPerTonRules,
          ),
        )
        .toList(growable: false);
    _loadedInvoiceIdsForAutoExpenseSync
      ..clear()
      ..addAll(
        pricedScopedIncomes
            .map((item) => '${item['id'] ?? ''}'.trim())
            .where((id) => id.isNotEmpty),
      );
    final expandedIncomes =
        _expandIncomeRowsForInvoiceList(pricedScopedIncomes);
    final scopedExpenses = rawExpenses.where((item) {
      final id = '${item['id'] ?? ''}'.trim();
      if (id.isNotEmpty && _locallyRemovedRowIds.contains(id)) return false;
      if (_isPengurus) return _isOwnedByCurrentUser(item);
      return true;
    }).toList();
    if (fixedIds.isEmpty) {
      return [expandedIncomes, scopedExpenses];
    }

    final filteredIncomes = expandedIncomes.where((item) {
      final id = '${item['id'] ?? ''}'.trim();
      final fixedIdentity = invoiceFixedIdentityForRow(item);
      return id.isEmpty ||
          !(fixedIds.contains(id) ||
              (fixedIdentity.isNotEmpty && fixedIds.contains(fixedIdentity)));
    }).toList();

    return [filteredIncomes, scopedExpenses];
  }

  Future<void> _runInvoiceListBackgroundMaintenanceAndReloadOnce({
    bool autoExpenseOnly = false,
  }) async {
    final autoExpenseChanges = await _cleanupManualArmadaAutoSanguInBackground(
      force: autoExpenseOnly,
    );
    if (autoExpenseChanges) {
      await _reloadAfterInvoiceListBackgroundChanges();
    }
    if (autoExpenseOnly) return;

    final hasOtherVisibleChanges = await _runInvoiceListBackgroundMaintenance();
    if (hasOtherVisibleChanges) {
      await _reloadAfterInvoiceListBackgroundChanges();
    }
  }

  Future<void> _reloadAfterInvoiceListBackgroundChanges() async {
    if (!mounted) return;
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

  Future<bool> _cleanupManualArmadaAutoSanguInBackground({
    bool force = false,
  }) async {
    if ((!force && _manualArmadaAutoSanguCleanupDone) ||
        _backgroundAutoSanguCleanupRunning) {
      return false;
    }
    _backgroundAutoSanguCleanupRunning = true;
    try {
      final report =
          await widget.repository.backfillAutoSanguExpensesForExistingInvoices(
        invoiceIds: _loadedInvoiceIdsForAutoExpenseSync,
      );
      _manualArmadaAutoSanguCleanupDone = !report.hasFailures;
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
    setState(() {
      _future = _load();
    });
    await _future;
    if (widget.session.isBackofficeUser) {
      unawaited(
          PushNotificationService.instance.refreshMonthlyFinanceReminder());
    }
    if (_isAdminOrOwner && runBackfill) {
      unawaited(
        _runInvoiceListBackgroundMaintenanceAndReloadOnce(
          autoExpenseOnly: true,
        ),
      );
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

  Future<List<_FixedInvoiceBatch>> _loadRemoteFixedInvoiceBatches() {
    return _loadRemoteFixedInvoiceBatchesImpl();
  }

  Future<void> _upsertRemoteFixedInvoiceBatch(_FixedInvoiceBatch batch) {
    return _upsertRemoteFixedInvoiceBatchImpl(batch);
  }

  Future<void> _syncLocalFixedInvoiceCache(
    List<_FixedInvoiceBatch> batches,
  ) {
    return _syncLocalFixedInvoiceCacheImpl(batches);
  }

  Future<Set<String>> _loadFixedInvoiceIds() {
    return _loadFixedInvoiceIdsImpl();
  }

  Future<Set<String>> _loadLocalFixedInvoiceIds() {
    return _loadLocalFixedInvoiceIdsImpl();
  }

  Future<List<_FixedInvoiceBatch>> _loadFixedInvoiceBatches() {
    return _loadFixedInvoiceBatchesImpl();
  }

  Future<List<_FixedInvoiceBatch>> _loadLocalFixedInvoiceBatches() {
    return _loadLocalFixedInvoiceBatchesImpl();
  }

  String _buildFixedInvoiceBatchId(Iterable<String> invoiceIds) {
    return _buildFixedInvoiceBatchIdImpl(invoiceIds);
  }

  Future<void> _markInvoicesAsFixed(
    Iterable<String> invoiceIds, {
    _FixedInvoiceBatch? batch,
  }) {
    return _markInvoicesAsFixedImpl(invoiceIds, batch: batch);
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
  }) {
    return _openInvoicePrintSelectorImpl(incomes: incomes);
  }

  Future<void> _openReportSummary({
    required List<Map<String, dynamic>> expenses,
  }) {
    return _openReportSummaryImpl(expenses: expenses);
  }

  List<Map<String, dynamic>> _buildCombinedRows(
    List<Map<String, dynamic>> incomes,
    List<Map<String, dynamic>> expenses,
  ) {
    String normalizeToken(dynamic value) {
      return expenseLinkToken(value);
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

    int? parseDetailIndex(dynamic value) {
      if (value is int) return value;
      return int.tryParse('${value ?? ''}'.trim());
    }

    String incomeSourceId(Map<String, dynamic> source) {
      final sourceId = '${source['__source_invoice_id'] ?? ''}'.trim();
      if (sourceId.isNotEmpty) return sourceId;
      return '${source['id'] ?? ''}'.trim();
    }

    String incomeRowKey(Map<String, dynamic> source) {
      final sourceId = incomeSourceId(source);
      final detailIndex = parseDetailIndex(source['__detail_index']);
      if (source['__invoice_list_expanded_detail'] == true &&
          sourceId.isNotEmpty &&
          detailIndex != null) {
        return '$sourceId#$detailIndex';
      }
      return '${source['id'] ?? sourceId}'.trim();
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
        '__sort_date': resolveIncomeDisplayDate(item),
        '__status': item['status'],
        '__recorded_by': item['diterima_oleh'] ?? '-',
        '__route': resolveRoute(item),
        '__armada_start_dates': searchFields['dates'],
        '__armada_plates': searchFields['plates'],
        '__armada_routes': searchFields['routes'],
        '__invoice_list_row_key': incomeRowKey(item),
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
    final incomeRowsBySourceId = <String, List<Map<String, dynamic>>>{};
    final incomeIdByInvoiceToken = <String, String>{};
    for (final income in incomeRows) {
      final id = '${income['id'] ?? ''}'.trim();
      final sourceId = incomeSourceId(income);
      if (id.isEmpty && sourceId.isEmpty) continue;
      final sourceKey = sourceId.isNotEmpty ? sourceId : id;
      incomeRowsBySourceId
          .putIfAbsent(sourceKey, () => <Map<String, dynamic>>[])
          .add(income);
      if (id.isNotEmpty) {
        incomeById.putIfAbsent(normalizeToken(id), () => income);
      }
      if (sourceId.isNotEmpty) {
        incomeById.putIfAbsent(normalizeToken(sourceId), () => income);
      }
      final rawInvoice = normalizeToken(income['no_invoice']);
      final formattedInvoice = normalizeToken(income['__number']);
      if (rawInvoice.isNotEmpty) {
        incomeIdByInvoiceToken[rawInvoice] = sourceKey;
      }
      if (formattedInvoice.isNotEmpty) {
        incomeIdByInvoiceToken[formattedInvoice] = sourceKey;
      }
    }
    for (final rows in incomeRowsBySourceId.values) {
      rows.sort((a, b) {
        final aIndex = parseDetailIndex(a['__detail_index']);
        final bIndex = parseDetailIndex(b['__detail_index']);
        if (aIndex != null && bIndex != null) {
          return aIndex.compareTo(bIndex);
        }
        if (aIndex != null) return -1;
        if (bIndex != null) return 1;
        final aDate = Formatters.parseDate(a['__date']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = Formatters.parseDate(b['__date']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
    }

    String normalizedRoutePart(dynamic value) {
      return '${value ?? ''}'
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    String routeKeyForDetail(
      Map<String, dynamic> detail, {
      Map<String, dynamic>? fallbackIncomeDetail,
    }) {
      final route = extractRouteDriverFromDetail(
        detail,
        fallbackIncomeDetail: fallbackIncomeDetail,
      );
      final muat = normalizedRoutePart(route.muat);
      final bongkar = normalizedRoutePart(route.bongkar);
      if (muat.isEmpty && bongkar.isEmpty) return '';
      return '$muat|$bongkar';
    }

    Map<String, dynamic>? firstIncomeDetail(Map<String, dynamic>? income) {
      if (income == null) return null;
      final details = _toDetailList(income['rincian']);
      if (details.isNotEmpty) return details.first;
      return income;
    }

    String buildSingleAutoExpenseRouteLabel(
      Map<String, dynamic> detail,
      Map<String, dynamic>? targetIncome,
    ) {
      final fallback = firstIncomeDetail(targetIncome);
      var route = extractRouteDriverFromDetail(
        detail,
        fallbackIncomeDetail: fallback,
      );
      if (route.muat.isEmpty && route.bongkar.isEmpty && fallback != null) {
        route = extractRouteDriverFromDetail(
          fallback,
          fallbackIncomeDetail: fallback,
        );
      }
      if (route.muat.isEmpty && route.bongkar.isEmpty) return '-';
      return '${route.muat.isEmpty ? '-' : route.muat}-'
          '${route.bongkar.isEmpty ? '-' : route.bongkar}';
    }

    String buildSingleAutoExpenseDriverLabel(
      Map<String, dynamic> detail,
      Map<String, dynamic>? targetIncome,
    ) {
      final fallback = firstIncomeDetail(targetIncome);
      final route = extractRouteDriverFromDetail(
        detail,
        fallbackIncomeDetail: fallback,
      );
      if (route.driver.trim().isNotEmpty) return route.driver.trim();
      return '-';
    }

    double expenseDetailAmount(Map<String, dynamic> detail) {
      for (final key in const [
        'jumlah',
        'amount',
        'total',
        'total_pengeluaran',
        'nominal',
        'subtotal',
      ]) {
        final amount = _toNum(detail[key]);
        if (amount > 0) return amount;
      }
      return 0;
    }

    dynamic expenseDetailDate(
      Map<String, dynamic> detail,
      Map<String, dynamic>? targetIncome,
      Map<String, dynamic> parentExpense,
    ) {
      for (final value in [
        detail['armada_start_date'],
        detail['tanggal'],
        targetIncome?['__date'],
        targetIncome?['tanggal'],
        targetIncome?['created_at'],
        parentExpense['tanggal'],
        parentExpense['created_at'],
      ]) {
        if (Formatters.parseDate(value) != null) return value;
      }
      return parentExpense['tanggal'] ?? parentExpense['created_at'];
    }

    Map<String, dynamic>? targetIncomeForExpenseDetail({
      required List<Map<String, dynamic>> targetRows,
      required Map<String, dynamic> expenseDetail,
      required int detailIndex,
      required int detailCount,
      required Set<String> usedRowKeys,
    }) {
      bool unused(Map<String, dynamic> row) {
        final key = '${row['__invoice_list_row_key'] ?? incomeRowKey(row)}';
        return !usedRowKeys.contains(key);
      }

      final explicitIndex = parseDetailIndex(
        expenseDetail['source_detail_index'] ??
            expenseDetail['detail_index'] ??
            expenseDetail['__detail_index'],
      );
      if (explicitIndex != null) {
        for (final row in targetRows) {
          if (parseDetailIndex(row['__detail_index']) == explicitIndex &&
              unused(row)) {
            return row;
          }
        }
      }

      if (detailCount == targetRows.length &&
          detailIndex < targetRows.length &&
          unused(targetRows[detailIndex])) {
        return targetRows[detailIndex];
      }

      final expenseRouteKey = routeKeyForDetail(expenseDetail);
      if (expenseRouteKey.isNotEmpty) {
        for (final row in targetRows) {
          if (!unused(row)) continue;
          final rowRouteKey = routeKeyForDetail(
            firstIncomeDetail(row) ?? row,
            fallbackIncomeDetail: row,
          );
          if (rowRouteKey == expenseRouteKey) return row;
        }
      }

      for (final row in targetRows) {
        if (unused(row)) return row;
      }
      return targetRows.isEmpty ? null : targetRows.first;
    }

    dynamic autoExpenseDateFromIncome(
      Map<String, dynamic> detail,
      Map<String, dynamic> income,
    ) {
      for (final value in [
        detail['armada_start_date'],
        detail['tanggal'],
        income['__date'],
        income['tanggal'],
        income['created_at'],
      ]) {
        if (Formatters.parseDate(value) != null) return value;
      }
      return income['__date'] ?? income['tanggal'] ?? income['created_at'];
    }

    Map<String, dynamic>? buildExpectedAutoExpenseRowForIncome(
      Map<String, dynamic> income,
    ) {
      final detail = firstIncomeDetail(income) ?? income;
      var route = extractRouteDriverFromDetail(
        detail,
        fallbackIncomeDetail: income,
      );
      if (route.muat.trim().isEmpty || route.bongkar.trim().isEmpty) {
        final routeLabel = '${income['__route'] ?? ''}'.trim();
        final parts = routeLabel
            .split(RegExp(r'\s*[-–—]\s*'))
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList(growable: false);
        if (parts.length >= 2) {
          route = (
            muat: route.muat.trim().isEmpty ? parts.first : route.muat,
            bongkar: route.bongkar.trim().isEmpty
                ? parts.sublist(1).join('-')
                : route.bongkar,
            driver: route.driver,
          );
        }
      }
      final pickup = route.muat.trim();
      final destination = route.bongkar.trim();
      if (pickup.isEmpty || destination.isEmpty) return null;

      final merged = <String, dynamic>{
        ...income,
        ...detail,
      };
      final cargo = '${detail['muatan'] ?? income['muatan'] ?? ''}'.trim();
      final displayDate = autoExpenseDateFromIncome(detail, income);
      final routeLabel = '${pickup.isEmpty ? '-' : pickup}-'
          '${destination.isEmpty ? '-' : destination}';
      final sourceId = incomeSourceId(income);
      final rowKey =
          '${income['__invoice_list_row_key'] ?? incomeRowKey(income)}';
      final detailIndex = parseDetailIndex(income['__detail_index']);
      final usesManualGabungan = _usesEffectiveManualArmada(
            merged,
            armadas: _invoiceListAutoExpenseArmadas,
          ) &&
          !manualArmadaRouteUsesSanguExpense(
            pickup: pickup,
            destination: destination,
          );

      if (usesManualGabungan) {
        final tonase = _toNum(detail['tonase'] ?? income['tonase']);
        final gabunganHarga = resolveGabunganExpenseHargaPerKg(
          storedHarga: _toNum(detail['harga'] ?? income['harga']),
          pickup: pickup,
          destination: destination,
          gabunganRules: _invoiceListAutoExpenseHargaRules,
        );
        final total = tonase > 0 && gabunganHarga > 0
            ? roundInvoiceRupiah(tonase * gabunganHarga)
            : 0.0;
        if (total <= 0) return null;
        return <String, dynamic>{
          'id': 'virtual-auto-gabungan:$rowKey',
          'no_expense': '-',
          'tanggal': displayDate,
          'kategori': 'Gabungan',
          'keterangan': 'Auto gabungan',
          'status': 'Paid',
          'dicatat_oleh': 'System',
          'note': sourceId.isEmpty ? null : 'AUTO_GABUNGAN:$sourceId',
          'rincian': [
            {
              'nama': 'Gabungan ($routeLabel)',
              'lokasi_muat': pickup,
              'lokasi_bongkar': destination,
              'armada_start_date': displayDate,
              'muatan': cargo,
              'tonase': tonase,
              'harga': gabunganHarga,
              'jumlah': total,
              if (detailIndex != null) 'source_detail_index': detailIndex,
            },
          ],
          'total_pengeluaran': total,
          '__type': 'Expense',
          '__number': '-',
          '__name': 'Gabungan',
          '__total': total,
          '__date': displayDate,
          '__sort_date': displayDate,
          '__status': 'Paid',
          '__recorded_by': 'System',
          '__route': routeLabel,
          '__is_auto_gabungan': true,
          '__virtual_auto_expense': true,
          '__linked_income_row_key': rowKey,
        };
      }

      final rule = resolvePrioritizedSanguRouteRule(
        pickup: pickup,
        destination: destination,
        customerName: '${income['nama_pelanggan'] ?? income['__name'] ?? ''}',
        invoiceEntity: '${income['invoice_entity'] ?? ''}',
      );
      final total = _toNum(rule?['nominal']);
      if (total <= 0) return null;
      final driver = route.driver.trim().isEmpty ? '-' : route.driver.trim();
      return <String, dynamic>{
        'id': 'virtual-auto-sangu:$rowKey',
        'no_expense': '-',
        'tanggal': displayDate,
        'kategori': 'Sangu Sopir',
        'keterangan': 'Auto sangu sopir',
        'status': 'Paid',
        'dicatat_oleh': 'System',
        'note': sourceId.isEmpty ? null : 'AUTO_SANGU:$sourceId',
        'rincian': [
          {
            'nama': '$driver ($routeLabel)',
            'nama_supir': driver == '-' ? null : driver,
            'lokasi_muat': pickup,
            'lokasi_bongkar': destination,
            'armada_start_date': displayDate,
            'muatan': cargo,
            'jumlah': total,
            if (detailIndex != null) 'source_detail_index': detailIndex,
          },
        ],
        'total_pengeluaran': total,
        '__type': 'Expense',
        '__number': '-',
        '__name': driver,
        '__total': total,
        '__date': displayDate,
        '__sort_date': displayDate,
        '__status': 'Paid',
        '__recorded_by': 'System',
        '__route': routeLabel,
        '__is_auto_sangu': true,
        '__virtual_auto_expense': true,
        '__linked_income_row_key': rowKey,
      };
    }

    bool autoExpenseMatchesExpected(
      Map<String, dynamic> row,
      Map<String, dynamic> expected,
    ) {
      if (row['__is_auto_sangu'] == true &&
          expected['__is_auto_sangu'] != true) {
        return false;
      }
      if (row['__is_auto_gabungan'] == true &&
          expected['__is_auto_gabungan'] != true) {
        return false;
      }
      final rowRoute = normalizedRoutePart(row['__route']);
      final expectedRoute = normalizedRoutePart(expected['__route']);
      if (rowRoute.isNotEmpty &&
          expectedRoute.isNotEmpty &&
          rowRoute != expectedRoute) {
        return false;
      }
      final rowDate = Formatters.parseDate(row['__date'] ?? row['tanggal']);
      final expectedDate = Formatters.parseDate(
        expected['__date'] ?? expected['tanggal'],
      );
      if (rowDate != null &&
          expectedDate != null &&
          (rowDate.year != expectedDate.year ||
              rowDate.month != expectedDate.month ||
              rowDate.day != expectedDate.day)) {
        return false;
      }
      return (_toNum(row['__total'] ?? row['total_pengeluaran']) -
                  _toNum(expected['__total'] ?? expected['total_pengeluaran']))
              .abs() <=
          1;
    }

    final expenseByIncomeId = <String, List<Map<String, dynamic>>>{};
    final standaloneExpenses = <Map<String, dynamic>>[];
    for (final item in expenses) {
      final autoSangu = isAutoSanguExpense(item);
      final autoGabungan = isAutoGabunganExpense(item);
      final marker = extractAutoExpenseMarker(item);

      final markerKey = normalizeToken(marker);
      String? linkedIncomeId;
      if (markerKey.isNotEmpty) {
        final incomeByMarkerId = incomeById[markerKey];
        if (incomeByMarkerId != null) {
          linkedIncomeId = '${incomeByMarkerId['id'] ?? ''}'.trim();
        } else {
          linkedIncomeId = incomeIdByInvoiceToken[markerKey];
        }
      }
      final linkedIncome = linkedIncomeId == null
          ? null
          : incomeById[normalizeToken(linkedIncomeId)];
      final autoRouteLabel = (autoSangu || autoGabungan)
          ? buildAutoSanguRouteLabel(item, linkedIncome)
          : '';
      final autoDriverLabel =
          autoSangu ? buildAutoSanguDriverLabel(item, linkedIncome) : '';

      Map<String, dynamic> mapExpenseRow({
        Map<String, dynamic>? detail,
        Map<String, dynamic>? targetIncome,
        int? detailIndex,
      }) {
        final hasDetail = detail != null;
        final detailTotal = hasDetail ? expenseDetailAmount(detail) : 0.0;
        final total =
            detailTotal > 0 ? detailTotal : _toNum(item['total_pengeluaran']);
        final displayDate = hasDetail
            ? expenseDetailDate(detail, targetIncome, item)
            : item['tanggal'] ?? item['created_at'];
        final displayRoute = hasDetail && (autoSangu || autoGabungan)
            ? buildSingleAutoExpenseRouteLabel(detail, targetIncome)
            : (autoSangu || autoGabungan)
                ? autoRouteLabel
                : (item['keterangan'] ?? item['kategori'] ?? '-');
        final displayName = autoSangu
            ? (hasDetail
                ? buildSingleAutoExpenseDriverLabel(detail, targetIncome)
                : autoDriverLabel)
            : autoGabungan
                ? 'Gabungan'
                : (item['kategori'] ?? item['keterangan'] ?? '-');
        return <String, dynamic>{
          ...item,
          if (hasDetail) 'rincian': [detail],
          'total_pengeluaran': total,
          '__type': 'Expense',
          '__number': item['no_expense'],
          '__name': displayName,
          '__total': total,
          '__date': displayDate,
          '__sort_date': displayDate,
          '__status': item['status'],
          '__recorded_by': item['dicatat_oleh'] ?? '-',
          '__route': displayRoute,
          '__is_auto_sangu': autoSangu,
          '__is_auto_gabungan': autoGabungan,
          if (detailIndex != null) '__auto_expense_detail_index': detailIndex,
          if (targetIncome != null)
            '__linked_income_row_key': targetIncome['__invoice_list_row_key'] ??
                incomeRowKey(targetIncome),
        };
      }

      final mapped = mapExpenseRow();
      if (linkedIncomeId != null && linkedIncomeId.isNotEmpty) {
        final targetRows = incomeRowsBySourceId[linkedIncomeId] ??
            const <Map<String, dynamic>>[];
        final expenseDetails = _toDetailList(item['rincian']);
        if ((autoSangu || autoGabungan) &&
            expenseDetails.isNotEmpty &&
            targetRows.length > 1) {
          final usedRowKeys = <String>{};
          var attached = 0;
          for (var detailIndex = 0;
              detailIndex < expenseDetails.length;
              detailIndex++) {
            final detail = expenseDetails[detailIndex];
            final amount = expenseDetailAmount(detail);
            if (amount <= 0) continue;
            final targetIncome = targetIncomeForExpenseDetail(
              targetRows: targetRows,
              expenseDetail: detail,
              detailIndex: detailIndex,
              detailCount: expenseDetails.length,
              usedRowKeys: usedRowKeys,
            );
            if (targetIncome == null) continue;
            final rowKey =
                '${targetIncome['__invoice_list_row_key'] ?? incomeRowKey(targetIncome)}'
                    .trim();
            if (rowKey.isEmpty) continue;
            usedRowKeys.add(rowKey);
            expenseByIncomeId
                .putIfAbsent(rowKey, () => <Map<String, dynamic>>[])
                .add(
                  mapExpenseRow(
                    detail: detail,
                    targetIncome: targetIncome,
                    detailIndex: detailIndex,
                  ),
                );
            attached++;
          }
          if (attached > 0) continue;
        }

        final fallbackRowKey = targetRows.isNotEmpty
            ? '${targetRows.first['__invoice_list_row_key'] ?? incomeRowKey(targetRows.first)}'
            : linkedIncomeId;
        expenseByIncomeId
            .putIfAbsent(fallbackRowKey, () => <Map<String, dynamic>>[])
            .add(mapped);
      } else if (shouldShowStandaloneInvoiceListExpense(mapped)) {
        standaloneExpenses.add(mapped);
      }
    }

    for (final income in incomeRows) {
      final rowKey =
          '${income['__invoice_list_row_key'] ?? incomeRowKey(income)}'.trim();
      if (rowKey.isEmpty) continue;
      final expected = buildExpectedAutoExpenseRowForIncome(income);
      if (expected == null) continue;
      final existing =
          expenseByIncomeId[rowKey] ?? const <Map<String, dynamic>>[];
      final hasMatching =
          existing.any((row) => autoExpenseMatchesExpected(row, expected));
      if (hasMatching) continue;
      final manualRows = existing
          .where((row) => !isInvoiceListAutoExpenseRow(row))
          .toList(growable: false);
      expenseByIncomeId[rowKey] = <Map<String, dynamic>>[
        expected,
        ...manualRows,
      ];
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

    final rowGroups = buildInvoiceListRowGroups(
      incomeRows: incomeRows,
      expenseByIncomeId: expenseByIncomeId,
      standaloneExpenses: standaloneExpenses,
    );
    rowGroups.sort((a, b) {
      final aDate = Formatters.parseDate(
            a.first['__sort_date'] ?? a.first['__date'],
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = Formatters.parseDate(
            b.first['__sort_date'] ?? b.first['__date'],
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final dateCompare = bDate.compareTo(aDate);
      if (dateCompare != 0) return dateCompare;
      return '${b.first['id'] ?? b.first['__number'] ?? ''}'
          .compareTo('${a.first['id'] ?? a.first['__number'] ?? ''}');
    });
    return rowGroups.expand((group) => group).toList(growable: false);
  }

  bool _isReturnedFixedInvoiceRow(Map<String, dynamic> item) {
    if ('${item['__type']}' != 'Income') return false;
    for (final value in [
      item['id'],
      item['__source_invoice_id'],
    ]) {
      final id = '${value ?? ''}'.trim();
      if (id.isNotEmpty && _returnedFixedInvoiceIds.contains(id)) return true;
    }
    final invoiceNumber =
        '${item['no_invoice'] ?? item['__number'] ?? ''}'.toUpperCase();
    final compactNumber = invoiceNumber.replaceAll(RegExp(r'[^A-Z0-9]+'), '');
    return RegExp(r'^(CV|PT)ANT\d{6,}$').hasMatch(compactNumber);
  }

  List<Map<String, dynamic>> _applyFilterAndLimit(
      List<Map<String, dynamic>> rows) {
    final q = _search.text.trim().toLowerCase();
    final now = DateTime.now();
    final incomeHistoryStart = _invoiceListIncomeHistoryStart(now);
    final expenseVisibleSince = DateTime(now.year, now.month - 1, 1);
    final rowGroups = <List<Map<String, dynamic>>>[];
    List<Map<String, dynamic>>? activeIncomeGroup;
    for (final row in rows) {
      if ('${row['__type']}' == 'Income') {
        activeIncomeGroup = <Map<String, dynamic>>[row];
        rowGroups.add(activeIncomeGroup);
        continue;
      }

      final linkedIncomeKey = '${row['__linked_income_row_key'] ?? ''}'.trim();
      final activeIncomeKey =
          '${activeIncomeGroup?.first['__invoice_list_row_key'] ?? activeIncomeGroup?.first['id'] ?? ''}'
              .trim();
      if (isInvoiceListAutoExpenseRow(row) &&
          activeIncomeGroup != null &&
          (linkedIncomeKey.isEmpty || linkedIncomeKey == activeIncomeKey)) {
        activeIncomeGroup.add(row);
        continue;
      }

      activeIncomeGroup = null;
      rowGroups.add(<Map<String, dynamic>>[row]);
    }

    bool dateAllowed(Map<String, dynamic> item) {
      final date = Formatters.parseDate(
        item['__date'] ??
            item['tanggal_kop'] ??
            item['tanggal'] ??
            item['created_at'],
      );
      if (date == null) return false;
      final isIncome = '${item['__type']}' == 'Income';
      final isReturnedIncome = _isReturnedFixedInvoiceRow(item);
      if (isIncome && date.isBefore(incomeHistoryStart)) return false;
      if (!isIncome &&
          !isReturnedIncome &&
          date.isBefore(expenseVisibleSince)) {
        return false;
      }
      if (date.isAfter(now)) return false;
      return true;
    }

    final indexedFilteredGroups =
        <({int index, List<Map<String, dynamic>> group})>[];
    for (var index = 0; index < rowGroups.length; index++) {
      final group = rowGroups[index];
      if (group.isEmpty) continue;
      final parent = group.first;
      if (!dateAllowed(parent)) continue;
      if (q.isNotEmpty &&
          !group.any((item) => _matchesKeywordInAnyColumn(item, q))) {
        continue;
      }
      indexedFilteredGroups.add((index: index, group: group));
    }

    indexedFilteredGroups.sort((a, b) {
      final aReturned = _isReturnedFixedInvoiceRow(a.group.first);
      final bReturned = _isReturnedFixedInvoiceRow(b.group.first);
      if (aReturned != bReturned) return aReturned ? -1 : 1;
      return a.index.compareTo(b.index);
    });

    final filtered = indexedFilteredGroups
        .expand((entry) => entry.group)
        .toList(growable: false);

    if (_limit == 'all') {
      return filtered;
    }
    final maxRows = int.tryParse(_limit) ?? 10;
    return limitInvoiceListRows(filtered, maxRows: maxRows);
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
          final isVirtualAutoExpense = item['__virtual_auto_expense'] == true;
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
            onPrimaryAction: isVirtualAutoExpense
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
            onDelete: !isVirtualAutoExpense &&
                    !isExpandedIncomeDetail &&
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
