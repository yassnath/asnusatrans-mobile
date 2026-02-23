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

  Future<DashboardBundle> loadAdminDashboard() async {
    try {
      final response = await Future.wait<dynamic>([
        _supabase
            .from('invoices')
            .select(
              'id,no_invoice,tanggal,nama_pelanggan,status,total_bayar,total_biaya,pph,armada_id,armada_start_date,armada_end_date,created_at',
            )
            .order('tanggal', ascending: false),
        _supabase
            .from('expenses')
            .select('id,no_expense,tanggal,total_pengeluaran,status,created_at')
            .order('tanggal', ascending: false),
        _supabase
            .from('armadas')
            .select('id,nama_truk,plat_nomor,created_at')
            .order('created_at', ascending: false),
        _supabase.from('invoice_items').select('invoice_id,armada_id'),
      ]);

      final invoices = _toMapList(response[0]);
      final expenses = _toMapList(response[1]);
      final armadas = _toMapList(response[2]);
      final invoiceItems = _toMapList(response[3]);

      final metrics = _buildMetrics(invoices, expenses);
      final monthlySeries = _buildMonthlySeries(invoices, expenses);
      final armadaUsage = _buildArmadaUsage(invoices, armadas, invoiceItems);
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
            'id,no_invoice,tanggal,nama_pelanggan,email,no_telp,due_date,'
            'lokasi_muat,lokasi_bongkar,armada_start_date,armada_end_date,'
            'tonase,harga,status,total_bayar,total_biaya,pph,diterima_oleh,'
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
        return _toMapList(res).map(_normalizeArmadaRow).toList();
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
          .select('id,armada_id,created_at')
          .order('created_at', ascending: false);
      return _toMapList(res);
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('column') || message.contains('does not exist')) {
        try {
          final fallback =
              await _supabase.from('invoices').select('id,armada_id');
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
    String status = 'Unpaid',
    DateTime? issuedDate,
    String? email,
    String? noTelp,
    DateTime? dueDate,
    String? pickup,
    String? destination,
    String? armadaId,
    DateTime? armadaStartDate,
    DateTime? armadaEndDate,
    double? tonase,
    double? harga,
    String? acceptedBy,
    String? customerId,
    String? orderId,
    List<Map<String, dynamic>>? details,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }

    final code = _makeDocumentCode('INC');
    final date =
        (issuedDate ?? DateTime.now()).toIso8601String().split('T').first;
    final selectedArmadaIds =
        _collectArmadaIds(primaryArmadaId: armadaId, details: details);

    try {
      final payload = <String, dynamic>{
        'no_invoice': code,
        'tanggal': date,
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
        'status': status,
        'total_biaya': total,
        'pph': max(0, (total * 0.02)),
        'total_bayar': max(0, total - (total * 0.02)),
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
    } on PostgrestException catch (e) {
      throw Exception('Gagal menambah invoice: ${e.message}');
    }
  }

  Future<void> createExpense({
    required double total,
    String status = 'Recorded',
    DateTime? expenseDate,
    String? note,
    String? kategori,
    String? keterangan,
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
        'dicatat_oleh': user.userMetadata?['username'] ??
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
            'id,no_invoice,tanggal,nama_pelanggan,email,no_telp,due_date,'
            'lokasi_muat,lokasi_bongkar,armada_start_date,armada_end_date,'
            'tonase,harga,status,total_biaya,pph,total_bayar,diterima_oleh,'
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
    String? dueDate,
    String? acceptedBy,
    String? pickup,
    String? destination,
    String? armadaId,
    String? armadaStartDate,
    String? armadaEndDate,
    double? tonase,
    double? harga,
    List<Map<String, dynamic>>? details,
  }) async {
    final selectedArmadaIds =
        _collectArmadaIds(primaryArmadaId: armadaId, details: details);
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
    } on PostgrestException catch (e) {
      throw Exception('Gagal update invoice: ${e.message}');
    }
  }

  Future<void> deleteInvoice(String id) async {
    try {
      await _supabase.from('invoices').delete().eq('id', id);
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
    List<Map<String, dynamic>> invoiceItems,
  ) {
    final counts = <String, int>{};
    final itemsByInvoice = <String, List<Map<String, dynamic>>>{};

    for (final item in invoiceItems) {
      final invoiceId = item['invoice_id']?.toString();
      if (invoiceId == null || invoiceId.isEmpty) continue;
      itemsByInvoice.putIfAbsent(invoiceId, () => []).add(item);
    }

    for (final invoice in invoices) {
      final invoiceId = invoice['id']?.toString();
      final related = invoiceId == null
          ? const <Map<String, dynamic>>[]
          : itemsByInvoice[invoiceId] ?? const <Map<String, dynamic>>[];

      if (related.isNotEmpty) {
        for (final item in related) {
          final armadaId = item['armada_id']?.toString();
          if (armadaId == null || armadaId.isEmpty) continue;
          counts[armadaId] = (counts[armadaId] ?? 0) + 1;
        }
      } else {
        final armadaId = invoice['armada_id']?.toString();
        if (armadaId == null || armadaId.isEmpty) continue;
        counts[armadaId] = (counts[armadaId] ?? 0) + 1;
      }
    }

    final list = armadas.map((armada) {
      final id = (armada['id'] ?? '').toString();
      return ArmadaUsage(
        name: (armada['nama_truk'] ?? 'Armada').toString(),
        plate: (armada['plat_nomor'] ?? '-').toString(),
        count: counts[id] ?? 0,
      );
    }).toList();

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
        number:
            Formatters.invoiceNumber(invoice['no_invoice'], invoice['tanggal']),
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
              invoice['no_invoice'], invoice['tanggal']),
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
              invoice['no_invoice'], invoice['tanggal']),
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
        'subtitle': Formatters.invoiceNumber(invoice['no_invoice'], tanggal),
        'dateLabel': Formatters.dmy(tanggal),
        'kind': 'income',
      });

      final armadaId = (invoice['armada_id'] ?? '').toString();
      final armada = armadaById[armadaId];
      final armadaLabel = armada == null
          ? 'Armada'
          : '${armada['nama_truk'] ?? 'Armada'} (${armada['plat_nomor'] ?? '-'})';
      final invoiceLabel =
          Formatters.invoiceNumber(invoice['no_invoice'], invoice['tanggal']);

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

  String _dateOnly(DateTime value) {
    return value.toIso8601String().split('T').first;
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
    if (primary.isNotEmpty) {
      ids.add(primary);
    }
    for (final detail in details ?? const <Map<String, dynamic>>[]) {
      final value = detail['armada_id'];
      final id = value == null ? '' : value.toString().trim();
      if (id.isNotEmpty) {
        ids.add(id);
      }
    }
    return ids;
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
}
