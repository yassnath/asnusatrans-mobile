part of 'dashboard_page.dart';

class _AdminCreateIncomeView extends StatefulWidget {
  const _AdminCreateIncomeView({
    required this.repository,
    required this.session,
    required this.onCreated,
    this.prefill,
    this.onPrefillConsumed,
  });

  final DashboardRepository repository;
  final AuthSession session;
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
  String _invoiceEntity = Formatters.invoiceEntityCvAnt;
  String _status = 'Unpaid';
  String _acceptedBy = 'Admin';
  bool _loading = false;
  late Future<List<dynamic>> _formFuture;
  final List<Map<String, dynamic>> _details = [];
  List<Map<String, dynamic>> _hargaPerTonRules = const [];
  bool _prefillApplied = false;
  bool _prefillArmadaResolved = false;
  bool get _isCompanyInvoice =>
      Formatters.isCompanyInvoiceEntity(_invoiceEntity);
  bool get _showSavedCustomerDropdown =>
      _invoiceEntity != Formatters.invoiceEntityPtAnt;

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
  void _refreshState(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _formFuture = _loadFormData();
    _details.add(_newDetail());
    _acceptedBy = widget.session.isOwner
        ? 'Owner'
        : (widget.session.isPengurus ? 'Pengurus' : 'Admin');
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
      final subtotalText = _safeNumberInputText(option['subtotal']);
      final driverText = _safeInputText(option['nama_supir']);
      final isDriverManual =
          driverText.isNotEmpty && !_isKnownDriverOption(driverText);
      final row = <String, dynamic>{
        'lokasi_muat': _safeInputText(option['lokasi_muat']),
        'lokasi_muat_manual': '',
        'lokasi_muat_is_manual':
            _safeInputText(option['lokasi_muat']).isNotEmpty &&
                !_defaultMuatOptions.contains(
                  _safeInputText(option['lokasi_muat']),
                ),
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
        'subtotal': subtotalText,
        'harga_auto': hargaText.isEmpty,
        'subtotal_auto': subtotalText.isNotEmpty && hargaText.isEmpty,
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
    final hasEmptyMuatan = _details.any(
      (row) => '${row['muatan'] ?? ''}'.trim().isEmpty,
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
        'subtotal': _toNum(row['subtotal']),
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
        invoiceEntity: _invoiceEntity,
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
        acceptedBy: widget.session.isPengurus ? 'Pengurus' : _acceptedBy,
        customerId: _linkedCustomerId,
        orderId: _linkedOrderId,
        details: detailsPayload,
        submissionRole: widget.session.normalizedRole,
        approvalStatus: widget.session.isPengurus ? 'pending' : 'approved',
        generateAutoSangu: !widget.session.isPengurus,
      );
      if (!mounted) return;
      _customer.clear();
      _email.clear();
      _phone.clear();
      _kopDate.text = _toInputDate(_date);
      _kopLocation.clear();
      _dueDate.clear();
      _status = 'Unpaid';
      _invoiceEntity = Formatters.invoiceEntityCvAnt;
      _acceptedBy = widget.session.isOwner
          ? 'Owner'
          : (widget.session.isPengurus ? 'Pengurus' : 'Admin');
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
          widget.session.isPengurus
              ? 'Income berhasil dikirim untuk ACC admin/owner.'
              : 'Invoice income berhasil ditambahkan.',
          widget.session.isPengurus
              ? 'Income has been submitted for admin/owner approval.'
              : 'Income invoice was added successfully.',
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
                          selected: _invoiceEntity ==
                              Formatters.invoiceEntityPersonal,
                          onTap: () => _switchInvoiceEntity(
                            Formatters.invoiceEntityPersonal,
                            customerOptions,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInvoiceModeDot(
                          label: 'CV. ANT',
                          selected:
                              _invoiceEntity == Formatters.invoiceEntityCvAnt,
                          onTap: () => _switchInvoiceEntity(
                            Formatters.invoiceEntityCvAnt,
                            customerOptions,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInvoiceModeDot(
                          label: 'PT. ANT',
                          selected:
                              _invoiceEntity == Formatters.invoiceEntityPtAnt,
                          onTap: () => _switchInvoiceEntity(
                            Formatters.invoiceEntityPtAnt,
                            customerOptions,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_showSavedCustomerDropdown) ...[
                    CvantDropdownField<String>(
                      initialValue: selectedCustomerValue,
                      decoration: InputDecoration(
                        labelText: _t(
                            'Data Customer Tersimpan', 'Saved Customer Data'),
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
                            _t(
                              'Other (Input Manual)',
                              'Other (Manual Input)',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => _applySavedCustomerOption(
                        value,
                        filteredCustomerOptions,
                        armadas: armadas,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.cardBorder(context),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _t(
                          'Untuk PT. ANT, nama customer diisi manual dulu.',
                          'For PT. ANT, customer name is entered manually for now.',
                        ),
                        style: TextStyle(
                          color: AppColors.textMutedFor(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _customer,
                    decoration: InputDecoration(
                      labelText: _t('Nama Customer', 'Customer Name'),
                      hintText: _t('Nama pelanggan', 'Customer name'),
                    ),
                    onChanged: (_) {
                      var hargaChanged = false;
                      for (final row in _details) {
                        hargaChanged =
                            _applyAutoHargaPerTon(row, force: true) ||
                                hargaChanged;
                      }
                      setState(() {
                        if (hargaChanged) {
                          _hargaFieldRefreshToken++;
                        }
                      });
                    },
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
                    final isMuatManual = row['lokasi_muat_is_manual'] == true ||
                        muatManual.isNotEmpty ||
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
                                  row['lokasi_muat_is_manual'] = true;
                                } else {
                                  row['lokasi_muat'] = value ?? '';
                                  row['lokasi_muat_manual'] = '';
                                  row['lokasi_muat_is_manual'] = false;
                                }
                                final hargaChanged = _applyAutoHargaPerTon(
                                  row,
                                  force: row['harga_auto'] == true ||
                                      row['subtotal_auto'] == true,
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
                                row['lokasi_muat_is_manual'] = true;
                                final hargaChanged = _applyAutoHargaPerTon(
                                  row,
                                  force: row['harga_auto'] == true ||
                                      row['subtotal_auto'] == true,
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
                              hintText: _t('Muatan', 'Cargo'),
                            ),
                            onChanged: (value) {
                              row['muatan'] = value;
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
                                    row['subtotal'] = '';
                                    row['harga_auto'] = false;
                                    row['subtotal_auto'] = false;
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
                  if (!widget.session.isPengurus) ...[
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
                  ],
                  const SizedBox(height: 8),
                  if (widget.session.isPengurus)
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: _t('Diterima Oleh', 'Accepted By'),
                      ),
                      child: const Text(
                        'Pengurus',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    )
                  else
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
