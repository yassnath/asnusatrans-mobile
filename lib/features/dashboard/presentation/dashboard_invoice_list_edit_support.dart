part of 'dashboard_page.dart';

extension _AdminInvoiceListViewStateEditSupport on _AdminInvoiceListViewState {
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
    String invoiceEntityMode = _resolveInvoiceEntity(
      invoiceEntity: item['invoice_entity'],
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
      final muatIsManual = muatText.isNotEmpty &&
          !_AdminInvoiceListViewState._defaultMuatOptions.contains(muatText);
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
        'lokasi_muat_is_manual': muatIsManual,
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
              final isCompanyInvoiceMode =
                  Formatters.isCompanyInvoiceEntity(invoiceEntityMode);
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
                                label: 'CV. ANT',
                                selected: invoiceEntityMode ==
                                    Formatters.invoiceEntityCvAnt,
                                onTap: () => setDialogState(
                                  () => invoiceEntityMode =
                                      Formatters.invoiceEntityCvAnt,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildEditInvoiceModeTab(
                                label: 'PT. ANT',
                                selected: invoiceEntityMode ==
                                    Formatters.invoiceEntityPtAnt,
                                onTap: () => setDialogState(
                                  () => invoiceEntityMode =
                                      Formatters.invoiceEntityPtAnt,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildEditInvoiceModeTab(
                                label: _t('Pribadi', 'Personal'),
                                selected: invoiceEntityMode ==
                                    Formatters.invoiceEntityPersonal,
                                onTap: () => setDialogState(
                                  () => invoiceEntityMode =
                                      Formatters.invoiceEntityPersonal,
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
                          final isMuatManual =
                              row['lokasi_muat_is_manual'] == true ||
                                  muatManual.isNotEmpty ||
                                  (muatValue.isNotEmpty &&
                                      !_AdminInvoiceListViewState
                                          ._defaultMuatOptions
                                          .contains(muatValue));
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
                                    ..._AdminInvoiceListViewState
                                        ._defaultMuatOptions
                                        .map(
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
                                        row['lokasi_muat_is_manual'] = true;
                                      } else {
                                        row['lokasi_muat'] = value ?? '';
                                        row['lokasi_muat_manual'] = '';
                                        row['lokasi_muat_is_manual'] = false;
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
                                      row['lokasi_muat_is_manual'] = true;
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
                                      return _AdminInvoiceListViewState
                                          ._manualArmadaOptionId;
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
                                      value: _AdminInvoiceListViewState
                                          ._manualArmadaOptionId,
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
                                      if (value ==
                                          _AdminInvoiceListViewState
                                              ._manualArmadaOptionId) {
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
                                            value !=
                                                _AdminInvoiceListViewState
                                                    ._manualArmadaOptionId,
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
                                      return _AdminInvoiceListViewState
                                          ._manualDriverOptionId;
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
                                    ..._AdminInvoiceListViewState
                                        ._defaultDriverOptions
                                        .map(
                                      (driver) => DropdownMenuItem<String>(
                                        value: driver,
                                        child: Text(driver),
                                      ),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: _AdminInvoiceListViewState
                                          ._manualDriverOptionId,
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
                                      if (value ==
                                          _AdminInvoiceListViewState
                                              ._manualDriverOptionId) {
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
                                            invoiceEntity: invoiceEntityMode,
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
}
