part of 'dashboard_page.dart';

extension _AdminInvoiceListFixedInvoiceCache on _AdminInvoiceListViewState {
  Future<List<_FixedInvoiceBatch>> _loadRemoteFixedInvoiceBatchesImpl() async {
    final rows = await widget.repository.fetchFixedInvoiceBatches();
    final batches = <_FixedInvoiceBatch>[];
    for (final row in rows) {
      final batch = _FixedInvoiceBatch.fromJson(row);
      if (batch == null) continue;
      batches.add(batch);
      final rawInvoiceNumber = '${row['invoice_number'] ?? ''}'.trim();
      if (rawInvoiceNumber.isNotEmpty &&
          rawInvoiceNumber != batch.invoiceNumber) {
        await _upsertRemoteFixedInvoiceBatchImpl(batch);
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

  Future<void> _upsertRemoteFixedInvoiceBatchImpl(_FixedInvoiceBatch batch) {
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

  Future<void> _syncLocalFixedInvoiceCacheImpl(
    List<_FixedInvoiceBatch> batches,
  ) async {
    final ids = batches
        .expand((batch) => batch.invoiceIds)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    await _saveFixedInvoiceIdsImpl(ids);
    await _saveFixedInvoiceBatchesImpl(batches);
  }

  Future<List<_FixedInvoiceBatch>> _loadMergedFixedInvoiceBatchesImpl() async {
    final prefs = await SharedPreferences.getInstance();
    final remotePromotionDone = prefs.getBool(
          _AdminInvoiceListViewState._fixedInvoiceRemotePromotionDoneKey,
        ) ??
        false;
    final localIds = await _loadLocalFixedInvoiceIdsImpl();
    final localBatches = await _loadLocalFixedInvoiceBatchesImpl();
    final remoteBatches = await _loadRemoteFixedInvoiceBatchesImpl();
    final knownInvoiceIds = <String>{
      ...localBatches.expand((batch) => batch.invoiceIds),
      ...remoteBatches.expand((batch) => batch.invoiceIds),
    }.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    final legacyIds = localIds.difference(knownInvoiceIds);
    final legacyBatches = legacyIds.isEmpty
        ? const <_FixedInvoiceBatch>[]
        : _buildLegacyFixedInvoiceBatchesFromInvoices(
            invoices: await widget.repository.fetchInvoicesByIds(
              legacyIds
                  .map(invoiceFixedSourceId)
                  .where((id) => id.isNotEmpty)
                  .toSet(),
            ),
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
      await _syncLocalFixedInvoiceCacheImpl(merged);
      return merged;
    }
    final merged = _mergeFixedInvoiceBatchesWithLocalFallback(
      remoteBatches: remoteBatches,
      localBatches: promotedLocalBatches,
    );
    if (merged.isNotEmpty) {
      await Future.wait(merged.map(_upsertRemoteFixedInvoiceBatchImpl));
      await prefs.setBool(
        _AdminInvoiceListViewState._fixedInvoiceRemotePromotionDoneKey,
        true,
      );
    }
    final refreshedRemote = await _loadRemoteFixedInvoiceBatchesImpl();
    final finalBatches = _mergeFixedInvoiceBatchesWithLocalFallback(
      remoteBatches: refreshedRemote,
      localBatches: merged,
      includeLocalOnly: false,
    );
    await _syncLocalFixedInvoiceCacheImpl(finalBatches);
    return finalBatches;
  }

  Future<Set<String>> _loadFixedInvoiceIdsImpl() async {
    final batches = await _loadMergedFixedInvoiceBatchesImpl();
    return batches
        .expand((batch) => batch.invoiceIds)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<Set<String>> _loadLocalFixedInvoiceIdsImpl() async {
    final prefs = await SharedPreferences.getInstance();
    final ids =
        prefs.getStringList(_AdminInvoiceListViewState._fixedInvoicePrefsKey) ??
            const <String>[];
    return ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
  }

  Future<void> _saveFixedInvoiceIdsImpl(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final values = ids.toList()..sort();
    await prefs.setStringList(
      _AdminInvoiceListViewState._fixedInvoicePrefsKey,
      values,
    );
  }

  Future<List<_FixedInvoiceBatch>> _loadFixedInvoiceBatchesImpl() async {
    return _loadMergedFixedInvoiceBatchesImpl();
  }

  Future<List<_FixedInvoiceBatch>> _loadLocalFixedInvoiceBatchesImpl() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValues = prefs.getStringList(
          _AdminInvoiceListViewState._fixedInvoiceBatchPrefsKey,
        ) ??
        const <String>[];
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

  Future<void> _saveFixedInvoiceBatchesImpl(
      List<_FixedInvoiceBatch> batches) async {
    final prefs = await SharedPreferences.getInstance();
    final values = batches
        .map((batch) => jsonEncode(batch.toJson()))
        .toList(growable: false);
    await prefs.setStringList(
      _AdminInvoiceListViewState._fixedInvoiceBatchPrefsKey,
      values,
    );
  }

  String _buildFixedInvoiceBatchIdImpl(Iterable<String> invoiceIds) {
    final ids = invoiceIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort();
    final seed = ids.isEmpty ? 'batch' : ids.join('_');
    return 'fixed_$seed';
  }

  Future<_FixedInvoiceBatch?> _buildFixedInvoiceBatchFromInvoiceIdsImpl(
    Set<String> invoiceIds, {
    _FixedInvoiceBatch? preferredBatch,
  }) async {
    if (preferredBatch != null) return preferredBatch;
    if (invoiceIds.isEmpty) return null;
    final sourceInvoices = await widget.repository.fetchInvoicesByIds(
      invoiceIds.map(invoiceFixedSourceId).where((id) => id.isNotEmpty).toSet(),
    );
    final generatedBatches = _buildLegacyFixedInvoiceBatchesFromInvoices(
      invoices: sourceInvoices,
      fixedIds: invoiceIds,
    );
    if (generatedBatches.isNotEmpty) {
      final nowIso = DateTime.now().toIso8601String();
      return generatedBatches.first.copyWith(
        batchId: _buildFixedInvoiceBatchIdImpl(invoiceIds),
        createdAt: nowIso,
        updatedAt: nowIso,
      );
    }
    final nowIso = DateTime.now().toIso8601String();
    return _FixedInvoiceBatch(
      batchId: _buildFixedInvoiceBatchIdImpl(invoiceIds),
      invoiceIds: invoiceIds.toList(growable: false),
      invoiceNumber: '',
      customerName: '',
      createdAt: nowIso,
      updatedAt: nowIso,
    );
  }

  Future<void> _markInvoicesAsFixedImpl(
    Iterable<String> invoiceIds, {
    _FixedInvoiceBatch? batch,
  }) async {
    final cleaned =
        invoiceIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (cleaned.isEmpty) return;
    await _forgetReturnedFixedInvoiceIds(cleaned);
    final effectiveBatch = await _buildFixedInvoiceBatchFromInvoiceIdsImpl(
      cleaned,
      preferredBatch: batch,
    );
    final existing = await _loadFixedInvoiceIdsImpl();
    existing.addAll(cleaned);
    await _saveFixedInvoiceIdsImpl(existing);
    if (effectiveBatch == null) return;
    final batches = await _loadLocalFixedInvoiceBatchesImpl();
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
    await _saveFixedInvoiceBatchesImpl(batches);
    for (final batchId in overlappingBatchIds) {
      await widget.repository.deleteFixedInvoiceBatch(batchId);
    }
    await _upsertRemoteFixedInvoiceBatchImpl(effectiveBatch);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _AdminInvoiceListViewState._fixedInvoiceRemotePromotionDoneKey,
      true,
    );
    final remoteBatches = await _loadRemoteFixedInvoiceBatchesImpl();
    final merged = _mergeFixedInvoiceBatchesWithLocalFallback(
      remoteBatches: remoteBatches,
      localBatches: batches,
      includeLocalOnly: false,
    );
    await _syncLocalFixedInvoiceCacheImpl(merged);
  }
}
