import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/app_security.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import '../utils/income_pricing_rule_logic.dart';
import '../utils/invoice_pph_logic.dart';
import '../utils/sangu_rule_logic.dart';
import '../utils/tolakan_logic.dart';

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

class InvoiceDetailDateSyncReport {
  const InvoiceDetailDateSyncReport({
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

class FinanceReminderEntitySummary {
  const FinanceReminderEntitySummary({
    required this.income,
    required this.autoSanguExpense,
  });

  final double income;
  final double autoSanguExpense;

  double get netProfit => income - autoSanguExpense;
}

class FinanceReminderSummary {
  const FinanceReminderSummary({
    required this.periodStart,
    required this.periodEndExclusive,
    required this.cv,
    required this.personal,
  });

  final DateTime periodStart;
  final DateTime periodEndExclusive;
  final FinanceReminderEntitySummary cv;
  final FinanceReminderEntitySummary personal;

  DateTime get month => DateTime(periodStart.year, periodStart.month, 1);
  double get totalIncome => cv.income + personal.income;
  double get totalExpense => cv.autoSanguExpense + personal.autoSanguExpense;
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

  _AutoSanguSyncResult plus(_AutoSanguSyncResult other) {
    return _AutoSanguSyncResult(
      created: created + other.created,
      updated: updated + other.updated,
      deleted: deleted + other.deleted,
      skipped: skipped + other.skipped,
      failed: failed + other.failed,
    );
  }
}

class DashboardRepository {
  DashboardRepository(this._supabase);

  static const _gabunganHargaRuleCustomerName = 'Gabungan';

  final SupabaseClient _supabase;
  bool? _invoiceNumberColumnAvailable;
  final Set<String> _unavailableInvoiceColumns = <String>{};
  final Set<String> _unavailableExpenseColumns = <String>{};
  final Set<String> _unavailableFixedInvoiceBatchColumns = <String>{};
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
    'paid_at',
    ..._invoiceWorkflowColumns,
  };
  static const _optionalExpenseColumns = <String>{
    'created_by',
  };
  static const _optionalFixedInvoiceBatchColumns = <String>{
    'status',
    'paid_at',
    'manual_paid_amount',
    'payment_details',
  };
  static const _requiredFixedInvoiceBatchPaymentColumns = <String>{
    'status',
    'paid_at',
    'manual_paid_amount',
    'payment_details',
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
    final allDetailsUseManualArmada = details != null &&
        details.isNotEmpty &&
        details.every(_detailUsesManualArmada);
    if (!allDetailsUseManualArmada &&
        primary.isNotEmpty &&
        _isLikelyUuid(primary)) {
      ids.add(primary);
    }
    for (final detail in details ?? const <Map<String, dynamic>>[]) {
      if (_detailUsesManualArmada(detail)) continue;
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
    final hasOnlyManualDetails = details != null &&
        details.isNotEmpty &&
        details.every(_detailUsesManualArmada);
    if (hasOnlyManualDetails) return null;

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
      if (_detailUsesManualArmada(detail)) continue;
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
    if (_detailUsesManualArmada(detail)) return null;
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
        final isManualArmada = _detailUsesManualArmada(next);

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
        if (isManualArmada) {
          next['armada_id'] = null;
          next['nama_supir'] = null;
          next['supir'] = null;
          next['driver'] = null;
          next['driver_name'] = null;
          next['armada_is_manual'] = true;
          final manual = _firstNonEmptyText([
            next['armada_manual'],
            next['armada_label'],
            next['armada'],
            _isManualArmadaText(next['plat_nomor']) ? next['plat_nomor'] : null,
            _isManualArmadaText(next['no_polisi']) ? next['no_polisi'] : null,
          ]);
          if (manual.isNotEmpty) {
            next['armada_manual'] = manual;
            next['armada_label'] = manual;
          }
        } else {
          fillText('armada_id', armadaId);
          fillText('nama_supir', namaSupir);
        }
        fillDate('armada_start_date', armadaStartDate);
        fillDate('armada_end_date', armadaEndDate);
        fillText('muatan', muatan);
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
    final manualSubtotal =
        _num(detail['manual_subtotal'] ?? detail['subtotal_manual']);
    if (manualSubtotal > 0) return roundInvoiceRupiah(manualSubtotal);

    final tonase = _num(detail['tonase']);
    final harga = _num(detail['harga']);
    final computedTotal = max(0, tonase * harga).toDouble();
    if (detail['subtotal_auto'] == true && computedTotal > 0) {
      return roundInvoiceRupiah(computedTotal);
    }

    final explicitSubtotal = _num(
      detail['subtotal'] ?? detail['total'] ?? detail['jumlah'],
    );
    if (explicitSubtotal > 0) return roundInvoiceRupiah(explicitSubtotal);
    return roundInvoiceRupiah(computedTotal);
  }

  bool _detailUsesManualArmada(Map<String, dynamic> detail) {
    final isManual = detail['armada_is_manual'];
    if (isManual is bool && isManual) return true;
    final isManualText = '${isManual ?? ''}'.trim().toLowerCase();
    if (isManualText == 'true' || isManualText == '1') return true;
    final manual = '${detail['armada_manual'] ?? ''}'.trim();
    if (manual.isNotEmpty) return true;
    return _isManualArmadaText(detail['armada_label']) ||
        _isManualArmadaText(detail['armada']) ||
        _isManualArmadaText(detail['plat_nomor']) ||
        _isManualArmadaText(detail['no_polisi']);
  }

  bool _isManualArmadaText(dynamic value) {
    final raw = '${value ?? ''}'.trim();
    if (raw.isEmpty) return false;
    final normalized =
        raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return normalized == 'gabungan' ||
        normalized.contains('gabungan') ||
        normalized == 'manual' ||
        normalized.contains('input manual');
  }

  String _normalizeGabunganExpenseRouteKey(dynamic value) {
    final key = normalizeIncomePricingRuleKey('${value ?? ''}');
    if (key.contains('bimoli')) return 'bimoli';
    if (key.contains('kendal')) return 'kendal';
    if (key.contains('kediri')) return 'kediri';
    if (key.contains('semarang')) return 'semarang';
    if (key.contains('kedawung') || key.contains('dawung')) {
      return 'kedawung';
    }
    if (key.contains('royal')) return 'royal';
    if (key.contains('pare')) return 'pare';
    if (key.contains('gempol')) return 'gempol';
    if (key.contains('mkp')) return 'mkp';
    if (key.contains('kedamean')) return 'kedamean';
    if (key.contains('temanggung')) return 'temanggung';
    if (key.contains('kig')) return 'kig';
    if (key.contains('sgm')) return 'sgm';
    if (key.contains('rex') || key.contains('beji')) return 'rex_beji';
    if (key == 't langon' || key == 'langon' || key == 'tlangon') {
      return 'langon';
    }
    if (key.contains('maspion')) return 'maspion';
    if (key == 'betoyo') return 'betoyo';
    return key;
  }

  bool _isGabunganHargaRuleCustomer(dynamic value) {
    final key = normalizeIncomePricingRuleKey('${value ?? ''}');
    return key == normalizeIncomePricingRuleKey(_gabunganHargaRuleCustomerName);
  }

  double _resolveGabunganExpenseRuleHargaPerTon({
    required List<Map<String, dynamic>> rules,
    required String pickup,
    required String destination,
  }) {
    if (rules.isEmpty) return 0.0;
    final pickupKey = normalizeIncomePricingRuleKey(pickup);
    final destinationKey = normalizeIncomePricingRuleKey(destination);
    if (destinationKey.isEmpty) return 0.0;

    int locationScore(String inputKey, String ruleKey) {
      if (ruleKey.isEmpty) return 100;
      if (inputKey.isEmpty) return 0;
      if (!incomePricingLocationKeyMatches(inputKey, ruleKey)) return 0;
      final inputCompact = inputKey.replaceAll(' ', '');
      final ruleCompact = ruleKey.replaceAll(' ', '');
      if (inputKey == ruleKey || inputCompact == ruleCompact) return 1000;
      return 600;
    }

    Map<String, dynamic>? bestRule;
    var bestScore = -1;
    for (final rule in rules) {
      if (rule['is_active'] == false) continue;
      if (!_isGabunganHargaRuleCustomer(rule['customer_name'])) continue;
      final harga = _num(rule['harga_per_ton'] ?? rule['harga']);
      if (harga <= 0) continue;

      final ruleBongkarKey =
          normalizeIncomePricingRuleKey('${rule['lokasi_bongkar'] ?? ''}');
      if (!incomePricingLocationKeyMatches(destinationKey, ruleBongkarKey)) {
        continue;
      }

      final ruleMuatKey =
          normalizeIncomePricingRuleKey('${rule['lokasi_muat'] ?? ''}');
      if (ruleMuatKey.isNotEmpty &&
          !incomePricingLocationKeyMatches(pickupKey, ruleMuatKey)) {
        continue;
      }

      final priority = int.tryParse('${rule['priority'] ?? ''}') ??
          _num(rule['priority']).toInt();
      final score = priority +
          locationScore(pickupKey, ruleMuatKey) +
          locationScore(destinationKey, ruleBongkarKey);
      if (score > bestScore) {
        bestScore = score;
        bestRule = rule;
      }
    }

    return _num(bestRule?['harga_per_ton'] ?? bestRule?['harga']);
  }

  double _resolveGabunganExpenseHargaPerTon({
    required String pickup,
    required String destination,
    String? customerName,
    List<Map<String, dynamic>> hargaPerTonRules =
        const <Map<String, dynamic>>[],
  }) {
    final ruleHarga = _resolveGabunganExpenseRuleHargaPerTon(
      rules: hargaPerTonRules,
      pickup: pickup,
      destination: destination,
    );
    if (ruleHarga > 0) return ruleHarga;

    final pickupKey = _normalizeGabunganExpenseRouteKey(pickup);
    final destinationKey = _normalizeGabunganExpenseRouteKey(destination);
    if (pickupKey == 'betoyo' && destinationKey == 'bimoli') return 33.0;
    if (pickupKey == 'maspion' && destinationKey == 'langon') return 23.0;
    switch (destinationKey) {
      case 'kendal':
        return 170.0;
      case 'kediri':
        return 80.0;
      case 'semarang':
        return 158.0;
      case 'kedawung':
        return 40.0;
      case 'royal':
        return 40.0;
      case 'pare':
        return 78.0;
      case 'gempol':
        return 50.0;
      case 'mkp':
        return 50.0;
      case 'kedamean':
        return 41.0;
      case 'temanggung':
        return 230.0;
      case 'kig':
        return 38.0;
      case 'sgm':
        return 40.0;
      case 'rex_beji':
        return 53.0;
      default:
        return 0.0;
    }
  }

  double _resolveGabunganExpenseTonase(Map<String, dynamic> detail) {
    final directTonase = _num(detail['tonase']);
    if (directTonase > 0) return directTonase;

    final detailTotal = _resolveIncomeDetailTotal(detail);
    final detailHarga = _num(detail['harga']);
    if (detailTotal > 0 && detailHarga > 0) {
      return detailTotal / detailHarga;
    }

    return 0.0;
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
    String? fallbackCustomerName,
    List<Map<String, dynamic>>? preloadedRules,
    List<Map<String, dynamic>>? preloadedHargaPerTonRules,
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

      final existingGabunganRows = _toMapList(
        await _supabase
            .from('expenses')
            .select(
              'id,no_expense,tanggal,status,dicatat_oleh,note,kategori,keterangan,rincian',
            )
            .like('note', 'AUTO_GABUNGAN:%'),
      ).where((row) {
        final note = '${row['note'] ?? ''}'.trim();
        if (!note.startsWith('AUTO_GABUNGAN:')) return false;
        final marker = note.substring('AUTO_GABUNGAN:'.length).trim();
        return markerCandidates.contains(marker);
      }).toList();

      Future<_AutoSanguSyncResult> syncAutoExpenseRows({
        required List<Map<String, dynamic>> existingRows,
        required List<Map<String, dynamic>> nextDetails,
        required String kategori,
        required String keterangan,
        required String notePrefix,
      }) async {
        if (nextDetails.isEmpty) {
          var deletedCount = 0;
          for (final row in existingRows) {
            final staleId = '${row['id'] ?? ''}'.trim();
            if (staleId.isEmpty) continue;
            try {
              await deleteExpense(staleId);
              deletedCount++;
            } catch (_) {}
          }
          return _AutoSanguSyncResult(
            deleted: deletedCount,
            skipped: deletedCount == 0 ? 1 : 0,
          );
        }

        final totalExpense = nextDetails.fold<double>(
          0,
          (sum, row) => sum + _num(row['jumlah']),
        );

        if (existingRows.isEmpty) {
          await createExpense(
            total: totalExpense,
            status: 'Paid',
            expenseDate: expenseDate,
            kategori: kategori,
            keterangan: keterangan,
            note: '$notePrefix:$preferredMarker',
            details: nextDetails,
          );
          return const _AutoSanguSyncResult(created: 1);
        }

        final primary = existingRows.first;
        final primaryId = '${primary['id'] ?? ''}'.trim();
        if (primaryId.isEmpty) {
          return const _AutoSanguSyncResult(skipped: 1);
        }
        await updateExpense(
          id: primaryId,
          date: _dateOnly(expenseDate),
          status: 'Paid',
          total: totalExpense,
          kategori: kategori,
          keterangan: keterangan,
          note: '$notePrefix:$preferredMarker',
          recordedBy: '${primary['dicatat_oleh'] ?? 'Admin'}'.trim(),
          details: nextDetails,
        );

        var deletedCount = 0;
        if (existingRows.length > 1) {
          for (final row in existingRows.skip(1)) {
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
            final baseAmount = resolveTolakanBaseValue(
              amount,
              cargo: detailCargo,
            );
            preservedBaseAmountByName[key] = baseAmount;
          }
        }
      }

      final rules = preloadedRules ?? await _fetchSanguRulesBestEffort();
      final hargaPerTonRules =
          preloadedHargaPerTonRules ?? await fetchHargaPerTonRules();
      final plateById = preloadedPlateById ??
          <String, String>{
            for (final armada in await fetchArmadas())
              '${armada['id'] ?? ''}'.trim():
                  '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
          };

      final expenseDetails = <Map<String, dynamic>>[];
      final gabunganExpenseDetails = <Map<String, dynamic>>[];
      for (final detail in details) {
        final originalPickup = _firstNonEmptyText([
          detail['lokasi_muat'],
          fallbackPickup,
        ]);
        final originalDestination = _firstNonEmptyText([
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
        final hasDepartureData = originalPickup.isNotEmpty ||
            originalDestination.isNotEmpty ||
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
        if (isOngkosKuliCargo(effectiveCargo)) {
          continue;
        }
        if (_detailUsesManualArmada(detail)) {
          final tonase = _resolveGabunganExpenseTonase(detail);
          final gabunganHarga = _resolveGabunganExpenseHargaPerTon(
            pickup: originalPickup,
            destination: originalDestination,
            customerName: _firstNonEmptyText([
              detail['nama_pelanggan'],
              detail['customer_name'],
              fallbackCustomerName,
            ]),
            hargaPerTonRules: hargaPerTonRules,
          );
          final gabunganTotal = tonase > 0 && gabunganHarga > 0
              ? roundInvoiceRupiah(tonase * gabunganHarga)
              : 0.0;
          if (gabunganTotal <= 0) {
            continue;
          }
          final pickupLabel =
              originalPickup.trim().isEmpty ? '-' : originalPickup.trim();
          final bongkarLabel = originalDestination.trim().isEmpty
              ? '-'
              : originalDestination.trim();
          final manualLabel = _firstNonEmptyText([
            detail['armada_manual'],
            detail['armada_label'],
            detail['armada'],
            'Gabungan',
          ]);
          gabunganExpenseDetails.add(<String, dynamic>{
            'nama': '$manualLabel ($pickupLabel-$bongkarLabel)',
            'nama_supir': null,
            'lokasi_muat': originalPickup,
            'lokasi_bongkar': originalDestination,
            'muatan': effectiveCargo,
            'tonase': tonase,
            'harga': gabunganHarga,
            'jumlah': gabunganTotal,
          });
          continue;
        }
        final baseRoute = (
          pickup: originalPickup.trim(),
          destination: originalDestination.trim(),
        );
        final displayRoute = resolveTolakanDisplayRoute(
          pickup: baseRoute.pickup,
          destination: baseRoute.destination,
          cargo: effectiveCargo,
        );
        final isTolakan = isTolakanCargo(effectiveCargo);
        final displayRouteDiffers = displayRoute.pickup != baseRoute.pickup ||
            displayRoute.destination != baseRoute.destination;
        final displayRouteMatch = isTolakan && displayRouteDiffers
            ? _findSanguRuleMatch(
                rules,
                pickup: displayRoute.pickup,
                destination: displayRoute.destination,
              )
            : null;
        final baseMatch = _findSanguRuleMatch(
          rules,
          pickup: baseRoute.pickup,
          destination: baseRoute.destination,
        );
        final match = displayRouteMatch ?? baseMatch;

        if (baseRoute.pickup.isEmpty &&
            baseRoute.destination.isEmpty &&
            match == null) {
          continue;
        }

        final plate = _resolvePlateTextFromDetail(
          detail,
          plateById: plateById,
          fallbackArmadaId: effectiveArmadaId,
        );
        final plateLabel = plate.isEmpty ? '-' : plate;
        final pickupLabel =
            displayRoute.pickup.isEmpty ? '-' : displayRoute.pickup;
        final bongkarLabel =
            displayRoute.destination.isEmpty ? '-' : displayRoute.destination;
        final detailName = '$plateLabel ($pickupLabel-$bongkarLabel)';
        final detailKey = normalizeDetailKey(detailName);
        final matchedNominal = _num(match?['nominal'] ?? 0);
        final preservedBaseNominal = preservedBaseAmountByName[detailKey] ?? 0;
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
          'lokasi_muat': displayRoute.pickup,
          'lokasi_bongkar': displayRoute.destination,
          'muatan': effectiveCargo,
          'jumlah': effectiveNominal,
        });
      }

      final gabunganResult = await syncAutoExpenseRows(
        existingRows: existingGabunganRows,
        nextDetails: gabunganExpenseDetails,
        kategori: 'Gabungan',
        keterangan: 'Auto gabungan - $invoiceNumber',
        notePrefix: 'AUTO_GABUNGAN',
      );

      final sanguResult = await syncAutoExpenseRows(
        existingRows: existingAutoRows,
        nextDetails: expenseDetails,
        kategori: 'Sangu Sopir',
        keterangan: 'Auto sangu sopir - $invoiceNumber',
        notePrefix: 'AUTO_SANGU',
      );

      final combined = gabunganResult.plus(sanguResult);
      if (combined.created + combined.updated + combined.deleted > 0) {
        return _AutoSanguSyncResult(
          created: combined.created,
          updated: combined.updated,
          deleted: combined.deleted,
          failed: combined.failed,
        );
      }
      return combined;
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

      final existingAutoRows = [
        ..._toMapList(
          await _supabase.from('expenses').select('id,note').like(
                'note',
                'AUTO_SANGU:%',
              ),
        ),
        ..._toMapList(
          await _supabase.from('expenses').select('id,note').like(
                'note',
                'AUTO_GABUNGAN:%',
              ),
        ),
      ];
      for (final row in existingAutoRows) {
        final id = '${row['id'] ?? ''}'.trim();
        final note = '${row['note'] ?? ''}'.trim();
        if (id.isEmpty) continue;
        final upperNote = note.toUpperCase();
        final marker = upperNote.startsWith('AUTO_SANGU:')
            ? note.substring('AUTO_SANGU:'.length).trim()
            : upperNote.startsWith('AUTO_GABUNGAN:')
                ? note.substring('AUTO_GABUNGAN:'.length).trim()
                : '';
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
      final hargaPerTonRules = await fetchHargaPerTonRules();
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
          fallbackCustomerName: '${invoice['nama_pelanggan'] ?? ''}',
          preloadedRules: rules,
          preloadedHargaPerTonRules: hargaPerTonRules,
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

  Future<InvoiceDetailDateSyncReport>
      syncSingleDetailInvoiceDepartureDates() async {
    var processedInvoices = 0;
    var updatedInvoices = 0;
    var skippedInvoices = 0;
    var failedInvoices = 0;

    try {
      final invoices = _toMapList(
        await _runInvoiceSelectWithFallback(
          'id,tanggal,armada_start_date,rincian,submission_role,approval_status',
          (columns) => _supabase.from('invoices').select(columns),
        ),
      );

      for (final invoice in invoices) {
        final invoiceId = '${invoice['id'] ?? ''}'.trim();
        if (invoiceId.isEmpty) continue;
        processedInvoices++;

        try {
          final details = _toMapList(invoice['rincian']);
          if (details.length != 1) {
            skippedInvoices++;
            continue;
          }

          final detail = Map<String, dynamic>.from(details.first);
          final canonicalDate =
              _resolveCanonicalSingleDetailInvoiceDate(invoice, detail);
          if (canonicalDate == null) {
            skippedInvoices++;
            continue;
          }

          final canonicalText = _dateOnly(canonicalDate);
          final detailStartDate =
              Formatters.parseDate(detail['armada_start_date']);
          final detailStartText =
              detailStartDate == null ? '' : _dateOnly(detailStartDate);
          final invoiceStartDate =
              Formatters.parseDate(invoice['armada_start_date']);
          final invoiceStartText =
              invoiceStartDate == null ? '' : _dateOnly(invoiceStartDate);
          final invoiceDate = Formatters.parseDate(invoice['tanggal']);
          final invoiceDateText =
              invoiceDate == null ? '' : _dateOnly(invoiceDate);

          if (detailStartText == canonicalText &&
              invoiceStartText == canonicalText &&
              invoiceDateText == canonicalText) {
            skippedInvoices++;
            continue;
          }

          detail['armada_start_date'] = canonicalText;
          if (detail.containsKey('tanggal')) {
            detail['tanggal'] = canonicalText;
          }

          await _updateInvoiceWithFallback(invoiceId, <String, dynamic>{
            'tanggal': canonicalText,
            'armada_start_date': canonicalText,
            'rincian': <Map<String, dynamic>>[detail],
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

    return InvoiceDetailDateSyncReport(
      processedInvoices: processedInvoices,
      updatedInvoices: updatedInvoices,
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
              includePph ? calculateInvoicePph2Percent(totalBiaya) : 0.0;
          final totalBayarValue = includePph
              ? calculateInvoiceTotalAfterPph(totalBiaya)
              : max(0, totalBiaya);
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
              '__muat_norm': normalizeSanguPlace(muat),
              '__bongkar_norm': normalizeSanguPlace(bongkar),
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
    final pickupNorm = normalizeSanguPlace(pickup);
    final destinationNorm = normalizeSanguPlace(destination);
    if (pickupNorm.isEmpty && destinationNorm.isEmpty) return null;

    final prioritizedRouteRule = resolvePrioritizedSanguRouteRule(
      pickup: pickup,
      destination: destination,
    );
    if (prioritizedRouteRule != null) {
      return prioritizedRouteRule;
    }

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

    if (destinationNorm == 'gempol') {
      return <String, dynamic>{
        'tempat': 'Gempol',
        'lokasi_muat': '',
        'lokasi_bongkar': 'Gempol',
        'nominal': 690000,
        '__muat_norm': '',
        '__bongkar_norm': 'gempol',
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
    if (_detailUsesManualArmada(detail)) {
      final manual = _firstNonEmptyText([
        detail['armada_manual'],
        detail['armada_label'],
        detail['armada'],
        detail['plat_nomor'],
        detail['no_polisi'],
      ]);
      if (manual.isEmpty || manual == '-') return '';
      final match = RegExp(
        r'\b[A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{1,3}\b',
      ).firstMatch(manual.toUpperCase());
      return (match?.group(0) ?? manual).trim().toUpperCase();
    }

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
