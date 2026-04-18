import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/app_security.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';

part 'dashboard_repository_dashboard.dart';
part 'dashboard_repository_fetch.dart';
part 'dashboard_repository_pengurus.dart';
part 'dashboard_repository_crud.dart';
part 'dashboard_repository_support.dart';

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

class IncomePricingBackfillReport {
  const IncomePricingBackfillReport({
    required this.processedInvoices,
    required this.updatedInvoices,
    required this.skippedInvoices,
    required this.failedInvoices,
  });

  final int processedInvoices;
  final int updatedInvoices;
  final int skippedInvoices;
  final int failedInvoices;

  bool get hasFailures => failedInvoices > 0;
  bool get hasChanges => updatedInvoices > 0;
}

class MonthlyFinanceReminderSummary {
  const MonthlyFinanceReminderSummary({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
  });

  final DateTime month;
  final double totalIncome;
  final double totalExpense;

  double get netProfit => totalIncome - totalExpense;
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
  final Set<String> _unavailableInvoiceColumns = <String>{};
  final Set<String> _unavailableExpenseColumns = <String>{};
  String? _cachedRoleUserId;
  String? _cachedCurrentRole;
  static const _invoiceWorkflowColumns = <String>{
    'submission_role',
    'approval_status',
    'approval_requested_at',
    'approval_requested_by',
    'approved_at',
    'approved_by',
    'rejected_at',
    'rejected_by',
    'edit_request_status',
    'edit_requested_at',
    'edit_requested_by',
    'edit_resolved_at',
    'edit_resolved_by',
  };
  static const _optionalInvoiceColumns = <String>{
    'no_invoice',
    'invoice_entity',
    ..._invoiceWorkflowColumns,
  };
  static const _optionalExpenseColumns = <String>{
    'created_by',
  };
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

  String _resolveCurrentUserRole(
    User user, {
    Map<String, dynamic>? profile,
  }) {
    final appRole = '${user.appMetadata['role'] ?? ''}'.trim().toLowerCase();
    if (appRole == 'admin' || appRole == 'owner' || appRole == 'pengurus') {
      return appRole;
    }
    return (profile?['role'] ?? user.userMetadata?['role'] ?? 'customer')
        .toString()
        .trim()
        .toLowerCase();
  }

  Future<String> _loadCurrentRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'customer';
    if (_cachedRoleUserId == user.id && _cachedCurrentRole != null) {
      return _cachedCurrentRole!;
    }
    try {
      final row = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = _resolveCurrentUserRole(
        user,
        profile: row == null ? null : Map<String, dynamic>.from(row),
      );
      _cachedRoleUserId = user.id;
      _cachedCurrentRole = role;
      return role;
    } catch (_) {
      final fallback = _resolveCurrentUserRole(user);
      _cachedRoleUserId = user.id;
      _cachedCurrentRole = fallback;
      return fallback;
    }
  }

  bool _isPengurusSubmission(Map<String, dynamic> row) {
    return '${row['submission_role'] ?? ''}'.trim().toLowerCase() == 'pengurus';
  }

  String _resolveApprovalStatus(Map<String, dynamic> row) {
    final status = '${row['approval_status'] ?? ''}'.trim().toLowerCase();
    if (status.isNotEmpty) return status;
    if (Formatters.parseDate(row['rejected_at']) != null) {
      return 'rejected';
    }
    if (Formatters.parseDate(row['approved_at']) != null) {
      return 'approved';
    }
    if (Formatters.parseDate(row['approval_requested_at']) != null) {
      return 'pending';
    }
    return _isPengurusSubmission(row) ? 'pending' : 'approved';
  }

  bool _isApprovedForBackoffice(Map<String, dynamic> row) {
    final approvalStatus = _resolveApprovalStatus(row);
    return !_isPengurusSubmission(row) || approvalStatus == 'approved';
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

  Future<void> _insertCustomerNotificationBestEffort({
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
      await _insertCustomerNotification(
        userId: userId,
        title: title,
        message: message,
        status: status,
        kind: kind,
        sourceType: sourceType,
        sourceId: sourceId,
        payload: payload,
      );
      await _sendPushNotificationBestEffort(
        userIds: <String>[userId],
        title: title,
        message: message,
        payload: <String, dynamic>{
          'source_type': sourceType,
          'source_id': sourceId,
          ...?payload,
        },
      );
    } catch (_) {
      // Best effort only: primary action should still succeed.
    }
  }

  Future<void> markCustomerNotificationRead(String notificationId) async {
    final cleanedId = notificationId.trim();
    if (cleanedId.isEmpty) return;
    try {
      await _supabase
          .from('customer_notifications')
          .update(<String, dynamic>{'status': 'read'}).eq('id', cleanedId);
    } on PostgrestException catch (e) {
      final lower = e.message.toLowerCase();
      final missingTable = lower.contains('customer_notifications') &&
          (lower.contains('does not exist') || lower.contains('column'));
      if (missingTable) return;
      throw Exception('Gagal memperbarui notifikasi: ${e.message}');
    }
  }

  Future<void> _broadcastRoleNotifications({
    required List<String> targetRoles,
    required String title,
    required String message,
    String kind = 'info',
    String? sourceType,
    String? sourceId,
    Map<String, dynamic>? payload,
  }) async {
    final cleanedRoles = targetRoles
        .map((role) => role.trim().toLowerCase())
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (cleanedRoles.isEmpty) return;
    Exception? notificationStoreError;
    try {
      await _supabase.rpc(
        'create_role_notifications',
        params: <String, dynamic>{
          'target_roles': cleanedRoles,
          'p_title': title,
          'p_message': message,
          'p_kind': kind,
          'p_source_type': sourceType,
          'p_source_id':
              (sourceId ?? '').trim().isEmpty ? null : sourceId!.trim(),
          'p_payload': payload ?? <String, dynamic>{},
        },
      );
    } on PostgrestException catch (e) {
      notificationStoreError =
          Exception('Gagal mengirim notifikasi staff: ${e.message}');
    }

    await _sendPushNotificationBestEffort(
      targetRoles: cleanedRoles,
      title: title,
      message: message,
      payload: <String, dynamic>{
        'source_type': sourceType,
        'source_id': sourceId,
        ...?payload,
      },
    );

    if (notificationStoreError != null) {
      throw notificationStoreError;
    }
  }

  Future<void> _sendPushNotificationBestEffort({
    List<String>? userIds,
    List<String>? targetRoles,
    required String title,
    required String message,
    Map<String, dynamic>? payload,
  }) async {
    final cleanedUserIds = (userIds ?? const <String>[])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final cleanedRoles = (targetRoles ?? const <String>[])
        .map((role) => role.trim().toLowerCase())
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (cleanedUserIds.isEmpty && cleanedRoles.isEmpty) return;

    try {
      final accessToken =
          _supabase.auth.currentSession?.accessToken.trim() ?? '';
      final response = await _supabase.functions.invoke(
        'send-push',
        headers: <String, String>{
          if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
        },
        body: <String, dynamic>{
          'userIds': cleanedUserIds,
          'targetRoles': cleanedRoles,
          'title': title,
          'message': message,
          'data': payload ?? <String, dynamic>{},
        },
      );
      final responseBody = response.data;
      final responseMap = responseBody is Map
          ? Map<String, dynamic>.from(
              responseBody.map(
                (key, value) => MapEntry('$key', value),
              ),
            )
          : const <String, dynamic>{};
      final delivered =
          int.tryParse('${responseMap['delivered'] ?? ''}'.trim()) ?? 0;
      final attempted =
          int.tryParse('${responseMap['attempted'] ?? ''}'.trim()) ?? 0;
      final errors = responseMap['errors'];
      if (response.status >= 400 || delivered <= 0) {
        AppSecurity.debugLog(
          'send-push returned no delivered notifications.',
          error: <String, dynamic>{
            'status': response.status,
            'delivered': delivered,
            'attempted': attempted,
            'target_roles': cleanedRoles,
            'user_ids': cleanedUserIds,
            'errors': errors,
          },
        );
      }
    } catch (_) {
      // Best effort only: push should never block primary app actions.
    }
  }

  Future<void> _notifyStaffAboutPengurusIncome({
    required String invoiceId,
    required String customerName,
    required DateTime invoiceDate,
    String? pickup,
    String? destination,
  }) async {
    final route =
        '${(pickup ?? '').trim().isEmpty ? '-' : pickup!.trim()} - ${(destination ?? '').trim().isEmpty ? '-' : destination!.trim()}';
    await _broadcastRoleNotifications(
      targetRoles: const ['admin', 'owner'],
      title: 'Income Baru dari Pengurus',
      message:
          'Pengurus membuat income baru untuk $customerName. Rute $route, tanggal ${Formatters.dmy(invoiceDate)}. Buka Penerimaan Order untuk meninjau.',
      kind: 'approval',
      sourceType: 'invoice',
      sourceId: invoiceId,
      payload: <String, dynamic>{
        'invoice_id': invoiceId,
        'request_type': 'new_income',
        'customer_name': customerName,
        'route': route,
        'target': 'order_acceptance',
      },
    );
  }

  Future<void> _notifyStaffAboutPengurusIncomeBestEffort({
    required String invoiceId,
    required String customerName,
    required DateTime invoiceDate,
    String? pickup,
    String? destination,
  }) async {
    try {
      await _notifyStaffAboutPengurusIncome(
        invoiceId: invoiceId,
        customerName: customerName,
        invoiceDate: invoiceDate,
        pickup: pickup,
        destination: destination,
      );
    } catch (_) {
      // Income pengurus tetap harus tersimpan walau notifikasi staff gagal.
    }
  }

  Future<void> _notifyStaffAboutPengurusEditRequest(
    Map<String, dynamic> invoice,
  ) async {
    final invoiceId = '${invoice['id'] ?? ''}'.trim();
    if (invoiceId.isEmpty) return;
    final route =
        '${invoice['lokasi_muat'] ?? '-'} - ${invoice['lokasi_bongkar'] ?? '-'}';
    await _broadcastRoleNotifications(
      targetRoles: const ['admin', 'owner'],
      title: 'Request Edit Income Pengurus',
      message:
          'Pengurus meminta persetujuan edit income ${invoice['nama_pelanggan'] ?? '-'} untuk rute $route. Buka Penerimaan Order untuk meninjau.',
      kind: 'approval',
      sourceType: 'invoice',
      sourceId: invoiceId,
      payload: <String, dynamic>{
        'invoice_id': invoiceId,
        'request_type': 'edit_request',
        'customer_name': '${invoice['nama_pelanggan'] ?? '-'}',
        'route': route,
        'target': 'order_acceptance',
      },
    );
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

  Future<void> _syncArmadaStatusByEndDate(
    List<Map<String, dynamic>> armadas,
  ) async {
    if (armadas.isEmpty) return;

    try {
      final role = await _loadCurrentRole();
      if (role != 'admin' && role != 'owner') {
        return;
      }

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
      return details.map((row) {
        final next = Map<String, dynamic>.from(row);

        void fillText(String key, String? fallback) {
          final current = '${next[key] ?? ''}'.trim();
          final fallbackText = (fallback ?? '').trim();
          if (current.isEmpty && fallbackText.isNotEmpty) {
            next[key] = fallbackText;
          }
        }

        void fillDate(String key, DateTime? fallback) {
          if (fallback == null) return;
          if (Formatters.parseDate(next[key]) != null) return;
          next[key] = _dateOnly(fallback);
        }

        fillText('lokasi_muat', pickup);
        fillText('lokasi_bongkar', destination);
        fillText('armada_id', armadaId);
        fillDate('armada_start_date', armadaStartDate);
        fillDate('armada_end_date', armadaEndDate);
        fillText('muatan', muatan);
        fillText('nama_supir', namaSupir);
        return next;
      }).toList();
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
    String? fallbackCargo,
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

      final preservedBaseAmountByName = <String, double>{};
      for (final row in existingAutoRows) {
        final detailRows = _toMapList(row['rincian']);
        for (final detail in detailRows) {
          final name = '${detail['nama'] ?? detail['name'] ?? ''}'.trim();
          if (name.isEmpty) continue;
          final key = normalizeDetailKey(name);
          if (key.isEmpty) continue;
          final amount = _num(detail['jumlah'] ?? detail['amount']);
          if (amount > 0) {
            final detailCargo = _firstNonEmptyText([
              detail['muatan'],
            ]);
            final baseAmount =
                _isTolakanCargo(detailCargo) ? amount * 2 : amount;
            preservedBaseAmountByName[key] = baseAmount;
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
        final effectiveCargo = _firstNonEmptyText([
          detail['muatan'],
          fallbackCargo,
        ]);
        final resolvedRoute = _resolveAutoSanguRouteForCargo(
          pickup: pickup,
          destination: bongkar,
          cargo: effectiveCargo,
        );
        final match = _findSanguRuleMatch(
          rules,
          pickup: resolvedRoute.pickup,
          destination: resolvedRoute.destination,
        );

        final plate = _resolvePlateTextFromDetail(
          detail,
          plateById: plateById,
          fallbackArmadaId: effectiveArmadaId,
        );
        final plateLabel = plate.isEmpty ? '-' : plate;
        final pickupLabel =
            resolvedRoute.pickup.isEmpty ? '-' : resolvedRoute.pickup;
        final bongkarLabel =
            resolvedRoute.destination.isEmpty ? '-' : resolvedRoute.destination;
        final detailName = '$plateLabel ($pickupLabel-$bongkarLabel)';
        final detailKey = normalizeDetailKey(detailName);
        final matchedNominal = _num(match?['nominal'] ?? 0);
        final preservedBaseNominal = preservedBaseAmountByName[detailKey] ?? 0;
        final isTolakan = _isTolakanCargo(effectiveCargo);
        final effectiveNominal = matchedNominal > 0
            ? (isTolakan ? matchedNominal / 2 : matchedNominal)
            : (preservedBaseNominal > 0
                ? (isTolakan ? preservedBaseNominal / 2 : preservedBaseNominal)
                : 0);
        if (effectiveNominal <= 0) {
          // Hindari memasukkan nominal yang tidak valid agar total tidak meleset.
          continue;
        }
        final singleDriverName = _extractSingleDriverName(detail);

        expenseDetails.add(<String, dynamic>{
          'nama': detailName,
          'nama_supir': singleDriverName,
          'lokasi_muat': resolvedRoute.pickup,
          'lokasi_bongkar': resolvedRoute.destination,
          'muatan': effectiveCargo,
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
          'id,no_invoice,invoice_entity,tanggal,tanggal_kop,lokasi_muat,'
          'lokasi_bongkar,armada_id,armada_start_date,muatan,rincian,'
          'nama_pelanggan,submission_role,approval_status',
          (columns) => _supabase.from('invoices').select(columns),
        ),
      ).where(_isApprovedForBackoffice).toList();

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
          fallbackCargo: '${invoice['muatan'] ?? ''}',
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

  Future<IncomePricingBackfillReport>
      backfillSpecialIncomePricingForExistingInvoices() async {
    var processedInvoices = 0;
    var updatedInvoices = 0;
    var skippedInvoices = 0;
    var failedInvoices = 0;
    try {
      final rules = await fetchHargaPerTonRules();
      if (rules.isEmpty) {
        return const IncomePricingBackfillReport(
          processedInvoices: 0,
          updatedInvoices: 0,
          skippedInvoices: 0,
          failedInvoices: 0,
        );
      }

      final invoices = _toMapList(
        await _runInvoiceSelectWithFallback(
          'id,no_invoice,invoice_entity,tanggal,tanggal_kop,nama_pelanggan,'
          'lokasi_muat,lokasi_bongkar,armada_id,armada_start_date,armada_end_date,'
          'tonase,harga,muatan,nama_supir,total_biaya,pph,total_bayar,rincian,'
          'submission_role,approval_status',
          (columns) => _supabase.from('invoices').select(columns),
        ),
      ).where(_isApprovedForBackoffice).toList();

      for (final invoice in invoices) {
        final invoiceId = '${invoice['id'] ?? ''}'.trim();
        if (invoiceId.isEmpty) continue;
        processedInvoices++;
        try {
          final customerName = '${invoice['nama_pelanggan'] ?? ''}'.trim();
          final fallbackPickup = '${invoice['lokasi_muat'] ?? ''}'.trim();
          final fallbackDestination =
              '${invoice['lokasi_bongkar'] ?? ''}'.trim();
          final details = _buildEffectiveIncomeDetails(
            details: _toMapList(invoice['rincian']),
            pickup: fallbackPickup,
            destination: fallbackDestination,
            armadaId: '${invoice['armada_id'] ?? ''}',
            armadaStartDate: Formatters.parseDate(invoice['armada_start_date']),
            armadaEndDate: Formatters.parseDate(invoice['armada_end_date']),
            tonase: _num(invoice['tonase']),
            harga: _num(invoice['harga']),
            muatan: '${invoice['muatan'] ?? ''}',
            namaSupir: '${invoice['nama_supir'] ?? ''}',
          );
          if (details.isEmpty) {
            skippedInvoices++;
            continue;
          }

          final nextDetails = <Map<String, dynamic>>[];
          var changed = false;
          for (final detail in details) {
            final updatedDetail = _applySpecialIncomePricingRuleToDetail(
              detail,
              rules: rules,
              customerName: customerName,
              fallbackPickup: fallbackPickup,
              fallbackDestination: fallbackDestination,
            );
            if (updatedDetail != null) {
              nextDetails.add(updatedDetail);
              changed = true;
            } else {
              nextDetails.add(Map<String, dynamic>.from(detail));
            }
          }

          if (!changed) {
            skippedInvoices++;
            continue;
          }

          final totalBiaya = nextDetails.fold<double>(
            0,
            (sum, detail) => sum + _resolveIncomeDetailTotal(detail),
          );
          if (totalBiaya <= 0) {
            skippedInvoices++;
            continue;
          }

          final first = nextDetails.first;
          final normalizedEntity = _resolveInvoiceEntity(
            invoiceEntity: '${invoice['invoice_entity'] ?? ''}'.trim(),
            invoiceNumber: invoice['no_invoice'],
            customerName: customerName,
            isCompany: _isCompanyCustomerName(customerName),
          );
          final includePph =
              Formatters.isCompanyInvoiceEntity(normalizedEntity);
          final pphValue =
              includePph ? max(0, (totalBiaya * 0.02).floorToDouble()) : 0.0;
          final totalBayarValue = max(0, totalBiaya - pphValue);
          final resolvedDriverNames = _resolveDriverNames(details: nextDetails);

          String? nullableText(dynamic value) {
            final text = '${value ?? ''}'.trim();
            return text.isEmpty ? null : text;
          }

          final resolvedPickup = nullableText(first['lokasi_muat']) ??
              nullableText(fallbackPickup);
          final resolvedDestination = nullableText(first['lokasi_bongkar']) ??
              nullableText(fallbackDestination);
          final resolvedArmadaId = nullableText(first['armada_id']) ??
              nullableText(invoice['armada_id']);
          final resolvedArmadaStartDate =
              nullableText(first['armada_start_date']) ??
                  nullableText(invoice['armada_start_date']);
          final resolvedArmadaEndDate =
              nullableText(first['armada_end_date']) ??
                  nullableText(invoice['armada_end_date']);

          await _updateInvoiceWithFallback(invoiceId, <String, dynamic>{
            'lokasi_muat': resolvedPickup,
            'lokasi_bongkar': resolvedDestination,
            'armada_id': resolvedArmadaId,
            'armada_start_date': resolvedArmadaStartDate,
            'armada_end_date': resolvedArmadaEndDate,
            'tonase': _num(first['tonase']),
            'harga': _num(first['harga']),
            'muatan': nullableText(first['muatan']),
            'nama_supir': resolvedDriverNames,
            'total_biaya': totalBiaya,
            'pph': pphValue,
            'total_bayar': totalBayarValue,
            'rincian': nextDetails,
            'updated_at': DateTime.now().toIso8601String(),
          });
          updatedInvoices++;
        } catch (_) {
          failedInvoices++;
        }
      }
    } catch (_) {
      failedInvoices++;
    }

    return IncomePricingBackfillReport(
      processedInvoices: processedInvoices,
      updatedInvoices: updatedInvoices,
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

    final batangToLangon =
        pickupNorm == 'batang' && destinationNorm == 'langon';
    final langonToBatang =
        pickupNorm == 'langon' && destinationNorm == 'batang';
    if (batangToLangon || langonToBatang) {
      return <String, dynamic>{
        'tempat': batangToLangon ? 'BATANG - T. LANGON' : 'T. LANGON - BATANG',
        'lokasi_muat': batangToLangon ? 'BATANG' : 'T. LANGON',
        'lokasi_bongkar': batangToLangon ? 'T. LANGON' : 'BATANG',
        'nominal': 3400000,
        '__muat_norm': batangToLangon ? 'batang' : 'langon',
        '__bongkar_norm': batangToLangon ? 'langon' : 'batang',
      };
    }

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

    for (final candidate in [
      _firstNonEmptyText([detail['armada_manual']]),
      _firstNonEmptyText([detail['armada_label'], detail['armada']]),
    ]) {
      final upper = candidate.toUpperCase();
      if (upper.isEmpty || upper == '-') continue;
      final match =
          RegExp(r'\b[A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{1,3}\b').firstMatch(upper);
      if (match != null) {
        return match.group(0)!.trim().toUpperCase();
      }
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
    if (normalized == 'langon' ||
        normalized == 't langon' ||
        normalized == 'tlangon') {
      return 'langon';
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

  bool _isTolakanCargo(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.contains('tolakan');
  }

  ({String pickup, String destination}) _resolveAutoSanguRouteForCargo({
    required String pickup,
    required String destination,
    required String cargo,
  }) {
    final cleanedPickup = pickup.trim();
    final cleanedDestination = destination.trim();
    if (!_isTolakanCargo(cargo)) {
      return (pickup: cleanedPickup, destination: cleanedDestination);
    }

    final pickupNorm = _normalizeSanguPlace(cleanedPickup);
    final destinationNorm = _normalizeSanguPlace(cleanedDestination);
    final isLangonToBatang =
        pickupNorm == 'langon' && destinationNorm == 'batang';
    if (!isLangonToBatang) {
      return (pickup: cleanedPickup, destination: cleanedDestination);
    }

    return (
      pickup: cleanedDestination,
      destination: cleanedPickup,
    );
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
