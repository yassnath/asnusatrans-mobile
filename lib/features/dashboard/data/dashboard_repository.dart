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

class DashboardRepository {
  DashboardRepository(this._supabase);

  final SupabaseClient _supabase;
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
      final response = await Future.wait<dynamic>([
        _supabase
            .from('invoices')
            .select(
              'id,no_invoice,tanggal,nama_pelanggan,status,total_bayar,total_biaya,pph,'
              'armada_id,armada_start_date,armada_end_date,muatan,created_at,rincian',
            )
            .order('tanggal', ascending: false),
        _supabase
            .from('expenses')
            .select('id,no_expense,tanggal,total_pengeluaran,status,created_at')
            .order('tanggal', ascending: false),
        _supabase
            .from('armadas')
            .select(
              'id,nama_truk,plat_nomor,kapasitas,status,is_active,created_at,updated_at',
            )
            .order('created_at', ascending: false),
      ]);

      final invoices = _toMapList(response[0]);
      final expenses = _toMapList(response[1]);
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
      final response = await Future.wait<dynamic>([
        _supabase
            .from('invoices')
            .select(
              'id,no_invoice,tanggal,armada_id,armada_start_date,armada_end_date,created_at,rincian',
            )
            .order('tanggal', ascending: false),
        _supabase
            .from('expenses')
            .select('id,no_expense,tanggal,created_at')
            .order('tanggal', ascending: false),
        _supabase
            .from('armadas')
            .select(
              'id,nama_truk,plat_nomor,kapasitas,status,is_active,created_at,updated_at',
            )
            .order('created_at', ascending: false),
      ]);

      final invoices = _toMapList(response[0]);
      final expenses = _toMapList(response[1]);
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
      final res = await _supabase
          .from('invoices')
          .select(
            'id,no_invoice,tanggal,tanggal_kop,lokasi_kop,nama_pelanggan,email,no_telp,due_date,'
            'lokasi_muat,lokasi_bongkar,armada_start_date,armada_end_date,'
            'tonase,harga,muatan,nama_supir,status,total_bayar,total_biaya,pph,diterima_oleh,'
            'customer_id,armada_id,order_id,rincian,created_at,updated_at',
          )
          .order('tanggal', ascending: false);
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
      return _toMapList(res);
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat expense: ${e.message}');
    }
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
      final res = await _supabase
          .from('invoices')
          .select(
            'customer_id,nama_pelanggan,email,no_telp,'
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
            'tanggal_kop': normalize(source?['tanggal_kop'] ?? row['tanggal_kop']),
            'lokasi_kop': normalize(source?['lokasi_kop'] ?? row['lokasi_kop']),
            'lokasi_muat': muat,
            'lokasi_bongkar': bongkar,
            'muatan': normalize(muatan),
            'nama_supir': normalize(source?['nama_supir']),
            'armada_id': '${source?['armada_id'] ?? ''}'.trim(),
            'armada_start_date': normalize(source?['armada_start_date']),
            'armada_end_date': normalize(source?['armada_end_date']),
            'tonase': source?['tonase'],
            'harga': source?['harga'],
            '__stamp': rowStamp(row),
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
        return cleaned;
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat opsi customer invoice: ${e.message}');
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

    final code = (noInvoice ?? '').trim().isEmpty
        ? _makeDocumentCode('INC')
        : noInvoice!.trim();
    final date =
        (issuedDate ?? DateTime.now()).toIso8601String().split('T').first;
    final selectedArmadaIds =
        _collectArmadaIds(primaryArmadaId: armadaId, details: details);
    final driverNames = _resolveDriverNames(
      explicitName: namaSupir,
      details: details,
    );

    final pphValue = includePph ? max(0, (total * 0.02)) : 0.0;
    final totalBayarValue = max(0, total - pphValue);

    try {
      final payload = <String, dynamic>{
        'no_invoice': code,
        'tanggal': date,
        'tanggal_kop': kopDate == null ? null : _dateOnly(kopDate),
        'lokasi_kop':
            kopLocation?.trim().isEmpty == true ? null : kopLocation?.trim(),
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
        'created_by': user.id,
      };

      if (customerId != null && customerId.trim().isNotEmpty) {
        payload['customer_id'] = customerId.trim();
      }
      if (orderId != null && orderId.trim().isNotEmpty) {
        payload['order_id'] = orderId.trim();
      }
      if (armadaId != null && armadaId.trim().isNotEmpty) {
        payload['armada_id'] = armadaId.trim();
      }
      if (details != null && details.isNotEmpty) {
        payload['rincian'] = details;
      }

      await _supabase.from('invoices').insert(payload);
      if (selectedArmadaIds.isNotEmpty) {
        await _setArmadaStatusBestEffort(
          selectedArmadaIds,
          status: 'Full',
        );
      }
      await _syncArmadaStatusNowBestEffort();
    } on PostgrestException catch (e) {
      throw Exception('Gagal menambah invoice: ${e.message}');
    }
  }

  Future<String> generateIncomeInvoiceNumber({
    required DateTime issuedDate,
    required bool isCompany,
  }) async {
    try {
      final monthStart = DateTime(issuedDate.year, issuedDate.month, 1);
      final nextMonth = DateTime(issuedDate.year, issuedDate.month + 1, 1);
      final res = await _supabase
          .from('invoices')
          .select('no_invoice,tanggal,nama_pelanggan')
          .gte('tanggal', _dateOnly(monthStart))
          .lt('tanggal', _dateOnly(nextMonth));

      final rows = _toMapList(res);
      final currentCount = rows.where((row) {
        final no = '${row['no_invoice'] ?? ''}';
        final customerName = '${row['nama_pelanggan'] ?? ''}'.trim();
        final isCompanyEntry = customerName.isNotEmpty
            ? _isCompanyCustomerName(customerName)
            : _isCompanyInvoiceNumber(no);
        return isCompany ? isCompanyEntry : !isCompanyEntry;
      }).length;

      final roman = _romanMonth(issuedDate.month);
      final seq = currentCount + 1;
      if (isCompany) {
        return '480 / CV.ANT / $roman / $seq';
      }
      return '268 / ANT / $roman / $seq';
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

    final code = _makeDocumentCode('EXP');
    final date =
        (expenseDate ?? DateTime.now()).toIso8601String().split('T').first;

    try {
      await _supabase.from('expenses').insert({
        'no_expense': code,
        'tanggal': date,
        'kategori': kategori?.trim().isEmpty == true ? null : kategori?.trim(),
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
    } on PostgrestException catch (e) {
      throw Exception('Gagal menambah expense: ${e.message}');
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
      final res = await _supabase
          .from('invoices')
          .select(
            'id,no_invoice,tanggal,tanggal_kop,lokasi_kop,nama_pelanggan,email,no_telp,due_date,'
            'lokasi_muat,lokasi_bongkar,armada_start_date,armada_end_date,'
            'tonase,harga,muatan,nama_supir,status,total_biaya,pph,total_bayar,diterima_oleh,'
            'customer_id,armada_id,order_id,rincian,created_at,updated_at',
          )
          .eq('id', id)
          .maybeSingle();
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
    List<Map<String, dynamic>>? details,
  }) async {
    final selectedArmadaIds =
        _collectArmadaIds(primaryArmadaId: armadaId, details: details);
    final driverNames = _resolveDriverNames(
      explicitName: namaSupir,
      details: details,
    );
    try {
      final payload = <String, dynamic>{
        'nama_pelanggan': customerName.trim(),
        'tanggal': date,
        'status': status,
        'total_biaya': totalBiaya,
        'pph': pph,
        'total_bayar': totalBayar,
        'email': email?.trim().isEmpty == true ? null : email?.trim(),
        'no_telp': noTelp?.trim().isEmpty == true ? null : noTelp?.trim(),
        'tanggal_kop': kopDate?.trim().isEmpty == true ? null : kopDate?.trim(),
        'lokasi_kop':
            kopLocation?.trim().isEmpty == true ? null : kopLocation?.trim(),
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
        'rincian': details,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (armadaId != null && armadaId.trim().isNotEmpty) {
        payload['armada_id'] = armadaId.trim();
      } else {
        payload['armada_id'] = null;
      }

      await _supabase.from('invoices').update(payload).eq('id', id);
      if (selectedArmadaIds.isNotEmpty) {
        await _setArmadaStatusBestEffort(
          selectedArmadaIds,
          status: 'Full',
        );
      }
      await _syncArmadaStatusNowBestEffort();
    } on PostgrestException catch (e) {
      throw Exception('Gagal update invoice: ${e.message}');
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
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat detail expense: ${e.message}');
    }
  }

  Future<void> updateExpense({
    required String id,
    required String date,
    required String status,
    required double total,
    String? kategori,
    String? keterangan,
    String? note,
    String? recordedBy,
    List<Map<String, dynamic>>? details,
  }) async {
    try {
      await _supabase.from('expenses').update({
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
      }).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Gagal update expense: ${e.message}');
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
        'pickup_date': pickupDate.toIso8601String().split('T').first,
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
      final res = await _supabase
          .from('invoices')
          .select(
            'id,no_invoice,status,total_biaya,pph,total_bayar,'
            'lokasi_muat,lokasi_bongkar,armada_id,tanggal,order_id,created_at',
          )
          .eq('order_id', orderId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
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
      final date =
          Formatters.parseDate(invoice['tanggal'] ?? invoice['created_at']);
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
      (sum, expense) => sum + _num(expense['total_pengeluaran']),
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
      final date =
          Formatters.parseDate(invoice['tanggal'] ?? invoice['created_at']);
      if (date == null || date.year != year) continue;
      income[date.month - 1] += _invoiceTotal(invoice);
    }

    for (final exp in expenses) {
      final date = Formatters.parseDate(exp['tanggal'] ?? exp['created_at']);
      if (date == null || date.year != year) continue;
      expense[date.month - 1] += _num(exp['total_pengeluaran']);
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
          invoice['tanggal'],
          customerName: invoice['nama_pelanggan'],
        ),
        customer: (invoice['nama_pelanggan'] ?? '-').toString(),
        dateLabel: Formatters.dmy(invoice['tanggal'] ?? invoice['created_at']),
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
            invoice['tanggal'],
            customerName: invoice['nama_pelanggan'],
          ),
          customer: (invoice['nama_pelanggan'] ?? '-').toString(),
          dateLabel:
              Formatters.dmy(invoice['tanggal'] ?? invoice['created_at']),
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
          dateLabel:
              Formatters.dmy(expense['tanggal'] ?? expense['created_at']),
          total: _num(expense['total_pengeluaran']),
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
    final combined = <TransactionItem>[
      ...invoices.map((invoice) {
        final id = (invoice['id'] ?? '').toString();
        return TransactionItem(
          id: id,
          type: 'Income',
          number: Formatters.invoiceNumber(
            invoice['no_invoice'],
            invoice['tanggal'],
            customerName: invoice['nama_pelanggan'],
          ),
          customer: (invoice['nama_pelanggan'] ?? '-').toString(),
          dateLabel:
              Formatters.dmy(invoice['tanggal'] ?? invoice['created_at']),
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
          dateLabel:
              Formatters.dmy(expense['tanggal'] ?? expense['created_at']),
          total: _num(expense['total_pengeluaran']),
          status: (expense['status'] ?? 'Recorded').toString(),
          link: '/expense-preview?id=$id',
        );
      }),
    ];

    combined.sort(
        (a, b) => _safeDate(b.dateLabel).compareTo(_safeDate(a.dateLabel)));
    return combined.take(6).toList();
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
      final tanggal = invoice['tanggal'] ?? invoice['created_at'];
      items.add({
        'id': 'inc-$id',
        'date': Formatters.parseDate(tanggal) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        'title': 'Pembuatan Income Invoice',
        'subtitle': Formatters.invoiceNumber(
          invoice['no_invoice'],
          tanggal,
          customerName: invoice['nama_pelanggan'],
        ),
        'dateLabel': Formatters.dmy(tanggal),
        'kind': 'income',
      });

      final invoiceLabel =
          Formatters.invoiceNumber(
        invoice['no_invoice'],
        invoice['tanggal'],
        customerName: invoice['nama_pelanggan'],
      );
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
              'subtitle': '$armadaLabel • $invoiceLabel',
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
              'subtitle': '$armadaLabel • $invoiceLabel',
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
            'subtitle': '$armadaLabel • $invoiceLabel',
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
            'subtitle': '$armadaLabel • $invoiceLabel',
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
        'subtitle': Formatters.invoiceNumber(expense['no_expense'], tanggal),
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

  double _num(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  double _invoiceTotal(Map<String, dynamic> invoice) {
    final totalBayar = _num(invoice['total_bayar']);
    if (totalBayar > 0) return totalBayar;
    final totalBiaya = _num(invoice['total_biaya']);
    final pph = _num(invoice['pph']);
    final fallback = totalBiaya - pph;
    return fallback > 0 ? fallback : 0;
  }

  DateTime _safeDate(String dmy) {
    final parts = dmy.split('-');
    if (parts.length != 3) return DateTime.fromMillisecondsSinceEpoch(0);
    final day = int.tryParse(parts[0]) ?? 1;
    final month = int.tryParse(parts[1]) ?? 1;
    final year = int.tryParse(parts[2]) ?? 1970;
    return DateTime(year, month, day);
  }

  String _makeDocumentCode(String prefix) {
    final now = DateTime.now();
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
    if (compact.contains('/ANT/') && !compact.contains('CV.ANT')) {
      return true;
    }
    return compact.startsWith('NO:268/');
  }

  String _romanMonth(int month) {
    const romans = <String>[
      'I',
      'II',
      'III',
      'IV',
      'V',
      'VI',
      'VII',
      'VIII',
      'IX',
      'X',
      'XI',
      'XII',
    ];
    final safe = month.clamp(1, 12);
    return romans[safe - 1];
  }

  String _dateOnly(DateTime value) {
    return value.toIso8601String().split('T').first;
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
