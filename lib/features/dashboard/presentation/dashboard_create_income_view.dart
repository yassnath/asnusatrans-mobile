part of 'dashboard_page.dart';

class _AdminCreateIncomeView extends StatefulWidget {
  const _AdminCreateIncomeView({
    required this.repository,
    required this.onCreated,
    this.prefill,
    this.onPrefillConsumed,
  });

  final DashboardRepository repository;
  final VoidCallback onCreated;
  final _InvoicePrefillData? prefill;
  final VoidCallback? onPrefillConsumed;

  @override
  State<_AdminCreateIncomeView> createState() => _AdminCreateIncomeViewState();
}

class _AdminCreateIncomeViewState extends State<_AdminCreateIncomeView> {
  static const _customerManualOptionId = '__other__';
  static const _manualArmadaOptionId = '__other_manual_armada__';
  static const _manualDriverOptionId = '__other_manual_driver__';
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

  final _customer = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _kopDate = TextEditingController();
  final _kopLocation = TextEditingController();
  final _dueDate = TextEditingController();
  final DateTime _date = DateTime.now();
  bool _isCompanyInvoice = true;
  String _status = 'Unpaid';
  String _acceptedBy = 'Admin';
  bool _loading = false;
  late Future<List<dynamic>> _formFuture;
  final List<Map<String, dynamic>> _details = [];
  List<Map<String, dynamic>> _hargaPerTonRules = const [];
  bool _prefillApplied = false;
  bool _prefillArmadaResolved = false;

  @override
  void dispose() {
    _customer.dispose();
    _email.dispose();
    _phone.dispose();
    _kopDate.dispose();
    _kopLocation.dispose();
    _dueDate.dispose();
    super.dispose();
  }

  String _prefillArmadaName = '';
  String _selectedCustomerOptionId = _customerManualOptionId;
  int _detailFieldRefreshToken = 0;
  int _hargaFieldRefreshToken = 0;
  String? _linkedCustomerId;
  String? _linkedOrderId;
  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  String _t(String id, String en) => _isEn ? en : id;

  @override
  void initState() {
    super.initState();
    _formFuture = _loadFormData();
    _details.add(_newDetail());
    _kopDate.text = _toInputDate(_date);
    _applyPrefill(widget.prefill);
  }

  @override
  void didUpdateWidget(covariant _AdminCreateIncomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prefill != widget.prefill) {
      _applyPrefill(widget.prefill);
    }
  }

  void _applyPrefill(_InvoicePrefillData? prefill) {
    if (prefill == null || _prefillApplied) return;

    final customerName = (prefill.customerName ?? '').trim();
    final customerEmail = (prefill.customerEmail ?? '').trim();
    final customerPhone = (prefill.customerPhone ?? '').trim();
    final pickup = (prefill.pickup ?? '').trim();
    final destination = (prefill.destination ?? '').trim();
    final armadaName = (prefill.armadaName ?? '').trim();

    if (customerName.isNotEmpty && _customer.text.trim().isEmpty) {
      _customer.text = customerName;
    }
    if (customerEmail.isNotEmpty && _email.text.trim().isEmpty) {
      _email.text = customerEmail;
    }
    if (customerPhone.isNotEmpty && _phone.text.trim().isEmpty) {
      _phone.text = customerPhone;
    }

    if (_details.isNotEmpty) {
      final first = _details.first;
      if (pickup.isNotEmpty && '${first['lokasi_muat']}'.trim().isEmpty) {
        first['lokasi_muat'] = pickup;
      }
      if (destination.isNotEmpty &&
          '${first['lokasi_bongkar']}'.trim().isEmpty) {
        first['lokasi_bongkar'] = destination;
      }
      if (prefill.pickupDate != null &&
          '${first['armada_start_date']}'.trim().isEmpty) {
        first['armada_start_date'] = _toInputDate(prefill.pickupDate!);
      }
    }

    _linkedCustomerId = prefill.customerId?.trim();
    _linkedOrderId = prefill.orderId?.trim();
    _prefillArmadaName = armadaName;
    _prefillApplied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onPrefillConsumed?.call();
    });
  }

  Future<List<dynamic>> _loadFormData() {
    return Future.wait<dynamic>([
      widget.repository.fetchArmadas(),
      widget.repository.fetchInvoiceCustomerOptions(),
      widget.repository.fetchHargaPerTonRules(),
    ]);
  }

  void _applySavedCustomerOption(
    String? optionId,
    List<Map<String, dynamic>> options, {
    required List<Map<String, dynamic>> armadas,
  }) {
    if (optionId == null) return;
    if (optionId == _customerManualOptionId) {
      setState(() {
        _selectedCustomerOptionId = _customerManualOptionId;
        _linkedCustomerId = null;
        _linkedOrderId = null;
      });
      return;
    }

    final selected = options.cast<Map<String, dynamic>?>().firstWhere(
          (option) => '${option?['id'] ?? ''}' == optionId,
          orElse: () => null,
        );
    if (selected == null) return;

    Map<String, dynamic> toDetailRow(Map<String, dynamic> option) {
      final hargaText = _safeNumberInputText(option['harga']);
      final driverText = _safeInputText(option['nama_supir']);
      final isDriverManual =
          driverText.isNotEmpty && !_isKnownDriverOption(driverText);
      final row = <String, dynamic>{
        'lokasi_muat': _safeInputText(option['lokasi_muat']),
        'lokasi_bongkar': _safeInputText(option['lokasi_bongkar']),
        'muatan': _safeInputText(option['muatan']),
        'nama_supir': driverText,
        'nama_supir_manual': isDriverManual ? driverText : '',
        'nama_supir_is_manual': isDriverManual,
        'nama_supir_auto': false,
        'armada_id': _safeInputText(option['armada_id']),
        'armada_manual': _safeInputText(option['armada_manual']),
        'armada_is_manual':
            _safeInputText(option['armada_manual']).isNotEmpty &&
                _safeInputText(option['armada_id']).isEmpty,
        'armada_start_date': _safeInputText(option['armada_start_date']),
        'armada_end_date': _safeInputText(option['armada_end_date']),
        'tonase': _safeNumberInputText(option['tonase']),
        'harga': hargaText,
        'harga_auto': hargaText.isEmpty,
      };
      final defaultDriver =
          _resolveDefaultDriverForRow(row, armadas: armadas)?.trim() ?? '';
      if (!isDriverManual && defaultDriver.isNotEmpty) {
        if (driverText.isEmpty ||
            _normalizeText(driverText) == _normalizeText(defaultDriver)) {
          row['nama_supir'] = defaultDriver;
          row['nama_supir_manual'] = '';
          row['nama_supir_is_manual'] = false;
          row['nama_supir_auto'] = true;
        }
      }
      return row;
    }

    final selectedDetails = (selected['details'] is List)
        ? (selected['details'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : const <Map<String, dynamic>>[];
    final sourceOptions = selectedDetails.isNotEmpty
        ? selectedDetails
        : <Map<String, dynamic>>[selected];

    setState(() {
      _selectedCustomerOptionId = optionId;
      _linkedCustomerId = '${selected['customer_id'] ?? ''}'.trim().isEmpty
          ? null
          : '${selected['customer_id']}'.trim();
      _linkedOrderId = null;
      _customer.text = '${selected['customer_name'] ?? ''}'.trim();
      _email.text = '${selected['email'] ?? ''}'.trim();
      _phone.text = '${selected['phone'] ?? ''}'.trim();
      final selectedKopDate = '${selected['tanggal_kop'] ?? ''}'.trim();
      final selectedKopLocation = '${selected['lokasi_kop'] ?? ''}'.trim();
      if (selectedKopDate.isNotEmpty) {
        _kopDate.text = selectedKopDate;
      }
      if (selectedKopLocation.isNotEmpty) {
        _kopLocation.text = selectedKopLocation;
      }

      _details
        ..clear()
        ..addAll(sourceOptions.map(toDetailRow));
      if (_details.isEmpty) {
        _details.add(_newDetail());
      }
      for (final row in _details) {
        _applyAutoHargaPerTon(row);
      }
      _detailFieldRefreshToken++;
    });
  }

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
      return number.floor().toString();
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
      return parsed.floor().toString();
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
    for (final keyword in _companyKeywords) {
      if (RegExp(keyword).hasMatch(normalized)) {
        return true;
      }
    }
    return false;
  }

  String _normalizeLokasiKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _lokasiKeyMatches(String inputKey, String ruleKey) {
    if (inputKey.isEmpty || ruleKey.isEmpty) return false;
    if (inputKey == ruleKey) return true;

    final inputTokens = inputKey.split(' ').where((part) => part.isNotEmpty);
    final ruleTokens = ruleKey.split(' ').where((part) => part.isNotEmpty);
    final inputList = inputTokens.toList(growable: false);
    final ruleList = ruleTokens.toList(growable: false);

    if (inputList.length < 2 || ruleList.isEmpty) {
      return false;
    }

    final shorter = inputList.length <= ruleList.length ? inputList : ruleList;
    final longer = inputList.length <= ruleList.length ? ruleList : inputList;
    return shorter.length >= 2 &&
        shorter.every((token) => longer.contains(token));
  }

  double? _resolveHargaPerTon({
    required String lokasiMuat,
    required String lokasiBongkar,
  }) {
    if (_hargaPerTonRules.isEmpty) return null;
    final bongkarKey = _normalizeLokasiKey(lokasiBongkar);
    if (bongkarKey.isEmpty) return null;
    final muatKey = _normalizeLokasiKey(lokasiMuat);

    Map<String, dynamic>? exactMatch;
    Map<String, dynamic>? fallbackMatch;

    for (final rule in _hargaPerTonRules) {
      final ruleBongkar =
          _normalizeLokasiKey('${rule['lokasi_bongkar'] ?? ''}'.trim());
      if (!_lokasiKeyMatches(bongkarKey, ruleBongkar)) continue;

      final ruleMuat =
          _normalizeLokasiKey('${rule['lokasi_muat'] ?? ''}'.trim());
      if (muatKey.isNotEmpty &&
          ruleMuat.isNotEmpty &&
          _lokasiKeyMatches(muatKey, ruleMuat)) {
        exactMatch = rule;
        break;
      }
      fallbackMatch ??= rule;
    }

    final matchedRule = exactMatch ?? fallbackMatch;
    if (matchedRule == null) return null;
    final resolved =
        _toNum(matchedRule['harga_per_ton'] ?? matchedRule['harga']);
    return resolved > 0 ? resolved : null;
  }

  bool _applyAutoHargaPerTon(
    Map<String, dynamic> row, {
    bool force = false,
  }) {
    final previousHarga = '${row['harga'] ?? ''}'.trim();
    final wasAuto = row['harga_auto'] == true;
    final harga = _resolveHargaPerTon(
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

    final nextHarga = _safeNumberInputText(harga);
    row['harga'] = nextHarga;
    row['harga_auto'] = true;
    return previousHarga != nextHarga || !wasAuto;
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

  List<Map<String, dynamic>> _filterCustomerOptionsByMode(
    List<Map<String, dynamic>> options, {
    bool? isCompanyOverride,
  }) {
    final isCompanyTarget = isCompanyOverride ?? _isCompanyInvoice;
    return options.where((option) {
      final name = '${option['customer_name'] ?? option['label'] ?? ''}';
      final isCompanyName = _isCompanyCustomerName(name);
      return isCompanyTarget ? isCompanyName : !isCompanyName;
    }).toList();
  }

  void _switchInvoiceMode(
    bool isCompany,
    List<Map<String, dynamic>> customerOptions,
  ) {
    if (_isCompanyInvoice == isCompany) return;
    final filtered = _filterCustomerOptionsByMode(
      customerOptions,
      isCompanyOverride: isCompany,
    );
    setState(() {
      _isCompanyInvoice = isCompany;
      final isCurrentValid = filtered.any(
        (item) => '${item['id']}' == _selectedCustomerOptionId,
      );
      if (!isCurrentValid) {
        _selectedCustomerOptionId = _customerManualOptionId;
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
      setState(() {});
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
    setState(() => _details[index][field] = _toInputDate(picked));
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
    setState(() => _dueDate.text = _toInputDate(picked));
  }

  Map<String, dynamic> _newDetail() {
    return {
      'lokasi_muat': '',
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
    };
  }

  double _detailSubtotal(Map<String, dynamic> row) {
    return _toNum(row['tonase']) * _toNum(row['harga']);
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
    setState(() => _details.add(_newDetail()));
  }

  void _removeDetail(int index) {
    if (_details.length == 1) return;
    setState(() => _details.removeAt(index));
  }

  Future<void> _save(List<Map<String, dynamic>> armadas) async {
    final customer = _customer.text.trim();
    if (customer.isEmpty || _subtotal <= 0) {
      _snack(
        _t('Nama customer dan rincian wajib diisi.',
            'Customer name and details are required.'),
        error: true,
      );
      return;
    }
    final first = _details.first;
    final firstArmadaId = '${first['armada_id']}'.trim();
    final firstArmadaManual = '${first['armada_manual'] ?? ''}'.trim();
    final armadaIdByPlate = _buildArmadaIdByPlate(armadas);
    final firstResolvedArmadaId = _resolveArmadaIdFromInput(
      armadaId: firstArmadaId,
      armadaManual: firstArmadaManual,
      armadaIdByPlate: armadaIdByPlate,
    );
    final hasArmadaSelection =
        firstResolvedArmadaId.isNotEmpty || firstArmadaManual.isNotEmpty;
    if ('${first['lokasi_muat']}'.trim().isEmpty ||
        '${first['lokasi_bongkar']}'.trim().isEmpty ||
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

    final selectedArmadaIds = _details
        .map(
          (row) => _resolveArmadaIdFromInput(
            armadaId: '${row['armada_id']}'.trim(),
            armadaManual: '${row['armada_manual'] ?? ''}'.trim(),
            armadaIdByPlate: armadaIdByPlate,
          ),
        )
        .where((id) => id.isNotEmpty)
        .toSet();
    Map<String, dynamic>? busyArmada;
    for (final armada in armadas) {
      final id = '${armada['id']}'.trim();
      if (!selectedArmadaIds.contains(id)) continue;
      final status = '${armada['status'] ?? 'Ready'}'.trim().toLowerCase();
      if (status != 'ready') {
        busyArmada = armada;
        break;
      }
    }
    if (busyArmada != null) {
      final armadaLabel =
          '${busyArmada['nama_truk'] ?? '-'} - ${busyArmada['plat_nomor'] ?? '-'}'
              .trim();
      final proceed = await showCvantConfirmPopup(
        context: context,
        type: CvantPopupType.warning,
        title: _t('Warning', 'Warning'),
        message: _t(
          'Armada $armadaLabel masih on the way. Apakah customer ingin menunggu?',
          'Fleet $armadaLabel is still on the way. Does the customer want to wait?',
        ),
        cancelLabel: _t('Tidak', 'No'),
        confirmLabel: _t('Ya', 'Yes'),
      );
      if (!proceed) return;
    }

    final detailsPayload = _details.map((row) {
      final armadaId = '${row['armada_id']}'.trim();
      final armadaManualRaw = _nullableInputText(row['armada_manual']) ?? '';
      final resolvedArmadaId = _resolveArmadaIdFromInput(
        armadaId: armadaId,
        armadaManual: armadaManualRaw,
        armadaIdByPlate: armadaIdByPlate,
      );
      final useManual = resolvedArmadaId.isEmpty && armadaManualRaw.isNotEmpty;
      return <String, dynamic>{
        'lokasi_muat': '${row['lokasi_muat']}'.trim(),
        'lokasi_bongkar': '${row['lokasi_bongkar']}'.trim(),
        'muatan': _nullableInputText(row['muatan']),
        'nama_supir': _nullableInputText(row['nama_supir']),
        'armada_id': resolvedArmadaId.isEmpty ? null : resolvedArmadaId,
        'armada_manual': useManual ? armadaManualRaw : null,
        'armada_label': useManual ? armadaManualRaw : null,
        'armada_start_date': '${row['armada_start_date']}'.trim().isEmpty
            ? null
            : '${row['armada_start_date']}',
        'armada_end_date': '${row['armada_end_date']}'.trim().isEmpty
            ? null
            : '${row['armada_end_date']}',
        'tonase': _toNum(row['tonase']),
        'harga': _toNum(row['harga']),
      };
    }).toList();
    final driverNames = detailsPayload
        .map((row) => _nullableInputText(row['nama_supir']))
        .whereType<String>()
        .expand(
          (value) => value
              .split(RegExp(r'[,;/]'))
              .map((part) => _nullableInputText(part))
              .whereType<String>(),
        )
        .toSet()
        .join(', ');

    DateTime? resolveDepartureDate() {
      for (final row in detailsPayload) {
        final parsed = Formatters.parseDate(row['armada_start_date']);
        if (parsed != null) return parsed;
      }
      return Formatters.parseDate(first['armada_start_date']);
    }

    final resolvedDepartureDate = resolveDepartureDate();
    final effectiveDate =
        resolvedDepartureDate ?? Formatters.parseDate(_kopDate.text) ?? _date;

    setState(() => _loading = true);
    try {
      await widget.repository.createInvoice(
        customerName: customer,
        total: _subtotal,
        noInvoice: null,
        includePph: _isCompanyInvoice,
        status: _status,
        issuedDate: effectiveDate,
        email: _email.text,
        noTelp: _phone.text,
        kopDate: Formatters.parseDate(_kopDate.text) ?? _date,
        kopLocation: _kopLocation.text,
        dueDate: Formatters.parseDate(_dueDate.text),
        pickup: '${first['lokasi_muat']}',
        destination: '${first['lokasi_bongkar']}',
        muatan: _nullableInputText(first['muatan']),
        armadaId: firstResolvedArmadaId.isEmpty ? null : firstResolvedArmadaId,
        armadaStartDate: Formatters.parseDate(first['armada_start_date']),
        armadaEndDate: Formatters.parseDate(first['armada_end_date']),
        tonase: _toNum(first['tonase']),
        harga: _toNum(first['harga']),
        namaSupir: driverNames.isEmpty ? null : driverNames,
        acceptedBy: _acceptedBy,
        customerId: _linkedCustomerId,
        orderId: _linkedOrderId,
        details: detailsPayload,
      );
      if (!mounted) return;
      _customer.clear();
      _email.clear();
      _phone.clear();
      _kopDate.text = _toInputDate(_date);
      _kopLocation.clear();
      _dueDate.clear();
      _status = 'Unpaid';
      _acceptedBy = 'Admin';
      _linkedCustomerId = null;
      _linkedOrderId = null;
      _prefillApplied = false;
      _prefillArmadaName = '';
      _prefillArmadaResolved = false;
      _details
        ..clear()
        ..add(_newDetail());
      _selectedCustomerOptionId = _customerManualOptionId;
      _formFuture = _loadFormData();
      await showCvantPopup(
        context: context,
        type: CvantPopupType.success,
        title: _t('Success', 'Success'),
        message: _t(
          'Invoice income berhasil ditambahkan.',
          'Income invoice was added successfully.',
        ),
        okLabel: 'OK',
        showOkButton: true,
        showCloseButton: true,
        barrierDismissible: false,
        autoCloseAfter: const Duration(seconds: 3),
      );
      if (!mounted) return;
      widget.onCreated();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
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

  Widget _buildInvoiceModeDot({
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color:
                    selected ? Colors.white : AppColors.textPrimaryFor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _formFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError) {
          return _ErrorView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() {
              _formFuture = _loadFormData();
            }),
          );
        }

        final payload = snapshot.data;
        if (payload == null || payload.length < 2) {
          return _ErrorView(
            message: _t(
              'Gagal memuat data form invoice.',
              'Failed to load invoice form data.',
            ),
            onRetry: () => setState(() {
              _formFuture = _loadFormData();
            }),
          );
        }
        final armadas = (payload[0] is List
                ? (payload[0] as List)
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
                : const <Map<String, dynamic>>[])
            .cast<Map<String, dynamic>>();
        final customerOptions = (payload[1] is List
                ? (payload[1] as List)
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
                : const <Map<String, dynamic>>[])
            .cast<Map<String, dynamic>>();
        final hargaPerTonRules = (payload.length > 2 && payload[2] is List)
            ? (payload[2] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : const <Map<String, dynamic>>[];
        _hargaPerTonRules = hargaPerTonRules;
        final isEn = _isEn;
        final filteredCustomerOptions =
            _filterCustomerOptionsByMode(customerOptions);
        _tryResolvePrefillArmada(armadas);
        _normalizeManualRowsToArmadaId(armadas);
        final selectedCustomerValue = filteredCustomerOptions.any(
                    (item) => '${item['id']}' == _selectedCustomerOptionId) ||
                _selectedCustomerOptionId == _customerManualOptionId
            ? _selectedCustomerOptionId
            : _customerManualOptionId;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Mode Invoice', 'Invoice Mode'),
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInvoiceModeDot(
                          label: isEn ? 'Personal' : 'Pribadi',
                          selected: !_isCompanyInvoice,
                          onTap: () =>
                              _switchInvoiceMode(false, customerOptions),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInvoiceModeDot(
                          label: isEn ? 'Company' : 'Perusahaan',
                          selected: _isCompanyInvoice,
                          onTap: () =>
                              _switchInvoiceMode(true, customerOptions),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CvantDropdownField<String>(
                    initialValue: selectedCustomerValue,
                    decoration: InputDecoration(
                      labelText:
                          _t('Data Customer Tersimpan', 'Saved Customer Data'),
                    ),
                    items: [
                      ...filteredCustomerOptions.map(
                        (option) => DropdownMenuItem<String>(
                          value: '${option['id']}',
                          child: Text('${option['label'] ?? '-'}'),
                        ),
                      ),
                      DropdownMenuItem<String>(
                        value: _customerManualOptionId,
                        child: Text(
                            _t('Other (Input Manual)', 'Other (Manual Input)')),
                      ),
                    ],
                    onChanged: (value) => _applySavedCustomerOption(
                      value,
                      filteredCustomerOptions,
                      armadas: armadas,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _customer,
                    decoration: InputDecoration(
                      labelText: _t('Nama Customer', 'Customer Name'),
                      hintText: _t('Nama pelanggan', 'Customer name'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: _t('Email Customer', 'Customer Email'),
                      hintText: 'email@domain.com',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: _t('No. Telp', 'Phone Number'),
                      hintText: '0812xxxx',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('Rincian Muat / Bongkar & Armada',
                        'Loading / Unloading & Fleet Details'),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ..._details.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    final rowSubtotal = _detailSubtotal(row);

                    final muatValue = '${row['lokasi_muat'] ?? ''}'.trim();
                    final muatManual =
                        '${row['lokasi_muat_manual'] ?? ''}'.trim();
                    final isMuatManual = muatManual.isNotEmpty ||
                        (muatValue.isNotEmpty &&
                            !_defaultMuatOptions.contains(muatValue));

                    return Container(
                      margin: EdgeInsets.only(
                          bottom: index == _details.length - 1 ? 0 : 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: AppColors.cardBorder(context)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          CvantDropdownField<String>(
                            initialValue: isMuatManual
                                ? 'Other (Input Manual)'
                                : (muatValue.isNotEmpty ? muatValue : null),
                            decoration: InputDecoration(
                              hintText: _t('Lokasi Muat', 'Loading Location'),
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
                                  _t('Other (Input Manual)',
                                      'Other (Manual Input)'),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                if (value == 'Other (Input Manual)') {
                                  row['lokasi_muat'] = '';
                                  row['lokasi_muat_manual'] = '';
                                } else {
                                  row['lokasi_muat'] = value ?? '';
                                  row['lokasi_muat_manual'] = '';
                                }
                                final hargaChanged = _applyAutoHargaPerTon(
                                  row,
                                  force: row['harga_auto'] == true,
                                );
                                if (hargaChanged) {
                                  _hargaFieldRefreshToken++;
                                }
                              });
                            },
                          ),
                          if (isMuatManual) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              key: ValueKey(
                                'lokasi_muat_manual-$index-$_detailFieldRefreshToken',
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
                                final hargaChanged = _applyAutoHargaPerTon(
                                  row,
                                  force: row['harga_auto'] == true,
                                );
                                setState(() {
                                  if (hargaChanged) {
                                    _hargaFieldRefreshToken++;
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                          ] else
                            const SizedBox(height: 8),
                          TextFormField(
                            key: ValueKey(
                              'lokasi_bongkar-$index-$_detailFieldRefreshToken',
                            ),
                            initialValue: '${row['lokasi_bongkar']}',
                            decoration: InputDecoration(
                              hintText:
                                  _t('Lokasi Bongkar', 'Unloading Location'),
                            ),
                            onChanged: (value) {
                              row['lokasi_bongkar'] = value;
                              final hargaChanged =
                                  _applyAutoHargaPerTon(row, force: true);
                              setState(() {
                                if (hargaChanged) {
                                  _hargaFieldRefreshToken++;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: ValueKey(
                              'muatan-$index-$_detailFieldRefreshToken',
                            ),
                            initialValue: '${row['muatan'] ?? ''}',
                            decoration: InputDecoration(
                              hintText:
                                  _t('Muatan (Opsional)', 'Cargo (Optional)'),
                            ),
                            onChanged: (value) => row['muatan'] = value,
                          ),
                          const SizedBox(height: 8),
                          CvantDropdownField<String>(
                            key: ValueKey(
                              'armada-$index-${row['armada_id']}-${row['armada_manual']}-${row['armada_is_manual']}',
                            ),
                            initialValue: () {
                              final armadaId = '${row['armada_id']}'.trim();
                              final armadaManual =
                                  '${row['armada_manual'] ?? ''}'.trim();
                              final isManual = row['armada_is_manual'] == true;
                              if (armadaId.isNotEmpty) return armadaId;
                              if (isManual || armadaManual.isNotEmpty) {
                                return _manualArmadaOptionId;
                              }
                              return '';
                            }(),
                            decoration: InputDecoration(
                              hintText: _t('Pilih Armada', 'Select Fleet'),
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
                                          text: '(${a['status'] ?? 'Ready'})',
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
                              setState(() {
                                if (value == _manualArmadaOptionId) {
                                  row['armada_id'] = '';
                                  row['armada_is_manual'] = true;
                                } else {
                                  row['armada_id'] = value ?? '';
                                  row['armada_is_manual'] = false;
                                  if ('${row['armada_id']}'.trim().isNotEmpty) {
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
                                _detailFieldRefreshToken++;
                              });
                            },
                          ),
                          if (row['armada_is_manual'] == true ||
                              ('${row['armada_manual'] ?? ''}'
                                      .trim()
                                      .isNotEmpty &&
                                  '${row['armada_id']}'.trim().isEmpty)) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              key: ValueKey(
                                'armada_manual-$index-$_detailFieldRefreshToken',
                              ),
                              initialValue: '${row['armada_manual'] ?? ''}',
                              decoration: InputDecoration(
                                hintText: _t(
                                  'Plat Nomor Manual (Other/Gabungan)',
                                  'Manual Plate Number (Other/Combined)',
                                ),
                              ),
                              onChanged: (value) => setState(() {
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
                              'driver-$index-${row['nama_supir']}-${row['nama_supir_manual']}-${row['nama_supir_is_manual']}-${row['nama_supir_auto']}',
                            ),
                            initialValue: () {
                              final driver =
                                  '${row['nama_supir'] ?? ''}'.trim();
                              final driverManual =
                                  '${row['nama_supir_manual'] ?? ''}'.trim();
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
                              hintText:
                                  _t('Pilih Nama Supir', 'Select Driver Name'),
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
                                child: Text(_t(
                                  'Other (Input Manual)',
                                  'Other (Manual Input)',
                                )),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                if (value == _manualDriverOptionId) {
                                  _enableManualDriverInput(row);
                                } else {
                                  row['nama_supir'] = value ?? '';
                                  row['nama_supir_manual'] = '';
                                  row['nama_supir_is_manual'] = false;
                                }
                                row['nama_supir_auto'] = false;
                                _detailFieldRefreshToken++;
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
                                'nama_supir_manual-$index-$_detailFieldRefreshToken',
                              ),
                              initialValue: '${row['nama_supir_manual'] ?? ''}',
                              decoration: InputDecoration(
                                hintText: _t(
                                  'Nama Supir (Manual)',
                                  'Driver Name (Manual)',
                                ),
                              ),
                              onChanged: (value) => setState(() {
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
                                child: InkWell(
                                  onTap: () => _pickDetailDate(
                                    index,
                                    'armada_start_date',
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText:
                                          _t('Tanggal Mulai', 'Start Date'),
                                    ),
                                    child: Text(
                                      '${row['armada_start_date']}'
                                              .trim()
                                              .isEmpty
                                          ? '-'
                                          : Formatters.dmy(
                                              row['armada_start_date'],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      _pickDetailDate(index, 'armada_end_date'),
                                  borderRadius: BorderRadius.circular(8),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText:
                                          _t('Tanggal Selesai', 'End Date'),
                                    ),
                                    child: Text(
                                      '${row['armada_end_date']}'.trim().isEmpty
                                          ? '-'
                                          : Formatters.dmy(
                                              row['armada_end_date'],
                                            ),
                                    ),
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
                                    'tonase-$index-$_detailFieldRefreshToken',
                                  ),
                                  initialValue: '${row['tonase']}',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _t('Tonase', 'Tonnage'),
                                  ),
                                  onChanged: (value) {
                                    row['tonase'] = value;
                                    setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  key: ValueKey(
                                    'harga-$index-$_detailFieldRefreshToken-$_hargaFieldRefreshToken',
                                  ),
                                  initialValue: '${row['harga']}',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _t('Harga / Ton', 'Price / Ton'),
                                  ),
                                  onChanged: (value) {
                                    row['harga'] = value;
                                    row['harga_auto'] = false;
                                    setState(() {});
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
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              if (_details.length > 1)
                                TextButton(
                                  onPressed: () => _removeDetail(index),
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
                    onPressed: _addDetail,
                    child: Text(_t('+ Tambah Rincian', '+ Add Detail')),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration:
                        InputDecoration(labelText: _t('Subtotal', 'Subtotal')),
                    child: Text(Formatters.rupiah(_subtotal)),
                  ),
                  if (_isCompanyInvoice) ...[
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'PPH (2%)'),
                      child: Text(Formatters.rupiah(_pph)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: InputDecoration(
                        labelText: _t('Total Bayar', 'Grand Total')),
                    child: Text(Formatters.rupiah(_totalBayar)),
                  ),
                  const SizedBox(height: 8),
                  CvantDropdownField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: _t('Status', 'Status'),
                    ),
                    items: const ['Unpaid', 'Paid', 'Waiting']
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _status = value ?? _status),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDueDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: _t('Tanggal Pelunasan', 'Payment Date'),
                      ),
                      child: Text(
                        _dueDate.text.trim().isEmpty
                            ? '-'
                            : Formatters.dmy(_dueDate.text.trim()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CvantDropdownField<String>(
                    initialValue: _acceptedBy,
                    decoration: InputDecoration(
                      labelText: _t('Diterima Oleh', 'Accepted By'),
                    ),
                    items: const ['Admin', 'Owner']
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _acceptedBy = value ?? _acceptedBy),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : () => _save(armadas),
                      child: Text(
                        _loading
                            ? _t('Menyimpan...', 'Saving...')
                            : _t('Simpan', 'Save'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _DashboardContentFooter(),
          ],
        );
      },
    );
  }

  String _toInputDate(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '${value.year}-$mm-$dd';
  }
}
