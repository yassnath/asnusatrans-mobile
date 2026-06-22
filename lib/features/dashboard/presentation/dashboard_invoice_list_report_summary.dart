part of 'dashboard_page.dart';

extension _AdminInvoiceListReportSummary on _AdminInvoiceListViewState {
  Future<void> _openReportSummaryImpl({
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
    final reportIncomeInvoices = dedupeReportInvoiceRowsById(
      fixedIncomeInvoices.where((item) {
        final id = '${item['id'] ?? ''}'.trim();
        if (id.isNotEmpty && _locallyRemovedRowIds.contains(id)) return false;
        if (_isPengurus) return _isOwnedByCurrentUser(item);
        if (_isAdminOrOwner) return _isPengurusIncomeApproved(item);
        return true;
      }),
    );
    final invoiceListIncomeInvoices = dedupeReportInvoiceRowsById(
      (await widget.repository.fetchInvoices()).where((item) {
        final id = '${item['id'] ?? ''}'.trim();
        if (id.isNotEmpty && _locallyRemovedRowIds.contains(id)) {
          return false;
        }
        if (_isPengurus) return _isOwnedByCurrentUser(item);
        if (_isAdminOrOwner) return _isPengurusIncomeApproved(item);
        return true;
      }),
    );
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
    final reportListedArmadaPlates = reportArmadaPlateById.values.toSet();
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

    bool reportRowUsesManualArmada(Map<String, dynamic> row) {
      return _isManualArmadaRow(row) &&
          !rowMatchesListedArmadaPlate(
            row,
            listedPlates: reportListedArmadaPlates,
          );
    }

    bool reportRowUsesGabunganArmada(
      Map<String, dynamic> row,
      Map<String, dynamic> invoice, {
      String? resolvedMuat,
      String? resolvedBongkar,
    }) {
      if (!reportRowUsesManualArmada(row)) return false;
      final muat =
          resolvedMuat ?? row['lokasi_muat'] ?? invoice['lokasi_muat'] ?? '';
      final bongkar = resolvedBongkar ??
          row['lokasi_bongkar'] ??
          invoice['lokasi_bongkar'] ??
          '';
      return !manualArmadaRouteUsesSanguExpense(
        pickup: '$muat',
        destination: '$bongkar',
      );
    }

    bool incomeUsesReportGabunganArmada(Map<String, dynamic> income) {
      final details = _toDetailList(income['rincian']);
      if (details.isNotEmpty) {
        return details.any(
          (row) =>
              reportRowUsesGabunganArmada(row, income) &&
              !isAntokTongkangMaspionLangonReportRow(row, income),
        );
      }
      return reportRowUsesGabunganArmada(income, income) &&
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
        if (reportRowUsesGabunganArmada(detail, invoice) ||
            reportRowUsesGabunganArmada(invoice, invoice)) {
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
        if (!isRegularIncomeHargaRule(rule)) continue;
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
        for (final entry
            in _AdminInvoiceListViewState._defaultDriverByPlate.entries) {
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
      final includedIncomeDetailIdentities = <String>{};

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
          if (!reserveReportIncomeDetailIdentity(
            seenIdentities: includedIncomeDetailIdentities,
            invoice: invoice,
            detailIndex: detailIndex,
          )) {
            continue;
          }

          final sanguAmount = resolveDetailSanguAmount(
            invoice: invoice,
            detail: detail,
            detailIndex: detailIndex,
            detailCount: detailRows.length,
          );
          final usesGabunganArmada = (reportRowUsesGabunganArmada(
                    detail,
                    invoice,
                    resolvedMuat: muat,
                    resolvedBongkar: bongkar,
                  ) ||
                  reportRowUsesGabunganArmada(
                    invoice,
                    invoice,
                    resolvedMuat: muat,
                    resolvedBongkar: bongkar,
                  )) &&
              !isAntokTongkangMaspionLangonReportRow(
                detail,
                invoice,
                resolvedMuat: muat,
                resolvedBongkar: bongkar,
              );
          final gabunganHarga = usesGabunganArmada
              ? resolveGabunganReportHargaPerTon(muat: muat, bongkar: bongkar)
              : 0.0;
          final gabunganTonase = _toNum(detail['tonase'] ?? invoice['tonase']);
          final gabunganAmount =
              usesGabunganArmada && gabunganHarga > 0 && gabunganTonase > 0
                  ? roundInvoiceRupiah(gabunganHarga * gabunganTonase)
                  : usesGabunganArmada
                      ? detailTotal
                      : 0.0;
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
}
