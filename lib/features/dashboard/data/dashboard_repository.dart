import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';

enum InvoiceDeliveryTarget {
  customerNotification,
  email,
}

class InvoiceDeliveryResult {
  const InvoiceDeliveryResult({
    required this.target,
    this.email,
    this.customerId,
  });

  final InvoiceDeliveryTarget target;
  final String? email;
  final String? customerId;
}

class AutoSanguBackfillReport {
  const AutoSanguBackfillReport({
    required this.processedInvoices,
    required this.createdExpenses,
    required this.updatedExpenses,
    required this.deletedExpenses,
    required this.skippedInvoices,
    required this.failedInvoices,
  });

  final int processedInvoices;
  final int createdExpenses;
  final int updatedExpenses;
  final int deletedExpenses;
  final int skippedInvoices;
  final int failedInvoices;

  bool get hasFailures => failedInvoices > 0;
}

class _AutoSanguSyncResult {
  const _AutoSanguSyncResult({
    this.created = 0,
    this.updated = 0,
    this.deleted = 0,
    this.skipped = 0,
    this.failed = 0,
  });

  final int created;
  final int updated;
  final int deleted;
  final int skipped;
  final int failed;
}

class DashboardRepository {
  DashboardRepository(this._supabase);

  final SupabaseClient _supabase;
  bool? _invoiceNumberColumnAvailable;
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

  Future<DashboardBundle> loadAdminDashboard() async {
    try {
      const invoiceColumns =
          'id,no_invoice,tanggal,tanggal_kop,nama_pelanggan,status,total_bayar,total_biaya,pph,'
          'armada_id,armada_start_date,armada_end_date,muatan,created_at,rincian';
      final response = await Future.wait<dynamic>([
        _runInvoiceSelectWithFallback(
          invoiceColumns,
          (columns) => _supabase
              .from('invoices')
              .select(columns)
              .order('tanggal', ascending: false),
        ),
        _supabase
            .from('expenses')
            .select(
              'id,no_expense,tanggal,total_pengeluaran,status,kategori,keterangan,note,rincian,created_at',
            )
            .order('tanggal', ascending: false),
        _supabase
            .from('armadas')
            .select(
              'id,nama_truk,plat_nomor,kapasitas,status,is_active,created_at,updated_at',
            )
            .order('created_at', ascending: false),
      ]);

      final invoices = _toMapList(response[0]);
      final expenses = _toMapList(response[1])
          .map(_normalizeExpenseRow)
          .where((row) => _expenseTotal(row) > 0)
          .toList();
      final armadas = _toMapList(response[2]).map(_normalizeArmadaRow).toList();
      await _syncArmadaStatusByEndDate(armadas);

      final metrics = _buildMetrics(invoices, expenses);
      final monthlySeries = _buildMonthlySeries(invoices, expenses);
      final armadaUsage = _buildArmadaUsage(invoices, armadas);
      final latestCustomers = _buildLatestCustomers(invoices);
      final biggestTransactions = _buildBiggestTransactions(invoices, expenses);
      final recentTransactions = _buildRecentTransactions(invoices, expenses);
      final recentActivities =
          _buildRecentActivities(invoices, expenses, armadas);

      return DashboardBundle(
        metrics: metrics,
        monthlySeries: monthlySeries,
        armadaUsages: armadaUsage,
        latestCustomers: latestCustomers,
        biggestTransactions: biggestTransactions,
        recentActivities: recentActivities,
        recentTransactions: recentTransactions,
      );
    } on PostgrestException catch (e) {
      throw Exception(
        'Gagal memuat data dashboard dari Supabase: ${e.message}. Pastikan schema SQL sudah dijalankan.',
      );
    }
  }

  Future<DashboardLiveSections> loadAdminLiveSections() async {
    try {
      const invoiceColumns = 'id,no_invoice,tanggal,tanggal_kop,nama_pelanggan,'
          'armada_id,armada_start_date,armada_end_date,created_at,rincian';
      final response = await Future.wait<dynamic>([
        _runInvoiceSelectWithFallback(
          invoiceColumns,
          (columns) => _supabase
              .from('invoices')
              .select(columns)
              .order('tanggal', ascending: false),
        ),
        _supabase
            .from('expenses')
            .select(
              'id,no_expense,tanggal,total_pengeluaran,status,kategori,keterangan,note,rincian,created_at',
            )
            .order('tanggal', ascending: false),
        _supabase
            .from('armadas')
            .select(
              'id,nama_truk,plat_nomor,kapasitas,status,is_active,created_at,updated_at',
            )
            .order('created_at', ascending: false),
      ]);

      final invoices = _toMapList(response[0]);
      final expenses = _toMapList(response[1])
          .map(_normalizeExpenseRow)
          .where((row) => _expenseTotal(row) > 0)
          .toList();
      final armadas = _toMapList(response[2]).map(_normalizeArmadaRow).toList();
      await _syncArmadaStatusByEndDate(armadas);

      return DashboardLiveSections(
        armadaUsages: _buildArmadaUsage(invoices, armadas),
        recentActivities: _buildRecentActivities(invoices, expenses, armadas),
      );
    } on PostgrestException catch (e) {
      throw Exception(
        'Gagal memuat ringkasan armada/aktivitas terbaru: ${e.message}',
      );
    }
  }

  Future<CustomerDashboardBundle> loadCustomerDashboard() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }

    try {
      final response = await _supabase
          .from('customer_orders')
          .select(
            'id,order_code,pickup,destination,pickup_date,service,total,status,created_at,updated_at',
          )
          .eq('customer_id', user.id)
          .order('created_at', ascending: false);

      final orders = _toMapList(response);
      final totalOrders = orders.length;
      final pendingPayments = orders.where((order) {
        final status = (order['status'] ?? '').toString().toLowerCase();
        return status.contains('pending') || status.contains('accepted');
      }).length;
      final totalSpend = orders
          .where(
            (order) => (order['status'] ?? '')
                .toString()
                .toLowerCase()
                .contains('paid'),
          )
          .fold<double>(0, (sum, order) => sum + _num(order['total']));

      final latest = orders.take(5).map((order) {
        final schedule =
            Formatters.dmy(order['pickup_date'] ?? order['created_at']);
        final code =
            (order['order_code'] ?? 'ORD-${order['id'] ?? '-'}').toString();
        final pickup = (order['pickup'] ?? '-').toString();
        final destination = (order['destination'] ?? '-').toString();

        return CustomerOrderSummary(
          code: code,
          routeLabel: '$pickup - $destination',
          scheduleLabel: schedule,
          service: (order['service'] ?? '-').toString(),
          total: _num(order['total']),
          status: (order['status'] ?? 'Pending').toString(),
        );
      }).toList();

      return CustomerDashboardBundle(
        totalOrders: totalOrders,
        pendingPayments: pendingPayments,
        totalSpend: totalSpend,
        latestOrders: latest,
      );
    } on PostgrestException catch (e) {
      throw Exception(
        'Gagal memuat order customer dari Supabase: ${e.message}. Pastikan schema SQL sudah dijalankan.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchInvoices() async {
    try {
      const invoiceColumns =
          'id,no_invoice,tanggal,tanggal_kop,lokasi_kop,nama_pelanggan,email,no_telp,due_date,'
          'lokasi_muat,lokasi_bongkar,armada_start_date,armada_end_date,'
          'tonase,harga,muatan,nama_supir,status,total_bayar,total_biaya,pph,diterima_oleh,'
          'customer_id,armada_id,order_id,rincian,created_at,updated_at';
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

  Future<List<Map<String, dynamic>>> fetchInvoicesSince(DateTime since) async {
    final mm = since.month.toString().padLeft(2, '0');
    final dd = since.day.toString().padLeft(2, '0');
    final iso = '${since.year}-$mm-$dd';
    try {
      const invoiceColumns =
          'id,no_invoice,tanggal,tanggal_kop,lokasi_kop,nama_pelanggan,email,no_telp,due_date,'
          'lokasi_muat,lokasi_bongkar,armada_start_date,armada_end_date,'
          'tonase,harga,muatan,nama_supir,status,total_bayar,total_biaya,pph,diterima_oleh,'
          'customer_id,armada_id,order_id,rincian,created_at,updated_at';
      final res = await _runInvoiceSelectWithFallback(
        invoiceColumns,
        (columns) => _supabase
            .from('invoices')
            .select(columns)
            .or(
              'tanggal.gte.$iso,tanggal_kop.gte.$iso,armada_start_date.gte.$iso',
            )
            .order('tanggal', ascending: false),
      );
      return _toMapList(res);
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat invoice: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchExpenses() async {
    try {
      final res = await _supabase
          .from('expenses')
          .select(
            'id,no_expense,tanggal,kategori,keterangan,total_pengeluaran,'
            'status,dicatat_oleh,note,rincian,created_at,updated_at',
          )
          .order('tanggal', ascending: false);
      return _toMapList(res)
          .map(_normalizeExpenseRow)
          .where((row) => _expenseTotal(row) > 0)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat expense: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchExpensesSince(DateTime since) async {
    final mm = since.month.toString().padLeft(2, '0');
    final dd = since.day.toString().padLeft(2, '0');
    final iso = '${since.year}-$mm-$dd';
    try {
      final res = await _supabase
          .from('expenses')
          .select(
            'id,no_expense,tanggal,kategori,keterangan,total_pengeluaran,'
            'status,dicatat_oleh,note,rincian,created_at,updated_at',
          )
          .gte('tanggal', iso)
          .order('tanggal', ascending: false);
      return _toMapList(res)
          .map(_normalizeExpenseRow)
          .where((row) => _expenseTotal(row) > 0)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat expense: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchFixedInvoiceBatches() async {
    try {
      final res = await _supabase
          .from('fixed_invoice_batches')
          .select(
            'batch_id,invoice_ids,invoice_number,customer_name,kop_date,'
            'kop_location,created_at,updated_at',
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
          'id,no_invoice,nama_pelanggan,tanggal,tanggal_kop',
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
        await _supabase
            .from('fixed_invoice_batches')
            .update(<String, dynamic>{
              'invoice_number': normalized,
              'updated_at': nowIso,
            })
            .eq('batch_id', batchId);
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
        await _syncArmadaStatusByEndDate(armadas);
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
    try {
      final res = await _supabase
          .from('harga_per_ton_rules')
          .select(
            'id,lokasi_muat,lokasi_bongkar,harga_per_ton,is_active,priority,created_at,updated_at',
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

  Future<Map<String, dynamic>?> fetchMyProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    const variants = <String>[
      'id,email,name,username,avatar_url,role,phone,gender,birth_date,address,city,company,created_at,updated_at',
      'id,email,name,username,role,phone,gender,birth_date,address,city,company,created_at,updated_at',
    ];

    PostgrestException? lastError;
    for (final columns in variants) {
      try {
        final res = await _supabase
            .from('profiles')
            .select(columns)
            .eq('id', user.id)
            .maybeSingle();
        if (res == null) return null;
        return Map<String, dynamic>.from(res);
      } on PostgrestException catch (e) {
        lastError = e;
        final message = e.message.toLowerCase();
        if (!message.contains('column') &&
            !message.contains('does not exist')) {
          throw Exception('Gagal memuat profil: ${e.message}');
        }
      }
    }

    throw Exception('Gagal memuat profil: ${lastError?.message ?? 'unknown'}');
  }

  Future<void> createInvoice({
    required String customerName,
    required double total,
    String? noInvoice,
    bool includePph = true,
    String status = 'Unpaid',
    DateTime? issuedDate,
    String? email,
    String? noTelp,
    DateTime? kopDate,
    String? kopLocation,
    DateTime? dueDate,
    String? pickup,
    String? destination,
    String? armadaId,
    DateTime? armadaStartDate,
    DateTime? armadaEndDate,
    double? tonase,
    double? harga,
    String? muatan,
    String? namaSupir,
    String? acceptedBy,
    String? customerId,
    String? orderId,
    List<Map<String, dynamic>>? details,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }

    DateTime? resolveIssueDateFromDetails(List<Map<String, dynamic>> rows) {
      for (final row in rows) {
        final parsed = Formatters.parseDate(row['armada_start_date']);
        if (parsed != null) return parsed;
      }
      if (armadaStartDate != null) return armadaStartDate;
      return null;
    }

    final effectiveDetails = _buildEffectiveIncomeDetails(
      details: details,
      pickup: pickup,
      destination: destination,
      armadaId: armadaId,
      armadaStartDate: armadaStartDate,
      armadaEndDate: armadaEndDate,
      tonase: tonase,
      harga: harga,
      muatan: muatan,
      namaSupir: namaSupir,
    );
    final sanitizedDetails = _sanitizeIncomeDetails(effectiveDetails);
    final parsedIssueDate = resolveIssueDateFromDetails(sanitizedDetails) ??
        issuedDate ??
        DateTime.now();
    final requestedInvoiceNumber =
        (noInvoice?.trim().isEmpty ?? true) ? null : noInvoice!.trim();
    final selectedArmadaIds =
        _collectArmadaIds(primaryArmadaId: armadaId, details: sanitizedDetails);

    if (sanitizedDetails.length > 1) {
      final invalidDetailIndexes = <int>[];
      for (var i = 0; i < sanitizedDetails.length; i++) {
        if (_resolveIncomeDetailTotal(sanitizedDetails[i]) <= 0) {
          invalidDetailIndexes.add(i + 1);
        }
      }
      if (invalidDetailIndexes.isNotEmpty) {
        final detailLabels = invalidDetailIndexes.join(', ');
        throw Exception(
          'Setiap keberangkatan wajib memiliki tonase dan harga. Periksa rincian ke-$detailLabels.',
        );
      }

      for (var i = 0; i < sanitizedDetails.length; i++) {
        final detail = Map<String, dynamic>.from(sanitizedDetails[i]);
        final detailPickup = '${detail['lokasi_muat'] ?? pickup ?? ''}'.trim();
        final detailDestination =
            '${detail['lokasi_bongkar'] ?? destination ?? ''}'.trim();
        final detailArmadaId =
            '${detail['armada_id'] ?? armadaId ?? ''}'.trim().isEmpty
                ? null
                : '${detail['armada_id'] ?? armadaId}'.trim();
        final detailArmadaStartDate =
            Formatters.parseDate(detail['armada_start_date']) ??
                armadaStartDate;
        final detailArmadaEndDate =
            Formatters.parseDate(detail['armada_end_date']) ?? armadaEndDate;
        final detailMuatan =
            '${detail['muatan'] ?? muatan ?? ''}'.trim().isEmpty
                ? null
                : '${detail['muatan'] ?? muatan}'.trim();
        final detailDriver = _resolveDriverNames(
          explicitName: '${detail['nama_supir'] ?? namaSupir ?? ''}',
          details: [detail],
        );
        final detailTonase = _num(detail['tonase']);
        final detailHarga = _num(detail['harga']);
        final detailTotal = _resolveIncomeDetailTotal(detail);
        final detailIssueDate = detailArmadaStartDate ?? parsedIssueDate;

        final inserted = await _insertSingleIncomeInvoice(
          customerName: customerName,
          total: detailTotal,
          requestedNoInvoice: i == 0 ? requestedInvoiceNumber : null,
          includePph: includePph,
          status: status,
          issueDate: detailIssueDate,
          email: email,
          noTelp: noTelp,
          kopDate: kopDate,
          kopLocation: kopLocation,
          dueDate: dueDate,
          pickup: detailPickup,
          destination: detailDestination,
          armadaId: detailArmadaId,
          armadaStartDate: detailArmadaStartDate,
          armadaEndDate: detailArmadaEndDate,
          tonase: detailTonase,
          harga: detailHarga,
          muatan: detailMuatan,
          namaSupir: detailDriver,
          acceptedBy: acceptedBy,
          customerId: customerId,
          orderId: orderId,
          details: [detail],
          createdBy: user.id,
        );

        await _createSanguExpenseFromIncomeBestEffort(
          invoiceId: inserted['id'],
          invoiceNumber: inserted['no_invoice'] ?? '-',
          expenseDate: detailIssueDate,
          details: [detail],
          fallbackPickup: detailPickup,
          fallbackDestination: detailDestination,
          fallbackArmadaId: detailArmadaId,
        );
      }

      await _setArmadaStatusBestEffort(
        selectedArmadaIds,
        status: 'Full',
      );
      await _syncArmadaStatusNowBestEffort();
      return;
    }

    final singleDetailList =
        sanitizedDetails.isEmpty ? effectiveDetails : sanitizedDetails;
    final singleInserted = await _insertSingleIncomeInvoice(
      customerName: customerName,
      total: total,
      requestedNoInvoice: requestedInvoiceNumber,
      includePph: includePph,
      status: status,
      issueDate: parsedIssueDate,
      email: email,
      noTelp: noTelp,
      kopDate: kopDate,
      kopLocation: kopLocation,
      dueDate: dueDate,
      pickup: pickup,
      destination: destination,
      armadaId: armadaId,
      armadaStartDate: armadaStartDate,
      armadaEndDate: armadaEndDate,
      tonase: tonase,
      harga: harga,
      muatan: muatan,
      namaSupir: namaSupir,
      acceptedBy: acceptedBy,
      customerId: customerId,
      orderId: orderId,
      details: singleDetailList,
      createdBy: user.id,
    );

    await _createSanguExpenseFromIncomeBestEffort(
      invoiceId: singleInserted['id'],
      invoiceNumber: singleInserted['no_invoice'] ?? '-',
      expenseDate: parsedIssueDate,
      details: singleDetailList,
      fallbackPickup: pickup,
      fallbackDestination: destination,
      fallbackArmadaId: armadaId,
    );

    await _setArmadaStatusBestEffort(
      selectedArmadaIds,
      status: 'Full',
    );
    await _syncArmadaStatusNowBestEffort();
  }

  Future<Map<String, String?>> _insertSingleIncomeInvoice({
    required String customerName,
    required double total,
    required bool includePph,
    required String status,
    required DateTime issueDate,
    required String createdBy,
    String? requestedNoInvoice,
    String? email,
    String? noTelp,
    DateTime? kopDate,
    String? kopLocation,
    DateTime? dueDate,
    String? pickup,
    String? destination,
    String? armadaId,
    DateTime? armadaStartDate,
    DateTime? armadaEndDate,
    double? tonase,
    double? harga,
    String? muatan,
    String? namaSupir,
    String? acceptedBy,
    String? customerId,
    String? orderId,
    List<Map<String, dynamic>>? details,
  }) async {
    final normalizedIssueDate = issueDate.toLocal();
    final date = _dateOnly(normalizedIssueDate);
    final normalizedKopLocation =
        kopLocation?.trim().isEmpty == true ? null : kopLocation?.trim();
    final driverNames = _resolveDriverNames(
      explicitName: namaSupir,
      details: details,
    );
    final pphValue = includePph ? max(0, (total * 0.02).floorToDouble()) : 0.0;
    final totalBayarValue = max(0, total - pphValue);
    final isCompanyInvoice = _isCompanyCustomerName(customerName.trim()) ||
        _isCompanyInvoiceNumber(requestedNoInvoice ?? '');
    var currentCode = '';
    if ((requestedNoInvoice ?? '').trim().isNotEmpty) {
      final normalized = Formatters.invoiceNumber(
        requestedNoInvoice!.trim(),
        kopDate ?? issueDate,
        customerName: customerName,
        isCompany: isCompanyInvoice,
      );
      currentCode = normalized == '-' ? requestedNoInvoice.trim() : normalized;
    }

    final basePayload = <String, dynamic>{
      'tanggal': date,
      'tanggal_kop': kopDate == null ? null : _dateOnly(kopDate),
      'lokasi_kop': normalizedKopLocation,
      'nama_pelanggan': customerName.trim(),
      'email': email?.trim().isEmpty == true ? null : email?.trim(),
      'no_telp': noTelp?.trim().isEmpty == true ? null : noTelp?.trim(),
      'due_date': dueDate == null ? null : _dateOnly(dueDate),
      'lokasi_muat': pickup?.trim().isEmpty == true ? null : pickup?.trim(),
      'lokasi_bongkar':
          destination?.trim().isEmpty == true ? null : destination?.trim(),
      'armada_start_date':
          armadaStartDate == null ? null : _dateOnly(armadaStartDate),
      'armada_end_date':
          armadaEndDate == null ? null : _dateOnly(armadaEndDate),
      'tonase': tonase,
      'harga': harga,
      'muatan': muatan?.trim().isEmpty == true ? null : muatan?.trim(),
      'nama_supir': driverNames,
      'status': status,
      'total_biaya': total,
      'pph': pphValue,
      'total_bayar': totalBayarValue,
      'diterima_oleh':
          acceptedBy?.trim().isEmpty == true ? null : acceptedBy?.trim(),
      'created_by': createdBy,
    };

    if (customerId != null && customerId.trim().isNotEmpty) {
      basePayload['customer_id'] = customerId.trim();
    }
    if (orderId != null && orderId.trim().isNotEmpty) {
      basePayload['order_id'] = orderId.trim();
    }
    if (armadaId != null && armadaId.trim().isNotEmpty) {
      basePayload['armada_id'] = armadaId.trim();
    }
    if (details != null && details.isNotEmpty) {
      basePayload['rincian'] = details;
    }

    String insertedInvoiceId = '';
    final payload = <String, dynamic>{
      ...basePayload,
      if (currentCode.isNotEmpty) 'no_invoice': currentCode,
    };
    try {
      final insertedRow = await _insertInvoiceWithFallback(
        payload,
        selectColumns: 'id,no_invoice',
      );
      insertedInvoiceId = '${insertedRow?['id'] ?? ''}'.trim();
      currentCode = '${insertedRow?['no_invoice'] ?? currentCode}'.trim();
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final duplicateNoInvoice = currentCode.isNotEmpty &&
          (e.code == '23505' ||
              msg.contains('duplicate key') ||
              msg.contains('invoices_no_invoice_key') ||
              msg.contains('no_invoice_key'));
      if (!duplicateNoInvoice) {
        throw Exception('Gagal menambah invoice: ${e.message}');
      }
      throw Exception(
        'Gagal menambah invoice: nomor invoice bentrok, silakan coba lagi.',
      );
    }

    return <String, String?>{
      'id': insertedInvoiceId,
      'no_invoice': currentCode,
    };
  }

  Future<String> generateIncomeInvoiceNumber({
    required DateTime issuedDate,
    required bool isCompany,
  }) async {
    if (_invoiceNumberColumnAvailable == false) {
      return '';
    }
    try {
      final localIssuedDate = issuedDate.toLocal();
      final res = await _runInvoiceSelectWithFallback(
        'no_invoice,nama_pelanggan,tanggal_kop,tanggal',
        (columns) => _supabase.from('invoices').select(columns),
      );
      if (_invoiceNumberColumnAvailable == false) {
        return '';
      }

      final rows = _toMapList(res);
      var maxSeq = 0;
      final yearTwoDigits = localIssuedDate.year % 100;
      for (final row in rows) {
        final no = '${row['no_invoice'] ?? ''}';
        final customerName = '${row['nama_pelanggan'] ?? ''}'.trim();
        final isCompanyEntry = customerName.isNotEmpty
            ? _isCompanyCustomerName(customerName)
            : _isCompanyInvoiceNumber(no);
        if (isCompany != isCompanyEntry) continue;
        final seq = _extractInvoiceSequenceForMonth(
          noInvoice: no,
          month: localIssuedDate.month,
          yearTwoDigits: yearTwoDigits,
          isCompany: isCompany,
          referenceDate:
              Formatters.parseDate(row['tanggal_kop'] ?? row['tanggal']),
        );
        if (seq > maxSeq) maxSeq = seq;
      }

      final mm = localIssuedDate.month.toString().padLeft(2, '0');
      final seq = (maxSeq + 1).toString().padLeft(2, '0');
      final yy = yearTwoDigits.toString().padLeft(2, '0');
      if (isCompany) {
        return 'CV.ANT$yy$mm$seq';
      }
      return 'BS$yy$mm$seq';
    } on PostgrestException catch (e) {
      throw Exception('Gagal menyiapkan nomor invoice: ${e.message}');
    }
  }

  Future<void> createExpense({
    required double total,
    String status = 'Unpaid',
    DateTime? expenseDate,
    String? note,
    String? kategori,
    String? keterangan,
    String? recordedBy,
    List<Map<String, dynamic>>? details,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }

    final issuedDate = (expenseDate ?? DateTime.now()).toLocal();
    final date = _dateOnly(issuedDate);

    var inserted = false;
    String? lastError;
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = await generateExpenseNumberForDate(issuedDate);
      try {
        await _supabase.from('expenses').insert({
          'no_expense': code,
          'tanggal': date,
          'kategori':
              kategori?.trim().isEmpty == true ? null : kategori?.trim(),
          'keterangan':
              keterangan?.trim().isEmpty == true ? null : keterangan?.trim(),
          'total_pengeluaran': total,
          'status': status,
          'dicatat_oleh': recordedBy?.trim().isNotEmpty == true
              ? recordedBy!.trim()
              : user.userMetadata?['username'] ??
                  user.userMetadata?['name'] ??
                  user.email ??
                  'unknown',
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
          'rincian': details,
          'created_by': user.id,
        });
        inserted = true;
        break;
      } on PostgrestException catch (e) {
        final msg = e.message.toLowerCase();
        final duplicate = e.code == '23505' ||
            msg.contains('no_expense') ||
            msg.contains('expenses_no_expense_key');
        if (!duplicate || attempt >= 4) {
          throw Exception('Gagal menambah expense: ${e.message}');
        }
        lastError = e.message;
      }
    }

    if (!inserted) {
      throw Exception(
        'Gagal menambah expense: ${lastError ?? 'nomor expense tidak dapat dibuat.'}',
      );
    }
  }

  Future<void> createArmada({
    required String name,
    required String plate,
    double? capacity,
    String status = 'Ready',
    bool active = true,
  }) async {
    try {
      await _supabase.from('armadas').insert({
        'nama_truk': name.trim(),
        'plat_nomor': plate.trim().toUpperCase(),
        'kapasitas': capacity ?? 0,
        'status': status,
        'is_active': active,
      });
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('column') || message.contains('does not exist')) {
        try {
          await _supabase.from('armadas').insert({
            'nama_truk': name.trim(),
            'plat_nomor': plate.trim().toUpperCase(),
            'is_active': active,
          });
          return;
        } on PostgrestException catch (fallbackError) {
          throw Exception('Gagal menambah armada: ${fallbackError.message}');
        }
      }
      throw Exception('Gagal menambah armada: ${e.message}');
    }
  }

  Future<Map<String, dynamic>?> fetchInvoiceById(String id) async {
    try {
      const invoiceColumns =
          'id,no_invoice,tanggal,tanggal_kop,lokasi_kop,nama_pelanggan,email,no_telp,due_date,'
          'lokasi_muat,lokasi_bongkar,armada_start_date,armada_end_date,'
          'tonase,harga,muatan,nama_supir,status,total_biaya,pph,total_bayar,diterima_oleh,'
          'customer_id,armada_id,order_id,rincian,created_at,updated_at';
      final res = await _runInvoiceSelectWithFallback(
        invoiceColumns,
        (columns) => _supabase
            .from('invoices')
            .select(columns)
            .eq('id', id)
            .maybeSingle(),
      );
      if (res == null) return null;
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat detail invoice: ${e.message}');
    }
  }

  Future<void> updateInvoice({
    required String id,
    required String customerName,
    required String date,
    required String status,
    required double totalBiaya,
    required double pph,
    required double totalBayar,
    String? email,
    String? noTelp,
    String? kopDate,
    String? kopLocation,
    String? dueDate,
    String? acceptedBy,
    String? pickup,
    String? destination,
    String? armadaId,
    String? armadaStartDate,
    String? armadaEndDate,
    double? tonase,
    double? harga,
    String? muatan,
    String? namaSupir,
    String? noInvoice,
    List<Map<String, dynamic>>? details,
  }) async {
    final selectedArmadaIds =
        _collectArmadaIds(primaryArmadaId: armadaId, details: details);
    final effectiveDetails = _buildEffectiveIncomeDetails(
      details: details,
      pickup: pickup,
      destination: destination,
      armadaId: armadaId,
      armadaStartDate: Formatters.parseDate(armadaStartDate),
      armadaEndDate: Formatters.parseDate(armadaEndDate),
      tonase: tonase,
      harga: harga,
      muatan: muatan,
      namaSupir: namaSupir,
    );
    final driverNames = _resolveDriverNames(
      explicitName: namaSupir,
      details: details,
    );
    var effectiveInvoiceNumber = noInvoice?.trim() ?? '';
    try {
      final normalizedKopLocation =
          kopLocation?.trim().isEmpty == true ? null : kopLocation?.trim();
      DateTime? resolveIssueDateForUpdate() {
        for (final row in effectiveDetails) {
          final parsed = Formatters.parseDate(row['armada_start_date']);
          if (parsed != null) return parsed;
        }
        final primaryParsed = Formatters.parseDate(armadaStartDate);
        if (primaryParsed != null) return primaryParsed;
        return Formatters.parseDate(date);
      }

      final resolvedIssueDate = resolveIssueDateForUpdate() ?? DateTime.now();
      final payload = <String, dynamic>{
        'nama_pelanggan': customerName.trim(),
        'tanggal': _dateOnly(resolvedIssueDate),
        'status': status,
        'total_biaya': totalBiaya,
        'pph': pph,
        'total_bayar': totalBayar,
        'email': email?.trim().isEmpty == true ? null : email?.trim(),
        'no_telp': noTelp?.trim().isEmpty == true ? null : noTelp?.trim(),
        'tanggal_kop': kopDate?.trim().isEmpty == true ? null : kopDate?.trim(),
        'lokasi_kop': normalizedKopLocation,
        'due_date': dueDate?.trim().isEmpty == true ? null : dueDate?.trim(),
        'diterima_oleh':
            acceptedBy?.trim().isEmpty == true ? null : acceptedBy?.trim(),
        'lokasi_muat': pickup?.trim().isEmpty == true ? null : pickup?.trim(),
        'lokasi_bongkar':
            destination?.trim().isEmpty == true ? null : destination?.trim(),
        'armada_start_date': armadaStartDate?.trim().isEmpty == true
            ? null
            : armadaStartDate?.trim(),
        'armada_end_date': armadaEndDate?.trim().isEmpty == true
            ? null
            : armadaEndDate?.trim(),
        'tonase': tonase,
        'harga': harga,
        'muatan': muatan?.trim().isEmpty == true ? null : muatan?.trim(),
        'nama_supir': driverNames,
        'rincian': effectiveDetails.isEmpty ? null : effectiveDetails,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (noInvoice != null && noInvoice.trim().isNotEmpty) {
        final normalized = Formatters.invoiceNumber(
          noInvoice.trim(),
          (kopDate?.trim().isNotEmpty == true) ? kopDate : date,
          customerName: customerName,
          isCompany: _isCompanyCustomerName(customerName),
        );
        payload['no_invoice'] =
            normalized == '-' ? noInvoice.trim() : normalized;
        effectiveInvoiceNumber = '${payload['no_invoice'] ?? ''}'.trim();
      }

      if (armadaId != null && armadaId.trim().isNotEmpty) {
        payload['armada_id'] = armadaId.trim();
      } else {
        payload['armada_id'] = null;
      }

      await _updateInvoiceWithFallback(id, payload);
      if (selectedArmadaIds.isNotEmpty) {
        await _setArmadaStatusBestEffort(
          selectedArmadaIds,
          status: 'Full',
        );
      }
      final expenseReferenceDate = _resolveExpenseReferenceDateFromDetails(
        effectiveDetails,
        fallbackDate: resolvedIssueDate,
      );
      await _createSanguExpenseFromIncomeBestEffort(
        invoiceId: id,
        invoiceNumber: effectiveInvoiceNumber,
        expenseDate: expenseReferenceDate,
        details: effectiveDetails,
        fallbackPickup: pickup,
        fallbackDestination: destination,
        fallbackArmadaId: armadaId,
      );
      await _syncArmadaStatusNowBestEffort();
    } on PostgrestException catch (e) {
      throw Exception('Gagal update invoice: ${e.message}');
    }
  }

  Future<void> updateInvoicePrintMeta({
    required String id,
    String? noInvoice,
    String? kopDate,
    String? kopLocation,
  }) async {
    await updateInvoicesPrintMetaBulk(
      updates: [
        <String, String?>{
          'id': id,
          'no_invoice': noInvoice,
          'kop_date': kopDate,
          'kop_location': kopLocation,
        },
      ],
    );
  }

  Future<void> updateInvoicesPrintMetaBulk({
    required List<Map<String, String?>> updates,
  }) async {
    if (updates.isEmpty) return;
    try {
      final cleanUpdates = updates
          .map((item) => <String, String?>{
                'id': (item['id'] ?? '').trim(),
                'no_invoice': (item['no_invoice'] ?? '').trim(),
                'kop_date': (item['kop_date'] ?? '').trim(),
                'kop_location': (item['kop_location'] ?? '').trim(),
              })
          .where((item) => (item['id'] ?? '').isNotEmpty)
          .toList();
      if (cleanUpdates.isEmpty) return;

      final ids = cleanUpdates.map((item) => item['id']!).toSet().toList();
      final current = await _runInvoiceSelectWithFallback(
        'id,no_invoice,nama_pelanggan,tanggal,tanggal_kop,lokasi_kop',
        (columns) =>
            _supabase.from('invoices').select(columns).inFilter('id', ids),
      );
      final currentRows = _toMapList(current);
      if (currentRows.isEmpty) {
        throw Exception('Invoice tidak ditemukan.');
      }
      final currentById = <String, Map<String, dynamic>>{
        for (final row in currentRows) '${row['id'] ?? ''}': row,
      };

      final nowIso = DateTime.now().toIso8601String();
      final payloads = <Map<String, dynamic>>[];
      for (final item in cleanUpdates) {
        final id = item['id']!;
        final currentMap = currentById[id];
        if (currentMap == null) continue;

        final customerName = '${currentMap['nama_pelanggan'] ?? ''}'.trim();
        final rawNoInvoice = (item['no_invoice'] ?? '').isNotEmpty
            ? item['no_invoice']!
            : '${currentMap['no_invoice'] ?? ''}'.trim();
        final effectiveKopDate = (item['kop_date'] ?? '').isNotEmpty
            ? item['kop_date']!
            : '${currentMap['tanggal_kop'] ?? currentMap['tanggal'] ?? ''}'
                .trim();
        final effectiveKopLocation = (item['kop_location'] ?? '').isNotEmpty
            ? item['kop_location']!
            : '${currentMap['lokasi_kop'] ?? ''}'.trim();

        final parsedEffectiveDate = Formatters.parseDate(effectiveKopDate) ??
            Formatters.parseDate(
                currentMap['tanggal_kop'] ?? currentMap['tanggal']) ??
            DateTime.now();
        final normalizedNoInvoice = rawNoInvoice.isEmpty
            ? rawNoInvoice
            : (() {
                final normalized = Formatters.invoiceNumber(
                  rawNoInvoice,
                  parsedEffectiveDate,
                  customerName: customerName,
                  isCompany: _isCompanyCustomerName(customerName),
                );
                return normalized == '-' ? rawNoInvoice : normalized;
              })();

        final payload = <String, dynamic>{
          'id': id,
          'updated_at': nowIso,
          'tanggal_kop': effectiveKopDate.isEmpty ? null : effectiveKopDate,
          'lokasi_kop':
              effectiveKopLocation.isEmpty ? null : effectiveKopLocation,
        };
        if (normalizedNoInvoice.isNotEmpty &&
            _invoiceNumberColumnAvailable != false) {
          payload['no_invoice'] = normalizedNoInvoice;
        }
        payloads.add(payload);
      }

      if (payloads.isEmpty) return;

      for (final payload in payloads) {
        final id = '${payload['id'] ?? ''}'.trim();
        if (id.isEmpty) continue;
        final updatePayload = Map<String, dynamic>.from(payload)..remove('id');
        await _updateInvoiceWithFallback(id, updatePayload);
      }
    } on PostgrestException catch (e) {
      throw Exception('Gagal update KOP invoice: ${e.message}');
    }
  }

  Future<void> deleteInvoice(String id) async {
    try {
      await _supabase.from('invoices').delete().eq('id', id);
      await _syncArmadaStatusNowBestEffort();
    } on PostgrestException catch (e) {
      throw Exception('Gagal hapus invoice: ${e.message}');
    }
  }

  Future<Map<String, dynamic>?> fetchExpenseById(String id) async {
    try {
      final res = await _supabase
          .from('expenses')
          .select(
            'id,no_expense,tanggal,kategori,keterangan,total_pengeluaran,'
            'status,dicatat_oleh,note,rincian,created_at,updated_at',
          )
          .eq('id', id)
          .maybeSingle();
      if (res == null) return null;
      return _normalizeExpenseRow(Map<String, dynamic>.from(res));
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat detail expense: ${e.message}');
    }
  }

  Future<void> updateExpense({
    required String id,
    required String date,
    required String status,
    required double total,
    String? noExpense,
    String? kategori,
    String? keterangan,
    String? note,
    String? recordedBy,
    List<Map<String, dynamic>>? details,
  }) async {
    try {
      final payload = <String, dynamic>{
        'tanggal': date,
        'status': status,
        'total_pengeluaran': total,
        'kategori': kategori?.trim().isEmpty == true ? null : kategori?.trim(),
        'keterangan':
            keterangan?.trim().isEmpty == true ? null : keterangan?.trim(),
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
        'dicatat_oleh':
            recordedBy?.trim().isEmpty == true ? null : recordedBy?.trim(),
        'rincian': details,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (noExpense != null && noExpense.trim().isNotEmpty) {
        payload['no_expense'] = noExpense.trim();
      }
      await _supabase.from('expenses').update(payload).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Gagal update expense: ${e.message}');
    }
  }

  Future<String> generateExpenseNumberForDate(
    DateTime issuedDate, {
    String? excludeExpenseId,
  }) async {
    final localIssuedDate = issuedDate.toLocal();
    final month = localIssuedDate.month.toString().padLeft(2, '0');
    final year = localIssuedDate.year.toString();
    final yearInt = localIssuedDate.year;
    final monthInt = localIssuedDate.month;
    final startDate = DateTime(yearInt, monthInt, 1);
    final endDate = (monthInt == 12)
        ? DateTime(yearInt + 1, 1, 1).subtract(const Duration(days: 1))
        : DateTime(yearInt, monthInt + 1, 1).subtract(const Duration(days: 1));
    final startIso = _dateOnly(startDate);
    final endIso = _dateOnly(endDate);

    try {
      final rows = _toMapList(
        await _supabase
            .from('expenses')
            .select('id,no_expense,tanggal')
            .gte('tanggal', startIso)
            .lte('tanggal', endIso),
      );
      final excludedId = excludeExpenseId?.trim() ?? '';
      var maxSeq = 0;
      for (final row in rows) {
        final id = '${row['id'] ?? ''}'.trim();
        if (excludedId.isNotEmpty && id == excludedId) continue;
        final no = '${row['no_expense'] ?? ''}'.trim().toUpperCase();
        final match = RegExp(r'^EXP-(\d{2})-(\d{4})-(\d{1,4})$').firstMatch(no);
        if (match == null) continue;
        final rowMonth = int.tryParse(match.group(1) ?? '') ?? 0;
        final rowYear = int.tryParse(match.group(2) ?? '') ?? 0;
        if (rowMonth != monthInt || rowYear != yearInt) continue;
        final seq = int.tryParse(match.group(3) ?? '') ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }

      final next = maxSeq + 1;
      if (next > 9999) {
        throw Exception(
          'Nomor expense bulan ini sudah mencapai batas 9999. Ganti periode bulan/tahun.',
        );
      }
      final seq4 = next.toString().padLeft(4, '0');
      return 'EXP-$month-$year-$seq4';
    } on PostgrestException catch (e) {
      throw Exception('Gagal menyiapkan nomor expense: ${e.message}');
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _supabase.from('expenses').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Gagal hapus expense: ${e.message}');
    }
  }

  Future<void> updateArmada({
    required String id,
    required String name,
    required String plate,
    double? capacity,
    String? status,
    bool? active,
  }) async {
    try {
      await _supabase.from('armadas').update({
        'nama_truk': name.trim(),
        'plat_nomor': plate.trim().toUpperCase(),
        'kapasitas': capacity ?? 0,
        'status': status ?? (active == false ? 'Inactive' : 'Ready'),
        'is_active': active ?? true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('column') || message.contains('does not exist')) {
        try {
          await _supabase.from('armadas').update({
            'nama_truk': name.trim(),
            'plat_nomor': plate.trim().toUpperCase(),
            'is_active': active ?? true,
          }).eq('id', id);
          return;
        } on PostgrestException catch (fallbackError) {
          throw Exception('Gagal update armada: ${fallbackError.message}');
        }
      }
      throw Exception('Gagal update armada: ${e.message}');
    }
  }

  Future<void> deleteArmada(String id) async {
    try {
      await _supabase.from('armadas').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Gagal hapus armada: ${e.message}');
    }
  }

  Future<void> createCustomerOrder({
    required String pickup,
    required String destination,
    required DateTime pickupDate,
    required String service,
    required double total,
    String pickupTime = '00:00',
    String fleet = '-',
    String? cargo,
    double? weight,
    double? distance,
    String? notes,
    bool insurance = false,
    double estimate = 0,
    double insuranceFee = 0,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }

    final code = _makeDocumentCode('ORD');

    try {
      await _supabase.from('customer_orders').insert({
        'order_code': code,
        'customer_id': user.id,
        'pickup': pickup.trim(),
        'destination': destination.trim(),
        'pickup_date': _dateOnly(pickupDate),
        'pickup_time': pickupTime,
        'service': service.trim(),
        'fleet': fleet.trim(),
        'cargo': cargo?.trim().isEmpty == true ? null : cargo?.trim(),
        'weight': weight,
        'distance': distance,
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        'insurance': insurance,
        'estimate': estimate,
        'insurance_fee': insuranceFee,
        'total': total,
        'status': 'Pending Payment',
      });
    } on PostgrestException catch (e) {
      throw Exception('Gagal membuat order: ${e.message}');
    }
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      await _supabase.from('customer_orders').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);
    } on PostgrestException catch (e) {
      throw Exception('Gagal update status order: ${e.message}');
    }
  }

  Future<void> payOrder({
    required String orderId,
    required String method,
    String? invoiceId,
  }) async {
    try {
      await _supabase.from('customer_orders').update({
        'status': 'Paid',
        'payment_method': method,
        'paid_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      if (invoiceId != null && invoiceId.trim().isNotEmpty) {
        await _supabase.from('invoices').update({
          'status': 'Paid',
          'order_id': orderId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', invoiceId.trim());
      }
    } on PostgrestException catch (e) {
      throw Exception('Gagal memproses pembayaran: ${e.message}');
    }
  }

  Future<Map<String, dynamic>?> findInvoiceForOrder(String orderId) async {
    try {
      const invoiceColumns = 'id,no_invoice,status,total_biaya,pph,total_bayar,'
          'lokasi_muat,lokasi_bongkar,armada_id,tanggal,order_id,created_at';
      final res = await _runInvoiceSelectWithFallback(
        invoiceColumns,
        (columns) => _supabase
            .from('invoices')
            .select(columns)
            .eq('order_id', orderId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle(),
      );
      if (res == null) return null;
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat invoice order: ${e.message}');
    }
  }

  Future<InvoiceDeliveryResult> dispatchInvoiceDelivery({
    required String invoiceId,
    required String invoiceNumber,
    required String customerName,
    String? customerId,
    String? customerEmail,
  }) async {
    final normalizedEmail = (customerEmail ?? '').trim().toLowerCase();
    final targetCustomer = await _resolveRegisteredCustomer(
      customerId: customerId,
      customerEmail: normalizedEmail,
    );

    if (targetCustomer != null) {
      final targetId = '${targetCustomer['id'] ?? ''}'.trim();
      if (targetId.isNotEmpty) {
        try {
          await _insertCustomerNotification(
            userId: targetId,
            title: 'Invoice Baru',
            message:
                'Invoice $invoiceNumber untuk $customerName sudah dikirim. Silakan cek detail invoice Anda.',
            kind: 'invoice',
            sourceType: 'invoice',
            sourceId: invoiceId,
            payload: <String, dynamic>{
              'invoice_id': invoiceId,
              'invoice_number': invoiceNumber,
              'customer_name': customerName,
            },
          );
          return InvoiceDeliveryResult(
            target: InvoiceDeliveryTarget.customerNotification,
            customerId: targetId,
          );
        } catch (_) {
          // Fallback: jika tabel notifikasi belum siap, tetap kirim via email.
          if (normalizedEmail.isNotEmpty) {
            return InvoiceDeliveryResult(
              target: InvoiceDeliveryTarget.email,
              email: normalizedEmail,
              customerId: targetId,
            );
          }
          rethrow;
        }
      }
    }

    if (normalizedEmail.isEmpty) {
      throw Exception(
        'Email customer tidak tersedia. Lengkapi email invoice agar bisa dikirim.',
      );
    }

    return InvoiceDeliveryResult(
      target: InvoiceDeliveryTarget.email,
      email: normalizedEmail,
    );
  }

  Future<void> updateMyProfile({
    required String name,
    required String email,
    String? username,
    String? avatarUrl,
    String? phone,
    String? gender,
    String? birthDate,
    String? address,
    String? city,
    String? company,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }
    try {
      final requestedEmail = email.trim().toLowerCase();
      final currentAuthEmail = (user.email ?? '').trim().toLowerCase();
      var profileEmail =
          currentAuthEmail.isEmpty ? requestedEmail : currentAuthEmail;

      if (requestedEmail.isNotEmpty && requestedEmail != currentAuthEmail) {
        try {
          await _supabase.auth.updateUser(
            UserAttributes(email: requestedEmail),
          );
          profileEmail = requestedEmail;
        } on AuthException catch (e) {
          throw Exception('Gagal memperbarui email akun: ${e.message}');
        }
      }

      final payload = <String, dynamic>{
        'name': name.trim(),
        'email': profileEmail,
        'username': username?.trim().isEmpty == true
            ? null
            : username?.trim().toLowerCase(),
        'avatar_url':
            avatarUrl?.trim().isEmpty == true ? null : avatarUrl?.trim(),
        'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
        'gender': gender?.trim().isEmpty == true ? null : gender?.trim(),
        'birth_date':
            birthDate?.trim().isEmpty == true ? null : birthDate?.trim(),
        'address': address?.trim().isEmpty == true ? null : address?.trim(),
        'city': city?.trim().isEmpty == true ? null : city?.trim(),
        'company': company?.trim().isEmpty == true ? null : company?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await _supabase.from('profiles').update(payload).eq('id', user.id);
      } on PostgrestException catch (e) {
        final message = e.message.toLowerCase();
        if (message.contains('avatar_url') &&
            (message.contains('column') ||
                message.contains('does not exist'))) {
          final fallback = Map<String, dynamic>.from(payload)
            ..remove('avatar_url');
          await _supabase.from('profiles').update(fallback).eq('id', user.id);
        } else {
          rethrow;
        }
      }

      final metadata = <String, dynamic>{
        'name': name.trim(),
      };
      if (username != null && username.trim().isNotEmpty) {
        metadata['username'] = username.trim().toLowerCase();
      }
      if (avatarUrl != null) {
        metadata['avatar_url'] =
            avatarUrl.trim().isEmpty ? null : avatarUrl.trim();
      }
      try {
        await _supabase.auth.updateUser(UserAttributes(data: metadata));
      } catch (_) {
        // Metadata sync is best-effort only.
      }
    } on PostgrestException catch (e) {
      throw Exception('Gagal memperbarui profil: ${e.message}');
    }
  }

  Future<void> updateMyPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }
    try {
      // Re-auth untuk validasi password lama.
      await _supabase.auth.signInWithPassword(
        email: user.email!,
        password: currentPassword,
      );
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw Exception(e.message);
    } on PostgrestException catch (e) {
      throw Exception('Gagal memperbarui password: ${e.message}');
    }
  }

  Future<Map<String, dynamic>?> _resolveRegisteredCustomer({
    String? customerId,
    String? customerEmail,
  }) async {
    final normalizedId = (customerId ?? '').trim();
    if (normalizedId.isNotEmpty) {
      try {
        final res = await _supabase
            .from('profiles')
            .select('id,email,role')
            .eq('id', normalizedId)
            .eq('role', 'customer')
            .maybeSingle();
        if (res != null) return Map<String, dynamic>.from(res);
      } on PostgrestException catch (e) {
        throw Exception('Gagal validasi customer invoice: ${e.message}');
      }
    }

    final normalizedEmail = (customerEmail ?? '').trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return null;
    }

    try {
      final res = await _supabase
          .from('profiles')
          .select('id,email,role')
          .eq('email', normalizedEmail)
          .eq('role', 'customer')
          .maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      throw Exception('Gagal validasi customer invoice: ${e.message}');
    }
  }

  Future<void> _insertCustomerNotification({
    required String userId,
    required String title,
    required String message,
    String status = 'unread',
    String kind = 'info',
    String? sourceType,
    String? sourceId,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await _supabase.from('customer_notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'status': status,
        'kind': kind,
        'source_type': sourceType,
        'source_id': sourceId,
        'payload': payload ?? <String, dynamic>{},
      });
    } on PostgrestException catch (e) {
      final lower = e.message.toLowerCase();
      final missingTable = lower.contains('customer_notifications') &&
          (lower.contains('does not exist') || lower.contains('column'));
      if (missingTable) {
        throw Exception(
          'Tabel customer_notifications belum tersedia. Jalankan schema.sql terbaru dulu.',
        );
      }
      throw Exception('Gagal kirim notifikasi customer: ${e.message}');
    }
  }

  MetricSummary _buildMetrics(
    List<Map<String, dynamic>> invoices,
    List<Map<String, dynamic>> expenses,
  ) {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));

    final recentInvoices = invoices.where((invoice) {
      final date = _invoiceReferenceDate(invoice);
      return date != null &&
          date.isAfter(start.subtract(const Duration(days: 1))) &&
          date.isBefore(now.add(const Duration(days: 1)));
    }).toList();

    final recentExpenses = expenses.where((expense) {
      final date =
          Formatters.parseDate(expense['tanggal'] ?? expense['created_at']);
      return date != null &&
          date.isAfter(start.subtract(const Duration(days: 1))) &&
          date.isBefore(now.add(const Duration(days: 1)));
    }).toList();

    final totalCustomers = recentInvoices.length;
    final totalIncome = recentInvoices.fold<double>(
      0,
      (sum, invoice) => sum + _invoiceTotal(invoice),
    );
    final totalExpense = recentExpenses.fold<double>(
      0,
      (sum, expense) => sum + _expenseTotal(expense),
    );

    return MetricSummary(
      totalCustomers: totalCustomers,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
    );
  }

  MonthlySeries _buildMonthlySeries(
    List<Map<String, dynamic>> invoices,
    List<Map<String, dynamic>> expenses,
  ) {
    final year = DateTime.now().year;
    final income = List<double>.filled(12, 0);
    final expense = List<double>.filled(12, 0);

    for (final invoice in invoices) {
      final date = _invoiceReferenceDate(invoice);
      if (date == null || date.year != year) continue;
      income[date.month - 1] += _invoiceTotal(invoice);
    }

    for (final exp in expenses) {
      final date = Formatters.parseDate(exp['tanggal'] ?? exp['created_at']);
      if (date == null || date.year != year) continue;
      expense[date.month - 1] += _expenseTotal(exp);
    }

    return MonthlySeries(income: income, expense: expense);
  }

  List<ArmadaUsage> _buildArmadaUsage(
    List<Map<String, dynamic>> invoices,
    List<Map<String, dynamic>> armadas,
  ) {
    final counts = <String, int>{};
    var otherCount = 0;
    final armadaByPlate = <String, String>{};
    String normalizePlate(String value) {
      return value.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    for (final armada in armadas) {
      final id = '${armada['id'] ?? ''}'.trim();
      final plate = normalizePlate('${armada['plat_nomor'] ?? ''}');
      if (id.isEmpty || plate.isEmpty) continue;
      armadaByPlate[plate] = id;
    }

    String? resolveArmadaId(Map<String, dynamic> row) {
      final direct = '${row['armada_id'] ?? ''}'.trim();
      if (direct.isNotEmpty) return direct;
      final label = '${row['armada_label'] ?? row['armada'] ?? ''}'.trim();
      if (label.isEmpty) return null;
      final match = RegExp(
        r'[A-Z]{1,2}\s?[0-9]{1,4}\s?[A-Z]{1,3}',
      ).firstMatch(label.toUpperCase());
      if (match == null) return null;
      return armadaByPlate[normalizePlate(match.group(0) ?? '')];
    }

    for (final invoice in invoices) {
      final detailRows = _toMapList(invoice['rincian']);
      if (detailRows.isNotEmpty) {
        for (final row in detailRows) {
          final armadaId = resolveArmadaId(row) ?? '';
          if (armadaId.isNotEmpty) {
            counts[armadaId] = (counts[armadaId] ?? 0) + 1;
            continue;
          }
          final manualArmada = (row['armada_manual'] ?? '').toString().trim();
          if (manualArmada.isNotEmpty) {
            otherCount += 1;
          }
        }
        continue;
      }

      final armadaId = '${invoice['armada_id'] ?? ''}'.trim();
      if (armadaId.isNotEmpty) {
        counts[armadaId] = (counts[armadaId] ?? 0) + 1;
        continue;
      }

      final manualArmada = '${invoice['armada_manual'] ?? ''}'.trim();
      if (manualArmada.isNotEmpty) {
        otherCount += 1;
      }
    }

    final list = armadas.map((armada) {
      final id = '${armada['id'] ?? ''}'.trim();
      return ArmadaUsage(
        name: (armada['nama_truk'] ?? 'Armada').toString(),
        plate: (armada['plat_nomor'] ?? '-').toString(),
        count: counts[id] ?? 0,
      );
    }).toList();

    if (otherCount > 0) {
      list.add(
        ArmadaUsage(
          name: 'Other Armada',
          plate: 'Manual Input',
          count: otherCount,
        ),
      );
    }

    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  List<TransactionItem> _buildLatestCustomers(
      List<Map<String, dynamic>> invoices) {
    final list = invoices.map((invoice) {
      final id = (invoice['id'] ?? '').toString();
      return TransactionItem(
        id: id,
        type: 'Income',
        number: Formatters.invoiceNumber(
          invoice['no_invoice'],
          invoice['tanggal_kop'] ?? invoice['tanggal'],
          customerName: invoice['nama_pelanggan'],
        ),
        customer: (invoice['nama_pelanggan'] ?? '-').toString(),
        displayName: (invoice['nama_pelanggan'] ?? '-').toString(),
        routeLabel: _invoiceRouteLabel(invoice),
        dateLabel: Formatters.dmy(_invoiceReferenceDateValue(invoice)),
        total: _invoiceTotal(invoice),
        status: (invoice['status'] ?? 'Waiting').toString(),
        link: '/invoice-preview?id=$id',
      );
    }).toList();

    list.sort(
        (a, b) => _safeDate(b.dateLabel).compareTo(_safeDate(a.dateLabel)));
    return list.take(6).toList();
  }

  List<TransactionItem> _buildBiggestTransactions(
    List<Map<String, dynamic>> invoices,
    List<Map<String, dynamic>> expenses,
  ) {
    final combined = <TransactionItem>[
      ...invoices.map((invoice) {
        final id = (invoice['id'] ?? '').toString();
        return TransactionItem(
          id: id,
          type: 'Income',
          number: Formatters.invoiceNumber(
            invoice['no_invoice'],
            invoice['tanggal_kop'] ?? invoice['tanggal'],
            customerName: invoice['nama_pelanggan'],
          ),
          customer: (invoice['nama_pelanggan'] ?? '-').toString(),
          displayName: (invoice['nama_pelanggan'] ?? '-').toString(),
          routeLabel: _invoiceRouteLabel(invoice),
          dateLabel: Formatters.dmy(_invoiceReferenceDateValue(invoice)),
          total: _invoiceTotal(invoice),
          status: (invoice['status'] ?? 'Waiting').toString(),
          link: '/invoice-preview?id=$id',
        );
      }),
      ...expenses.map((expense) {
        final id = (expense['id'] ?? '').toString();
        return TransactionItem(
          id: id,
          type: 'Expense',
          number: Formatters.invoiceNumber(
              expense['no_expense'], expense['tanggal']),
          customer: '-',
          displayName: _expenseDisplayName(expense),
          routeLabel: _expenseRouteLabel(expense),
          dateLabel:
              Formatters.dmy(expense['tanggal'] ?? expense['created_at']),
          total: _expenseTotal(expense),
          status: (expense['status'] ?? 'Recorded').toString(),
          link: '/expense-preview?id=$id',
        );
      }),
    ];

    combined.sort((a, b) => b.total.compareTo(a.total));
    return combined.take(6).toList();
  }

  List<TransactionItem> _buildRecentTransactions(
    List<Map<String, dynamic>> invoices,
    List<Map<String, dynamic>> expenses,
  ) {
    DateTime resolveCreatedAt(dynamic value) {
      return Formatters.parseDate(value) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    bool isAutoSanguExpense(Map<String, dynamic> expense) {
      final note = '${expense['note'] ?? ''}'.trim().toUpperCase();
      if (note.startsWith('AUTO_SANGU:')) return true;
      final description = '${expense['keterangan'] ?? ''}'.trim().toLowerCase();
      return description.startsWith('auto sangu sopir -');
    }

    String expenseDashboardLabel(Map<String, dynamic> expense) {
      if (isAutoSanguExpense(expense)) {
        return _expenseRouteLabel(expense);
      }
      final category = '${expense['kategori'] ?? ''}'.trim();
      if (category.isNotEmpty) return category;
      final description = '${expense['keterangan'] ?? ''}'.trim();
      if (description.isNotEmpty) return description;
      return _expenseRouteLabel(expense);
    }

    void ensureEntry({
      required List<Map<String, dynamic>> selected,
      required bool Function(Map<String, dynamic> row) predicate,
      required Map<String, dynamic> candidate,
      int Function(List<Map<String, dynamic>> selected)? replaceIndexBuilder,
    }) {
      if (candidate.isEmpty || selected.any(predicate)) return;
      if (selected.length < 6) {
        selected.add(candidate);
        return;
      }
      final replaceIndex = replaceIndexBuilder?.call(selected) ?? -1;
      selected[replaceIndex >= 0 ? replaceIndex : selected.length - 1] =
          candidate;
    }

    void ensureMinimumCount({
      required List<Map<String, dynamic>> selected,
      required Iterable<Map<String, dynamic>> candidates,
      required bool Function(Map<String, dynamic> row) predicate,
      required int minimum,
      required int Function(List<Map<String, dynamic>> selected)
          replaceIndexBuilder,
    }) {
      if (minimum <= 0) return;
      final presentCount = selected.where(predicate).length;
      if (presentCount >= minimum) return;
      final needed = minimum - presentCount;
      final missingCandidates = candidates
          .where((candidate) => candidate.isNotEmpty)
          .where(
            (candidate) =>
                !selected.any((row) => row['item'] == candidate['item']),
          )
          .take(needed)
          .toList();
      for (final candidate in missingCandidates) {
        ensureEntry(
          selected: selected,
          predicate: (row) => row['item'] == candidate['item'],
          candidate: candidate,
          replaceIndexBuilder: replaceIndexBuilder,
        );
      }
    }

    final entries = <Map<String, dynamic>>[
      ...invoices.map((invoice) {
        final id = (invoice['id'] ?? '').toString();
        final dateValue = _invoiceReferenceDateValue(invoice);
        return {
          'type': 'income',
          'date': _invoiceReferenceDate(invoice),
          'timestamp': resolveCreatedAt(invoice['created_at'] ?? dateValue),
          'item': TransactionItem(
            id: id,
            type: 'Income',
            number: Formatters.invoiceNumber(
              invoice['no_invoice'],
              invoice['tanggal_kop'] ?? invoice['tanggal'],
              customerName: invoice['nama_pelanggan'],
            ),
            customer: (invoice['nama_pelanggan'] ?? '-').toString(),
            dateLabel: Formatters.dmy(dateValue),
            total: _invoiceTotal(invoice),
            status: (invoice['status'] ?? 'Waiting').toString(),
            link: '/invoice-preview?id=$id',
          ),
        };
      }),
      ...expenses.map((expense) {
        final id = (expense['id'] ?? '').toString();
        final dateValue = expense['tanggal'] ?? expense['created_at'];
        final autoSangu = isAutoSanguExpense(expense);
        return {
          'type': 'expense',
          'isAutoSangu': autoSangu,
          'date': Formatters.parseDate(dateValue),
          'timestamp': resolveCreatedAt(expense['created_at'] ?? dateValue),
          'item': TransactionItem(
            id: id,
            type: 'Expense',
            number: Formatters.invoiceNumber(
              expense['no_expense'],
              expense['tanggal'],
            ),
            customer: expenseDashboardLabel(expense),
            dateLabel: Formatters.dmy(dateValue),
            total: _expenseTotal(expense),
            status: (expense['status'] ?? 'Recorded').toString(),
            link: '/expense-preview?id=$id',
            isAutoSangu: autoSangu,
          ),
        };
      }),
    ];

    entries.sort((a, b) {
      final ad =
          (a['date'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd =
          (b['date'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byDate = bd.compareTo(ad);
      if (byDate != 0) return byDate;
      final at = (a['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bt = (b['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final byTimestamp = bt.compareTo(at);
      if (byTimestamp != 0) return byTimestamp;
      if (a['type'] == b['type']) return 0;
      if (a['type'] == 'expense') return -1;
      return 1;
    });

    final selected = entries.take(6).toList();
    final expenseEntries = entries
        .where((row) => row['type'] == 'expense')
        .toList(growable: false);
    final autoSanguEntries = entries
        .where((row) => row['type'] == 'expense' && row['isAutoSangu'] == true)
        .toList(growable: false);
    final incomeEntries =
        entries.where((row) => row['type'] == 'income').toList(growable: false);
    final latestExpense = expenseEntries.isEmpty
        ? const <String, dynamic>{}
        : expenseEntries.first;
    final latestAutoSanguExpense = autoSanguEntries.isEmpty
        ? const <String, dynamic>{}
        : autoSanguEntries.first;
    final latestIncome =
        incomeEntries.isEmpty ? const <String, dynamic>{} : incomeEntries.first;

    ensureEntry(
      selected: selected,
      predicate: (row) => row['type'] == 'expense',
      candidate: latestExpense,
      replaceIndexBuilder: (rows) => rows.lastIndexWhere(
        (row) => row['type'] != 'income',
      ),
    );
    ensureEntry(
      selected: selected,
      predicate: (row) => row['isAutoSangu'] == true,
      candidate: latestAutoSanguExpense,
      replaceIndexBuilder: (rows) {
        final regularExpenseIndex = rows.lastIndexWhere(
          (row) => row['type'] == 'expense' && row['isAutoSangu'] != true,
        );
        if (regularExpenseIndex >= 0) return regularExpenseIndex;
        return rows.lastIndexWhere((row) => row['type'] != 'income');
      },
    );
    ensureMinimumCount(
      selected: selected,
      candidates: expenseEntries,
      predicate: (row) => row['type'] == 'expense',
      minimum: min(2, expenseEntries.length),
      replaceIndexBuilder: (rows) => rows.lastIndexWhere(
        (row) => row['type'] == 'income' && row['isAutoSangu'] != true,
      ),
    );
    ensureEntry(
      selected: selected,
      predicate: (row) => row['type'] == 'income',
      candidate: latestIncome,
      replaceIndexBuilder: (rows) => rows.lastIndexWhere(
        (row) => row['type'] == 'expense' && row['isAutoSangu'] != true,
      ),
    );

    selected.sort((a, b) {
      final ad =
          (a['date'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd =
          (b['date'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byDate = bd.compareTo(ad);
      if (byDate != 0) return byDate;
      final at = (a['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bt = (b['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final byTimestamp = bt.compareTo(at);
      if (byTimestamp != 0) return byTimestamp;
      if (a['type'] == b['type']) return 0;
      if (a['type'] == 'expense') return -1;
      return 1;
    });
    return selected
        .map((row) => row['item'] as TransactionItem)
        .take(6)
        .toList();
  }

  String _expenseRouteLabel(Map<String, dynamic> expense) {
    final details = _toMapList(expense['rincian']);
    final routes = <String>[];
    final seen = <String>{};

    String normalizeKey(String value) {
      return value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    String buildRoute(String muat, String bongkar) {
      final left = muat.trim().isEmpty ? '-' : muat.trim();
      final right = bongkar.trim().isEmpty ? '-' : bongkar.trim();
      return '$left-$right';
    }

    for (final detail in details) {
      var muat = '${detail['lokasi_muat'] ?? ''}'.trim();
      var bongkar = '${detail['lokasi_bongkar'] ?? ''}'.trim();

      if (muat.isEmpty || bongkar.isEmpty) {
        final rawName = '${detail['nama'] ?? detail['name'] ?? ''}'.trim();
        final routeRaw = RegExp(r'\(([^()]*)\)').firstMatch(rawName)?.group(1);
        if (routeRaw != null && routeRaw.trim().isNotEmpty) {
          final parts = routeRaw.split('-');
          if (muat.isEmpty && parts.isNotEmpty) {
            muat = parts.first.trim();
          }
          if (bongkar.isEmpty && parts.length >= 2) {
            bongkar = parts.sublist(1).join('-').trim();
          }
        }
      }

      if (muat.isEmpty && bongkar.isEmpty) continue;
      final route = buildRoute(muat, bongkar);
      final key = normalizeKey(route);
      if (key.isEmpty) continue;
      if (seen.add(key)) routes.add(route);
    }

    if (routes.isNotEmpty) return routes.join(' | ');

    final fromDescription = '${expense['keterangan'] ?? ''}'.trim();
    if (fromDescription.contains('-')) return fromDescription;

    return '-';
  }

  String _invoiceRouteLabel(Map<String, dynamic> invoice) {
    final details = _toMapList(invoice['rincian']);
    final routes = <String>[];
    final seen = <String>{};

    String normalizeKey(String value) {
      return value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    String buildRoute(String muat, String bongkar) {
      final left = muat.trim().isEmpty ? '-' : muat.trim();
      final right = bongkar.trim().isEmpty ? '-' : bongkar.trim();
      return '$left-$right';
    }

    void pushRoute(String muat, String bongkar) {
      if (muat.trim().isEmpty && bongkar.trim().isEmpty) return;
      final route = buildRoute(muat, bongkar);
      final key = normalizeKey(route);
      if (key.isEmpty) return;
      if (seen.add(key)) routes.add(route);
    }

    if (details.isNotEmpty) {
      for (final detail in details) {
        pushRoute(
          '${detail['lokasi_muat'] ?? invoice['lokasi_muat'] ?? ''}',
          '${detail['lokasi_bongkar'] ?? invoice['lokasi_bongkar'] ?? ''}',
        );
      }
    } else {
      pushRoute(
        '${invoice['lokasi_muat'] ?? ''}',
        '${invoice['lokasi_bongkar'] ?? ''}',
      );
    }

    if (routes.isEmpty) return '-';
    return routes.join(' | ');
  }

  String _expenseDisplayName(Map<String, dynamic> expense) {
    final details = _toMapList(expense['rincian']);
    final names = <String>[];
    final seen = <String>{};

    void pushName(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty || normalized == '-') return;
      final key = normalized.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (seen.add(key)) names.add(normalized);
    }

    for (final detail in details) {
      final explicitDriver = _extractSingleDriverName(detail);
      if ((explicitDriver ?? '').trim().isNotEmpty) {
        pushName(explicitDriver!);
        continue;
      }
      final rawName = '${detail['nama'] ?? detail['name'] ?? ''}'.trim();
      final label = rawName.split('(').first.trim();
      if (label.isNotEmpty) {
        pushName(label);
      }
    }

    if (names.isNotEmpty) return names.join(' | ');

    final category = '${expense['kategori'] ?? ''}'.trim();
    if (category.isNotEmpty) return category;
    final description = '${expense['keterangan'] ?? ''}'.trim();
    if (description.isNotEmpty) return description;
    return '-';
  }

  List<ActivityItem> _buildRecentActivities(
    List<Map<String, dynamic>> invoices,
    List<Map<String, dynamic>> expenses,
    List<Map<String, dynamic>> armadas,
  ) {
    final items = <Map<String, dynamic>>[];
    final armadaById = <String, Map<String, dynamic>>{
      for (final armada in armadas)
        '${armada['id'] ?? ''}': Map<String, dynamic>.from(armada),
    };

    for (final invoice in invoices) {
      final id = (invoice['id'] ?? '').toString();
      final tanggal = _invoiceReferenceDateValue(invoice);
      final customerName = (invoice['nama_pelanggan'] ?? '-').toString();
      items.add({
        'id': 'inc-$id',
        'date': Formatters.parseDate(tanggal) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        'title': 'Pembuatan Income Invoice',
        'subtitle': customerName,
        'dateLabel': Formatters.dmy(tanggal),
        'kind': 'income',
      });
      final details = _toMapList(invoice['rincian']);
      if (details.isNotEmpty) {
        for (var i = 0; i < details.length; i++) {
          final row = details[i];
          final rowArmadaId = '${row['armada_id'] ?? ''}'.trim();
          final armada = rowArmadaId.isEmpty ? null : armadaById[rowArmadaId];
          final manual = '${row['armada_manual'] ?? ''}'.trim();
          final fallback =
              '${row['armada_label'] ?? row['armada'] ?? ''}'.trim();
          final armadaLabel = armada == null
              ? (manual.isNotEmpty
                  ? manual
                  : (fallback.isNotEmpty ? fallback : 'Armada'))
              : '${armada['nama_truk'] ?? 'Armada'} (${armada['plat_nomor'] ?? '-'})';

          final startDate = Formatters.parseDate(
            row['armada_start_date'] ?? invoice['armada_start_date'],
          );
          if (startDate != null) {
            items.add({
              'id': 'arm-start-$id-$i',
              'date': startDate,
              'title': 'Keberangkatan armada',
              'subtitle': armadaLabel,
              'dateLabel': Formatters.dmy(startDate),
              'kind': 'armada_start',
            });
          }

          final endDate = Formatters.parseDate(
            row['armada_end_date'] ?? invoice['armada_end_date'],
          );
          if (endDate != null) {
            items.add({
              'id': 'arm-done-$id-$i',
              'date': endDate,
              'title': 'Armada selesai jalan',
              'subtitle': armadaLabel,
              'dateLabel': Formatters.dmy(endDate),
              'kind': 'armada_done',
            });
          }
        }
      } else {
        final armadaId = (invoice['armada_id'] ?? '').toString().trim();
        final armada = armadaById[armadaId];
        final armadaLabel = armada == null
            ? 'Armada'
            : '${armada['nama_truk'] ?? 'Armada'} (${armada['plat_nomor'] ?? '-'})';

        final startDate =
            Formatters.parseDate(invoice['armada_start_date'] ?? '');
        if (startDate != null) {
          items.add({
            'id': 'arm-start-$id',
            'date': startDate,
            'title': 'Keberangkatan armada',
            'subtitle': armadaLabel,
            'dateLabel': Formatters.dmy(startDate),
            'kind': 'armada_start',
          });
        }

        final endDate = Formatters.parseDate(invoice['armada_end_date'] ?? '');
        if (endDate != null) {
          items.add({
            'id': 'arm-done-$id',
            'date': endDate,
            'title': 'Armada selesai jalan',
            'subtitle': armadaLabel,
            'dateLabel': Formatters.dmy(endDate),
            'kind': 'armada_done',
          });
        }
      }
    }

    for (final expense in expenses) {
      final id = (expense['id'] ?? '').toString();
      final tanggal = expense['tanggal'] ?? expense['created_at'];
      items.add({
        'id': 'exp-$id',
        'date': Formatters.parseDate(tanggal) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        'title': 'Pembuatan Expense',
        'subtitle': Formatters.rupiah(_expenseTotal(expense)),
        'dateLabel': Formatters.dmy(tanggal),
        'kind': 'expense',
      });
    }

    for (final armada in armadas) {
      final id = (armada['id'] ?? '').toString();
      items.add({
        'id': 'arm-$id',
        'date': Formatters.parseDate(armada['created_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        'title': 'Penambahan armada',
        'subtitle':
            '${(armada['nama_truk'] ?? 'Armada')} (${(armada['plat_nomor'] ?? '-')})',
        'dateLabel': Formatters.dmy(armada['created_at']),
        'kind': 'armada',
      });
    }

    items.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return items.take(10).map((item) {
      return ActivityItem(
        id: item['id'] as String,
        title: item['title'] as String,
        subtitle: item['subtitle'] as String,
        dateLabel: item['dateLabel'] as String,
        kind: item['kind'] as String,
      );
    }).toList();
  }

  List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  Map<String, dynamic> _normalizeFixedInvoiceBatchRow(
    Map<String, dynamic> row,
  ) {
    final invoiceIds = (row['invoice_ids'] as List<dynamic>? ?? const [])
        .map((id) => '$id'.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final rawInvoiceNumber = '${row['invoice_number'] ?? ''}'.trim();
    final normalizedInvoiceNumber = rawInvoiceNumber.isEmpty
        ? rawInvoiceNumber
        : (() {
            final normalized = Formatters.invoiceNumber(
              rawInvoiceNumber,
              row['kop_date'] ?? row['created_at'],
              customerName: row['customer_name'],
            );
            return normalized == '-' ? rawInvoiceNumber : normalized;
          })();
    return <String, dynamic>{
      'batch_id': '${row['batch_id'] ?? ''}'.trim(),
      'invoice_ids': invoiceIds,
      'invoice_number': normalizedInvoiceNumber,
      'customer_name': '${row['customer_name'] ?? ''}'.trim(),
      'kop_date': '${row['kop_date'] ?? ''}'.trim(),
      'kop_location': '${row['kop_location'] ?? ''}'.trim(),
      'created_at': '${row['created_at'] ?? ''}'.trim(),
      'updated_at': '${row['updated_at'] ?? ''}'.trim(),
    };
  }

  bool _selectColumnsInclude(String columns, String target) {
    final normalizedTarget = target.trim().toLowerCase();
    return columns
        .split(',')
        .map((column) => column.trim().toLowerCase())
        .any((column) => column == normalizedTarget);
  }

  String _removeSelectColumn(String columns, String target) {
    final normalizedTarget = target.trim().toLowerCase();
    return columns
        .split(',')
        .map((column) => column.trim())
        .where(
          (column) =>
              column.isNotEmpty && column.toLowerCase() != normalizedTarget,
        )
        .join(',');
  }

  bool _isMissingInvoiceNumberColumnError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('no_invoice') &&
        (message.contains('does not exist') ||
            message.contains('could not find') ||
            message.contains('schema cache'));
  }

  bool _isMissingFixedInvoiceBatchTableError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('fixed_invoice_batches') &&
        (message.contains('does not exist') ||
            message.contains('could not find') ||
            message.contains('schema cache') ||
            message.contains('relation'));
  }

  String _invoiceSelectColumnsForCurrentSchema(String columns) {
    return _invoiceNumberColumnAvailable == false
        ? _removeSelectColumn(columns, 'no_invoice')
        : columns;
  }

  Future<T> _runInvoiceSelectWithFallback<T>(
    String columns,
    Future<T> Function(String columns) request,
  ) async {
    final preferredColumns = _invoiceSelectColumnsForCurrentSchema(columns);
    try {
      final result = await request(preferredColumns);
      if (_selectColumnsInclude(preferredColumns, 'no_invoice')) {
        _invoiceNumberColumnAvailable = true;
      }
      return result;
    } on PostgrestException catch (error) {
      if (!_isMissingInvoiceNumberColumnError(error) ||
          !_selectColumnsInclude(columns, 'no_invoice')) {
        rethrow;
      }

      final fallbackColumns = _removeSelectColumn(columns, 'no_invoice');
      if (fallbackColumns == preferredColumns) rethrow;
      _invoiceNumberColumnAvailable = false;
      return await request(fallbackColumns);
    }
  }

  Future<Map<String, dynamic>?> _insertInvoiceWithFallback(
    Map<String, dynamic> payload, {
    String selectColumns = 'id,no_invoice',
  }) async {
    final preferredPayload = Map<String, dynamic>.from(payload);
    if (_invoiceNumberColumnAvailable == false) {
      preferredPayload.remove('no_invoice');
    }
    final preferredColumns = _invoiceSelectColumnsForCurrentSchema(
      selectColumns,
    );

    try {
      final result = await _supabase
          .from('invoices')
          .insert(preferredPayload)
          .select(preferredColumns)
          .maybeSingle();
      if (_selectColumnsInclude(preferredColumns, 'no_invoice')) {
        _invoiceNumberColumnAvailable = true;
      }
      return result == null ? null : Map<String, dynamic>.from(result);
    } on PostgrestException catch (error) {
      if (!_isMissingInvoiceNumberColumnError(error) ||
          !payload.containsKey('no_invoice')) {
        rethrow;
      }

      _invoiceNumberColumnAvailable = false;
      final fallbackPayload = Map<String, dynamic>.from(payload)
        ..remove('no_invoice');
      final fallbackColumns = _removeSelectColumn(selectColumns, 'no_invoice');
      final result = await _supabase
          .from('invoices')
          .insert(fallbackPayload)
          .select(fallbackColumns)
          .maybeSingle();
      return result == null ? null : Map<String, dynamic>.from(result);
    }
  }

  Future<void> _updateInvoiceWithFallback(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final preferredPayload = Map<String, dynamic>.from(payload);
    if (_invoiceNumberColumnAvailable == false) {
      preferredPayload.remove('no_invoice');
    }

    try {
      await _supabase.from('invoices').update(preferredPayload).eq('id', id);
      if (preferredPayload.containsKey('no_invoice')) {
        _invoiceNumberColumnAvailable = true;
      }
    } on PostgrestException catch (error) {
      if (!_isMissingInvoiceNumberColumnError(error) ||
          !payload.containsKey('no_invoice')) {
        rethrow;
      }

      _invoiceNumberColumnAvailable = false;
      final fallbackPayload = Map<String, dynamic>.from(payload)
        ..remove('no_invoice');
      await _supabase.from('invoices').update(fallbackPayload).eq('id', id);
    }
  }

  double _num(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _firstNonEmptyText(Iterable<dynamic> values) {
    for (final value in values) {
      final text = '${value ?? ''}'.trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return '';
  }

  double _expenseDetailAmount(Map<String, dynamic> detail) {
    final candidates = <dynamic>[
      detail['jumlah'],
      detail['amount'],
      detail['total'],
      detail['nominal'],
      detail['biaya'],
    ];
    for (final candidate in candidates) {
      final parsed = _num(candidate);
      if (parsed > 0) return parsed;
    }
    return 0;
  }

  double _expenseTotal(Map<String, dynamic> expense) {
    final direct = _num(expense['total_pengeluaran']);
    if (direct > 0) return direct;
    final details = _toMapList(expense['rincian']);
    if (details.isEmpty) return 0;
    var sum = 0.0;
    for (final detail in details) {
      sum += _expenseDetailAmount(detail);
    }
    return sum > 0 ? sum : 0;
  }

  Map<String, dynamic> _normalizeExpenseRow(Map<String, dynamic> expense) {
    final normalized = Map<String, dynamic>.from(expense);
    final total = _expenseTotal(normalized);
    if (total > 0) {
      normalized['total_pengeluaran'] = total;
    }
    return normalized;
  }

  double _invoiceTotal(Map<String, dynamic> invoice) {
    final totalBayar = _num(invoice['total_bayar']);
    if (totalBayar > 0) return totalBayar;
    final totalBiaya = _num(invoice['total_biaya']);
    final pph = _num(invoice['pph']);
    final fallback = totalBiaya - pph;
    return fallback > 0 ? fallback : 0;
  }

  dynamic _invoiceReferenceDateValue(Map<String, dynamic> invoice) {
    final detailRows = _toMapList(invoice['rincian']);
    for (final row in detailRows) {
      final raw = row['armada_start_date'];
      if (Formatters.parseDate(raw) != null) return raw;
    }
    if (Formatters.parseDate(invoice['armada_start_date']) != null) {
      return invoice['armada_start_date'];
    }
    return invoice['tanggal_kop'] ??
        invoice['tanggal'] ??
        invoice['created_at'];
  }

  DateTime? _invoiceReferenceDate(Map<String, dynamic> invoice) {
    return Formatters.parseDate(_invoiceReferenceDateValue(invoice));
  }

  dynamic _expenseReferenceDateValueFromDetails(
    List<Map<String, dynamic>> details, {
    dynamic fallbackDate,
  }) {
    for (final row in details) {
      final raw = row['armada_start_date'];
      if (Formatters.parseDate(raw) != null) return raw;
    }
    return fallbackDate;
  }

  DateTime _resolveExpenseReferenceDateFromDetails(
    List<Map<String, dynamic>> details, {
    dynamic fallbackDate,
  }) {
    return Formatters.parseDate(
          _expenseReferenceDateValueFromDetails(
            details,
            fallbackDate: fallbackDate,
          ),
        ) ??
        DateTime.now();
  }

  DateTime _safeDate(String dmy) {
    final parts = dmy.split('-');
    if (parts.length != 3) return DateTime.fromMillisecondsSinceEpoch(0);
    final day = int.tryParse(parts[0]) ?? 1;
    final month = int.tryParse(parts[1]) ?? 1;
    final year = int.tryParse(parts[2]) ?? 1970;
    return DateTime(year, month, day);
  }

  String _makeDocumentCode(
    String prefix, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final yy = now.year.toString();
    final tail =
        (now.microsecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return '$prefix-$mm-$yy-$tail';
  }

  bool _isCompanyInvoiceNumber(String number) {
    final raw = number.toUpperCase().trim();
    if (raw.isEmpty) return false;
    final compact = raw.replaceAll(RegExp(r'\s+'), '');
    if (compact.contains('CV.ANT') || compact.contains('/CV.ANT/')) {
      return true;
    }
    if (_isPersonalInvoiceNumber(raw)) {
      return false;
    }
    // Legacy pattern defaults to company to keep backward compatibility.
    return raw.startsWith('INC-');
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

  bool _isPersonalInvoiceNumber(String number) {
    final raw = number.toUpperCase().trim();
    if (raw.isEmpty) return false;
    final compact = raw.replaceAll(RegExp(r'\s+'), '');
    if ((compact.contains('/BS/') ||
            compact.contains('/ANT/') ||
            compact.startsWith('BS')) &&
        !compact.contains('CV.ANT')) {
      return true;
    }
    return compact.startsWith('NO:268/') || compact.startsWith('NO:BS/');
  }

  int _romanToMonth(String roman) {
    const map = <String, int>{
      'I': 1,
      'II': 2,
      'III': 3,
      'IV': 4,
      'V': 5,
      'VI': 6,
      'VII': 7,
      'VIII': 8,
      'IX': 9,
      'X': 10,
      'XI': 11,
      'XII': 12,
    };
    return map[roman.trim().toUpperCase()] ?? 0;
  }

  int _extractInvoiceSequenceForMonth({
    required String noInvoice,
    required int month,
    required int yearTwoDigits,
    required bool isCompany,
    DateTime? referenceDate,
  }) {
    final cleaned = noInvoice
        .replaceFirst(RegExp(r'^\s*NO\s*:\s*', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) return 0;

    final compactPattern = RegExp(
      r'^(CV\.ANT|BS)(\d{2})(\d{2})(\d{2,})$',
      caseSensitive: false,
    );
    final compactMatch = compactPattern.firstMatch(cleaned);
    if (compactMatch != null) {
      final prefix = (compactMatch.group(1) ?? '').toUpperCase().trim();
      final rowYear = int.tryParse(compactMatch.group(2) ?? '') ?? -1;
      final rowMonth = int.tryParse(compactMatch.group(3) ?? '') ?? 0;
      final seq = int.tryParse(compactMatch.group(4) ?? '') ?? 0;
      final sameType = isCompany ? prefix == 'CV.ANT' : prefix == 'BS';
      if (sameType && rowMonth == month && rowYear == yearTwoDigits) {
        return seq;
      }
      return 0;
    }

    // Legacy pattern:
    // 017 / BS / I / 26
    // 017 / CV.ANT / I / 26
    final newPattern = RegExp(
      r'^(\d{1,4})\s*\/\s*(CV\.ANT|BS|ANT)\s*\/\s*([IVX]+)\s*\/\s*(\d{2})\s*$',
      caseSensitive: false,
    );
    final newMatch = newPattern.firstMatch(cleaned);
    if (newMatch != null) {
      final seq = int.tryParse(newMatch.group(1) ?? '') ?? 0;
      final prefix = (newMatch.group(2) ?? '').toUpperCase().trim();
      final rowMonth = _romanToMonth(newMatch.group(3) ?? '');
      final rowYear = int.tryParse(newMatch.group(4) ?? '') ?? -1;
      final sameType =
          isCompany ? prefix == 'CV.ANT' : (prefix == 'BS' || prefix == 'ANT');
      if (sameType && rowMonth == month && rowYear == yearTwoDigits) {
        return seq;
      }
      return 0;
    }

    // Legacy converted pattern (without year):
    final legacyPattern = RegExp(
      r'^(480\s*\/\s*CV\.ANT|268\s*\/\s*ANT)\s*\/\s*([IVX]+)\s*\/\s*(\d+)\s*$',
      caseSensitive: false,
    );
    final legacyMatch = legacyPattern.firstMatch(cleaned);
    if (legacyMatch != null) {
      final prefix =
          (legacyMatch.group(1) ?? '').toUpperCase().replaceAll(' ', '');
      final sameType = isCompany
          ? prefix.startsWith('480/CV.ANT')
          : prefix.startsWith('268/ANT');
      if (!sameType) return 0;

      final rowMonth = _romanToMonth(legacyMatch.group(2) ?? '');
      if (rowMonth != month) return 0;
      final rowYear =
          referenceDate == null ? yearTwoDigits : (referenceDate.year % 100);
      if (rowYear != yearTwoDigits) return 0;

      return int.tryParse(legacyMatch.group(3) ?? '') ?? 0;
    }

    // Older INC-MM-YYYY-SEQ pattern.
    final oldInc =
        RegExp(r'^INC-(\d{2})-(\d{4})-(\d{1,})$', caseSensitive: false)
            .firstMatch(cleaned.toUpperCase());
    if (oldInc != null) {
      final rowMonth = int.tryParse(oldInc.group(1) ?? '') ?? 0;
      final rowYear = (int.tryParse(oldInc.group(2) ?? '') ?? 0) % 100;
      if (rowMonth != month || rowYear != yearTwoDigits) return 0;
      return int.tryParse(oldInc.group(3) ?? '') ?? 0;
    }

    return 0;
  }

  String _dateOnly(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool _isLikelyUuid(String value) {
    final normalized = value.trim().toLowerCase();
    final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    return pattern.hasMatch(normalized);
  }

  Future<void> _syncArmadaStatusByEndDate(
    List<Map<String, dynamic>> armadas,
  ) async {
    if (armadas.isEmpty) return;

    try {
      final rows = await _supabase
          .from('invoices')
          .select('armada_id,armada_end_date,status,rincian');

      final usageRows = _toMapList(rows);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final fullArmadaIds = <String>{};

      bool isBlockedStatus(String status) {
        final lower = status.toLowerCase();
        if (lower.contains('cancel') || lower.contains('reject')) {
          return false;
        }
        return lower.contains('full') ||
            lower.contains('on the way') ||
            lower.contains('waiting') ||
            lower.contains('unpaid') ||
            lower.contains('paid') ||
            lower.contains('progress');
      }

      void markArmadaUsage(String armadaId, DateTime? endDate, String status) {
        if (!_isLikelyUuid(armadaId)) return;

        if (endDate == null) {
          if (isBlockedStatus(status)) {
            fullArmadaIds.add(armadaId);
          }
          return;
        }

        final releaseDate = DateTime(endDate.year, endDate.month, endDate.day);
        if (today.isBefore(releaseDate)) {
          fullArmadaIds.add(armadaId);
        }
      }

      for (final row in usageRows) {
        final status = '${row['status'] ?? ''}'.trim();
        final detailRows = _toMapList(row['rincian']);

        if (detailRows.isNotEmpty) {
          for (final detail in detailRows) {
            final detailArmadaId = '${detail['armada_id'] ?? ''}'.trim();
            final detailEndDate = Formatters.parseDate(
                detail['armada_end_date'] ?? row['armada_end_date']);
            markArmadaUsage(detailArmadaId, detailEndDate, status);
          }
          continue;
        }

        final armadaId = '${row['armada_id'] ?? ''}'.trim();
        final endDate = Formatters.parseDate(row['armada_end_date']);
        markArmadaUsage(armadaId, endDate, status);
      }

      final updates = <MapEntry<String, String>>[];
      for (final armada in armadas) {
        final id = '${armada['id'] ?? ''}'.trim();
        if (!_isLikelyUuid(id)) continue;

        final isInactive = (armada['is_active'] == false) ||
            '${armada['status'] ?? ''}'.trim().toLowerCase() == 'inactive';
        if (isInactive) continue;

        final nextStatus = fullArmadaIds.contains(id) ? 'Full' : 'Ready';
        final currentStatus = '${armada['status'] ?? 'Ready'}'.trim();
        if (currentStatus.toLowerCase() == nextStatus.toLowerCase()) continue;

        armada['status'] = nextStatus;
        updates.add(MapEntry(id, nextStatus));
      }

      for (final entry in updates) {
        try {
          await _supabase.from('armadas').update({
            'status': entry.value,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', entry.key);
        } catch (_) {
          // Best effort: fetch tetap jalan walau update status gagal.
        }
      }
    } catch (_) {
      // Best effort: fetch armada tetap jalan walau sinkron status gagal.
    }
  }

  Map<String, dynamic> _normalizeArmadaRow(Map<String, dynamic> row) {
    final result = Map<String, dynamic>.from(row);
    result['nama_truk'] = '${row['nama_truk'] ?? '-'}';
    result['plat_nomor'] = '${row['plat_nomor'] ?? '-'}';
    result['kapasitas'] = _num(row['kapasitas']);

    final isActive = row['is_active'] != false;
    final rawStatus = '${row['status'] ?? ''}'.trim();
    final normalizedStatus =
        rawStatus.isEmpty ? (isActive ? 'Ready' : 'Inactive') : rawStatus;

    result['status'] = normalizedStatus;
    result['is_active'] = isActive;
    return result;
  }

  Set<String> _collectArmadaIds({
    String? primaryArmadaId,
    List<Map<String, dynamic>>? details,
  }) {
    final ids = <String>{};
    final primary = primaryArmadaId?.trim() ?? '';
    if (primary.isNotEmpty && _isLikelyUuid(primary)) {
      ids.add(primary);
    }
    for (final detail in details ?? const <Map<String, dynamic>>[]) {
      final value = detail['armada_id'];
      final id = value == null ? '' : value.toString().trim();
      if (id.isNotEmpty && _isLikelyUuid(id)) {
        ids.add(id);
      }
    }
    return ids;
  }

  String? _resolveDriverNames({
    String? explicitName,
    List<Map<String, dynamic>>? details,
  }) {
    final direct = explicitName?.trim();
    if (direct != null && direct.isNotEmpty) {
      final lowered = direct.toLowerCase();
      if (lowered != 'null' && lowered != 'undefined' && lowered != '-') {
        return direct;
      }
    }
    return _deriveDriverNames(details);
  }

  String? _deriveDriverNames(List<Map<String, dynamic>>? details) {
    if (details == null || details.isEmpty) return null;
    final names = <String>{};
    for (final detail in details) {
      final candidateValues = <String>[];
      final primaryRaw =
          '${detail['nama_supir'] ?? detail['namaSupir'] ?? detail['supir'] ?? detail['driver_name'] ?? detail['driver'] ?? detail['nama supir'] ?? ''}'
              .trim();
      if (primaryRaw.isNotEmpty) {
        candidateValues.add(primaryRaw);
      }

      for (final entry in detail.entries) {
        final key =
            entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (!key.contains('supir') && !key.contains('driver')) continue;
        final raw = '${entry.value ?? ''}'.trim();
        if (raw.isNotEmpty) {
          candidateValues.add(raw);
        }
      }

      for (final raw in candidateValues) {
        for (final part in raw.split(RegExp(r'[,;/]'))) {
          final name = part.trim();
          final lowered = name.toLowerCase();
          if (name.isNotEmpty &&
              lowered != 'null' &&
              lowered != 'undefined' &&
              lowered != '-') {
            names.add(name);
          }
        }
      }
    }
    if (names.isEmpty) return null;
    return names.join(', ');
  }

  String? _extractSingleDriverName(Map<String, dynamic>? detail) {
    if (detail == null || detail.isEmpty) return null;
    final candidateValues = <String>[];
    final primaryRaw =
        '${detail['nama_supir'] ?? detail['namaSupir'] ?? detail['supir'] ?? detail['driver_name'] ?? detail['driver'] ?? detail['nama supir'] ?? ''}'
            .trim();
    if (primaryRaw.isNotEmpty) {
      candidateValues.add(primaryRaw);
    }

    for (final entry in detail.entries) {
      final key = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (!key.contains('supir') && !key.contains('driver')) continue;
      final raw = '${entry.value ?? ''}'.trim();
      if (raw.isNotEmpty) {
        candidateValues.add(raw);
      }
    }

    for (final raw in candidateValues) {
      for (final part in raw.split(RegExp(r'[,;/]'))) {
        final name = part.trim();
        final lowered = name.toLowerCase();
        if (name.isNotEmpty &&
            lowered != 'null' &&
            lowered != 'undefined' &&
            lowered != '-') {
          return name;
        }
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _buildEffectiveIncomeDetails({
    List<Map<String, dynamic>>? details,
    String? pickup,
    String? destination,
    String? armadaId,
    DateTime? armadaStartDate,
    DateTime? armadaEndDate,
    double? tonase,
    double? harga,
    String? muatan,
    String? namaSupir,
  }) {
    if (details != null && details.isNotEmpty) {
      return details.map((row) => Map<String, dynamic>.from(row)).toList();
    }

    final hasFallback = (pickup?.trim().isNotEmpty == true) ||
        (destination?.trim().isNotEmpty == true) ||
        (armadaId?.trim().isNotEmpty == true) ||
        (muatan?.trim().isNotEmpty == true) ||
        (namaSupir?.trim().isNotEmpty == true) ||
        ((tonase ?? 0) > 0) ||
        ((harga ?? 0) > 0);
    if (!hasFallback) return const <Map<String, dynamic>>[];

    return <Map<String, dynamic>>[
      <String, dynamic>{
        'lokasi_muat': pickup?.trim().isEmpty == true ? null : pickup?.trim(),
        'lokasi_bongkar':
            destination?.trim().isEmpty == true ? null : destination?.trim(),
        'armada_id': armadaId?.trim().isEmpty == true ? null : armadaId?.trim(),
        'armada_start_date':
            armadaStartDate == null ? null : _dateOnly(armadaStartDate),
        'armada_end_date':
            armadaEndDate == null ? null : _dateOnly(armadaEndDate),
        'tonase': tonase,
        'harga': harga,
        'muatan': muatan?.trim().isEmpty == true ? null : muatan?.trim(),
        'nama_supir':
            namaSupir?.trim().isEmpty == true ? null : namaSupir?.trim(),
      },
    ];
  }

  List<Map<String, dynamic>> _sanitizeIncomeDetails(
    List<Map<String, dynamic>> details,
  ) {
    return details
        .map((row) => Map<String, dynamic>.from(row))
        .where(_hasMeaningfulIncomeDetail)
        .toList();
  }

  bool _hasMeaningfulIncomeDetail(Map<String, dynamic> detail) {
    final textKeys = <String>[
      'lokasi_muat',
      'lokasi_bongkar',
      'muatan',
      'nama_supir',
      'armada_id',
      'armada_manual',
      'armada_label',
      'armada_start_date',
      'armada_end_date',
    ];
    for (final key in textKeys) {
      if ('${detail[key] ?? ''}'.trim().isNotEmpty) {
        return true;
      }
    }
    return _resolveIncomeDetailTotal(detail) > 0;
  }

  double _resolveIncomeDetailTotal(Map<String, dynamic> detail) {
    final explicitSubtotal = _num(
      detail['subtotal'] ?? detail['total'] ?? detail['jumlah'],
    );
    if (explicitSubtotal > 0) return explicitSubtotal;
    final tonase = _num(detail['tonase']);
    final harga = _num(detail['harga']);
    return max(0, tonase * harga);
  }

  bool _detailUsesManualArmada(Map<String, dynamic> detail) {
    final manual = '${detail['armada_manual'] ?? ''}'.trim();
    if (manual.isNotEmpty) return true;
    final isManual = detail['armada_is_manual'];
    if (isManual is bool && isManual) return true;
    return false;
  }

  bool _shouldSkipAutoSanguForManualArmada(
    List<Map<String, dynamic>> details,
  ) {
    if (details.isEmpty) return false;
    return details.any(_detailUsesManualArmada);
  }

  Future<_AutoSanguSyncResult> _createSanguExpenseFromIncomeBestEffort({
    String? invoiceId,
    required String invoiceNumber,
    required DateTime expenseDate,
    required List<Map<String, dynamic>> details,
    String? fallbackPickup,
    String? fallbackDestination,
    String? fallbackArmadaId,
    List<Map<String, dynamic>>? preloadedRules,
    Map<String, String>? preloadedPlateById,
  }) async {
    if (details.isEmpty) {
      return const _AutoSanguSyncResult(skipped: 1);
    }
    try {
      final preferredMarker = invoiceId?.trim().isNotEmpty == true
          ? invoiceId!.trim()
          : invoiceNumber.trim();
      if (preferredMarker.isEmpty) {
        return const _AutoSanguSyncResult(skipped: 1);
      }

      final markerCandidates = <String>{
        preferredMarker,
        if (invoiceId?.trim().isNotEmpty == true) invoiceId!.trim(),
        if (invoiceNumber.trim().isNotEmpty) invoiceNumber.trim(),
      };

      final existingAutoRows = _toMapList(
        await _supabase
            .from('expenses')
            .select(
              'id,no_expense,tanggal,status,dicatat_oleh,note,kategori,keterangan,rincian',
            )
            .like('note', 'AUTO_SANGU:%'),
      ).where((row) {
        final note = '${row['note'] ?? ''}'.trim();
        if (!note.startsWith('AUTO_SANGU:')) return false;
        final marker = note.substring('AUTO_SANGU:'.length).trim();
        return markerCandidates.contains(marker);
      }).toList();

      if (_shouldSkipAutoSanguForManualArmada(details)) {
        var deletedCount = 0;
        if (existingAutoRows.isNotEmpty) {
          for (final row in existingAutoRows) {
            final staleId = '${row['id'] ?? ''}'.trim();
            if (staleId.isEmpty) continue;
            try {
              await deleteExpense(staleId);
              deletedCount++;
            } catch (_) {}
          }
        }
        return _AutoSanguSyncResult(
          deleted: deletedCount,
          skipped: 1,
        );
      }

      String normalizeDetailKey(String value) {
        return value
            .toUpperCase()
            .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

      final preservedAmountByName = <String, double>{};
      for (final row in existingAutoRows) {
        final detailRows = _toMapList(row['rincian']);
        for (final detail in detailRows) {
          final name = '${detail['nama'] ?? detail['name'] ?? ''}'.trim();
          if (name.isEmpty) continue;
          final key = normalizeDetailKey(name);
          if (key.isEmpty) continue;
          final amount = _num(detail['jumlah'] ?? detail['amount']);
          if (amount > 0) {
            preservedAmountByName[key] = amount;
          }
        }
      }

      final rules = preloadedRules ?? await _fetchSanguRulesBestEffort();
      final plateById = preloadedPlateById ??
          <String, String>{
            for (final armada in await fetchArmadas())
              '${armada['id'] ?? ''}'.trim():
                  '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
          };

      final expenseDetails = <Map<String, dynamic>>[];
      for (final detail in details) {
        final pickup = _firstNonEmptyText([
          detail['lokasi_muat'],
          fallbackPickup,
        ]);
        final bongkar = _firstNonEmptyText([
          detail['lokasi_bongkar'],
          fallbackDestination,
        ]);
        final effectiveArmadaId = _firstNonEmptyText([
          detail['armada_id'],
          fallbackArmadaId,
        ]);
        final effectiveArmadaManual = _firstNonEmptyText([
          detail['armada_manual'],
        ]);
        final effectiveArmadaLabel = _firstNonEmptyText([
          detail['armada_label'],
          detail['armada'],
        ]);
        final hasDepartureData = pickup.isNotEmpty ||
            bongkar.isNotEmpty ||
            effectiveArmadaId.isNotEmpty ||
            effectiveArmadaManual.isNotEmpty ||
            effectiveArmadaLabel.isNotEmpty;
        if (!hasDepartureData) {
          continue;
        }
        final match = _findSanguRuleMatch(
          rules,
          pickup: pickup,
          destination: bongkar,
        );

        final plate = _resolvePlateTextFromDetail(
          detail,
          plateById: plateById,
          fallbackArmadaId: effectiveArmadaId,
        );
        final plateLabel = plate.isEmpty ? '-' : plate;
        final pickupLabel = pickup.isEmpty ? '-' : pickup;
        final bongkarLabel = bongkar.isEmpty ? '-' : bongkar;
        final detailName = '$plateLabel ($pickupLabel-$bongkarLabel)';
        final detailKey = normalizeDetailKey(detailName);
        final matchedNominal = _num(match?['nominal'] ?? 0);
        final preservedNominal = preservedAmountByName[detailKey] ?? 0;
        final effectiveNominal = matchedNominal > 0
            ? matchedNominal
            : (preservedNominal > 0 ? preservedNominal : 0);
        if (effectiveNominal <= 0) {
          // Hindari memasukkan nominal yang tidak valid agar total tidak meleset.
          continue;
        }
        final singleDriverName = _extractSingleDriverName(detail);

        expenseDetails.add(<String, dynamic>{
          'nama': detailName,
          'nama_supir': singleDriverName,
          'jumlah': effectiveNominal,
        });
      }

      if (expenseDetails.isEmpty) {
        var deletedCount = 0;
        if (existingAutoRows.isNotEmpty) {
          for (final row in existingAutoRows) {
            final staleId = '${row['id'] ?? ''}'.trim();
            if (staleId.isEmpty) continue;
            try {
              await deleteExpense(staleId);
              deletedCount++;
            } catch (_) {}
          }
        }
        return _AutoSanguSyncResult(
          deleted: deletedCount,
          skipped: 1,
        );
      }
      final totalExpense = expenseDetails.fold<double>(
        0,
        (sum, row) => sum + _num(row['jumlah']),
      );

      if (existingAutoRows.isEmpty) {
        await createExpense(
          total: totalExpense,
          status: 'Paid',
          expenseDate: expenseDate,
          kategori: 'Sangu Sopir',
          keterangan: 'Auto sangu sopir - $invoiceNumber',
          note: 'AUTO_SANGU:$preferredMarker',
          details: expenseDetails,
        );
        return const _AutoSanguSyncResult(created: 1);
      }

      final primary = existingAutoRows.first;
      final primaryId = '${primary['id'] ?? ''}'.trim();
      if (primaryId.isEmpty) {
        return const _AutoSanguSyncResult(skipped: 1);
      }
      await updateExpense(
        id: primaryId,
        date: _dateOnly(expenseDate),
        status: 'Paid',
        total: totalExpense,
        kategori: 'Sangu Sopir',
        keterangan: 'Auto sangu sopir - $invoiceNumber',
        note: 'AUTO_SANGU:$preferredMarker',
        recordedBy: '${primary['dicatat_oleh'] ?? 'Admin'}'.trim(),
        details: expenseDetails,
      );

      var deletedCount = 0;
      if (existingAutoRows.length > 1) {
        for (final row in existingAutoRows.skip(1)) {
          final duplicateId = '${row['id'] ?? ''}'.trim();
          if (duplicateId.isEmpty) continue;
          await deleteExpense(duplicateId);
          deletedCount++;
        }
      }
      return _AutoSanguSyncResult(
        updated: 1,
        deleted: deletedCount,
      );
    } catch (_) {
      // Best effort: invoice income tetap sukses walau auto-expense gagal.
      return const _AutoSanguSyncResult(failed: 1);
    }
  }

  Future<AutoSanguBackfillReport>
      backfillAutoSanguExpensesForExistingInvoices() async {
    var processedInvoices = 0;
    var createdExpenses = 0;
    var updatedExpenses = 0;
    var deletedExpenses = 0;
    var skippedInvoices = 0;
    var failedInvoices = 0;
    try {
      final invoices = _toMapList(
        await _runInvoiceSelectWithFallback(
          'id,no_invoice,tanggal,tanggal_kop,lokasi_muat,lokasi_bongkar,armada_id,armada_start_date,rincian,nama_pelanggan',
          (columns) => _supabase.from('invoices').select(columns),
        ),
      );

      String normalizeMarker(String value) {
        return value
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(' /', '/')
            .replaceAll('/ ', '/');
      }

      final validMarkers = <String>{};
      for (final invoice in invoices) {
        final invoiceId = '${invoice['id'] ?? ''}'.trim();
        final noInvoice = '${invoice['no_invoice'] ?? ''}'.trim();
        final normalizedNoInvoice = Formatters.invoiceNumber(
          noInvoice,
          invoice['tanggal_kop'] ?? invoice['tanggal'],
          customerName: invoice['nama_pelanggan'],
        );

        if (invoiceId.isNotEmpty) {
          validMarkers.add(normalizeMarker(invoiceId));
        }
        if (noInvoice.isNotEmpty) {
          validMarkers.add(normalizeMarker(noInvoice));
        }
        if (normalizedNoInvoice.isNotEmpty && normalizedNoInvoice != '-') {
          validMarkers.add(normalizeMarker(normalizedNoInvoice));
        }
      }

      final existingAutoRows = _toMapList(
        await _supabase.from('expenses').select('id,note').like(
              'note',
              'AUTO_SANGU:%',
            ),
      );
      for (final row in existingAutoRows) {
        final id = '${row['id'] ?? ''}'.trim();
        final note = '${row['note'] ?? ''}'.trim();
        if (id.isEmpty || !note.startsWith('AUTO_SANGU:')) continue;
        final marker = note.substring('AUTO_SANGU:'.length).trim();
        final markerKey = normalizeMarker(marker);
        if (markerKey.isEmpty) continue;
        if (!validMarkers.contains(markerKey)) {
          try {
            await deleteExpense(id);
            deletedExpenses++;
          } catch (_) {
            failedInvoices++;
          }
        }
      }

      final rules = await _fetchSanguRulesBestEffort();
      final plateById = <String, String>{
        for (final armada in await fetchArmadas())
          '${armada['id'] ?? ''}'.trim():
              '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
      };

      for (final invoice in invoices) {
        final invoiceId = '${invoice['id'] ?? ''}'.trim();
        final invoiceNumber = '${invoice['no_invoice'] ?? ''}'.trim();
        if (invoiceId.isEmpty && invoiceNumber.isEmpty) continue;
        processedInvoices++;

        final details = _buildEffectiveIncomeDetails(
          details: _toMapList(invoice['rincian']),
          pickup: '${invoice['lokasi_muat'] ?? ''}',
          destination: '${invoice['lokasi_bongkar'] ?? ''}',
          armadaId: '${invoice['armada_id'] ?? ''}',
        );
        if (details.isEmpty) {
          skippedInvoices++;
          continue;
        }
        final expenseReferenceDate = _resolveExpenseReferenceDateFromDetails(
          details,
          fallbackDate: invoice['armada_start_date'] ?? invoice['tanggal'],
        );

        final result = await _createSanguExpenseFromIncomeBestEffort(
          invoiceId: invoiceId.isEmpty ? null : invoiceId,
          invoiceNumber: invoiceNumber.isEmpty ? '-' : invoiceNumber,
          expenseDate: expenseReferenceDate,
          details: details,
          fallbackPickup: '${invoice['lokasi_muat'] ?? ''}',
          fallbackDestination: '${invoice['lokasi_bongkar'] ?? ''}',
          fallbackArmadaId: '${invoice['armada_id'] ?? ''}',
          preloadedRules: rules,
          preloadedPlateById: plateById,
        );
        createdExpenses += result.created;
        updatedExpenses += result.updated;
        deletedExpenses += result.deleted;
        skippedInvoices += result.skipped;
        failedInvoices += result.failed;
      }
    } catch (_) {
      failedInvoices++;
    }
    return AutoSanguBackfillReport(
      processedInvoices: processedInvoices,
      createdExpenses: createdExpenses,
      updatedExpenses: updatedExpenses,
      deletedExpenses: deletedExpenses,
      skippedInvoices: skippedInvoices,
      failedInvoices: failedInvoices,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchSanguRulesBestEffort() async {
    try {
      final res = await _supabase
          .from('sangu_driver_rules')
          .select('tempat,lokasi_muat,lokasi_bongkar,nominal,is_active')
          .eq('is_active', true);
      return _toMapList(res)
          .map((row) {
            final tempat = '${row['tempat'] ?? ''}'.trim();
            var muat = '${row['lokasi_muat'] ?? ''}'.trim();
            var bongkar = '${row['lokasi_bongkar'] ?? ''}'.trim();
            final nominal = _num(row['nominal']);
            if (nominal <= 0) return null;

            if (muat.isEmpty && bongkar.isEmpty && tempat.contains('-')) {
              final chunks = tempat.split('-');
              if (chunks.length >= 2) {
                muat = chunks.first.trim();
                bongkar = chunks.sublist(1).join('-').trim();
              }
            }
            if (muat.isEmpty && bongkar.isEmpty && tempat.isNotEmpty) {
              bongkar = tempat;
            }
            if (muat.isEmpty && bongkar.isEmpty) return null;

            return <String, dynamic>{
              'tempat': tempat.isEmpty ? '$muat-$bongkar' : tempat,
              'lokasi_muat': muat,
              'lokasi_bongkar': bongkar,
              'nominal': nominal,
              '__muat_norm': _normalizeSanguPlace(muat),
              '__bongkar_norm': _normalizeSanguPlace(bongkar),
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) =>
            _sanguRuleSpecificity(b).compareTo(_sanguRuleSpecificity(a)));
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Map<String, dynamic>? _findSanguRuleMatch(
    List<Map<String, dynamic>> rules, {
    required String pickup,
    required String destination,
  }) {
    final pickupNorm = _normalizeSanguPlace(pickup);
    final destinationNorm = _normalizeSanguPlace(destination);
    if (pickupNorm.isEmpty && destinationNorm.isEmpty) return null;

    bool containsEither(String left, String right) {
      if (left.isEmpty || right.isEmpty) return false;
      return left == right || left.contains(right) || right.contains(left);
    }

    int scoreRule(Map<String, dynamic> rule) {
      final muatNorm = '${rule['__muat_norm'] ?? ''}';
      final bongkarNorm = '${rule['__bongkar_norm'] ?? ''}';
      if (muatNorm.isNotEmpty && bongkarNorm.isNotEmpty) {
        if (pickupNorm == muatNorm && destinationNorm == bongkarNorm) {
          return 400;
        }
        if (containsEither(pickupNorm, muatNorm) &&
            containsEither(destinationNorm, bongkarNorm)) {
          return 300;
        }
        if (pickupNorm == muatNorm || destinationNorm == bongkarNorm) {
          return 180;
        }
        return 0;
      }
      if (muatNorm.isEmpty && bongkarNorm.isNotEmpty) {
        if (destinationNorm == bongkarNorm) return 260;
        if (containsEither(destinationNorm, bongkarNorm)) return 140;
        return 0;
      }
      if (bongkarNorm.isEmpty && muatNorm.isNotEmpty) {
        if (pickupNorm == muatNorm) return 240;
        if (containsEither(pickupNorm, muatNorm)) return 130;
        return 0;
      }
      return 0;
    }

    Map<String, dynamic>? bestRule;
    var bestScore = 0;
    var bestSpecificity = -1;
    for (final rule in rules) {
      final score = scoreRule(rule);
      final specificity = _sanguRuleSpecificity(rule);
      if (score > bestScore ||
          (score == bestScore && score > 0 && specificity > bestSpecificity)) {
        bestScore = score;
        bestRule = rule;
        bestSpecificity = specificity;
      }
    }
    if (bestRule != null && bestScore > 0) return bestRule;

    // Fallback khusus: lokasi bongkar Purwodadi.
    // Tetap dianjurkan menambahkan rule di tabel sangu_driver_rules,
    // tapi fallback ini menjaga agar auto expense tetap terbentuk.
    if (destinationNorm == 'purwodadi' ||
        destinationNorm.contains('purwodadi')) {
      return <String, dynamic>{
        'tempat': 'PURWODADI',
        'lokasi_muat': '',
        'lokasi_bongkar': 'PURWODADI',
        'nominal': 920000,
        '__muat_norm': '',
        '__bongkar_norm': 'purwodadi',
      };
    }

    // Fallback khusus: jika lokasi bongkar di Pare dan belum ada rule yang cocok,
    // otomatis gunakan nominal yang disepakati untuk biaya supir.
    if (destinationNorm == 'pare') {
      return <String, dynamic>{
        'tempat': 'Pare',
        'lokasi_muat': '',
        'lokasi_bongkar': 'Pare',
        'nominal': 1050000,
        '__muat_norm': '',
        '__bongkar_norm': 'pare',
      };
    }

    // Fallback khusus: lokasi bongkar Sudali.
    // Tetap dianjurkan menambahkan rule di tabel sangu_driver_rules,
    // tapi fallback ini menjaga agar auto expense tetap terbentuk.
    if (destinationNorm == 'sudali' || destinationNorm.contains('sudali')) {
      return <String, dynamic>{
        'tempat': 'Sudali',
        'lokasi_muat': '',
        'lokasi_bongkar': 'Sudali',
        'nominal': 805000,
        '__muat_norm': '',
        '__bongkar_norm': 'sudali',
      };
    }

    return null;
  }

  String _resolvePlateTextFromDetail(
    Map<String, dynamic> detail, {
    required Map<String, String> plateById,
    String? fallbackArmadaId,
  }) {
    final detailArmadaId = _firstNonEmptyText([
      detail['armada_id'],
      fallbackArmadaId,
    ]);
    if (detailArmadaId.isNotEmpty) {
      final plateByMap = plateById[detailArmadaId];
      if (plateByMap != null && plateByMap.trim().isNotEmpty) {
        return plateByMap.trim().toUpperCase();
      }
    }

    final directPlate = _firstNonEmptyText([
      detail['plat_nomor'],
      detail['no_polisi'],
    ]).toUpperCase();
    if (directPlate.isNotEmpty && directPlate != '-') {
      return directPlate;
    }

    final manual = _firstNonEmptyText([
      detail['armada_manual'],
    ]).toUpperCase();
    if (manual.isNotEmpty && manual != '-') {
      return manual;
    }

    final label = _firstNonEmptyText([
      detail['armada_label'],
      detail['armada'],
    ]).toUpperCase();
    final match =
        RegExp(r'\b[A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{1,3}\b').firstMatch(label);
    if (match != null) {
      return match.group(0)!.trim().toUpperCase();
    }
    return '';
  }

  int _sanguRuleSpecificity(Map<String, dynamic> rule) {
    final muatNorm = '${rule['__muat_norm'] ?? ''}'.trim();
    final bongkarNorm = '${rule['__bongkar_norm'] ?? ''}'.trim();
    final muatTokens = muatNorm.isEmpty
        ? 0
        : muatNorm.split(' ').where((e) => e.isNotEmpty).length;
    final bongkarTokens = bongkarNorm.isEmpty
        ? 0
        : bongkarNorm.split(' ').where((e) => e.isNotEmpty).length;
    return (muatNorm.isNotEmpty ? 10000 : 0) +
        (bongkarNorm.isNotEmpty ? 5000 : 0) +
        (muatTokens * 1000) +
        (bongkarTokens * 500) +
        (muatNorm.length * 10) +
        bongkarNorm.length;
  }

  String _normalizeSanguPlace(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return normalized;
    if (normalized.contains('purwodadi')) return 'purwodadi';
    if (normalized.contains('pare')) return 'pare';
    if (normalized.contains('sudali') || normalized.contains('soedali')) {
      return 'sudali';
    }
    if (normalized.contains('kedawung') || normalized.contains('dawung')) {
      return 'kedawung';
    }
    if (normalized.contains('singosari') ||
        (normalized.contains('ksi') && normalized.contains('singosari'))) {
      return 'singosari';
    }
    if (normalized.contains('cj') && normalized.contains('mojoagung')) {
      return 'mojoagung';
    }
    if (normalized.contains('mojoagung')) return 'mojoagung';
    if (normalized.contains('bricon') && normalized.contains('mojo')) {
      return 'bricon';
    }
    if (normalized.contains('bricon')) return 'bricon';
    if (normalized.contains('kletek') && normalized.contains('bmc')) {
      return 'kletek';
    }
    if (normalized.contains('safelock')) return 'safelock';
    if (normalized.contains('tuban') || normalized.contains('jenu')) {
      return 'tuban jenu';
    }
    if (normalized.contains('kediri')) return 'kediri';
    if (normalized.contains('sragen')) return 'sragen';
    if (normalized.contains('bimoli')) return 'bimoli';
    if (normalized.contains('batang')) return 'batang';
    if (normalized.contains('kig')) return 'kig';
    if (normalized.contains('kendal')) return 'kendal';
    if (normalized.contains('gema')) return 'gema';
    if (normalized.contains('mkp')) return 'mkp';
    if (normalized.contains('sgm')) return 'sgm';
    if (normalized.contains('molindo')) return 'molindo';
    if (normalized.contains('muncar')) return 'muncar';
    if (normalized.contains('tongas')) return 'tongas';
    if (normalized.contains('tanggulangin')) return 'tanggulangin';
    if (normalized.contains('tim')) return 'tim';
    if (normalized.contains('aspal')) return 'aspal';
    return normalized;
  }

  Future<void> _setArmadaStatusBestEffort(
    Set<String> armadaIds, {
    required String status,
  }) async {
    if (armadaIds.isEmpty) return;
    final payload = <String, dynamic>{
      'status': status,
      'is_active': status.toLowerCase() != 'inactive',
      'updated_at': DateTime.now().toIso8601String(),
    };
    for (final id in armadaIds) {
      try {
        await _supabase.from('armadas').update(payload).eq('id', id);
      } catch (_) {
        // Best effort: invoice tetap tersimpan walau status armada gagal di-sync.
      }
    }
  }

  Future<void> _syncArmadaStatusNowBestEffort() async {
    try {
      const columns =
          'id,nama_truk,plat_nomor,kapasitas,status,is_active,created_at,updated_at';
      final res = await _supabase
          .from('armadas')
          .select(columns)
          .order('created_at', ascending: false);
      final armadas = _toMapList(res).map(_normalizeArmadaRow).toList();
      await _syncArmadaStatusByEndDate(armadas);
    } catch (_) {
      // Best effort: status akan tersinkron saat fetch armada berikutnya.
    }
  }
}

