part of 'dashboard_page.dart';

bool _isOngkosKuliIncomeRow(Map<String, dynamic> row) {
  return isOngkosKuliCargo('${row['muatan'] ?? ''}');
}

bool _hasRequiredIncomeDetailDate(Map<String, dynamic> row) {
  return '${row['armada_start_date'] ?? ''}'.trim().isNotEmpty;
}

void _enableDirectTotalOnlyIncomeRow(Map<String, dynamic> row) {
  row['tonase'] = '';
  row['harga'] = '';
  row['harga_auto'] = false;
  row['subtotal_auto'] = false;
}

void _resetDirectTotalOnlyIncomeRow(Map<String, dynamic> row) {
  row['subtotal'] = '';
  row['harga_auto'] = true;
  row['subtotal_auto'] = false;
}

double? _nullableIncomeNumber(dynamic value) {
  if (value == null) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty || raw.toLowerCase() == 'null' || raw == '-') {
    return null;
  }
  return _toNum(value);
}

class _IncomeDuplicateMatch {
  const _IncomeDuplicateMatch({
    required this.invoiceNumber,
    required this.customerName,
    required this.dateLabel,
    required this.routeLabel,
    required this.armadaLabel,
    this.fixedInvoiceNumber,
  });

  final String invoiceNumber;
  final String customerName;
  final String dateLabel;
  final String routeLabel;
  final String armadaLabel;
  final String? fixedInvoiceNumber;
}

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

  /// Pricing customer/route biasa tidak boleh tercampur rule armada Gabungan.
  List<Map<String, dynamic>> get _nonGabunganRules =>
      _hargaPerTonRules.where(isRegularIncomeHargaRule).toList(growable: false);

  double? _resolveHargaPerTon({
    String? customerName,
    required String lokasiMuat,
    required String lokasiBongkar,
    String? muatan,
  }) {
    final matchedRule = _resolveHargaRuleShared(
      rules: _nonGabunganRules,
      customerName: customerName ?? _customer.text.trim(),
      lokasiMuat: lokasiMuat,
      lokasiBongkar: lokasiBongkar,
      muatan: muatan ?? '',
    );
    final adjustedHarga = _resolveHargaPerTonValueShared(
      matchedRule,
      muatan: muatan ?? '',
    );
    return resolveIncomeRegularHargaForRoute(
      regularRule: matchedRule,
      adjustedRegularHarga: adjustedHarga,
      pickup: lokasiMuat,
      destination: lokasiBongkar,
    );
  }

  double? _resolveFlatSubtotal({
    String? customerName,
    required String lokasiMuat,
    required String lokasiBongkar,
    String? muatan,
  }) {
    final matchedRule = _resolveHargaRuleShared(
      rules: _nonGabunganRules,
      customerName: customerName ?? _customer.text.trim(),
      lokasiMuat: lokasiMuat,
      lokasiBongkar: lokasiBongkar,
      muatan: muatan ?? '',
    );
    return _resolveHargaFlatTotalShared(
      matchedRule,
      muatan: muatan ?? '',
    );
  }

  bool _applyAutoHargaPerTon(
    Map<String, dynamic> row, {
    bool force = false,
    List<Map<String, dynamic>>? armadas,
  }) {
    final previousHarga = '${row['harga'] ?? ''}'.trim();
    final previousSubtotal = '${row['subtotal'] ?? ''}'.trim();
    final wasAuto = row['harga_auto'] == true;
    final wasAutoSubtotal = row['subtotal_auto'] == true;
    final isManualArmada = _usesEffectiveManualArmada(row, armadas: armadas);
    final lokasiMuat = '${row['lokasi_muat'] ?? ''}';
    final lokasiBongkar = '${row['lokasi_bongkar'] ?? ''}';
    final muatan = '${row['muatan'] ?? ''}';

    final regularHarga = _resolveHargaPerTon(
      customerName: _customer.text.trim(),
      lokasiMuat: lokasiMuat,
      lokasiBongkar: lokasiBongkar,
      muatan: muatan,
    );
    final harga = resolveIncomeAutoHargaPerKg(
      regularHarga: regularHarga,
      usesManualArmada: isManualArmada,
      pickup: lokasiMuat,
      destination: lokasiBongkar,
      gabunganRules: _hargaPerTonRules,
    );
    final flatSubtotal = _resolveFlatSubtotal(
      customerName: _customer.text.trim(),
      lokasiMuat: lokasiMuat,
      lokasiBongkar: lokasiBongkar,
      muatan: muatan,
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

  bool _isManualArmadaRow(Map<String, dynamic> row) {
    return rowUsesManualArmada(row);
  }

  bool _isManualArmadaText(dynamic value) {
    return isManualArmadaText(value);
  }

  void _clearDriverForManualArmadaIfNeeded(Map<String, dynamic> row) {
    if (!_usesEffectiveManualArmada(row)) return;
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
      '__row_key': _newDetailRowKey(),
      'lokasi_muat': '',
      'lokasi_muat_manual': '',
      'lokasi_muat_is_manual': false,
      'lokasi_bongkar': '',
      'muatan': _AdminCreateIncomeViewState._defaultCargoText,
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
    return _resolveInvoiceDetailExcelSubtotalShared(row);
  }

  Future<List<_IncomeDuplicateMatch>> _findDuplicateIncomeMatches({
    required List<Map<String, dynamic>> detailsPayload,
    required List<Map<String, dynamic>> armadas,
  }) async {
    final plateByArmadaId = _buildArmadaPlateById(armadas);
    final targetSignatures = detailsPayload
        .map(
          (detail) => _incomeDuplicateSignature(
            customerName: _customer.text.trim(),
            invoiceEntity: _invoiceEntity,
            detail: detail,
            parent: null,
            plateByArmadaId: plateByArmadaId,
          ),
        )
        .where((signature) => signature.isNotEmpty)
        .toSet();
    if (targetSignatures.isEmpty) return const <_IncomeDuplicateMatch>[];

    final results = await Future.wait<dynamic>([
      widget.repository.fetchInvoices(),
      widget.repository.fetchFixedInvoiceBatches(),
    ]);
    final invoices = (results[0] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final fixedBatches = (results[1] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(_FixedInvoiceBatch.fromJson)
        .whereType<_FixedInvoiceBatch>()
        .toList(growable: false);
    final fixedNumberByInvoiceId = <String, String>{};
    for (final batch in fixedBatches) {
      final invoiceNumber = batch.invoiceNumber.trim();
      if (invoiceNumber.isEmpty) continue;
      for (final id in batch.invoiceIds) {
        fixedNumberByInvoiceId[id.trim()] = invoiceNumber;
      }
    }

    final matches = <_IncomeDuplicateMatch>[];
    final seenInvoiceIds = <String>{};
    for (final invoice in invoices) {
      final invoiceId = '${invoice['id'] ?? ''}'.trim();
      final rows = _incomeDuplicateRowsForInvoice(invoice);
      Map<String, dynamic>? matchedDetail;
      for (final detail in rows) {
        final signature = _incomeDuplicateSignature(
          customerName: '${invoice['nama_pelanggan'] ?? ''}',
          invoiceEntity: '${invoice['invoice_entity'] ?? ''}',
          detail: detail,
          parent: invoice,
          plateByArmadaId: plateByArmadaId,
        );
        if (targetSignatures.contains(signature)) {
          matchedDetail = detail;
          break;
        }
      }
      if (matchedDetail == null || !seenInvoiceIds.add(invoiceId)) continue;
      matches.add(
        _incomeDuplicateMatchFromInvoice(
          invoice,
          matchedDetail,
          fixedNumberByInvoiceId[invoiceId],
          plateByArmadaId,
        ),
      );
      if (matches.length >= 5) break;
    }
    return matches;
  }

  Future<bool> _confirmDuplicateIncomeSave(
    List<_IncomeDuplicateMatch> matches,
  ) async {
    final lines = matches.map((match) {
      final fixedLabel = (match.fixedInvoiceNumber ?? '').trim().isEmpty
          ? ''
          : ' • Fix: ${match.fixedInvoiceNumber}';
      return '• ${match.invoiceNumber} • ${match.dateLabel} • '
          '${match.customerName} • ${match.routeLabel} • '
          '${match.armadaLabel}$fixedLabel';
    }).join('\n');
    return showCvantConfirmPopup(
      context: context,
      type: CvantPopupType.warning,
      title: _t(
        'Data income sudah pernah dibuat',
        'Income data already exists',
      ),
      message: _t(
        'Data yang sama persis sudah ditemukan di invoice list/fix invoice:\n\n$lines\n\nKalau ini memang data baru yang sengaja dibuat ulang, pilih Tetap Simpan.',
        'The exact same data was found in invoice list/fixed invoice:\n\n$lines\n\nIf this is intentionally a new duplicate entry, choose Save Anyway.',
      ),
      cancelLabel: _t('Batal Simpan', 'Cancel Save'),
      confirmLabel: _t('Tetap Simpan', 'Save Anyway'),
    );
  }

  List<Map<String, dynamic>> _incomeDuplicateRowsForInvoice(
    Map<String, dynamic> invoice,
  ) {
    final rows = _fixedInvoiceMapList(invoice['rincian']);
    if (rows.isNotEmpty) return rows;
    return <Map<String, dynamic>>[invoice];
  }

  _IncomeDuplicateMatch _incomeDuplicateMatchFromInvoice(
    Map<String, dynamic> invoice,
    Map<String, dynamic> detail,
    String? fixedInvoiceNumber,
    Map<String, String> plateByArmadaId,
  ) {
    final invoiceNumber = Formatters.invoiceNumber(
      invoice['no_invoice'],
      invoice['tanggal'] ?? invoice['tanggal_kop'] ?? invoice['created_at'],
      customerName: invoice['nama_pelanggan'],
    );
    final pickup = _incomeDuplicateDisplayField(
      detail,
      invoice,
      const ['lokasi_muat'],
      fallback: '-',
    );
    final destination = _incomeDuplicateDisplayField(
      detail,
      invoice,
      const ['lokasi_bongkar'],
      fallback: '-',
    );
    final armada = _incomeDuplicateArmadaDisplay(
      detail,
      invoice,
      plateByArmadaId,
    );
    return _IncomeDuplicateMatch(
      invoiceNumber: invoiceNumber == '-' ? 'Invoice' : invoiceNumber,
      customerName: _incomeDuplicateDisplayField(
        invoice,
        null,
        const ['nama_pelanggan', 'customer_name'],
        fallback: '-',
      ),
      dateLabel: _incomeDuplicateDateDisplay(
        _incomeDuplicateRawField(
          detail,
          invoice,
          const ['armada_start_date', 'tanggal'],
        ),
      ),
      routeLabel: '$pickup-$destination',
      armadaLabel: armada,
      fixedInvoiceNumber: fixedInvoiceNumber,
    );
  }

  Map<String, String> _buildArmadaPlateById(
    List<Map<String, dynamic>> armadas,
  ) {
    final map = <String, String>{};
    for (final armada in armadas) {
      final id = '${armada['id'] ?? ''}'.trim();
      final plate = _normalizePlateText('${armada['plat_nomor'] ?? ''}');
      if (id.isNotEmpty && plate.isNotEmpty) {
        map[id] = plate;
      }
    }
    return map;
  }

  String _incomeDuplicateSignature({
    required String customerName,
    required String invoiceEntity,
    required Map<String, dynamic> detail,
    required Map<String, dynamic>? parent,
    required Map<String, String> plateByArmadaId,
  }) {
    final entity = Formatters.normalizeInvoiceEntity(
      invoiceEntity,
      invoiceNumber: parent?['no_invoice'],
      customerName: customerName,
    );
    final subtotal = _incomeDuplicateSubtotal(detail, parent);
    final parts = <String>[
      _incomeDuplicateTextKey(entity),
      _incomeDuplicateTextKey(customerName),
      _incomeDuplicateDateKey(
        _incomeDuplicateRawField(
          detail,
          parent,
          const ['armada_start_date', 'tanggal'],
        ),
      ),
      _incomeDuplicateDateKey(
        _incomeDuplicateRawField(detail, parent, const ['armada_end_date']),
      ),
      _incomeDuplicateTextKey(
        _incomeDuplicateRawField(detail, parent, const ['lokasi_muat']),
      ),
      _incomeDuplicateTextKey(
        _incomeDuplicateRawField(detail, parent, const ['lokasi_bongkar']),
      ),
      _incomeDuplicateTextKey(
        _incomeDuplicateRawField(detail, parent, const ['muatan']),
      ),
      _incomeDuplicateArmadaKey(detail, parent, plateByArmadaId),
      _incomeDuplicateTonaseKey(
        _incomeDuplicateRawField(detail, parent, const ['tonase']),
      ),
      _incomeDuplicateRateKey(
        _incomeDuplicateRawField(detail, parent, const ['harga']),
      ),
      subtotal > 0 ? roundInvoiceRupiah(subtotal).toStringAsFixed(0) : '',
    ];
    return parts.join('|');
  }

  dynamic _incomeDuplicateRawField(
    Map<String, dynamic> detail,
    Map<String, dynamic>? parent,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = detail[key];
      if (_incomeDuplicateHasValue(value)) return value;
    }
    if (parent != null) {
      for (final key in keys) {
        final value = parent[key];
        if (_incomeDuplicateHasValue(value)) return value;
      }
    }
    return '';
  }

  String _incomeDuplicateDisplayField(
    Map<String, dynamic> detail,
    Map<String, dynamic>? parent,
    List<String> keys, {
    String fallback = '',
  }) {
    final value = '${_incomeDuplicateRawField(detail, parent, keys)}'.trim();
    return value.isEmpty ? fallback : value;
  }

  bool _incomeDuplicateHasValue(dynamic value) {
    final raw = '${value ?? ''}'.trim();
    if (raw.isEmpty) return false;
    final lowered = raw.toLowerCase();
    return lowered != 'null' && lowered != 'undefined';
  }

  String _incomeDuplicateTextKey(dynamic value) {
    return '${value ?? ''}'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _incomeDuplicateDateKey(dynamic value) {
    final raw = '${value ?? ''}'.trim();
    if (raw.isEmpty) return '';
    final parsed = Formatters.parseDate(raw);
    if (parsed == null) return _incomeDuplicateTextKey(raw);
    final mm = parsed.month.toString().padLeft(2, '0');
    final dd = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$mm-$dd';
  }

  String _incomeDuplicateDateDisplay(dynamic value) {
    final parsed = Formatters.parseDate(value);
    if (parsed == null) {
      final raw = '${value ?? ''}'.trim();
      return raw.isEmpty ? '-' : raw;
    }
    final dd = parsed.day.toString().padLeft(2, '0');
    final mm = parsed.month.toString().padLeft(2, '0');
    return '$dd-$mm-${parsed.year}';
  }

  String _incomeDuplicateTonaseKey(dynamic value) {
    if (!_incomeDuplicateHasValue(value)) return '';
    return _toNum(value).toStringAsFixed(3);
  }

  String _incomeDuplicateRateKey(dynamic value) {
    if (!_incomeDuplicateHasValue(value)) return '';
    return _toNum(value).toStringAsFixed(2);
  }

  double _incomeDuplicateSubtotal(
    Map<String, dynamic> detail,
    Map<String, dynamic>? parent,
  ) {
    for (final key in const [
      'manual_subtotal',
      'subtotal_manual',
      'subtotal',
      'total',
      'jumlah',
      'total_biaya',
    ]) {
      final value = detail[key];
      if (_incomeDuplicateHasValue(value) && _toNum(value) > 0) {
        return roundInvoiceRupiah(_toNum(value));
      }
    }
    final tonase = _toNum(_incomeDuplicateRawField(
      detail,
      parent,
      const ['tonase'],
    ));
    final harga = _toNum(_incomeDuplicateRawField(
      detail,
      parent,
      const ['harga'],
    ));
    final computed = tonase * harga;
    if (computed > 0) return roundInvoiceRupiah(computed);
    if (parent != null) {
      for (final key in const ['total_biaya', 'total_bayar']) {
        final value = parent[key];
        if (_incomeDuplicateHasValue(value) && _toNum(value) > 0) {
          return roundInvoiceRupiah(_toNum(value));
        }
      }
    }
    return 0;
  }

  String _incomeDuplicateArmadaKey(
    Map<String, dynamic> detail,
    Map<String, dynamic>? parent,
    Map<String, String> plateByArmadaId,
  ) {
    final armadaId = '${_incomeDuplicateRawField(
      detail,
      parent,
      const ['armada_id'],
    )}'
        .trim();
    if (armadaId.isNotEmpty && plateByArmadaId[armadaId] != null) {
      return _normalizePlateText(plateByArmadaId[armadaId]!);
    }
    for (final key in const [
      'plat_nomor',
      'no_polisi',
      'nopol',
      'plat',
      'armada_manual',
      'armada_label',
      'armada',
    ]) {
      final raw = '${_incomeDuplicateRawField(detail, parent, [key])}'.trim();
      if (raw.isEmpty) continue;
      final plate = _extractPlateFromText(raw);
      if (plate != null && plate.isNotEmpty) return _normalizePlateText(plate);
      return _incomeDuplicateTextKey(raw);
    }
    if (armadaId.isNotEmpty) return armadaId;
    return '';
  }

  String _incomeDuplicateArmadaDisplay(
    Map<String, dynamic> detail,
    Map<String, dynamic>? parent,
    Map<String, String> plateByArmadaId,
  ) {
    final key = _incomeDuplicateArmadaKey(detail, parent, plateByArmadaId);
    if (key.isEmpty) return '-';
    return key == _incomeDuplicateTextKey(key) ? key : key.toUpperCase();
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

  String? _extractPlateFromText(String value) {
    return extractArmadaPlateFromText(value);
  }

  Map<String, String> _buildArmadaIdByPlate(
    List<Map<String, dynamic>> armadas,
  ) {
    return buildArmadaIdByPlate(armadas);
  }

  bool _usesEffectiveManualArmada(
    Map<String, dynamic> row, {
    List<Map<String, dynamic>>? armadas,
  }) {
    if (!_isManualArmadaRow(row)) return false;
    final sourceArmadas = armadas ?? _loadedArmadas;
    if (sourceArmadas.isEmpty) return true;
    return resolveListedArmadaIdFromRow(
      row,
      armadaIdByPlate: _buildArmadaIdByPlate(sourceArmadas),
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

  void _normalizeManualRowsToArmadaId(List<Map<String, dynamic>> armadas) {
    if (_details.isEmpty) return;
    var changed = false;
    for (final row in _details) {
      final beforeDriver = '${row['nama_supir'] ?? ''}'.trim();
      final beforeManual = '${row['nama_supir_manual'] ?? ''}'.trim();
      final beforeIsManual = row['nama_supir_is_manual'] == true;
      final beforeIsAuto = row['nama_supir_auto'] == true;
      final promoted = _promoteManualPlateToListedArmada(row, armadas: armadas);
      if (_usesEffectiveManualArmada(row, armadas: armadas)) {
        _clearDriverForManualArmadaIfNeeded(row);
      } else {
        _applyDefaultDriverForRow(row, armadas: armadas);
      }
      if (promoted ||
          beforeDriver != '${row['nama_supir'] ?? ''}'.trim() ||
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

  double get _pph =>
      _isCompanyInvoice ? calculateInvoicePph2Percent(_subtotal) : 0;
  double get _totalBayar => _isCompanyInvoice
      ? calculateInvoiceTotalAfterPph(_subtotal)
      : max(0, _subtotal);

  void _addDetail() {
    _refreshState(() => _details.add(_newDetail()));
  }

  void _removeDetail(int index) {
    if (_details.length == 1) return;
    _refreshState(() => _details.removeAt(index));
  }
}
