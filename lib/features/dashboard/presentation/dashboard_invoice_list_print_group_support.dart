part of 'dashboard_page.dart';

extension _AdminInvoiceListViewStatePrintGroupSupport
    on _AdminInvoiceListViewState {
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
      final entity = _resolveInvoiceEntity(
        invoiceEntity: item['invoice_entity'],
        invoiceNumber: item['no_invoice'],
        customerName: item['nama_pelanggan'],
      );
      final key = '$entity|$customerName';
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
    final resolvedInvoiceEntity = _resolveInvoiceEntity(
      invoiceEntity: baseItem['invoice_entity'],
      invoiceNumber: baseItem['no_invoice'],
      customerName: customerName,
    );
    final isCompanyInvoice = _resolveIsCompanyInvoice(
      invoiceEntity: baseItem['invoice_entity'],
      invoiceNumber: baseItem['no_invoice'],
      customerName: customerName,
    );
    double detailSubtotal(Map<String, dynamic> row) {
      return _resolveInvoiceDetailSubtotalShared(row);
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
    baseItem['invoice_entity'] = resolvedInvoiceEntity;
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

    String invoiceEntity(Map<String, dynamic> item) {
      return _resolveInvoiceEntity(
        invoiceEntity: item['invoice_entity'],
        invoiceNumber: item['no_invoice'],
        customerName: item['nama_pelanggan'],
      );
    }

    String bucketKey({
      required DateTime issuedDate,
      required String invoiceEntity,
    }) {
      final localDate = issuedDate.toLocal();
      final kind = Formatters.normalizeInvoiceEntity(invoiceEntity);
      return '$kind|${localDate.year % 100}|${localDate.month}';
    }

    void consumeExistingInvoiceNumber({
      required String invoiceNumber,
      required DateTime issuedDate,
      required String invoiceEntity,
      DateTime? referenceDate,
    }) {
      final localDate = issuedDate.toLocal();
      final normalizedEntity = Formatters.normalizeInvoiceEntity(invoiceEntity);
      final seq = _extractPrintInvoiceSequence(
        invoiceNumber: invoiceNumber,
        month: localDate.month,
        yearTwoDigits: localDate.year % 100,
        invoiceEntity: normalizedEntity,
        referenceDate: referenceDate ?? localDate,
      );
      if (seq <= 0) return;
      final key = bucketKey(
        issuedDate: localDate,
        invoiceEntity: normalizedEntity,
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
        invoiceEntity: invoiceEntity(income),
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
        invoiceEntity: _resolveInvoiceEntity(
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
        final aEntity = invoiceEntity(a.baseItem);
        final bEntity = invoiceEntity(b.baseItem);
        final byEntity = aEntity.compareTo(bEntity);
        if (byEntity != 0) return byEntity;
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
      final resolvedEntity = invoiceEntity(item);
      final normalizedExisting = Formatters.invoiceNumber(
        item['no_invoice'],
        item['tanggal_kop'] ?? item['tanggal'],
        customerName: item['nama_pelanggan'],
        isCompany: Formatters.isCompanyInvoiceEntity(resolvedEntity),
        invoiceEntity: resolvedEntity,
      );

      if (normalizedExisting != '-') {
        generatedById[group.id] = normalizedExisting;
        consumeExistingInvoiceNumber(
          invoiceNumber: normalizedExisting,
          issuedDate: existingIssuedDate,
          invoiceEntity: resolvedEntity,
          referenceDate: existingIssuedDate,
        );
        continue;
      }

      final key = bucketKey(
        issuedDate: generatedIssuedDate,
        invoiceEntity: resolvedEntity,
      );
      final nextSeq = (maxSeqByBucket[key] ?? 0) + 1;
      maxSeqByBucket[key] = nextSeq;
      generatedById[group.id] = _buildPrintInvoiceNumber(
        sequence: nextSeq,
        issuedDate: generatedIssuedDate,
        invoiceEntity: resolvedEntity,
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
    final modeLabel = _resolveInvoiceEntityLabel(
      invoiceEntity: item['invoice_entity'],
      invoiceNumber: item['no_invoice'],
      customerName: item['nama_pelanggan'],
    );
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
}
