import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/cvant_button_styles.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/i18n/language_controller.dart';
import '../../../core/notifications/android_device_settings_service.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/security/app_security.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cvant_dropdown_field.dart';
import '../../../core/widgets/page_fade_in.dart';
import '../../../core/widgets/cvant_popup.dart';
import '../../../core/widgets/cvant_logo.dart';
import '../../auth/data/biometric_login_service.dart';
import '../../auth/models/auth_session.dart';
import '../data/dashboard_repository.dart';
import '../models/dashboard_models.dart';
import 'widgets/armada_overview_card.dart';
import 'widgets/customer_orders_card.dart';
import 'widgets/income_expense_chart_card.dart';
import 'widgets/latest_customers_card.dart';
import 'widgets/metric_card.dart';
import 'widgets/recent_activity_card.dart';
import 'widgets/recent_transactions_card.dart';

part 'dashboard_invoice_printing.dart';
part 'dashboard_admin_user_views.dart';
part 'dashboard_calendar_notifications_views.dart';
part 'dashboard_create_income_view.dart';
part 'dashboard_create_expense_view.dart';
part 'dashboard_create_fleet_and_order_views.dart';
part 'dashboard_invoice_list_view.dart';
part 'dashboard_fixed_invoice_view.dart';
part 'dashboard_admin_operations_views.dart';
part 'dashboard_customer_views.dart';

class _InvoicePrefillData {
  const _InvoicePrefillData({
    this.orderId,
    this.customerId,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.pickup,
    this.destination,
    this.pickupDate,
    this.armadaName,
  });

  final String? orderId;
  final String? customerId;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? pickup;
  final String? destination;
  final DateTime? pickupDate;
  final String? armadaName;
}

String _formatRupiahNoPrefix(num value) {
  return Formatters.rupiah(value).replaceAll(RegExp(r'Rp\.?\s*'), '').trim();
}

String formatRupiahNoPrefix(num value) => _formatRupiahNoPrefix(value);

String formatInvoiceTonase(dynamic value) {
  return Formatters.decimal(_toNum(value), useGrouping: true);
}

String formatInvoiceHargaPerTon(dynamic value) {
  return Formatters.decimalFixed(_toNum(value), decimalDigits: 1);
}

Uint8List _trimWhiteMarginsFromPng(
  Uint8List bytes, {
  int threshold = 248,
  int horizontalPadding = 6,
  int verticalPadding = 1,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  var left = decoded.width;
  var top = decoded.height;
  var right = -1;
  var bottom = -1;

  for (var y = 0; y < decoded.height; y++) {
    for (var x = 0; x < decoded.width; x++) {
      final pixel = decoded.getPixel(x, y);
      if (pixel.a <= 8) continue;
      if (pixel.r < threshold || pixel.g < threshold || pixel.b < threshold) {
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
  }

  if (right < left || bottom < top) return bytes;

  final cropLeft = max(0, left - horizontalPadding);
  final cropTop = max(0, top - verticalPadding);
  final cropRight = min(decoded.width - 1, right + horizontalPadding);
  final cropBottom = min(decoded.height - 1, bottom + verticalPadding);
  final cropped = img.copyCrop(
    decoded,
    x: cropLeft,
    y: cropTop,
    width: cropRight - cropLeft + 1,
    height: cropBottom - cropTop + 1,
  );
  return Uint8List.fromList(img.encodePng(cropped));
}

String _normalizeInvoicePrintLocationLabel(dynamic raw) {
  final value = '${raw ?? ''}'.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (value.isEmpty) return '-';
  return value.split(' ').map((segment) {
    if (segment.isEmpty) return segment;
    final cleanLetters = segment.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (cleanLetters.isNotEmpty && cleanLetters.length <= 3) {
      return segment.toUpperCase();
    }
    final lower = segment.toLowerCase();
    return lower.substring(0, 1).toUpperCase() + lower.substring(1);
  }).join(' ');
}

String _formatInvoiceTableDate(dynamic value) {
  final date = Formatters.parseDate(value);
  if (date == null) return '-';
  const monthNames = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final year = (date.year % 100).toString().padLeft(2, '0');
  return '${date.day}-${monthNames[date.month - 1]}-$year';
}

String _menuLabel(String key, AppLanguage language) {
  final isEn = language == AppLanguage.en;
  switch (key.toLowerCase()) {
    case 'dashboard':
      return isEn ? 'Dashboard' : 'Dashboard';
    case 'invoice list':
      return isEn ? 'Invoice List' : 'Daftar Invoice';
    case 'invoice add income':
      return isEn ? 'Invoice Add Income' : 'Tambah Pemasukkan';
    case 'invoice add expense':
      return isEn ? 'Invoice Add Expense' : 'Tambah Pengeluaran';
    case 'fix invoice':
      return isEn ? 'Fix Invoice' : 'Fix Invoice';
    case 'calendar':
      return isEn ? 'Calendar' : 'Kalender';
    case 'fleet list':
      return isEn ? 'Fleet List' : 'Daftar Armada';
    case 'fleet add new':
      return isEn ? 'Fleet Add New' : 'Tambah Armada';
    case 'order acceptance':
      return isEn ? 'Order Acceptance' : 'Penerimaan Order';
    case 'customer registrations':
      return isEn ? 'Customer Registrations' : 'Registrasi Customer';
    case 'add user':
      return isEn ? 'Add User' : 'Tambah User';
    case 'settings':
      return isEn ? 'Settings' : 'Pengaturan';
    case 'order':
      return isEn ? 'Order' : 'Order';
    case 'order history':
      return isEn ? 'Order History' : 'Riwayat Order';
    case 'notifications':
      return isEn ? 'Notifications' : 'Notifikasi';
    default:
      return key;
  }
}

String _flattenSearchText(dynamic value) {
  if (value == null) return '';
  if (value is Map) {
    return value.entries
        .map((entry) => '${entry.key} ${_flattenSearchText(entry.value)}')
        .join(' ');
  }
  if (value is Iterable) {
    return value.map(_flattenSearchText).join(' ');
  }
  return value.toString();
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.session,
    required this.repository,
    required this.biometricService,
    required this.onLogout,
  });

  final AuthSession session;
  final DashboardRepository repository;
  final BiometricLoginService biometricService;
  final Future<void> Function() onLogout;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _staffAlertSeenPrefsKeyPrefix = 'staff_alert_seen_at_v1';
  static const _adminMenus = <String>[
    'Dashboard',
    'Invoice List',
    'Fix Invoice',
    'Invoice Add Income',
    'Invoice Add Expense',
    'Calendar',
    'Fleet List',
    'Fleet Add New',
    'Order Acceptance',
    'Customer Registrations',
    'Add User',
    'Settings',
  ];

  static const _pengurusMenus = <String>[
    'Dashboard',
    'Invoice List',
    'Invoice Add Income',
    'Invoice Add Expense',
    'Settings',
  ];

  static const _customerMenus = <String>[
    'Dashboard',
    'Order',
    'Order History',
    'Notifications',
    'Settings',
  ];

  late Future<DashboardBundle> _adminFuture;
  late Future<CustomerDashboardBundle> _customerFuture;
  Timer? _dashboardAutoRefreshTimer;
  final ValueNotifier<List<ArmadaUsage>?> _armadaUsageNotifier =
      ValueNotifier<List<ArmadaUsage>?>(null);
  final ValueNotifier<List<ActivityItem>?> _recentActivitiesNotifier =
      ValueNotifier<List<ActivityItem>?>(null);
  StreamSubscription<PushNavigationIntent>? _pushIntentSubscription;
  int _adminIndex = 0;
  int _customerIndex = 0;
  _InvoicePrefillData? _invoicePrefill;
  int _staffApprovalBadgeCount = 0;
  List<Map<String, dynamic>> _staffNotifications = const [];
  DateTime? _staffAlertsSeenAt;
  bool _staffAlertsSeenLoaded = false;
  bool _androidPushPromptShown = false;

  int get _staffUnreadNotificationCount => _staffNotifications
      .where(
        (item) =>
            '${item['status'] ?? 'unread'}'.trim().toLowerCase() != 'read',
      )
      .length;

  int get _staffNotificationBadgeCount => _staffUnreadNotificationCount;

  String get _staffAlertSeenPrefsKey {
    final userKey = widget.session.userId?.trim();
    if (userKey != null && userKey.isNotEmpty) {
      return '$_staffAlertSeenPrefsKeyPrefix:$userKey';
    }
    final roleKey = widget.session.normalizedRole.trim().isEmpty
        ? 'staff'
        : widget.session.normalizedRole.trim().toLowerCase();
    return '$_staffAlertSeenPrefsKeyPrefix:$roleKey';
  }

  Map<String, dynamic> _buildStaffApprovalAlertItem(
    Map<String, dynamic> request,
  ) {
    final requestType =
        '${request['__request_type'] ?? 'new_income'}'.trim().toLowerCase();
    final isEditRequest = requestType == 'edit_request';
    final customerName = '${request['nama_pelanggan'] ?? '-'}'.trim();
    final creatorName = '${request['__creator_name'] ?? '-'}'.trim();
    final pickup = '${request['lokasi_muat'] ?? '-'}'.trim();
    final destination = '${request['lokasi_bongkar'] ?? '-'}'.trim();
    final route = '$pickup-$destination';
    final requestDate =
        Formatters.parseDate(request['approval_requested_at']) ??
            Formatters.parseDate(request['edit_requested_at']) ??
            Formatters.parseDate(request['created_at']) ??
            DateTime.now();
    final message = isEditRequest
        ? 'Pengurus $creatorName meminta persetujuan edit untuk income $customerName. Rute $route.'
        : 'Income baru dari pengurus $creatorName untuk $customerName menunggu persetujuan. Rute $route pada ${Formatters.dmy(requestDate)}.';

    return <String, dynamic>{
      'id': '',
      'title': isEditRequest
          ? 'Request Edit Income Pengurus'
          : 'Income Baru dari Pengurus',
      'message': message,
      'status': 'unread',
      'kind': 'approval',
      'source_type': 'invoice',
      'source_id': '${request['id'] ?? ''}'.trim(),
      'payload': <String, dynamic>{
        'invoice_id': '${request['id'] ?? ''}'.trim(),
        'request_type': requestType,
      },
      'created_at': (request['approval_requested_at'] ??
              request['edit_requested_at'] ??
              request['created_at'] ??
              DateTime.now().toIso8601String())
          .toString(),
      '__synthetic': true,
    };
  }

  List<Map<String, dynamic>> _buildStaffApprovalAlerts(
    List<Map<String, dynamic>> queue,
  ) {
    return queue.map(_buildStaffApprovalAlertItem).toList(growable: false);
  }

  Future<void> _ensureStaffAlertsSeenLoaded() async {
    if (_staffAlertsSeenLoaded || !widget.session.isAdminOrOwner) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_staffAlertSeenPrefsKey)?.trim() ?? '';
    _staffAlertsSeenAt = raw.isEmpty ? null : DateTime.tryParse(raw);
    _staffAlertsSeenLoaded = true;
  }

  DateTime _alertCreatedAt(Map<String, dynamic> item) {
    return Formatters.parseDate(item['created_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Map<String, dynamic>> _applySeenStatusToStaffAlerts(
    List<Map<String, dynamic>> items,
  ) {
    final seenAt = _staffAlertsSeenAt;
    return items.map((item) {
      final base = Map<String, dynamic>.from(item);
      if (seenAt != null && !_alertCreatedAt(base).isAfter(seenAt)) {
        base['status'] = 'read';
      } else {
        base['status'] = '${base['status'] ?? 'unread'}';
      }
      return base;
    }).toList(growable: false);
  }

  Future<void> _markStaffAlertsRead(
    Iterable<Map<String, dynamic>> items,
  ) async {
    final alerts = items.toList(growable: false);
    if (alerts.isEmpty) return;
    DateTime? nextSeenAt = _staffAlertsSeenAt;
    for (final item in alerts) {
      final createdAt = _alertCreatedAt(item);
      if (nextSeenAt == null || createdAt.isAfter(nextSeenAt)) {
        nextSeenAt = createdAt;
      }
    }
    if (nextSeenAt == null) return;
    _staffAlertsSeenAt = nextSeenAt;
    _staffAlertsSeenLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _staffAlertSeenPrefsKey, nextSeenAt.toIso8601String());
    if (!mounted) return;
    setState(() {
      _staffNotifications = _applySeenStatusToStaffAlerts(_staffNotifications);
    });
  }

  Future<void> _openStaffNotificationTarget(
    Map<String, dynamic> item, {
    Iterable<Map<String, dynamic>>? visibleNotifications,
  }) async {
    final notificationId = '${item['id'] ?? ''}'.trim();
    final isSynthetic = item['__synthetic'] == true;
    if (notificationId.isNotEmpty && !isSynthetic) {
      try {
        await widget.repository.markCustomerNotificationRead(notificationId);
      } catch (_) {
        // Keep navigation working even if marking as read fails.
      }
    }
    if (isSynthetic) {
      await _markStaffAlertsRead(
        visibleNotifications ?? _staffNotifications,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    setState(() {
      _adminIndex = 8;
      _staffNotifications = _staffNotifications.map((current) {
        if (isSynthetic) {
          return <String, dynamic>{...current, 'status': 'read'};
        }
        if (notificationId.isEmpty) return current;
        if ('${current['id'] ?? ''}'.trim() != notificationId) return current;
        return <String, dynamic>{...current, 'status': 'read'};
      }).toList(growable: false);
    });
    unawaited(_refreshStaffAlerts());
  }

  @override
  void initState() {
    super.initState();
    _reload();
    _startDashboardAutoRefresh();
    _pushIntentSubscription =
        PushNotificationService.instance.intents.listen(_handlePushIntent);
    final pendingIntent =
        PushNotificationService.instance.consumePendingIntent();
    if (pendingIntent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handlePushIntent(pendingIntent);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureAndroidRealtimePushSetup());
    });
  }

  @override
  void dispose() {
    _dashboardAutoRefreshTimer?.cancel();
    _pushIntentSubscription?.cancel();
    _armadaUsageNotifier.dispose();
    _recentActivitiesNotifier.dispose();
    super.dispose();
  }

  void _handlePushIntent(PushNavigationIntent intent) {
    if (!mounted) return;
    if (widget.session.isAdminOrOwner &&
        intent.target == PushNavigationTarget.orderAcceptance) {
      setState(() {
        _adminIndex = 8;
      });
      _reload();
      return;
    }
    if (widget.session.isPengurus &&
        intent.target == PushNavigationTarget.invoiceList) {
      setState(() {
        _adminIndex = 1;
      });
      _reload();
      return;
    }
    if (widget.session.isCustomer &&
        intent.target == PushNavigationTarget.customerNotifications) {
      setState(() {
        _customerIndex = 3;
      });
      return;
    }
  }

  void _reload() {
    final adminFuture = widget.repository.loadAdminDashboard();
    _adminFuture = adminFuture;
    _customerFuture = widget.repository.loadCustomerDashboard();
    unawaited(_refreshStaffAlerts());
    adminFuture.then((bundle) {
      if (!mounted) return;
      _armadaUsageNotifier.value = List<ArmadaUsage>.from(
        bundle.armadaUsages,
      );
      _recentActivitiesNotifier.value = List<ActivityItem>.from(
        bundle.recentActivities,
      );
    }).catchError((_) {});
  }

  Future<void> _ensureAndroidRealtimePushSetup() async {
    if (_androidPushPromptShown ||
        !widget.session.isAdminOrOwner ||
        !Platform.isAndroid ||
        !mounted) {
      return;
    }

    _androidPushPromptShown = true;
    final ignoringBatteryOptimizations = await AndroidDeviceSettingsService
        .instance
        .isIgnoringBatteryOptimizations();
    if (!mounted) return;

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Aktifkan Notifikasi Realtime'),
          content: Text(
            ignoringBatteryOptimizations
                ? 'Notifikasi aplikasi sudah boleh berjalan lebih bebas dari optimasi baterai. Untuk beberapa Android seperti Xiaomi, POCO, OPPO, vivo, dan Realme, autostart dan pengaturan notifikasi aplikasi tetap perlu dipastikan aktif.'
                : 'Agar notifikasi income pengurus masuk seperti aplikasi chat, izinkan aplikasi berjalan tanpa batasan baterai lalu cek autostart dan pengaturan notifikasi aplikasi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('later'),
              child: const Text('Nanti'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('notification'),
              child: const Text('Pengaturan Notifikasi'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('autostart'),
              child: const Text('Autostart'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('battery'),
              child: const Text('Optimasi Baterai'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    switch (action) {
      case 'notification':
        await AndroidDeviceSettingsService.instance
            .openAppNotificationSettings();
        break;
      case 'autostart':
        await AndroidDeviceSettingsService.instance
            .openAutostartSettingsBestEffort();
        break;
      case 'battery':
        await AndroidDeviceSettingsService.instance
            .requestIgnoreBatteryOptimizations();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await AndroidDeviceSettingsService.instance
            .openAutostartSettingsBestEffort();
        break;
      default:
        break;
    }
  }

  Future<void> _refreshDashboardLiveSections() async {
    if (!mounted || widget.session.isCustomer || _adminIndex != 0) return;
    try {
      final live = await widget.repository.loadAdminLiveSections();
      if (!mounted) return;
      _armadaUsageNotifier.value = live.armadaUsages;
      _recentActivitiesNotifier.value = live.recentActivities;
    } catch (_) {
      // Keep current data if live refresh fails.
    }
  }

  void _startDashboardAutoRefresh() {
    _dashboardAutoRefreshTimer?.cancel();
    _dashboardAutoRefreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) {
        _refreshDashboardLiveSections();
        _refreshStaffAlerts();
      },
    );
  }

  Future<void> _refreshStaffAlerts() async {
    if (!widget.session.isAdminOrOwner) return;
    try {
      await _ensureStaffAlertsSeenLoaded();
      final queue = await widget.repository.fetchPengurusApprovalQueue();
      final alertItems = _applySeenStatusToStaffAlerts(
        _buildStaffApprovalAlerts(queue),
      );
      if (!mounted) return;
      setState(() {
        _staffApprovalBadgeCount = queue.length;
        _staffNotifications = alertItems;
      });
    } catch (_) {
      // Keep existing badge values when refresh fails.
    }
  }

  Future<void> _openStaffNotificationsDialog() async {
    if (!widget.session.isAdminOrOwner) return;
    await _refreshStaffAlerts();
    if (!mounted) return;
    final notifications = List<Map<String, dynamic>>.from(_staffNotifications)
      ..sort((a, b) {
        final aDate = Formatters.parseDate(a['created_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = Formatters.parseDate(b['created_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        return AlertDialog(
          title: const Text('Notifications Alert'),
          content: SizedBox(
            width: 520,
            child: notifications.isEmpty
                ? Text(
                    'Belum ada request income pengurus yang menunggu persetujuan.',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      final kind = '${item['kind'] ?? 'info'}'.toLowerCase();
                      final color = kind.contains('success')
                          ? AppColors.success
                          : kind.contains('warning')
                              ? AppColors.warning
                              : kind.contains('error')
                                  ? AppColors.danger
                                  : AppColors.blue;
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppColors.cardBorder(context)),
                          color: AppColors.surfaceSoft(context),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.notifications_active_outlined,
                                  size: 18,
                                  color: color,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${item['title'] ?? 'Notifikasi'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  Formatters.dmy(
                                    item['created_at'] ?? DateTime.now(),
                                  ),
                                  style: TextStyle(
                                    color: AppColors.textMutedFor(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${item['message'] ?? '-'}',
                              style: TextStyle(
                                color: AppColors.textMutedFor(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  tooltip: 'Buka Penerimaan Order',
                                  onPressed: () => _openStaffNotificationTarget(
                                    item,
                                    visibleNotifications: notifications,
                                  ),
                                  style: IconButton.styleFrom(
                                    foregroundColor: AppColors.blue,
                                    side: BorderSide(
                                      color: AppColors.blue,
                                    ),
                                  ),
                                  icon:
                                      const Icon(Icons.remove_red_eye_outlined),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.language,
      builder: (context, language, _) {
        final isCustomer = widget.session.isCustomer;
        final isPengurus = widget.session.isPengurus;
        final menuKeys = isCustomer
            ? _customerMenus
            : (isPengurus ? _pengurusMenus : _adminMenus);
        final selected = isCustomer ? _customerIndex : _adminIndex;
        final isLightMode = AppColors.isLight(context);
        final bodyKey = ValueKey<String>(
          '${language.code}-${isCustomer ? 'customer-page-$_customerIndex' : 'admin-page-$_adminIndex'}',
        );
        final pageBody = isCustomer
            ? _buildCustomerBody()
            : (isPengurus ? _buildPengurusBody() : _buildAdminBody());

        return Scaffold(
          backgroundColor: AppColors.pageBackground(context),
          drawer: _DashboardDrawer(
            items: menuKeys,
            language: language,
            selectedIndex: selected,
            badgeCountsByKey: widget.session.isAdminOrOwner
                ? <String, int>{
                    'Order Acceptance': _staffApprovalBadgeCount,
                  }
                : const <String, int>{},
            onSelect: (index) {
              setState(() {
                final shouldReloadDashboard =
                    (!isCustomer && index == 0) || (isCustomer && index == 0);
                if (shouldReloadDashboard) {
                  _reload();
                }
                if (isCustomer) {
                  _customerIndex = index;
                } else {
                  _adminIndex = index;
                }
              });
              Navigator.of(context).pop();
            },
            onLogout: widget.onLogout,
          ),
          appBar: AppBar(
            titleSpacing: 6,
            title: Text(
              _menuLabel(menuKeys[selected], language),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            actions: [
              if (widget.session.isAdminOrOwner)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Badge(
                    isLabelVisible: _staffNotificationBadgeCount > 0,
                    label: Text('$_staffNotificationBadgeCount'),
                    child: IconButton(
                      tooltip: 'Notifications Alert',
                      onPressed: _openStaffNotificationsDialog,
                      icon: const Icon(Icons.notifications_active_outlined),
                    ),
                  ),
                ),
              IconButton(
                tooltip: isLightMode ? 'Dark Mode' : 'Light Mode',
                onPressed: ThemeController.toggle,
                icon: Icon(
                  isLightMode
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14, left: 2),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceSoft(context),
                  backgroundImage: widget.session.isPengurus
                      ? null
                      : (isCustomer
                          ? const AssetImage('assets/images/iconapk.png')
                          : AssetImage(
                              widget.session.isOwner
                                  ? 'assets/images/pp-owner.webp'
                                  : 'assets/images/pp-admin.webp',
                            )),
                  child: widget.session.isPengurus
                      ? Text(
                          'P',
                          style: TextStyle(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.pageBackground(context),
                  AppColors.pageBackgroundDeep(context),
                ],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _DashboardBackgroundGlow(isLight: AppColors.isLight(context)),
                PageFadeIn(
                  key: bodyKey,
                  child: pageBody,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminBody() {
    switch (_adminIndex) {
      case 0:
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: _buildAdminDashboard(),
        );
      case 1:
        return _AdminInvoiceListView(
          repository: widget.repository,
          session: widget.session,
          isOwner: widget.session.isOwner,
          onDataChanged: () => setState(_reload),
          onQuickMenuSelect: (index) {
            setState(() => _adminIndex = index);
          },
        );
      case 2:
        return _AdminFixedInvoiceView(
          repository: widget.repository,
          onDataChanged: () => setState(_reload),
        );
      case 3:
        return _AdminCreateIncomeView(
          repository: widget.repository,
          session: widget.session,
          onCreated: () => setState(() {
            _reload();
            _adminIndex = 1;
          }),
          prefill: _invoicePrefill,
          onPrefillConsumed: () {
            if (!mounted || _invoicePrefill == null) return;
            setState(() => _invoicePrefill = null);
          },
        );
      case 4:
        return _AdminCreateExpenseView(
          repository: widget.repository,
          session: widget.session,
          onCreated: () => setState(() {
            _reload();
            _adminIndex = 1;
          }),
        );
      case 5:
        return _AdminCalendarView(repository: widget.repository);
      case 6:
        return _AdminFleetListView(
          repository: widget.repository,
          onQuickMenuSelect: (index) {
            setState(() => _adminIndex = index);
          },
        );
      case 7:
        return _AdminCreateFleetView(
          repository: widget.repository,
          onCreated: () => setState(_reload),
        );
      case 8:
        return _AdminOrderAcceptanceView(
          repository: widget.repository,
          session: widget.session,
          onCreateInvoice: (prefill) {
            setState(() {
              _invoicePrefill = prefill;
              _adminIndex = 3;
            });
          },
          onDataChanged: () => setState(_reload),
        );
      case 9:
        return _AdminCustomerRegistrationsView(repository: widget.repository);
      case 10:
        return const _AdminAddUserView();
      case 11:
        return _CustomerSettingsView(
          repository: widget.repository,
          session: widget.session,
          biometricService: widget.biometricService,
        );
      default:
        return const _SimplePlaceholderView(
          title: 'Halaman tidak ditemukan',
          message: 'Menu belum tersedia.',
        );
    }
  }

  Widget _buildPengurusBody() {
    switch (_adminIndex) {
      case 0:
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: _buildAdminDashboard(),
        );
      case 1:
        return _AdminInvoiceListView(
          repository: widget.repository,
          session: widget.session,
          isOwner: false,
          onDataChanged: () => setState(_reload),
          onQuickMenuSelect: (index) {
            setState(() => _adminIndex = index);
          },
        );
      case 2:
        return _AdminCreateIncomeView(
          repository: widget.repository,
          session: widget.session,
          onCreated: () => setState(() {
            _reload();
            _adminIndex = 1;
          }),
          prefill: _invoicePrefill,
          onPrefillConsumed: () {
            if (!mounted || _invoicePrefill == null) return;
            setState(() => _invoicePrefill = null);
          },
        );
      case 3:
        return _AdminCreateExpenseView(
          repository: widget.repository,
          session: widget.session,
          onCreated: () => setState(() {
            _reload();
            _adminIndex = 1;
          }),
        );
      case 4:
        return _CustomerSettingsView(
          repository: widget.repository,
          session: widget.session,
          biometricService: widget.biometricService,
        );
      default:
        return const _SimplePlaceholderView(
          title: 'Halaman tidak ditemukan',
          message: 'Menu belum tersedia.',
        );
    }
  }

  Widget _buildCustomerBody() {
    switch (_customerIndex) {
      case 0:
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: _buildCustomerDashboard(),
        );
      case 1:
        return _CustomerCreateOrderView(
          repository: widget.repository,
          onCreated: () => setState(_reload),
        );
      case 2:
        return _CustomerOrderHistoryView(repository: widget.repository);
      case 3:
        return _CustomerNotificationsView(repository: widget.repository);
      case 4:
        return _CustomerSettingsView(
          repository: widget.repository,
          session: widget.session,
          biometricService: widget.biometricService,
        );
      default:
        return const _SimplePlaceholderView(
          title: 'Halaman tidak ditemukan',
          message: 'Menu belum tersedia.',
        );
    }
  }

  Widget _buildAdminDashboard() {
    final invoiceListIndex = 1;
    final armadaListIndex = widget.session.isPengurus ? invoiceListIndex : 6;
    final activityIndex = widget.session.isPengurus ? invoiceListIndex : 5;
    return FutureBuilder<DashboardBundle>(
      future: _adminFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _ErrorView(
            message:
                snapshot.error?.toString().replaceFirst('Exception: ', '') ??
                    'Gagal memuat dashboard.',
            onRetry: () => setState(_reload),
          );
        }

        final data = snapshot.data!;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
          children: [
            _AutoLoopMetricStrip(
              height: 134,
              items: [
                MetricCard(
                  title: 'Total Customers',
                  value: '${data.metrics.totalCustomers}',
                  subtitle: 'Last 30 days customers',
                  gradient: AppColors.cardGradientCyan,
                  icon: Icons.group_outlined,
                  iconBg: AppColors.cyan,
                ),
                MetricCard(
                  title: 'Total Income',
                  value: Formatters.rupiah(data.metrics.totalIncome),
                  subtitle: 'Last 30 days income',
                  gradient: AppColors.cardGradientGreen,
                  icon: Icons.account_balance_wallet_outlined,
                  iconBg: AppColors.success,
                ),
                MetricCard(
                  title: 'Total Expense',
                  value: Formatters.rupiah(data.metrics.totalExpense),
                  subtitle: 'Last 30 days expense',
                  gradient: AppColors.cardGradientRed,
                  icon: Icons.receipt_long_outlined,
                  iconBg: AppColors.danger,
                ),
              ],
            ),
            const SizedBox(height: 10),
            IncomeExpenseChartCard(
              income: data.monthlySeries.income,
              expense: data.monthlySeries.expense,
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<List<ArmadaUsage>?>(
              valueListenable: _armadaUsageNotifier,
              builder: (context, liveItems, _) {
                return ArmadaOverviewCard(
                  items: liveItems ?? data.armadaUsages,
                  onViewAll: () =>
                      setState(() => _adminIndex = armadaListIndex),
                );
              },
            ),
            const SizedBox(height: 10),
            LatestCustomersCard(
              latestCustomers: data.latestCustomers,
              biggestTransactions: data.biggestTransactions,
              onViewAll: () => setState(() => _adminIndex = invoiceListIndex),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<List<ActivityItem>?>(
              valueListenable: _recentActivitiesNotifier,
              builder: (context, liveItems, _) {
                return RecentActivityCard(
                  items: liveItems ?? data.recentActivities,
                  onViewAll: () => setState(() => _adminIndex = activityIndex),
                );
              },
            ),
            const SizedBox(height: 10),
            RecentTransactionsCard(
              items: data.recentTransactions,
              onViewAll: () => setState(() => _adminIndex = invoiceListIndex),
            ),
            const SizedBox(height: 10),
            const _DashboardContentFooter(),
          ],
        );
      },
    );
  }

  Widget _buildCustomerDashboard() {
    return FutureBuilder<CustomerDashboardBundle>(
      future: _customerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _ErrorView(
            message:
                snapshot.error?.toString().replaceFirst('Exception: ', '') ??
                    'Gagal memuat customer dashboard.',
            onRetry: () => setState(_reload),
          );
        }

        final data = snapshot.data!;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
          children: [
            _AutoLoopMetricStrip(
              height: 134,
              items: [
                MetricCard(
                  title: 'Total Orders',
                  value: '${data.totalOrders}',
                  subtitle: 'Jumlah order customer',
                  gradient: AppColors.cardGradientCyan,
                  icon: Icons.assignment_outlined,
                  iconBg: AppColors.cyan,
                ),
                MetricCard(
                  title: 'Pending Payment',
                  value: '${data.pendingPayments}',
                  subtitle: 'Order belum lunas',
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x33F59E0B), Color(0x1AB45309)],
                  ),
                  icon: Icons.hourglass_bottom_outlined,
                  iconBg: AppColors.warning,
                ),
                MetricCard(
                  title: 'Total Spend',
                  value: Formatters.rupiah(data.totalSpend),
                  subtitle: 'Akumulasi order paid',
                  gradient: AppColors.cardGradientGreen,
                  icon: Icons.payments_outlined,
                  iconBg: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 10),
            CustomerOrdersCard(
              orders: data.latestOrders,
              onViewAll: () => setState(() => _customerIndex = 2),
            ),
            const SizedBox(height: 10),
            const _DashboardContentFooter(),
          ],
        );
      },
    );
  }
}

class _AutoLoopMetricStrip extends StatefulWidget {
  const _AutoLoopMetricStrip({
    required this.items,
    this.height = 134,
  });

  final List<Widget> items;
  final double height;

  @override
  State<_AutoLoopMetricStrip> createState() => _AutoLoopMetricStripState();
}

class _AutoLoopMetricStripState extends State<_AutoLoopMetricStrip> {
  static const _autoTick = Duration(seconds: 3);
  static const _animDuration = Duration(milliseconds: 420);

  late final PageController _controller;
  Timer? _timer;
  int _page = 10000;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: _page,
      viewportFraction: 1.0,
    );
    _startAuto();
  }

  @override
  void didUpdateWidget(covariant _AutoLoopMetricStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      _startAuto();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAuto() {
    _timer?.cancel();
    if (widget.items.length <= 1) return;
    _timer = Timer.periodic(_autoTick, (_) {
      if (!_controller.hasClients) return;
      final nextPage = _page + 1;
      _controller.animateToPage(
        nextPage,
        duration: _animDuration,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: widget.height,
      child: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.idle) {
            _startAuto();
          } else {
            _timer?.cancel();
          }
          return false;
        },
        child: PageView.builder(
          controller: _controller,
          padEnds: false,
          onPageChanged: (page) => _page = page,
          itemBuilder: (context, index) {
            final item = widget.items[index % widget.items.length];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Align(alignment: Alignment.center, child: item),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardContentFooter extends StatelessWidget {
  const _DashboardContentFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 18),
      child: Text(
        'Solvix Studio \u00a9 2026',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textMutedFor(context),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DashboardBackgroundGlow extends StatelessWidget {
  const _DashboardBackgroundGlow({required this.isLight});

  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _DashboardGlowPainter(isLight: isLight),
      ),
    );
  }
}

class _DashboardGlowPainter extends CustomPainter {
  const _DashboardGlowPainter({required this.isLight});

  final bool isLight;

  @override
  void paint(Canvas canvas, Size size) {
    final first = isLight ? const Color(0x335B8CFF) : const Color(0x665B8CFF);
    final second = isLight ? const Color(0x22A855F7) : const Color(0x55A855F7);
    final third = isLight ? const Color(0x1522D3EE) : const Color(0x3322D3EE);

    final paintOne = Paint()
      ..shader = RadialGradient(
        colors: [first, const Color(0x005B8CFF)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.2, size.height * 0.2),
          radius: size.width * 0.75,
        ),
      );
    canvas.drawRect(Offset.zero & size, paintOne);

    final paintTwo = Paint()
      ..shader = RadialGradient(
        colors: [second, const Color(0x00A855F7)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.86, size.height * 0.34),
          radius: size.width * 0.62,
        ),
      );
    canvas.drawRect(Offset.zero & size, paintTwo);

    final paintThree = Paint()
      ..shader = RadialGradient(
        colors: [third, const Color(0x0022D3EE)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.56, size.height * 0.92),
          radius: size.width * 0.7,
        ),
      );
    canvas.drawRect(Offset.zero & size, paintThree);
  }

  @override
  bool shouldRepaint(covariant _DashboardGlowPainter oldDelegate) =>
      oldDelegate.isLight != isLight;
}

class _DashboardDrawer extends StatelessWidget {
  const _DashboardDrawer({
    required this.items,
    required this.language,
    required this.selectedIndex,
    this.badgeCountsByKey = const <String, int>{},
    required this.onSelect,
    required this.onLogout,
  });

  final List<String> items;
  final AppLanguage language;
  final int selectedIndex;
  final Map<String, int> badgeCountsByKey;
  final ValueChanged<int> onSelect;
  final Future<void> Function() onLogout;

  IconData _iconForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'dashboard':
        return Icons.dashboard_outlined;
      case 'invoice list':
        return Icons.receipt_long_outlined;
      case 'fix invoice':
        return Icons.fact_check_outlined;
      case 'invoice add income':
        return Icons.trending_up_outlined;
      case 'invoice add expense':
        return Icons.trending_down_outlined;
      case 'calendar':
        return Icons.calendar_month_outlined;
      case 'fleet list':
        return Icons.local_shipping_outlined;
      case 'fleet add new':
        return Icons.add_road_outlined;
      case 'order acceptance':
        return Icons.fact_check_outlined;
      case 'customer registrations':
        return Icons.group_add_outlined;
      case 'add user':
        return Icons.person_add_outlined;
      case 'assign role':
        return Icons.manage_accounts_outlined;
      case 'role access':
        return Icons.admin_panel_settings_outlined;
      case 'access denied':
        return Icons.lock_outline;
      case 'coming soon':
        return Icons.rocket_launch_outlined;
      case 'order':
        return Icons.inventory_2_outlined;
      case 'order history':
        return Icons.history_outlined;
      case 'notifications':
        return Icons.notifications_outlined;
      case 'settings':
        return Icons.settings_outlined;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = language == AppLanguage.en;
    final width = min(MediaQuery.sizeOf(context).width * 0.78, 320.0);
    final dividerColor = AppColors.divider(context);
    final mutedText = AppColors.textMutedFor(context);
    final baseText = AppColors.textSecondaryFor(context);
    return Drawer(
      width: width,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      backgroundColor: AppColors.surface(context),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: CvantLogo(
                height: 42,
                fit: BoxFit.contain,
              ),
            ),
            Divider(color: dividerColor, height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemBuilder: (context, index) {
                  final active = index == selectedIndex;
                  final badgeCount = badgeCountsByKey[items[index]] ?? 0;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: active ? AppColors.sidebarActiveGradient : null,
                      color: active ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: active ? AppColors.sidebarActiveShadow : null,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      visualDensity: VisualDensity.compact,
                      leading: Icon(
                        _iconForLabel(items[index]),
                        size: 20,
                        color: active ? Colors.white : mutedText,
                      ),
                      title: Text(
                        _menuLabel(items[index], language),
                        style: TextStyle(
                          fontSize: 13,
                          color: active ? Colors.white : baseText,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      trailing: badgeCount <= 0
                          ? null
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : AppColors.danger,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$badgeCount',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                      onTap: () => onSelect(index),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemCount: items.length,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showCvantConfirmPopup(
                      context: context,
                      title: isEn ? 'Logout Confirmation' : 'Konfirmasi Logout',
                      message: isEn
                          ? 'You will be signed out from the application. Continue?'
                          : 'Anda akan keluar dari aplikasi. Lanjutkan logout?',
                      type: CvantPopupType.error,
                      cancelLabel: isEn ? 'Cancel' : 'Batal',
                      confirmLabel: isEn ? 'Logout' : 'Logout',
                    );
                    if (!ok) return;
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    await onLogout();
                  },
                  style: CvantButtonStyles.outlined(
                    context,
                    color: AppColors.danger,
                    borderColor: AppColors.danger.withValues(alpha: 0.8),
                  ),
                  icon: const Icon(Icons.power_settings_new),
                  label: Text(isEn ? 'Log Out' : 'Keluar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textMutedFor(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}

class _SimplePlaceholderView extends StatelessWidget {
  const _SimplePlaceholderView({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textMutedFor(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 72),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center, style: TextStyle(color: muted)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _DashboardContentFooter(),
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    final isNonActive = lower.contains('inactive') ||
        lower.contains('non active') ||
        lower.contains('non-active');
    final isActive = lower.contains('active') && !isNonActive;
    final isCancelled = lower.contains('cancel') || lower.contains('reject');
    final isUnpaid = lower.contains('unpaid');
    final isWaiting = lower.contains('waiting') || lower.contains('pending');
    final isPaid = lower.contains('paid') && !isUnpaid;
    final isRecorded = lower.contains('recorded');
    final color = lower.contains('ready')
        ? AppColors.success
        : lower.contains('full')
            ? AppColors.warning
            : isActive
                ? AppColors.success
                : isNonActive
                    ? AppColors.neutralOutline
                    : isCancelled
                        ? AppColors.danger
                        : isUnpaid
                            ? AppColors.warning
                            : isWaiting
                                ? AppColors.warning
                                : isRecorded
                                    ? AppColors.neutralOutline
                                    : isPaid
                                        ? AppColors.success
                                        : lower.contains('accept')
                                            ? AppColors.blue
                                            : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
