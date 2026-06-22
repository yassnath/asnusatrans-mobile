part of 'dashboard_page.dart';

extension _AdminInvoiceListPrintSelector on _AdminInvoiceListViewState {
  Future<void> _openInvoicePrintSelectorImpl({
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
            columns: _AdminInvoiceListViewState._invoiceListColumns,
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
    final printHargaPerTonRules = await (() async {
      try {
        return await widget.repository.fetchHargaPerTonRules();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    })();
    for (var index = 0; index < allPrintableIncomes.length; index++) {
      allPrintableIncomes[index] = _applyRegularInvoicePricingForPrintItem(
        allPrintableIncomes[index],
        hargaPerTonRules: printHargaPerTonRules,
      );
    }

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
}
