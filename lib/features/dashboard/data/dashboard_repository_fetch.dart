part of 'dashboard_repository.dart';

extension DashboardRepositoryFetchExtension on DashboardRepository {
  Future<List<Map<String, dynamic>>> fetchInvoices() async {
    try {
      const invoiceColumns =
          'id,no_invoice,invoice_entity,tanggal,tanggal_kop,lokasi_kop,nama_pelanggan,email,no_telp,due_date,'
          'lokasi_muat,lokasi_bongkar,armada_start_date,armada_end_date,'
          'tonase,harga,muatan,nama_supir,status,total_bayar,total_biaya,pph,diterima_oleh,'
          'customer_id,armada_id,order_id,rincian,created_at,updated_at,created_by,'
          'submission_role,approval_status,approval_requested_at,approval_requested_by,'
          'approved_at,approved_by,rejected_at,rejected_by,edit_request_status,'
          'edit_requested_at,edit_requested_by,edit_resolved_at,edit_resolved_by';
      final res = await _runInvoiceSelectWithFallback(
        invoiceColumns,
        (columns) => _supabase
            .from('invoices')
            .select(columns)
            .order('tanggal', ascending: false),
      );
      return _toMapList(res);
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat invoice: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchInvoicesByIds(
    Iterable<String> ids,
  ) async {
    final cleanedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (cleanedIds.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    try {
      const invoiceColumns =
          'id,no_invoice,invoice_entity,tanggal,tanggal_kop,lokasi_kop,nama_pelanggan,email,no_telp,due_date,'
          'lokasi_muat,lokasi_bongkar,armada_start_date,armada_end_date,'
          'tonase,harga,muatan,nama_supir,status,total_bayar,total_biaya,pph,diterima_oleh,'
          'customer_id,armada_id,order_id,rincian,created_at,updated_at,created_by,'
          'submission_role,approval_status,approval_requested_at,approval_requested_by,'
          'approved_at,approved_by,rejected_at,rejected_by,edit_request_status,'
          'edit_requested_at,edit_requested_by,edit_resolved_at,edit_resolved_by';
      const chunkSize = 150;
      final rows = <Map<String, dynamic>>[];
      for (var start = 0; start < cleanedIds.length; start += chunkSize) {
        final end = (start + chunkSize < cleanedIds.length)
            ? start + chunkSize
            : cleanedIds.length;
        final chunk = cleanedIds.sublist(start, end);
        final res = await _runInvoiceSelectWithFallback(
          invoiceColumns,
          (columns) => _supabase
              .from('invoices')
              .select(columns)
              .inFilter('id', chunk)
              .order('tanggal', ascending: false),
        );
        rows.addAll(_toMapList(res));
      }
      return rows;
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat invoice batch: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchInvoicesSince(DateTime since) async {
    try {
      const invoiceColumns =
          'id,no_invoice,invoice_entity,tanggal,tanggal_kop,lokasi_kop,nama_pelanggan,email,no_telp,due_date,'
          'lokasi_muat,lokasi_bongkar,armada_start_date,armada_end_date,'
          'tonase,harga,muatan,nama_supir,status,total_bayar,total_biaya,pph,diterima_oleh,'
          'customer_id,armada_id,order_id,rincian,created_at,updated_at,created_by,'
          'submission_role,approval_status,approval_requested_at,approval_requested_by,'
          'approved_at,approved_by,rejected_at,rejected_by,edit_request_status,'
          'edit_requested_at,edit_requested_by,edit_resolved_at,edit_resolved_by';
      final res = await fetchInvoicesSinceWithScope(
        since,
        columns: invoiceColumns,
      );
      return _toMapList(res);
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat invoice: ${e.message}');
    }
  }

  Future<dynamic> fetchInvoicesSinceWithScope(
    DateTime since, {
    required String columns,
    String? createdBy,
    int? limit,
  }) {
    final mm = since.month.toString().padLeft(2, '0');
    final dd = since.day.toString().padLeft(2, '0');
    final iso = '${since.year}-$mm-$dd';
    final cleanedCreatedBy = createdBy?.trim();
    return _runInvoiceSelectWithFallback(
      columns,
      (resolvedColumns) {
        dynamic query = _supabase.from('invoices').select(resolvedColumns).or(
              'tanggal.gte.$iso,tanggal_kop.gte.$iso,armada_start_date.gte.$iso',
            );
        if (cleanedCreatedBy != null && cleanedCreatedBy.isNotEmpty) {
          query = query.eq('created_by', cleanedCreatedBy);
        }
        query = query.order('tanggal', ascending: false);
        if (limit != null && limit > 0) {
          query = query.limit(limit);
        }
        return query;
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchExpenses() async {
    try {
      final res = await _runExpenseSelectWithFallback(
        'id,no_expense,tanggal,kategori,keterangan,total_pengeluaran,'
        'status,dicatat_oleh,note,rincian,created_at,updated_at,created_by',
        (columns) => _supabase
            .from('expenses')
            .select(columns)
            .order('tanggal', ascending: false),
      );
      return _toMapList(res)
          .map(_normalizeExpenseRow)
          .where((row) => _expenseTotal(row) > 0)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat expense: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchExpensesSince(DateTime since) async {
    try {
      final res = await fetchExpensesSinceWithScope(
        since,
        'id,no_expense,tanggal,kategori,keterangan,total_pengeluaran,'
        'status,dicatat_oleh,note,rincian,created_at,updated_at,created_by',
      );
      return _toMapList(res)
          .map(_normalizeExpenseRow)
          .where((row) => _expenseTotal(row) > 0)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat expense: ${e.message}');
    }
  }

  Future<dynamic> fetchExpensesSinceWithScope(
    DateTime since,
    String columns, {
    String? createdBy,
    int? limit,
  }) {
    final mm = since.month.toString().padLeft(2, '0');
    final dd = since.day.toString().padLeft(2, '0');
    final iso = '${since.year}-$mm-$dd';
    final cleanedCreatedBy = createdBy?.trim();
    return _runExpenseSelectWithFallback(
      columns,
      (resolvedColumns) {
        dynamic query = _supabase
            .from('expenses')
            .select(resolvedColumns)
            .gte('tanggal', iso);
        if (cleanedCreatedBy != null && cleanedCreatedBy.isNotEmpty) {
          query = query.eq('created_by', cleanedCreatedBy);
        }
        query = query.order('tanggal', ascending: false);
        if (limit != null && limit > 0) {
          query = query.limit(limit);
        }
        return query;
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchFixedInvoiceBatches() async {
    try {
      final res = await _supabase
          .from('fixed_invoice_batches')
          .select(
            'batch_id,invoice_ids,invoice_number,customer_name,kop_date,'
            'kop_location,status,paid_at,created_at,updated_at',
          )
          .order('created_at', ascending: false);
      return _toMapList(res).map(_normalizeFixedInvoiceBatchRow).toList();
    } on PostgrestException catch (e) {
      if (_isMissingFixedInvoiceBatchTableError(e)) {
        return const <Map<String, dynamic>>[];
      }
      throw Exception('Gagal memuat fix invoice: ${e.message}');
    }
  }

  Future<void> upsertFixedInvoiceBatch({
    required String batchId,
    required List<String> invoiceIds,
    required String invoiceNumber,
    required String customerName,
    String? kopDate,
    String? kopLocation,
    String? createdAt,
    String? status,
    String? paidAt,
  }) async {
    final cleanedBatchId = batchId.trim();
    final cleanedInvoiceIds = invoiceIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (cleanedBatchId.isEmpty || cleanedInvoiceIds.isEmpty) return;

    final normalizedInvoiceNumber = invoiceNumber.trim().isEmpty
        ? ''
        : (() {
            final normalized = Formatters.invoiceNumber(
              invoiceNumber.trim(),
              (kopDate ?? '').trim().isEmpty ? createdAt : kopDate,
              customerName: customerName,
            );
            return normalized == '-' ? invoiceNumber.trim() : normalized;
          })();

    final payload = <String, dynamic>{
      'batch_id': cleanedBatchId,
      'invoice_ids': cleanedInvoiceIds,
      'invoice_number': normalizedInvoiceNumber,
      'customer_name': customerName.trim(),
      'kop_date': (kopDate ?? '').trim().isEmpty ? null : kopDate!.trim(),
      'kop_location':
          (kopLocation ?? '').trim().isEmpty ? null : kopLocation!.trim(),
      'status': (status ?? '').trim().isEmpty ? 'Unpaid' : status!.trim(),
      'paid_at': (paidAt ?? '').trim().isEmpty ? null : paidAt!.trim(),
      'created_at': (createdAt ?? '').trim().isEmpty
          ? DateTime.now().toIso8601String()
          : createdAt!.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase
          .from('fixed_invoice_batches')
          .upsert(payload, onConflict: 'batch_id');
    } on PostgrestException catch (e) {
      if (_isMissingFixedInvoiceBatchTableError(e)) {
        return;
      }
      throw Exception('Gagal menyimpan fix invoice: ${e.message}');
    }
  }

  Future<void> deleteFixedInvoiceBatch(String batchId) async {
    final cleanedBatchId = batchId.trim();
    if (cleanedBatchId.isEmpty) return;
    try {
      await _supabase
          .from('fixed_invoice_batches')
          .delete()
          .eq('batch_id', cleanedBatchId);
    } on PostgrestException catch (e) {
      if (_isMissingFixedInvoiceBatchTableError(e)) {
        return;
      }
      throw Exception('Gagal menghapus fix invoice: ${e.message}');
    }
  }

  Future<({int updatedInvoices, int updatedFixedBatches})>
      normalizeLegacyInvoiceNumbers() async {
    var updatedInvoices = 0;
    var updatedFixedBatches = 0;

    if (_invoiceNumberColumnAvailable != false) {
      try {
        final invoiceRows = await _runInvoiceSelectWithFallback(
          'id,no_invoice,invoice_entity,nama_pelanggan,tanggal,tanggal_kop',
          (columns) => _supabase.from('invoices').select(columns),
        );
        if (_invoiceNumberColumnAvailable != false) {
          final rows = _toMapList(invoiceRows);
          final nowIso = DateTime.now().toIso8601String();
          for (final row in rows) {
            final id = '${row['id'] ?? ''}'.trim();
            final rawInvoiceNumber = '${row['no_invoice'] ?? ''}'.trim();
            if (id.isEmpty || rawInvoiceNumber.isEmpty) continue;
            final normalized = Formatters.invoiceNumber(
              rawInvoiceNumber,
              row['tanggal_kop'] ?? row['tanggal'],
              customerName: row['nama_pelanggan'],
            );
            if (normalized == '-' || normalized == rawInvoiceNumber) continue;
            await _updateInvoiceWithFallback(id, <String, dynamic>{
              'no_invoice': normalized,
              'updated_at': nowIso,
            });
            updatedInvoices++;
          }
        }
      } on PostgrestException catch (e) {
        if (!_isMissingInvoiceNumberColumnError(e)) {
          rethrow;
        }
      }
    }

    try {
      final res = await _supabase.from('fixed_invoice_batches').select(
            'batch_id,invoice_number,customer_name,kop_date,created_at',
          );
      final nowIso = DateTime.now().toIso8601String();
      for (final row in _toMapList(res)) {
        final batchId = '${row['batch_id'] ?? ''}'.trim();
        final rawInvoiceNumber = '${row['invoice_number'] ?? ''}'.trim();
        if (batchId.isEmpty || rawInvoiceNumber.isEmpty) continue;
        final normalized = Formatters.invoiceNumber(
          rawInvoiceNumber,
          row['kop_date'] ?? row['created_at'],
          customerName: row['customer_name'],
        );
        if (normalized == '-' || normalized == rawInvoiceNumber) continue;
        await _supabase.from('fixed_invoice_batches').update(<String, dynamic>{
          'invoice_number': normalized,
          'updated_at': nowIso,
        }).eq('batch_id', batchId);
        updatedFixedBatches++;
      }
    } on PostgrestException catch (e) {
      if (!_isMissingFixedInvoiceBatchTableError(e)) {
        rethrow;
      }
    }

    return (
      updatedInvoices: updatedInvoices,
      updatedFixedBatches: updatedFixedBatches,
    );
  }

  Future<List<Map<String, dynamic>>> fetchArmadas() async {
    final rpcSynced = await _syncArmadaStatusesRpcBestEffort();
    final rpcArmadas = await _fetchIncomeFormArmadasRpcBestEffort();
    if (rpcArmadas.isNotEmpty) {
      return rpcArmadas.map(_normalizeArmadaRow).toList();
    }

    const variants = <String>[
      'id,nama_truk,plat_nomor,kapasitas,status,is_active,created_at,updated_at',
      'id,nama_truk,plat_nomor,kapasitas,status,is_active,created_at',
      'id,nama_truk,plat_nomor,is_active,created_at,updated_at',
      'id,nama_truk,plat_nomor,is_active,created_at',
    ];

    PostgrestException? lastError;
    for (final columns in variants) {
      try {
        final res = await _supabase
            .from('armadas')
            .select(columns)
            .order('created_at', ascending: false);
        final armadas = _toMapList(res).map(_normalizeArmadaRow).toList();
        if (!rpcSynced) {
          await _syncArmadaStatusByEndDate(armadas);
        }
        return armadas;
      } on PostgrestException catch (e) {
        lastError = e;
        final message = e.message.toLowerCase();
        if (!message.contains('column') &&
            !message.contains('does not exist')) {
          throw Exception('Gagal memuat armada: ${e.message}');
        }
      }
    }

    throw Exception('Gagal memuat armada: ${lastError?.message ?? 'unknown'}');
  }

  Future<List<Map<String, dynamic>>>
      _fetchIncomeFormArmadasRpcBestEffort() async {
    try {
      final res = await _supabase.rpc('get_income_form_armadas');
      return _toMapList(res);
    } catch (_) {
      // Schema lama belum punya RPC referensi form income.
      return <Map<String, dynamic>>[];
    }
  }

  Future<bool> _syncArmadaStatusesRpcBestEffort() async {
    try {
      await _supabase.rpc('sync_armada_statuses');
      return true;
    } catch (_) {
      // Schema lama belum punya RPC ini. Fallback lama tetap dipakai untuk staff.
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchInvoiceArmadaUsage() async {
    try {
      final res = await _supabase
          .from('invoices')
          .select('id,armada_id,rincian,created_at')
          .order('created_at', ascending: false);
      return _toMapList(res);
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('column') || message.contains('does not exist')) {
        try {
          final fallback =
              await _supabase.from('invoices').select('id,armada_id,rincian');
          return _toMapList(fallback);
        } on PostgrestException catch (fallbackError) {
          throw Exception(
            'Gagal memuat pemakaian armada invoice: ${fallbackError.message}',
          );
        }
      }
      throw Exception('Gagal memuat pemakaian armada invoice: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchInvoiceCustomerOptions() async {
    try {
      final armadaRows =
          await _supabase.from('armadas').select('id,plat_nomor');
      final armadaIdByPlateKey = <String, String>{};
      String plateKey(String value) {
        return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').trim();
      }

      for (final armada in _toMapList(armadaRows)) {
        final id = '${armada['id'] ?? ''}'.trim();
        final key = plateKey('${armada['plat_nomor'] ?? ''}');
        if (id.isEmpty || key.isEmpty) continue;
        armadaIdByPlateKey[key] = id;
      }

      final res = await _supabase
          .from('invoices')
          .select(
            'id,customer_id,nama_pelanggan,email,no_telp,'
            'tanggal_kop,lokasi_kop,'
            'lokasi_muat,lokasi_bongkar,muatan,nama_supir,'
            'armada_id,armada_start_date,armada_end_date,tonase,harga,'
            'rincian,created_at,updated_at',
          )
          .order('updated_at', ascending: false);
      final rows = _toMapList(res);
      final latestByKey = <String, Map<String, dynamic>>{};

      String normalize(dynamic value) {
        return (value ?? '').toString().trim().replaceAll(RegExp(r'\s+'), ' ');
      }

      String? resolveArmadaIdFromText(dynamic value) {
        final text = normalize(value);
        if (text.isEmpty) return null;
        final direct = armadaIdByPlateKey[plateKey(text)];
        if (direct != null && direct.isNotEmpty) return direct;
        final matched = RegExp(
          r'[A-Z]{1,2}[\s-]*[0-9]{1,4}[\s-]*[A-Z]{1,3}',
        ).firstMatch(text.toUpperCase());
        if (matched == null) return null;
        final key = plateKey(matched.group(0) ?? '');
        return armadaIdByPlateKey[key];
      }

      String normalizeKey(dynamic value) {
        return normalize(value).toLowerCase();
      }

      DateTime rowStamp(Map<String, dynamic> row) {
        return Formatters.parseDate(row['updated_at'] ?? row['created_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
      }

      for (final row in rows) {
        final customerName = normalize(row['nama_pelanggan']);
        if (customerName.isEmpty) continue;

        final email = normalize(row['email']);
        final phone = normalize(row['no_telp']);
        final detailRows = _toMapList(row['rincian']);

        void addOption({
          required String muat,
          required String bongkar,
          String? muatan,
          Map<String, dynamic>? source,
        }) {
          final rawArmadaId = '${source?['armada_id'] ?? ''}'.trim();
          final rawManualArmada = normalize(
            source?['armada_manual'] ??
                source?['armada_label'] ??
                source?['armada'],
          );
          final resolvedArmadaId = rawArmadaId.isNotEmpty
              ? rawArmadaId
              : (resolveArmadaIdFromText(rawManualArmada) ?? '');
          final resolvedManualArmada =
              resolvedArmadaId.isEmpty ? rawManualArmada : '';
          final detailEntry = <String, dynamic>{
            'lokasi_muat': muat,
            'lokasi_bongkar': bongkar,
            'muatan': normalize(muatan),
            'nama_supir': normalize(source?['nama_supir']),
            'armada_id': resolvedArmadaId,
            'armada_manual': resolvedManualArmada,
            'armada_start_date': normalize(source?['armada_start_date']),
            'armada_end_date': normalize(source?['armada_end_date']),
            'tonase': source?['tonase'],
            'harga': source?['harga'],
          };
          final detailFingerprint = [
            normalize(detailEntry['lokasi_muat']),
            normalize(detailEntry['lokasi_bongkar']),
            normalize(detailEntry['muatan']),
            normalize(detailEntry['nama_supir']),
            normalize(detailEntry['armada_id']),
            normalize(detailEntry['armada_manual']),
            normalize(detailEntry['armada_start_date']),
            normalize(detailEntry['armada_end_date']),
            normalize(detailEntry['tonase']),
            normalize(detailEntry['harga']),
          ].join('|');
          final routeLabel = (muat.isEmpty && bongkar.isEmpty)
              ? '-'
              : '${muat.isEmpty ? '-' : muat}-${bongkar.isEmpty ? '-' : bongkar}';
          final key =
              '${normalizeKey(customerName)}|${normalizeKey(muat)}|${normalizeKey(bongkar)}';
          final candidate = <String, dynamic>{
            'id': key,
            'label': '$customerName: $routeLabel',
            'customer_id': '${row['customer_id'] ?? ''}'.trim(),
            'customer_name': customerName,
            'email': email,
            'phone': phone,
            'tanggal_kop':
                normalize(source?['tanggal_kop'] ?? row['tanggal_kop']),
            'lokasi_kop': normalize(source?['lokasi_kop'] ?? row['lokasi_kop']),
            'lokasi_muat': muat,
            'lokasi_bongkar': bongkar,
            'muatan': normalize(muatan),
            'nama_supir': normalize(source?['nama_supir']),
            'armada_id': resolvedArmadaId,
            'armada_manual': resolvedManualArmada,
            'armada_start_date': normalize(source?['armada_start_date']),
            'armada_end_date': normalize(source?['armada_end_date']),
            'tonase': source?['tonase'],
            'harga': source?['harga'],
            'details': <Map<String, dynamic>>[detailEntry],
            '__stamp': rowStamp(row),
            '__detail_fingerprints': <String>{detailFingerprint},
          };
          final existing = latestByKey[key];
          if (existing == null) {
            latestByKey[key] = candidate;
            return;
          }
          final existingStamp = existing['__stamp'] as DateTime;
          final candidateStamp = candidate['__stamp'] as DateTime;
          if (candidateStamp.isAfter(existingStamp)) {
            latestByKey[key] = candidate;
            return;
          }
          if (candidateStamp.isAtSameMomentAs(existingStamp)) {
            final fingerprints =
                (existing['__detail_fingerprints'] as Set<String>? ??
                        <String>{})
                    .toSet();
            if (fingerprints.add(detailFingerprint)) {
              final details = _toMapList(existing['details']);
              details.add(detailEntry);
              existing['details'] = details;
              existing['__detail_fingerprints'] = fingerprints;
            }
          }
        }

        if (detailRows.isNotEmpty) {
          for (final detail in detailRows) {
            addOption(
              muat: normalize(detail['lokasi_muat'] ?? row['lokasi_muat']),
              bongkar:
                  normalize(detail['lokasi_bongkar'] ?? row['lokasi_bongkar']),
              muatan: '${detail['muatan'] ?? row['muatan'] ?? ''}',
              source: detail,
            );
          }
          continue;
        }

        addOption(
          muat: normalize(row['lokasi_muat']),
          bongkar: normalize(row['lokasi_bongkar']),
          muatan: '${row['muatan'] ?? ''}',
          source: row,
        );
      }

      final options = latestByKey.values.toList()
        ..sort((a, b) {
          final aStamp = a['__stamp'] as DateTime;
          final bStamp = b['__stamp'] as DateTime;
          return bStamp.compareTo(aStamp);
        });

      return options.map((option) {
        final cleaned = Map<String, dynamic>.from(option);
        cleaned.remove('__stamp');
        cleaned.remove('__detail_fingerprints');
        return cleaned;
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat opsi customer invoice: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchHargaPerTonRules() async {
    final rpcRules = await _fetchHargaPerTonRulesRpcBestEffort();
    if (rpcRules.isNotEmpty) return rpcRules;

    try {
      final res = await _supabase
          .from('harga_per_ton_rules')
          .select(
            'id,customer_name,lokasi_muat,lokasi_bongkar,harga_per_ton,flat_total,is_active,priority,created_at,updated_at',
          )
          .eq('is_active', true)
          .order('priority', ascending: false)
          .order('created_at', ascending: false);
      return _toMapList(res);
    } on PostgrestException catch (e) {
      final lower = e.message.toLowerCase();
      final missingTable = lower.contains('harga_per_ton_rules') &&
          (lower.contains('does not exist') || lower.contains('column'));
      if (missingTable) {
        // Graceful fallback: feature auto-harga tetap optional jika schema belum dijalankan.
        return <Map<String, dynamic>>[];
      }
      throw Exception('Gagal memuat referensi harga / ton: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>>
      _fetchHargaPerTonRulesRpcBestEffort() async {
    try {
      final res = await _supabase.rpc('get_income_form_harga_per_ton_rules');
      return _toMapList(res);
    } catch (_) {
      // Schema lama belum punya RPC referensi harga / ton.
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchOrders({
    bool currentUserOnly = false,
  }) async {
    try {
      dynamic query = _supabase.from('customer_orders').select(
            'id,order_code,customer_id,pickup,destination,pickup_date,pickup_time,service,fleet,cargo,weight,distance,notes,insurance,estimate,insurance_fee,total,status,payment_method,paid_at,created_at,updated_at',
          );
      if (currentUserOnly) {
        final user = _supabase.auth.currentUser;
        if (user == null) {
          throw Exception('Session tidak ditemukan. Silakan login ulang.');
        }
        query = query.eq('customer_id', user.id);
      }
      final res = await query.order('created_at', ascending: false);
      return _toMapList(res);
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat order: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCustomerProfiles() async {
    try {
      final res = await _supabase
          .from('profiles')
          .select(
            'id,email,name,username,role,phone,address,city,company,created_at',
          )
          .eq('role', 'customer')
          .order('created_at', ascending: false);
      return _toMapList(res);
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat customer registrations: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCustomerNotifications({
    bool currentUserOnly = true,
    String? userId,
  }) async {
    final targetUserId = currentUserOnly
        ? _supabase.auth.currentUser?.id
        : (userId?.trim().isEmpty == true ? null : userId?.trim());
    if (currentUserOnly && targetUserId == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }

    try {
      dynamic query = _supabase.from('customer_notifications').select(
            'id,user_id,title,message,status,kind,source_type,source_id,payload,created_at',
          );
      if (targetUserId != null) {
        query = query.eq('user_id', targetUserId);
      }
      final res = await query.order('created_at', ascending: false);
      return _toMapList(res);
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      final tableMissing = message.contains('customer_notifications') &&
          (message.contains('does not exist') || message.contains('column'));
      if (tableMissing) return <Map<String, dynamic>>[];
      throw Exception('Gagal memuat notifikasi customer: ${e.message}');
    }
  }
}
