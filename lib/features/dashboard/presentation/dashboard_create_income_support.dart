part of 'dashboard_page.dart';

extension _AdminCreateIncomeViewStateSupport on _AdminCreateIncomeViewState {
  String _safeInputText(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.toLowerCase() == 'null') return '';
    return raw;
  }

  String _safeNumberInputText(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      final number = value.toDouble();
      if (!number.isFinite) return '';
      return _formatEditableNumberShared(number);
    }
    final raw = value.toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';
    final sanitized = raw.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (sanitized.isEmpty ||
        sanitized == '-' ||
        sanitized == '.' ||
        sanitized == ',') {
      return raw;
    }
    var candidate = sanitized;
    if (candidate.contains('.') && candidate.contains(',')) {
      candidate = candidate.replaceAll('.', '').replaceAll(',', '.');
    } else if (candidate.contains(',') && !candidate.contains('.')) {
      candidate = candidate.replaceAll(',', '.');
    } else if (candidate.contains('.') && candidate.split('.').length > 2) {
      candidate = candidate.replaceAll('.', '');
    }
    final parsed = double.tryParse(candidate);
    if (parsed != null) {
      return _formatEditableNumberShared(parsed);
    }
    return raw;
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
    for (final keyword in _AdminCreateIncomeViewState._companyKeywords) {
      if (RegExp(keyword).hasMatch(normalized)) {
        return true;
      }
    }
    return false;
  }

  double? _resolveHargaPerTon({
    String? customerName,
    required String lokasiMuat,
    required String lokasiBongkar,
    String? muatan,
  }) {
    final matchedRule = _resolveHargaRuleShared(
      rules: _hargaPerTonRules,
      customerName: customerName ?? _customer.text.trim(),
      lokasiMuat: lokasiMuat,
      lokasiBongkar: lokasiBongkar,
    );
    return _resolveHargaPerTonValueShared(
      matchedRule,
      muatan: muatan ?? '',
    );
  }

  double? _resolveFlatSubtotal({
    String? customerName,
    required String lokasiMuat,
    required String lokasiBongkar,
    String? muatan,
  }) {
    final matchedRule = _resolveHargaRuleShared(
      rules: _hargaPerTonRules,
      customerName: customerName ?? _customer.text.trim(),
      lokasiMuat: lokasiMuat,
      lokasiBongkar: lokasiBongkar,
    );
    return _resolveHargaFlatTotalShared(
      matchedRule,
      muatan: muatan ?? '',
    );
  }

  bool _applyAutoHargaPerTon(
    Map<String, dynamic> row, {
    bool force = false,
  }) {
    final previousHarga = '${row['harga'] ?? ''}'.trim();
    final previousSubtotal = '${row['subtotal'] ?? ''}'.trim();
    final wasAuto = row['harga_auto'] == true;
    final wasAutoSubtotal = row['subtotal_auto'] == true;
    final harga = _resolveHargaPerTon(
      customerName: _customer.text.trim(),
      lokasiMuat: '${row['lokasi_muat'] ?? ''}',
      lokasiBongkar: '${row['lokasi_bongkar'] ?? ''}',
      muatan: '${row['muatan'] ?? ''}',
    );
    final flatSubtotal = _resolveFlatSubtotal(
      customerName: _customer.text.trim(),
      lokasiMuat: '${row['lokasi_muat'] ?? ''}',
      lokasiBongkar: '${row['lokasi_bongkar'] ?? ''}',
      muatan: '${row['muatan'] ?? ''}',
    );
    final hasAutoHarga = harga != null && harga > 0;
    final hasFlatSubtotal = flatSubtotal != null && flatSubtotal > 0;
    if (!hasAutoHarga && !hasFlatSubtotal) {
      if (force &&
          (wasAuto || wasAutoSubtotal) &&
          (previousHarga.isNotEmpty || previousSubtotal.isNotEmpty)) {
        row['harga'] = '';
        row['subtotal'] = '';
        row['harga_auto'] = true;
        row['subtotal_auto'] = false;
        return true;
      }
      return false;
    }

    final currentHarga = _toNum(row['harga']);
    final currentSubtotal = _toNum(row['subtotal']);
    final isAuto = row['harga_auto'] == true;
    final isAutoSubtotal = row['subtotal_auto'] == true;
    if (!force &&
        ((currentHarga > 0 && !isAuto) ||
            (currentSubtotal > 0 && !isAutoSubtotal))) {
      return false;
    }

    final nextHarga = hasAutoHarga ? _safeNumberInputText(harga) : '';
    final nextSubtotal =
        hasFlatSubtotal ? _safeNumberInputText(flatSubtotal) : '';
    row['harga'] = nextHarga;
    row['subtotal'] = nextSubtotal;
    row['harga_auto'] = true;
    row['subtotal_auto'] = hasFlatSubtotal;
    return previousHarga != nextHarga ||
        previousSubtotal != nextSubtotal ||
        !wasAuto ||
        wasAutoSubtotal != hasFlatSubtotal;
  }

  bool _isKnownDriverOption(String value) {
    final normalized = _normalizeText(value);
    if (normalized.isEmpty) return false;
    return _AdminCreateIncomeViewState._defaultDriverOptions
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
    for (final entry
        in _AdminCreateIncomeViewState._defaultDriverByPlate.entries) {
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

  List<Map<String, dynamic>> _filterCustomerOptionsByMode(
    List<Map<String, dynamic>> options, {
    String? invoiceEntityOverride,
  }) {
    final effectiveEntity = Formatters.normalizeInvoiceEntity(
      invoiceEntityOverride ?? _invoiceEntity,
    );
    final isCompanyTarget = Formatters.isCompanyInvoiceEntity(effectiveEntity);
    return options.where((option) {
      final name = '${option['customer_name'] ?? option['label'] ?? ''}';
      final isCompanyName = _isCompanyCustomerName(name);
      return isCompanyTarget ? isCompanyName : !isCompanyName;
    }).toList();
  }

  void _switchInvoiceEntity(
    String invoiceEntity,
    List<Map<String, dynamic>> customerOptions,
  ) {
    final nextEntity = Formatters.normalizeInvoiceEntity(invoiceEntity);
    if (_invoiceEntity == nextEntity) return;
    final filtered = _filterCustomerOptionsByMode(
      customerOptions,
      invoiceEntityOverride: nextEntity,
    );
    _refreshState(() {
      _invoiceEntity = nextEntity;
      if (nextEntity == Formatters.invoiceEntityPtAnt) {
        _selectedCustomerOptionId =
            _AdminCreateIncomeViewState._customerManualOptionId;
        _linkedCustomerId = null;
        _linkedOrderId = null;
        return;
      }
      final isCurrentValid = filtered.any(
        (item) => '${item['id']}' == _selectedCustomerOptionId,
      );
      if (!isCurrentValid) {
        _selectedCustomerOptionId =
            _AdminCreateIncomeViewState._customerManualOptionId;
        _linkedCustomerId = null;
        _linkedOrderId = null;
        _customer.clear();
        _email.clear();
        _phone.clear();
        _detailFieldRefreshToken++;
      }
    });
  }

  String _normalizeText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _tryResolvePrefillArmada(List<Map<String, dynamic>> armadas) {
    if (_prefillArmadaResolved || _prefillArmadaName.trim().isEmpty) return;
    if (_details.isEmpty) return;
    if ('${_details.first['armada_id']}'.trim().isNotEmpty) {
      _prefillArmadaResolved = true;
      return;
    }

    final target = _normalizeText(_prefillArmadaName);
    if (target.isEmpty) return;
    Map<String, dynamic>? matched;
    for (final item in armadas) {
      final name = _normalizeText('${item['nama_truk'] ?? ''}');
      if (name.isEmpty) continue;
      if (name == target || name.contains(target) || target.contains(name)) {
        matched = item;
        break;
      }
    }

    _prefillArmadaResolved = true;
    if (matched == null) return;
    _details.first['armada_id'] = '${matched['id']}';
    _applyDefaultDriverForRow(_details.first, armadas: armadas);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshState(() {});
    });
  }

  Future<void> _pickDetailDate(int index, String field) async {
    final initial =
        Formatters.parseDate(_details[index][field]) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (picked == null) return;
    _refreshState(() => _details[index][field] = _toInputDate(picked));
  }

  Future<void> _pickDueDate() async {
    final initial = Formatters.parseDate(_dueDate.text) ??
        _date.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (picked == null) return;
    _refreshState(() => _dueDate.text = _toInputDate(picked));
  }

  Map<String, dynamic> _newDetail() {
    return {
      'lokasi_muat': '',
      'lokasi_muat_manual': '',
      'lokasi_muat_is_manual': false,
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
      'subtotal': '',
      'harga_auto': true,
      'subtotal_auto': false,
    };
  }

  double _detailSubtotal(Map<String, dynamic> row) {
    return _resolveInvoiceDetailSubtotalShared(row);
  }

  String? _nullableInputText(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final lowered = raw.toLowerCase();
    if (lowered == 'null' || lowered == 'undefined' || lowered == '-') {
      return null;
    }
    return raw;
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

  String? _extractPlateFromText(String value) {
    final match = RegExp(
      r'[A-Z]{1,2}\s?[0-9]{1,4}\s?[A-Z]{1,3}',
    ).firstMatch(value.toUpperCase());
    if (match == null) return null;
    final plate = _normalizePlateText(match.group(0) ?? '');
    return plate.isEmpty ? null : plate;
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

  void _normalizeManualRowsToArmadaId(List<Map<String, dynamic>> armadas) {
    if (_details.isEmpty) return;
    final armadaIdByPlate = _buildArmadaIdByPlate(armadas);
    if (armadaIdByPlate.isEmpty) return;
    var changed = false;
    for (final row in _details) {
      final currentArmadaId = '${row['armada_id'] ?? ''}'.trim();
      final currentManual = '${row['armada_manual'] ?? ''}'.trim();
      if (currentArmadaId.isNotEmpty || currentManual.isEmpty) continue;
      final resolvedArmadaId = _resolveArmadaIdFromInput(
        armadaId: currentArmadaId,
        armadaManual: currentManual,
        armadaIdByPlate: armadaIdByPlate,
      );
      if (resolvedArmadaId.isEmpty) continue;
      row['armada_id'] = resolvedArmadaId;
      row['armada_manual'] = '';
      row['armada_is_manual'] = false;
      changed = true;
    }
    for (final row in _details) {
      final beforeDriver = '${row['nama_supir'] ?? ''}'.trim();
      final beforeManual = '${row['nama_supir_manual'] ?? ''}'.trim();
      final beforeIsManual = row['nama_supir_is_manual'] == true;
      final beforeIsAuto = row['nama_supir_auto'] == true;
      _applyDefaultDriverForRow(row, armadas: armadas);
      if (beforeDriver != '${row['nama_supir'] ?? ''}'.trim() ||
          beforeManual != '${row['nama_supir_manual'] ?? ''}'.trim() ||
          beforeIsManual != (row['nama_supir_is_manual'] == true) ||
          beforeIsAuto != (row['nama_supir_auto'] == true)) {
        changed = true;
      }
    }
    if (changed) {
      _detailFieldRefreshToken++;
    }
  }

  double get _subtotal {
    return _details.fold<double>(
      0,
      (sum, row) => sum + _detailSubtotal(row),
    );
  }

  double get _pph => _isCompanyInvoice ? (_subtotal * 0.02).floorToDouble() : 0;
  double get _totalBayar => max(0, _subtotal - _pph);

  void _addDetail() {
    _refreshState(() => _details.add(_newDetail()));
  }

  void _removeDetail(int index) {
    if (_details.length == 1) return;
    _refreshState(() => _details.removeAt(index));
  }
}
