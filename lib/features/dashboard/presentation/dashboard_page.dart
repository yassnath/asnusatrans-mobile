import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/cvant_button_styles.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/i18n/language_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cvant_dropdown_field.dart';
import '../../../core/widgets/page_fade_in.dart';
import '../../../core/widgets/cvant_popup.dart';
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

String _menuLabel(String key, AppLanguage language) {
  final isEn = language == AppLanguage.en;
  switch (key.toLowerCase()) {
    case 'dashboard':
      return isEn ? 'Dashboard' : 'Dashboard';
    case 'invoice list':
      return isEn ? 'Invoice List' : 'Daftar Invoice';
    case 'invoice add income':
      return isEn ? 'Invoice Add Income' : 'Tambah Invoice Pemasukan';
    case 'invoice add expense':
      return isEn ? 'Invoice Add Expense' : 'Tambah Invoice Pengeluaran';
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
  static const _adminMenus = <String>[
    'Dashboard',
    'Invoice List',
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
  int _adminIndex = 0;
  int _customerIndex = 0;
  _InvoicePrefillData? _invoicePrefill;

  @override
  void initState() {
    super.initState();
    _reload();
    _startDashboardAutoRefresh();
  }

  @override
  void dispose() {
    _dashboardAutoRefreshTimer?.cancel();
    _armadaUsageNotifier.dispose();
    _recentActivitiesNotifier.dispose();
    super.dispose();
  }

  void _reload() {
    final adminFuture = widget.repository.loadAdminDashboard();
    _adminFuture = adminFuture;
    _customerFuture = widget.repository.loadCustomerDashboard();
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.language,
      builder: (context, language, _) {
        final isCustomer = widget.session.isCustomer;
        final menuKeys = isCustomer ? _customerMenus : _adminMenus;
        final selected = isCustomer ? _customerIndex : _adminIndex;
        final isLightMode = AppColors.isLight(context);
        final bodyKey = ValueKey<String>(
          '${language.code}-${isCustomer ? 'customer-page-$_customerIndex' : 'admin-page-$_adminIndex'}',
        );
        final pageBody = isCustomer ? _buildCustomerBody() : _buildAdminBody();

        return Scaffold(
          backgroundColor: AppColors.pageBackground(context),
          drawer: _DashboardDrawer(
            items: menuKeys,
            language: language,
            selectedIndex: selected,
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
                  backgroundImage: isCustomer
                      ? const AssetImage('assets/images/icon.webp')
                      : AssetImage(
                          widget.session.role.toLowerCase() == 'owner'
                              ? 'assets/images/pp-owner.webp'
                              : 'assets/images/pp-admin.webp',
                        ),
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
          isOwner: widget.session.role.toLowerCase() == 'owner',
          onDataChanged: () => setState(_reload),
          onQuickMenuSelect: (index) {
            setState(() => _adminIndex = index);
          },
        );
      case 2:
        return _AdminCreateIncomeView(
          repository: widget.repository,
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
          onCreated: () => setState(() {
            _reload();
            _adminIndex = 1;
          }),
        );
      case 4:
        return _AdminCalendarView(repository: widget.repository);
      case 5:
        return _AdminFleetListView(
          repository: widget.repository,
          onQuickMenuSelect: (index) {
            setState(() => _adminIndex = index);
          },
        );
      case 6:
        return _AdminCreateFleetView(
          repository: widget.repository,
          onCreated: () => setState(_reload),
        );
      case 7:
        return _AdminOrderAcceptanceView(
          repository: widget.repository,
          onCreateInvoice: (prefill) {
            setState(() {
              _invoicePrefill = prefill;
              _adminIndex = 2;
            });
          },
        );
      case 8:
        return _AdminCustomerRegistrationsView(repository: widget.repository);
      case 9:
        return const _AdminAddUserView();
      case 10:
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
                  onViewAll: () => setState(() => _adminIndex = 5),
                );
              },
            ),
            const SizedBox(height: 10),
            LatestCustomersCard(
              latestCustomers: data.latestCustomers,
              biggestTransactions: data.biggestTransactions,
              onViewAll: () => setState(() => _adminIndex = 1),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<List<ActivityItem>?>(
              valueListenable: _recentActivitiesNotifier,
              builder: (context, liveItems, _) {
                return RecentActivityCard(
                  items: liveItems ?? data.recentActivities,
                  onViewAll: () => setState(() => _adminIndex = 4),
                );
              },
            ),
            const SizedBox(height: 10),
            RecentTransactionsCard(
              items: data.recentTransactions,
              onViewAll: () => setState(() => _adminIndex = 1),
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
    required this.onSelect,
    required this.onLogout,
  });

  final List<String> items;
  final AppLanguage language;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Future<void> Function() onLogout;

  IconData _iconForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'dashboard':
        return Icons.dashboard_outlined;
      case 'invoice list':
        return Icons.receipt_long_outlined;
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
              child: Image.asset(
                'assets/images/logo.webp',
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

class _AdminAddUserView extends StatefulWidget {
  const _AdminAddUserView();

  @override
  State<_AdminAddUserView> createState() => _AdminAddUserViewState();
}

class _AdminAddUserViewState extends State<_AdminAddUserView> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  String _department = 'Operation';
  String _designation = 'Staff';

  static const _departments = <String>[
    'Operation',
    'Finance',
    'Sales',
    'Management',
  ];
  static const _designations = <String>[
    'Staff',
    'Supervisor',
    'Manager',
    'Director',
  ];

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (_fullName.text.trim().isEmpty || _email.text.trim().isEmpty) {
      showCvantPopup(
        context: context,
        type: CvantPopupType.error,
        title: 'Error',
        message: 'Full Name dan Email wajib diisi.',
      );
      return;
    }
    showCvantPopup(
      context: context,
      type: CvantPopupType.success,
      title: 'Success',
      message: 'Data user berhasil disimpan.',
    );
  }

  void _reset() {
    _fullName.clear();
    _email.clear();
    _phone.clear();
    _description.clear();
    setState(() {
      _department = _departments.first;
      _designation = _designations.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile Image',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x3FFFFFFF)),
                        gradient: const LinearGradient(
                          colors: [Color(0x334B9DFF), Color(0x335A2DD8)],
                        ),
                      ),
                      child: const Icon(Icons.person_outline, size: 42),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: AppColors.blue),
                        ),
                        child: const Icon(Icons.camera_alt_outlined, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fullName,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'Enter Full Name',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  hintText: 'Enter email address',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: 'Enter phone number',
                ),
              ),
              const SizedBox(height: 8),
              CvantDropdownField<String>(
                initialValue: _department,
                decoration: const InputDecoration(labelText: 'Department *'),
                items: _departments
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _department = value);
                },
              ),
              const SizedBox(height: 8),
              CvantDropdownField<String>(
                initialValue: _designation,
                decoration: const InputDecoration(labelText: 'Designation *'),
                items: _designations
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _designation = value);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Write description...',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reset,
                      style: CvantButtonStyles.outlined(
                        context,
                        color: AppColors.danger,
                        borderColor: AppColors.danger,
                      ),
                      child: Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _DashboardContentFooter(),
      ],
    );
  }
}

class _AdminAssignRoleView extends StatefulWidget {
  const _AdminAssignRoleView();

  @override
  State<_AdminAssignRoleView> createState() => _AdminAssignRoleViewState();
}

class _AdminAssignRoleViewState extends State<_AdminAssignRoleView> {
  final _search = TextEditingController();
  int _show = 10;
  String _status = 'All';

  final _roles = <Map<String, String>>[
    {
      'username': 'Kathryn Murphy',
      'role': 'Waiter',
      'status': 'Active',
    },
    {
      'username': 'Annette Black',
      'role': 'Manager',
      'status': 'Active',
    },
    {
      'username': 'Ronald Richards',
      'role': 'Project Manager',
      'status': 'Inactive',
    },
    {
      'username': 'Darlene Robertson',
      'role': 'Game Developer',
      'status': 'Active',
    },
  ];
  static const _options = [
    'Waiter',
    'Manager',
    'Project Manager',
    'Game Developer',
    'Head',
    'Management',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final rows = _roles
        .where((row) {
          if (_status != 'All' && row['status'] != _status) {
            return false;
          }
          if (q.isEmpty) return true;
          return row.values.any((v) => v.toLowerCase().contains(q));
        })
        .take(_show)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _PanelCard(
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Show',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 86,
                    child: CvantDropdownField<int>(
                      initialValue: _show,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.zero,
                      ),
                      items: const [1, 2, 3, 4, 5, 10]
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text('$item'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _show = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _LegacySearchField(
                controller: _search,
                hint: 'Search',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              CvantDropdownField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const ['All', 'Active', 'Inactive']
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const _SimplePlaceholderView(
            title: 'Tidak ada user',
            message: 'Data user tidak ditemukan.',
          )
        else
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PanelCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'S.L ${index + 1}',
                      style: TextStyle(
                        color: AppColors.textMutedFor(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.sidebarSelection(context),
                          child: Text(
                            item['username']![0].toUpperCase(),
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['username']!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              _StatusPill(label: item['status'] ?? 'Inactive'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CvantDropdownField<String>(
                      initialValue: item['role'],
                      decoration:
                          const InputDecoration(labelText: 'Assign Role'),
                      items: _options
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option,
                              child: Text(option),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _roles[index]['role'] = value);
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _AdminRoleAccessView extends StatefulWidget {
  const _AdminRoleAccessView();

  @override
  State<_AdminRoleAccessView> createState() => _AdminRoleAccessViewState();
}

class _AdminRoleAccessViewState extends State<_AdminRoleAccessView> {
  final _search = TextEditingController();
  int _show = 10;
  String _status = 'All';

  final _rows = <Map<String, String>>[
    {
      'date': '25 Jan 2024',
      'role': 'Admin',
      'description': 'Akses penuh ke semua fitur sistem.',
      'status': 'Active',
    },
    {
      'date': '25 Jan 2024',
      'role': 'Owner',
      'description': 'Akses laporan, approval, dan monitoring.',
      'status': 'Active',
    },
    {
      'date': '10 Feb 2024',
      'role': 'Customer',
      'description': 'Akses order, payment, dan notifikasi.',
      'status': 'Inactive',
    },
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openRoleDialog({int? index}) async {
    final isEdit = index != null;
    final source = isEdit ? _rows[index] : const <String, String>{};
    final role = TextEditingController(text: source['role'] ?? '');
    final description =
        TextEditingController(text: source['description'] ?? '');
    String status = source['status'] ?? 'Active';
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Role' : 'Add New Role'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: role,
                        decoration: const InputDecoration(
                          labelText: 'Role Name',
                          hintText: 'Masukkan nama role',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: description,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Masukkan deskripsi role',
                        ),
                      ),
                      const SizedBox(height: 8),
                      CvantDropdownField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const ['Active', 'Inactive']
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => status = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  style: CvantButtonStyles.outlined(
                    context,
                    color: AppColors.isLight(context)
                        ? AppColors.textSecondaryLight
                        : const Color(0xFFE2E8F0),
                    borderColor: AppColors.neutralOutline,
                  ),
                  child: Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () {
                          final roleName = role.text.trim();
                          if (roleName.isEmpty) {
                            showCvantPopup(
                              context: this.context,
                              type: CvantPopupType.error,
                              title: 'Error',
                              message: 'Role name wajib diisi.',
                            );
                            return;
                          }

                          setDialogState(() => saving = true);
                          final payload = <String, String>{
                            'date': source['date'] ??
                                Formatters.dmy(DateTime.now()),
                            'role': roleName,
                            'description': description.text.trim().isEmpty
                                ? '-'
                                : description.text.trim(),
                            'status': status,
                          };

                          setState(() {
                            if (isEdit) {
                              _rows[index] = payload;
                            } else {
                              _rows.insert(0, payload);
                            }
                          });

                          Navigator.pop(context);
                          showCvantPopup(
                            context: this.context,
                            type: CvantPopupType.success,
                            title: 'Success',
                            message: isEdit
                                ? 'Role berhasil diperbarui.'
                                : 'Role baru berhasil ditambahkan.',
                          );
                        },
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteRole(int index) async {
    final roleName = _rows[index]['role'] ?? 'role ini';
    final ok = await showCvantConfirmPopup(
      context: context,
      type: CvantPopupType.error,
      title: 'Hapus Role',
      message: 'Yakin ingin menghapus $roleName?',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    setState(() => _rows.removeAt(index));
    if (!mounted) return;
    showCvantPopup(
      context: context,
      type: CvantPopupType.success,
      title: 'Success',
      message: 'Role berhasil dihapus.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final rows = _rows
        .where((row) {
          if (_status != 'All' && row['status'] != _status) {
            return false;
          }
          if (query.isEmpty) return true;
          return row.values.any((value) => value.toLowerCase().contains(query));
        })
        .take(_show)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _PanelCard(
          child: Column(
            children: [
              Row(
                children: [
                  Text('Show',
                      style: TextStyle(color: AppColors.textMutedFor(context))),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 86,
                    child: CvantDropdownField<int>(
                      initialValue: _show,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.zero,
                      ),
                      items: const [1, 2, 3, 5, 10]
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text('$item'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _show = value);
                      },
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _openRoleDialog(),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text('Add New Role'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _LegacySearchField(
                controller: _search,
                hint: 'Search',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              CvantDropdownField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const ['All', 'Active', 'Inactive']
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const _SimplePlaceholderView(
            title: 'Tidak ada role',
            message: 'Data role access tidak ditemukan.',
          )
        else
          ...rows.asMap().entries.map((entry) {
            final row = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PanelCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'S.L ${entry.key + 1}',
                      style: TextStyle(
                        color: AppColors.textMutedFor(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      row['role'] ?? '-',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Create Date: ${row['date'] ?? '-'}',
                      style: TextStyle(color: AppColors.textMutedFor(context)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      row['description'] ?? '-',
                      style: TextStyle(color: AppColors.textMutedFor(context)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatusPill(label: row['status'] ?? 'Inactive'),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _openRoleDialog(index: entry.key),
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          onPressed: () => _deleteRole(entry.key),
                          icon: const Icon(Icons.delete_outline),
                          color: AppColors.danger,
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ignore: unused_element
class _AdminAccessDeniedView extends StatelessWidget {
  const _AdminAccessDeniedView({required this.onGoHome});

  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Image.asset('assets/images/logo.webp', width: 96),
            const Spacer(),
            OutlinedButton(
              onPressed: onGoHome,
              child: Text('Go To Home'),
            ),
          ],
        ),
        const SizedBox(height: 40),
        const Icon(Icons.lock_outline, size: 72, color: AppColors.danger),
        const SizedBox(height: 14),
        Text(
          'Access Denied',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          "You don't have authorization to get to this page.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMutedFor(context)),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onGoHome,
          icon: const Icon(Icons.home_outlined),
          label: Text('Go Back To Home'),
        ),
      ],
    );
  }
}

class _AdminComingSoonView extends StatefulWidget {
  const _AdminComingSoonView({required this.onGoHome});

  final VoidCallback onGoHome;

  @override
  State<_AdminComingSoonView> createState() => _AdminComingSoonViewState();
}

class _AdminComingSoonViewState extends State<_AdminComingSoonView> {
  late final DateTime _deadline;
  final _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    _deadline = DateTime.now().add(const Duration(days: 99));
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = _deadline.difference(DateTime.now());
    final days = max(0, diff.inDays);
    final hours = max(0, diff.inHours % 24);
    final minutes = max(0, diff.inMinutes % 60);
    final seconds = max(0, diff.inSeconds % 60);

    Widget countdown(String label, int value) {
      final borderColor = AppColors.cardBorder(context);
      return Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft(context),
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: Center(
              child: Text(
                value.toString().padLeft(2, '0'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style:
                TextStyle(color: AppColors.textMutedFor(context), fontSize: 12),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Image.asset('assets/images/logo.webp', width: 96),
            const Spacer(),
            OutlinedButton(
              onPressed: widget.onGoHome,
              child: Text('Go To Home'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Our site is creating. Keep persistence, we are not far off',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Do you want to get updates? Please subscribe now',
          style: TextStyle(color: AppColors.textMutedFor(context)),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            countdown('days', days),
            countdown('hours', hours),
            countdown('minutes', minutes),
            countdown('seconds', seconds),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          decoration: const InputDecoration(hintText: 'wowdash@gmail.com'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () {
            final email = _email.text.trim();
            if (email.isEmpty || !email.contains('@')) {
              showCvantPopup(
                context: context,
                type: CvantPopupType.error,
                title: 'Error',
                message: 'Masukkan email valid untuk menerima update.',
              );
              return;
            }
            _email.clear();
            showCvantPopup(
              context: context,
              type: CvantPopupType.success,
              title: 'Success',
              message: 'Terima kasih. Kami akan kirim update ke email kamu.',
            );
          },
          icon: const Icon(Icons.notifications_active_outlined),
          label: Text('Knock Us'),
        ),
      ],
    );
  }
}

class _LegacySearchField extends StatelessWidget {
  const _LegacySearchField({
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
      ),
    );
  }
}

class _AdminCalendarView extends StatefulWidget {
  const _AdminCalendarView({required this.repository});

  final DashboardRepository repository;

  @override
  State<_AdminCalendarView> createState() => _AdminCalendarViewState();
}

class _AdminCalendarViewState extends State<_AdminCalendarView> {
  late Future<List<dynamic>> _future;
  DateTime _visibleMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  String _t(String id, String en) => _isEn ? en : id;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() {
    return Future.wait([
      widget.repository.fetchInvoices(),
      widget.repository.fetchExpenses(),
      widget.repository.fetchArmadas(),
    ]);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  List<_CalendarEvent> _buildEvents(
    List<Map<String, dynamic>> invoices,
    List<Map<String, dynamic>> expenses,
    List<Map<String, dynamic>> armadas,
  ) {
    final events = <_CalendarEvent>[];
    final armadaById = <String, Map<String, dynamic>>{
      for (final armada in armadas)
        '${armada['id'] ?? ''}': Map<String, dynamic>.from(armada),
    };
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    List<Map<String, dynamic>> detailRows(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return const <Map<String, dynamic>>[];
    }

    String resolveArmadaLabel(
        Map<String, dynamic> invoice, Map<String, dynamic>? row) {
      final rowArmadaId = '${row?['armada_id'] ?? ''}'.trim();
      final invoiceArmadaId = '${invoice['armada_id'] ?? ''}'.trim();
      final armada =
          armadaById[rowArmadaId.isNotEmpty ? rowArmadaId : invoiceArmadaId];
      if (armada != null) {
        return '${armada['nama_truk'] ?? 'Armada'} - ${armada['plat_nomor'] ?? '-'}';
      }

      final manual = '${row?['armada_manual'] ?? ''}'.trim();
      if (manual.isNotEmpty) return manual;
      final fallback = '${row?['armada_label'] ?? row?['armada'] ?? ''}'.trim();
      if (fallback.isNotEmpty) return fallback;
      return _t('Lainnya', 'Other');
    }

    for (final invoice in invoices) {
      final invoiceId = '${invoice['id'] ?? ''}';
      final invoiceDate =
          Formatters.parseDate(invoice['tanggal'] ?? invoice['created_at']);
      events.add(
        _CalendarEvent(
          id: invoiceId,
          type: 'income',
          title: Formatters.invoiceNumber(
            invoice['no_invoice'],
            invoice['tanggal_kop'] ?? invoice['tanggal'],
            customerName: invoice['nama_pelanggan'],
          ),
          subtitle: '${invoice['nama_pelanggan'] ?? '-'}',
          status: '${invoice['status'] ?? 'Waiting'}',
          total: _toNum(invoice['total_bayar'] ?? invoice['total_biaya']),
          date: invoiceDate,
          dotColor: AppColors.blue,
        ),
      );

      final details = detailRows(invoice['rincian']);
      final scheduleRows =
          details.isNotEmpty ? details : <Map<String, dynamic>>[invoice];

      for (var i = 0; i < scheduleRows.length; i++) {
        final row = scheduleRows[i];
        final startDate = Formatters.parseDate(
          row['armada_start_date'] ?? invoice['armada_start_date'],
        );
        final endDate = Formatters.parseDate(
          row['armada_end_date'] ?? invoice['armada_end_date'],
        );
        if (startDate == null || endDate == null) {
          continue;
        }

        final normalizedStart =
            DateTime(startDate.year, startDate.month, startDate.day);
        final normalizedEnd =
            DateTime(endDate.year, endDate.month, endDate.day);
        final statusColor = todayOnly.isAfter(normalizedEnd)
            ? AppColors.success
            : (todayOnly.isBefore(normalizedStart)
                ? AppColors.blue
                : AppColors.warning);
        final armadaLabel = resolveArmadaLabel(invoice, row);

        for (var day = normalizedStart;
            !day.isAfter(normalizedEnd);
            day = day.add(const Duration(days: 1))) {
          events.add(
            _CalendarEvent(
              id: '$invoiceId-$i-${_dateKey(day)}',
              type: 'armada',
              title: armadaLabel,
              subtitle:
                  '${Formatters.dmy(normalizedStart)} -> ${Formatters.dmy(normalizedEnd)}',
              status: _t('Jadwal Armada', 'Fleet Schedule'),
              total: 0,
              date: day,
              startDate: normalizedStart,
              endDate: normalizedEnd,
              dotColor: statusColor,
            ),
          );
        }
      }
    }

    for (final expense in expenses) {
      final expenseDate =
          Formatters.parseDate(expense['tanggal'] ?? expense['created_at']);
      events.add(
        _CalendarEvent(
          id: '${expense['id'] ?? ''}',
          type: 'expense',
          title: Formatters.invoiceNumber(
              expense['no_expense'], expense['tanggal']),
          subtitle:
              '${expense['keterangan'] ?? expense['note'] ?? _t('Expense', 'Expense')}',
          status: '${expense['status'] ?? 'Recorded'}',
          total: _toNum(expense['total_pengeluaran']),
          date: expenseDate,
          dotColor: AppColors.danger,
        ),
      );
    }

    events.sort((a, b) {
      final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return events;
  }

  Map<String, List<_CalendarEvent>> _eventsByDate(
    List<_CalendarEvent> source,
    DateTime month,
  ) {
    final result = <String, List<_CalendarEvent>>{};
    for (final event in source) {
      final date = event.date;
      if (date == null) continue;
      if (date.year != month.year || date.month != month.month) continue;
      final key = _dateKey(date);
      result.putIfAbsent(key, () => <_CalendarEvent>[]).add(event);
    }

    for (final entry in result.entries) {
      entry.value.sort((a, b) {
        int rank(String type) {
          switch (type) {
            case 'armada':
              return 0;
            case 'income':
              return 1;
            case 'expense':
              return 2;
            default:
              return 9;
          }
        }

        final diff = rank(a.type) - rank(b.type);
        if (diff != 0) return diff;
        return a.title.compareTo(b.title);
      });
    }

    return result;
  }

  String _dateKey(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  String _weekdayLabel(DateTime date) {
    final names = _isEn
        ? const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
        : const ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    return names[date.weekday % 7];
  }

  int _daysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  String _monthYearLabel(DateTime month) {
    final names = _isEn
        ? const <String>[
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ]
        : const <String>[
            'Januari',
            'Februari',
            'Maret',
            'April',
            'Mei',
            'Juni',
            'Juli',
            'Agustus',
            'September',
            'Oktober',
            'November',
            'Desember',
          ];
    return '${names[month.month - 1]} ${month.year}';
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visibleMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: _t('Pilih Bulan', 'Pick Month'),
    );
    if (picked == null) return;
    setState(() {
      _visibleMonth = DateTime(picked.year, picked.month, 1);
    });
  }

  void _goPrevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    });
  }

  void _goNextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    });
  }

  Color _eventColor(_CalendarEvent event) {
    if (event.type == 'income') return AppColors.blue;
    if (event.type == 'expense') return AppColors.danger;
    return event.dotColor;
  }

  Future<void> _openEvent(_CalendarEvent event) async {
    final typeLabel = event.type == 'income'
        ? _t('Income', 'Income')
        : (event.type == 'expense'
            ? _t('Expense', 'Expense')
            : _t('Armada', 'Fleet'));
    final dateLabel = event.date == null ? '-' : Formatters.dmy(event.date);
    final rangeLabel = event.startDate != null && event.endDate != null
        ? '\n${_t('Rentang', 'Range')}: ${Formatters.dmy(event.startDate)} -> ${Formatters.dmy(event.endDate)}'
        : '';
    final totalLabel = event.type == 'armada'
        ? ''
        : '\n${_t('Total', 'Total')}: ${Formatters.rupiah(event.total)}';
    await showCvantPopup(
      context: context,
      type: CvantPopupType.info,
      title: '$typeLabel ${_t('Detail', 'Detail')}',
      message:
          '${event.title}\n${event.subtitle}\n${_t('Status', 'Status')}: ${event.status}\n${_t('Tanggal', 'Date')}: $dateLabel$totalLabel$rangeLabel',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _ErrorView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() {
              _future = _load();
            }),
          );
        }

        final invoices =
            (snapshot.data![0] as List).cast<Map<String, dynamic>>();
        final expenses =
            (snapshot.data![1] as List).cast<Map<String, dynamic>>();
        final armadas =
            (snapshot.data![2] as List).cast<Map<String, dynamic>>();
        final events = _buildEvents(invoices, expenses, armadas);
        final eventsByDate = _eventsByDate(events, _visibleMonth);
        final totalDays = _daysInMonth(_visibleMonth);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            children: [
              _PanelCard(
                child: Row(
                  children: [
                    SizedBox(
                      width: 38,
                      height: 34,
                      child: OutlinedButton(
                        onPressed: _goPrevMonth,
                        style: CvantButtonStyles.outlined(
                          context,
                          color: AppColors.textSecondaryFor(context),
                          borderColor: AppColors.cardBorder(context),
                        ).copyWith(
                          minimumSize:
                              const WidgetStatePropertyAll(Size(38, 34)),
                          maximumSize:
                              const WidgetStatePropertyAll(Size(38, 34)),
                          padding:
                              const WidgetStatePropertyAll(EdgeInsets.zero),
                          alignment: Alignment.center,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Center(
                          child: Icon(Icons.chevron_left, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton(
                        onPressed: _pickMonth,
                        child: Text(
                          _monthYearLabel(_visibleMonth),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 38,
                      height: 34,
                      child: OutlinedButton(
                        onPressed: _goNextMonth,
                        style: CvantButtonStyles.outlined(
                          context,
                          color: AppColors.textSecondaryFor(context),
                          borderColor: AppColors.cardBorder(context),
                        ).copyWith(
                          minimumSize:
                              const WidgetStatePropertyAll(Size(38, 34)),
                          maximumSize:
                              const WidgetStatePropertyAll(Size(38, 34)),
                          padding:
                              const WidgetStatePropertyAll(EdgeInsets.zero),
                          alignment: Alignment.center,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Center(
                          child: Icon(Icons.chevron_right, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ...List.generate(totalDays, (index) {
                final dayDate = DateTime(
                    _visibleMonth.year, _visibleMonth.month, index + 1);
                final key = _dateKey(dayDate);
                final items = eventsByDate[key] ?? const <_CalendarEvent>[];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PanelCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _weekdayLabel(dayDate),
                                style: TextStyle(
                                  color: AppColors.textMutedFor(context),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              Formatters.dmy(dayDate),
                              style: TextStyle(
                                color: AppColors.textMutedFor(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (items.isEmpty)
                          Text(
                            _t('Tidak ada data', 'No data'),
                            style: TextStyle(
                              color: AppColors.textMutedFor(context),
                              fontSize: 12,
                            ),
                          )
                        else
                          ...items.map((event) {
                            final color = _eventColor(event);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                onTap: () => _openEvent(event),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 9,
                                            height: 9,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              event.title,
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          if (event.type != 'armada')
                                            Text(
                                              Formatters.rupiah(event.total),
                                              style: TextStyle(
                                                color: AppColors.textMutedFor(
                                                    context),
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        event.subtitle,
                                        style: TextStyle(
                                          color:
                                              AppColors.textMutedFor(context),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
              const _DashboardContentFooter(),
            ],
          ),
        );
      },
    );
  }
}

class _CustomerNotificationsView extends StatefulWidget {
  const _CustomerNotificationsView({required this.repository});

  final DashboardRepository repository;

  @override
  State<_CustomerNotificationsView> createState() =>
      _CustomerNotificationsViewState();
}

class _CustomerNotificationsViewState
    extends State<_CustomerNotificationsView> {
  static const _readStorageKey = 'cvant_customer_notification_read_ids';
  late Future<List<dynamic>> _future;
  Set<String> _readIds = <String>{};
  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  String _t(String id, String en) => _isEn ? en : id;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadReadIds();
  }

  Future<List<dynamic>> _load() {
    return Future.wait<dynamic>([
      widget.repository.fetchOrders(currentUserOnly: true),
      widget.repository.fetchCustomerNotifications(currentUserOnly: true),
    ]);
  }

  Future<void> _loadReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_readStorageKey) ?? const <String>[];
    if (!mounted) return;
    setState(() => _readIds = values.toSet());
  }

  Future<void> _markRead(String id) async {
    if (id.isEmpty || _readIds.contains(id)) return;
    final next = {..._readIds, id};
    setState(() => _readIds = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readStorageKey, next.toList());
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  List<_NotificationItem> _buildNotifications({
    required List<Map<String, dynamic>> orderRows,
    required List<Map<String, dynamic>> directRows,
  }) {
    final items = orderRows.map((row) {
      final status = (row['status'] ?? 'Pending').toString();
      final statusLower = status.toLowerCase();
      final code = (row['order_code'] ?? '-').toString();
      final pickup = (row['pickup'] ?? '-').toString();
      final destination = (row['destination'] ?? '-').toString();

      String title = _t(
        'Order menunggu konfirmasi',
        'Order is waiting for confirmation',
      );
      String message = _t(
        'Order $code untuk rute $pickup -> $destination sedang diproses.',
        'Order $code for route $pickup -> $destination is being processed.',
      );
      IconData icon = Icons.hourglass_bottom_outlined;
      Color color = AppColors.warning;

      if (statusLower.contains('paid')) {
        title = _t('Pembayaran dikonfirmasi', 'Payment confirmed');
        message = _t('Order $code sudah dibayar. Terima kasih.',
            'Order $code has been paid. Thank you.');
        icon = Icons.check_circle_outline;
        color = AppColors.success;
      } else if (statusLower.contains('accept')) {
        title = _t('Order diterima', 'Order accepted');
        message = _t(
          'Order $code diterima admin. Jadwal pengiriman akan diproses.',
          'Order $code was accepted by admin. Delivery schedule will be processed.',
        );
        icon = Icons.task_alt_outlined;
        color = AppColors.blue;
      } else if (statusLower.contains('reject')) {
        title = _t('Order ditolak', 'Order rejected');
        message = _t(
          'Order $code ditolak. Silakan cek detail dan ajukan ulang.',
          'Order $code was rejected. Please review details and submit again.',
        );
        icon = Icons.cancel_outlined;
        color = AppColors.danger;
      }

      return _NotificationItem(
        id: 'order-${row['id'] ?? ''}',
        title: title,
        message: message,
        status: status,
        createdAt: Formatters.parseDate(row['updated_at'] ?? row['created_at']),
        icon: icon,
        color: color,
      );
    }).toList();

    for (final row in directRows) {
      final kind = (row['kind'] ?? 'info').toString().toLowerCase();
      final rawStatus = (row['status'] ?? 'Info').toString();
      IconData icon = Icons.notifications_active_outlined;
      Color color = AppColors.blue;

      if (kind.contains('invoice')) {
        icon = Icons.receipt_long_outlined;
        color = AppColors.blue;
      } else if (kind.contains('success')) {
        icon = Icons.check_circle_outline;
        color = AppColors.success;
      } else if (kind.contains('warning')) {
        icon = Icons.warning_amber;
        color = AppColors.warning;
      } else if (kind.contains('error')) {
        icon = Icons.error_outline;
        color = AppColors.danger;
      }

      items.add(
        _NotificationItem(
          id: 'direct-${row['id'] ?? row['source_id'] ?? ''}',
          title: (row['title'] ?? _t('Notifikasi', 'Notification')).toString(),
          message: (row['message'] ?? '-').toString(),
          status: rawStatus.isEmpty ? _t('Info', 'Info') : rawStatus,
          createdAt: Formatters.parseDate(row['created_at']),
          icon: icon,
          color: color,
        ),
      );
    }

    items.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError) {
          return _ErrorView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() {
              _future = _load();
            }),
          );
        }

        final orderRows = snapshot.data == null
            ? <Map<String, dynamic>>[]
            : (snapshot.data![0] as List).cast<Map<String, dynamic>>();
        final directRows = snapshot.data == null
            ? <Map<String, dynamic>>[]
            : (snapshot.data![1] as List).cast<Map<String, dynamic>>();
        if (orderRows.isEmpty && directRows.isEmpty) {
          return _SimplePlaceholderView(
            title: _t('Belum ada notifikasi', 'No notifications yet'),
            message: _t(
              'Notifikasi akan muncul setelah order diproses atau invoice dikirim.',
              'Notifications will appear after orders are processed or invoices are sent.',
            ),
          );
        }

        final items = _buildNotifications(
          orderRows: orderRows,
          directRows: directRows,
        );
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == items.length) {
                return const _DashboardContentFooter();
              }
              final item = items[index];
              final isRead = _readIds.contains(item.id);
              return _PanelCard(
                child: Opacity(
                  opacity: isRead ? 0.75 : 1,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(item.icon, size: 20, color: item.color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.message,
                              style: TextStyle(
                                  color: AppColors.textMutedFor(context)),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _StatusPill(label: item.status),
                                const Spacer(),
                                Text(
                                  item.createdAt == null
                                      ? '-'
                                      : Formatters.dmy(item.createdAt),
                                  style: TextStyle(
                                    color: AppColors.textMutedFor(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                    isRead ? null : () => _markRead(item.id),
                                child: Text(
                                  isRead
                                      ? _t('Sudah dibaca', 'Read')
                                      : _t('Tandai dibaca', 'Mark as read'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CalendarEvent {
  const _CalendarEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.total,
    required this.date,
    this.startDate,
    this.endDate,
    this.dotColor = AppColors.blue,
  });

  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String status;
  final double total;
  final DateTime? date;
  final DateTime? startDate;
  final DateTime? endDate;
  final Color dotColor;
}

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String message;
  final String status;
  final DateTime? createdAt;
  final IconData icon;
  final Color color;
}

class _AdminCreateIncomeView extends StatefulWidget {
  const _AdminCreateIncomeView({
    required this.repository,
    required this.onCreated,
    this.prefill,
    this.onPrefillConsumed,
  });

  final DashboardRepository repository;
  final VoidCallback onCreated;
  final _InvoicePrefillData? prefill;
  final VoidCallback? onPrefillConsumed;

  @override
  State<_AdminCreateIncomeView> createState() => _AdminCreateIncomeViewState();
}

class _AdminCreateIncomeViewState extends State<_AdminCreateIncomeView> {
  static const _customerManualOptionId = '__other__';
  static const _manualArmadaOptionId = '__other_manual_armada__';
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
  final _customer = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _kopDate = TextEditingController();
  final _kopLocation = TextEditingController();
  final _dueDate = TextEditingController();
  DateTime _date = DateTime.now();
  bool _isCompanyInvoice = true;
  String _status = 'Unpaid';
  String _acceptedBy = 'Admin';
  bool _loading = false;
  bool _invoiceNoLoading = false;
  String _invoiceNoPreview = '-';
  int _invoiceNoRequestToken = 0;
  late Future<List<dynamic>> _formFuture;
  final List<Map<String, dynamic>> _details = [];
  bool _prefillApplied = false;
  bool _prefillArmadaResolved = false;
  String _prefillArmadaName = '';
  String _selectedCustomerOptionId = _customerManualOptionId;
  int _detailFieldRefreshToken = 0;
  String? _linkedCustomerId;
  String? _linkedOrderId;
  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  String _t(String id, String en) => _isEn ? en : id;

  @override
  void initState() {
    super.initState();
    _formFuture = _loadFormData();
    _details.add(_newDetail());
    _kopDate.text = _toInputDate(_date);
    _applyPrefill(widget.prefill);
    _refreshInvoiceNumberPreview();
  }

  @override
  void didUpdateWidget(covariant _AdminCreateIncomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prefill != widget.prefill) {
      _applyPrefill(widget.prefill);
    }
  }

  @override
  void dispose() {
    _customer.dispose();
    _email.dispose();
    _phone.dispose();
    _kopDate.dispose();
    _kopLocation.dispose();
    _dueDate.dispose();
    super.dispose();
  }

  void _applyPrefill(_InvoicePrefillData? prefill) {
    if (prefill == null || _prefillApplied) return;

    final customerName = (prefill.customerName ?? '').trim();
    final customerEmail = (prefill.customerEmail ?? '').trim();
    final customerPhone = (prefill.customerPhone ?? '').trim();
    final pickup = (prefill.pickup ?? '').trim();
    final destination = (prefill.destination ?? '').trim();
    final armadaName = (prefill.armadaName ?? '').trim();

    if (customerName.isNotEmpty && _customer.text.trim().isEmpty) {
      _customer.text = customerName;
    }
    if (customerEmail.isNotEmpty && _email.text.trim().isEmpty) {
      _email.text = customerEmail;
    }
    if (customerPhone.isNotEmpty && _phone.text.trim().isEmpty) {
      _phone.text = customerPhone;
    }

    if (_details.isNotEmpty) {
      final first = _details.first;
      if (pickup.isNotEmpty && '${first['lokasi_muat']}'.trim().isEmpty) {
        first['lokasi_muat'] = pickup;
      }
      if (destination.isNotEmpty &&
          '${first['lokasi_bongkar']}'.trim().isEmpty) {
        first['lokasi_bongkar'] = destination;
      }
      if (prefill.pickupDate != null &&
          '${first['armada_start_date']}'.trim().isEmpty) {
        first['armada_start_date'] = _toInputDate(prefill.pickupDate!);
      }
    }

    _linkedCustomerId = prefill.customerId?.trim();
    _linkedOrderId = prefill.orderId?.trim();
    _prefillArmadaName = armadaName;
    _prefillApplied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onPrefillConsumed?.call();
    });
  }

  Future<List<dynamic>> _loadFormData() {
    return Future.wait<dynamic>([
      widget.repository.fetchArmadas(),
      widget.repository.fetchInvoiceCustomerOptions(),
    ]);
  }

  void _applySavedCustomerOption(
    String? optionId,
    List<Map<String, dynamic>> options,
  ) {
    if (optionId == null) return;
    if (optionId == _customerManualOptionId) {
      setState(() {
        _selectedCustomerOptionId = _customerManualOptionId;
        _linkedCustomerId = null;
        _linkedOrderId = null;
      });
      return;
    }

    final selected = options.cast<Map<String, dynamic>?>().firstWhere(
          (option) => '${option?['id'] ?? ''}' == optionId,
          orElse: () => null,
        );
    if (selected == null) return;

    Map<String, dynamic> toDetailRow(Map<String, dynamic> option) {
      return {
        'lokasi_muat': _safeInputText(option['lokasi_muat']),
        'lokasi_bongkar': _safeInputText(option['lokasi_bongkar']),
        'muatan': _safeInputText(option['muatan']),
        'nama_supir': _safeInputText(option['nama_supir']),
        'armada_id': _safeInputText(option['armada_id']),
        'armada_manual': _safeInputText(option['armada_manual']),
        'armada_is_manual':
            _safeInputText(option['armada_manual']).isNotEmpty &&
                _safeInputText(option['armada_id']).isEmpty,
        'armada_start_date': _safeInputText(option['armada_start_date']),
        'armada_end_date': _safeInputText(option['armada_end_date']),
        'tonase': _safeNumberInputText(option['tonase']),
        'harga': _safeNumberInputText(option['harga']),
      };
    }

    final selectedDetails = (selected['details'] is List)
        ? (selected['details'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : const <Map<String, dynamic>>[];
    final sourceOptions = selectedDetails.isNotEmpty
        ? selectedDetails
        : <Map<String, dynamic>>[selected];

    setState(() {
      _selectedCustomerOptionId = optionId;
      _linkedCustomerId = '${selected['customer_id'] ?? ''}'.trim().isEmpty
          ? null
          : '${selected['customer_id']}'.trim();
      _linkedOrderId = null;
      _customer.text = '${selected['customer_name'] ?? ''}'.trim();
      _email.text = '${selected['email'] ?? ''}'.trim();
      _phone.text = '${selected['phone'] ?? ''}'.trim();
      final selectedKopDate = '${selected['tanggal_kop'] ?? ''}'.trim();
      final selectedKopLocation = '${selected['lokasi_kop'] ?? ''}'.trim();
      if (selectedKopDate.isNotEmpty) {
        _kopDate.text = selectedKopDate;
      }
      if (selectedKopLocation.isNotEmpty) {
        _kopLocation.text = selectedKopLocation;
      }

      _details
        ..clear()
        ..addAll(sourceOptions.map(toDetailRow));
      if (_details.isEmpty) {
        _details.add(_newDetail());
      }
      _detailFieldRefreshToken++;
    });
    _refreshInvoiceNumberPreview();
  }

  String _safeInputText(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.toLowerCase() == 'null') return '';
    return raw;
  }

  String _safeNumberInputText(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      final number = value.toDouble();
      if (number == number.truncateToDouble()) {
        return number.toInt().toString();
      }
      return number.toString();
    }
    final raw = value.toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';
    return raw;
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

  List<Map<String, dynamic>> _filterCustomerOptionsByMode(
    List<Map<String, dynamic>> options, {
    bool? isCompanyOverride,
  }) {
    final isCompanyTarget = isCompanyOverride ?? _isCompanyInvoice;
    return options.where((option) {
      final name = '${option['customer_name'] ?? option['label'] ?? ''}';
      final isCompanyName = _isCompanyCustomerName(name);
      return isCompanyTarget ? isCompanyName : !isCompanyName;
    }).toList();
  }

  Future<void> _refreshInvoiceNumberPreview() async {
    final requestToken = ++_invoiceNoRequestToken;
    if (mounted) {
      setState(() => _invoiceNoLoading = true);
    }
    try {
      final effectiveDate = Formatters.parseDate(_kopDate.text) ?? _date;
      final generated = await widget.repository.generateIncomeInvoiceNumber(
        issuedDate: effectiveDate,
        isCompany: _isCompanyInvoice,
      );
      if (!mounted || requestToken != _invoiceNoRequestToken) return;
      setState(() {
        _invoiceNoPreview = generated;
        _invoiceNoLoading = false;
      });
    } catch (_) {
      if (!mounted || requestToken != _invoiceNoRequestToken) return;
      setState(() {
        _invoiceNoPreview = '-';
        _invoiceNoLoading = false;
      });
    }
  }

  void _switchInvoiceMode(
    bool isCompany,
    List<Map<String, dynamic>> customerOptions,
  ) {
    if (_isCompanyInvoice == isCompany) return;
    final filtered = _filterCustomerOptionsByMode(
      customerOptions,
      isCompanyOverride: isCompany,
    );
    setState(() {
      _isCompanyInvoice = isCompany;
      final isCurrentValid = filtered.any(
        (item) => '${item['id']}' == _selectedCustomerOptionId,
      );
      if (!isCurrentValid) {
        _selectedCustomerOptionId = _customerManualOptionId;
        _linkedCustomerId = null;
        _linkedOrderId = null;
        _customer.clear();
        _email.clear();
        _phone.clear();
        _detailFieldRefreshToken++;
      }
    });
    _refreshInvoiceNumberPreview();
  }

  String _normalizeText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _tryResolvePrefillArmada(List<Map<String, dynamic>> armadas) {
    if (_prefillArmadaResolved || _prefillArmadaName.trim().isEmpty) return;
    if (_details.isEmpty) return;
    if ('${_details.first['armada_id']}'.trim().isNotEmpty) {
      _prefillArmadaResolved = true;
      return;
    }

    final target = _normalizeText(_prefillArmadaName);
    if (target.isEmpty) return;
    Map<String, dynamic>? matched;
    for (final item in armadas) {
      final name = _normalizeText('${item['nama_truk'] ?? ''}');
      if (name.isEmpty) continue;
      if (name == target || name.contains(target) || target.contains(name)) {
        matched = item;
        break;
      }
    }

    _prefillArmadaResolved = true;
    if (matched == null) return;
    _details.first['armada_id'] = '${matched['id']}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (picked != null) {
      final previousDateText = _toInputDate(_date);
      setState(() {
        _date = picked;
        final currentKop = _kopDate.text.trim();
        if (currentKop.isEmpty || currentKop == previousDateText) {
          _kopDate.text = _toInputDate(picked);
        }
      });
      _refreshInvoiceNumberPreview();
    }
  }

  Future<void> _pickDetailDate(int index, String field) async {
    final initial =
        Formatters.parseDate(_details[index][field]) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (picked == null) return;
    setState(() => _details[index][field] = _toInputDate(picked));
  }

  Future<void> _pickDueDate() async {
    final initial = Formatters.parseDate(_dueDate.text) ??
        _date.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (picked == null) return;
    setState(() => _dueDate.text = _toInputDate(picked));
  }

  Future<void> _pickKopDate() async {
    final initial = Formatters.parseDate(_kopDate.text) ?? _date;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (picked == null) return;
    setState(() => _kopDate.text = _toInputDate(picked));
    _refreshInvoiceNumberPreview();
  }

  Map<String, dynamic> _newDetail() {
    return {
      'lokasi_muat': '',
      'lokasi_bongkar': '',
      'muatan': '',
      'nama_supir': '',
      'armada_id': '',
      'armada_manual': '',
      'armada_is_manual': false,
      'armada_start_date': '',
      'armada_end_date': '',
      'tonase': '',
      'harga': '',
    };
  }

  double _detailSubtotal(Map<String, dynamic> row) {
    return _toNum(row['tonase']) * _toNum(row['harga']);
  }

  String? _nullableInputText(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final lowered = raw.toLowerCase();
    if (lowered == 'null' || lowered == 'undefined' || lowered == '-') {
      return null;
    }
    return raw;
  }

  Color _armadaStatusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('full')) return AppColors.warning;
    if (lower.contains('ready')) return AppColors.success;
    if (lower.contains('inactive') ||
        lower.contains('non active') ||
        lower.contains('non-active')) {
      return AppColors.neutralOutline;
    }
    return AppColors.textMutedFor(context);
  }

  String _normalizePlateText(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _extractPlateFromText(String value) {
    final match = RegExp(
      r'[A-Z]{1,2}\s?[0-9]{1,4}\s?[A-Z]{1,3}',
    ).firstMatch(value.toUpperCase());
    if (match == null) return null;
    final plate = _normalizePlateText(match.group(0) ?? '');
    return plate.isEmpty ? null : plate;
  }

  Map<String, String> _buildArmadaIdByPlate(
    List<Map<String, dynamic>> armadas,
  ) {
    final map = <String, String>{};
    for (final armada in armadas) {
      final id = '${armada['id'] ?? ''}'.trim();
      final plate = _normalizePlateText('${armada['plat_nomor'] ?? ''}');
      if (id.isEmpty || plate.isEmpty) continue;
      map[plate] = id;
    }
    return map;
  }

  String _resolveArmadaIdFromInput({
    required String armadaId,
    required String armadaManual,
    required Map<String, String> armadaIdByPlate,
  }) {
    final direct = armadaId.trim();
    if (direct.isNotEmpty) return direct;
    final manual = armadaManual.trim();
    if (manual.isEmpty) return '';
    final extracted = _extractPlateFromText(manual);
    final normalized = _normalizePlateText(manual);
    return armadaIdByPlate[extracted ?? normalized] ?? '';
  }

  void _normalizeManualRowsToArmadaId(List<Map<String, dynamic>> armadas) {
    if (_details.isEmpty) return;
    final armadaIdByPlate = _buildArmadaIdByPlate(armadas);
    if (armadaIdByPlate.isEmpty) return;
    var changed = false;
    for (final row in _details) {
      final currentArmadaId = '${row['armada_id'] ?? ''}'.trim();
      final currentManual = '${row['armada_manual'] ?? ''}'.trim();
      if (currentArmadaId.isNotEmpty || currentManual.isEmpty) continue;
      final resolvedArmadaId = _resolveArmadaIdFromInput(
        armadaId: currentArmadaId,
        armadaManual: currentManual,
        armadaIdByPlate: armadaIdByPlate,
      );
      if (resolvedArmadaId.isEmpty) continue;
      row['armada_id'] = resolvedArmadaId;
      row['armada_manual'] = '';
      row['armada_is_manual'] = false;
      changed = true;
    }
    if (changed) {
      _detailFieldRefreshToken++;
    }
  }

  double get _subtotal {
    return _details.fold<double>(
      0,
      (sum, row) => sum + _detailSubtotal(row),
    );
  }

  double get _pph => _isCompanyInvoice ? _subtotal * 0.02 : 0;
  double get _totalBayar => max(0, _subtotal - _pph);

  void _addDetail() {
    setState(() => _details.add(_newDetail()));
  }

  void _removeDetail(int index) {
    if (_details.length == 1) return;
    setState(() => _details.removeAt(index));
  }

  Future<void> _save(List<Map<String, dynamic>> armadas) async {
    final customer = _customer.text.trim();
    if (customer.isEmpty || _subtotal <= 0) {
      _snack(
        _t('Nama customer dan rincian wajib diisi.',
            'Customer name and details are required.'),
        error: true,
      );
      return;
    }
    final first = _details.first;
    final firstArmadaId = '${first['armada_id']}'.trim();
    final firstArmadaManual = '${first['armada_manual'] ?? ''}'.trim();
    final armadaIdByPlate = _buildArmadaIdByPlate(armadas);
    final firstResolvedArmadaId = _resolveArmadaIdFromInput(
      armadaId: firstArmadaId,
      armadaManual: firstArmadaManual,
      armadaIdByPlate: armadaIdByPlate,
    );
    final hasArmadaSelection =
        firstResolvedArmadaId.isNotEmpty || firstArmadaManual.isNotEmpty;
    if ('${first['lokasi_muat']}'.trim().isEmpty ||
        '${first['lokasi_bongkar']}'.trim().isEmpty ||
        !hasArmadaSelection) {
      _snack(
        _t(
          'Lokasi muat, lokasi bongkar, dan armada wajib diisi.',
          'Loading location, unloading location, and fleet are required.',
        ),
        error: true,
      );
      return;
    }

    final selectedArmadaIds = _details
        .map(
          (row) => _resolveArmadaIdFromInput(
            armadaId: '${row['armada_id']}'.trim(),
            armadaManual: '${row['armada_manual'] ?? ''}'.trim(),
            armadaIdByPlate: armadaIdByPlate,
          ),
        )
        .where((id) => id.isNotEmpty)
        .toSet();
    Map<String, dynamic>? busyArmada;
    for (final armada in armadas) {
      final id = '${armada['id']}'.trim();
      if (!selectedArmadaIds.contains(id)) continue;
      final status = '${armada['status'] ?? 'Ready'}'.trim().toLowerCase();
      if (status != 'ready') {
        busyArmada = armada;
        break;
      }
    }
    if (busyArmada != null) {
      final armadaLabel =
          '${busyArmada['nama_truk'] ?? '-'} - ${busyArmada['plat_nomor'] ?? '-'}'
              .trim();
      final proceed = await showCvantConfirmPopup(
        context: context,
        type: CvantPopupType.warning,
        title: _t('Warning', 'Warning'),
        message: _t(
          'Armada $armadaLabel masih on the way. Apakah customer ingin menunggu?',
          'Fleet $armadaLabel is still on the way. Does the customer want to wait?',
        ),
        cancelLabel: _t('Tidak', 'No'),
        confirmLabel: _t('Ya', 'Yes'),
      );
      if (!proceed) return;
    }

    final detailsPayload = _details.map((row) {
      final armadaId = '${row['armada_id']}'.trim();
      final armadaManualRaw = _nullableInputText(row['armada_manual']) ?? '';
      final resolvedArmadaId = _resolveArmadaIdFromInput(
        armadaId: armadaId,
        armadaManual: armadaManualRaw,
        armadaIdByPlate: armadaIdByPlate,
      );
      final useManual = resolvedArmadaId.isEmpty && armadaManualRaw.isNotEmpty;
      return <String, dynamic>{
        'lokasi_muat': '${row['lokasi_muat']}'.trim(),
        'lokasi_bongkar': '${row['lokasi_bongkar']}'.trim(),
        'muatan': _nullableInputText(row['muatan']),
        'nama_supir': _nullableInputText(row['nama_supir']),
        'armada_id': resolvedArmadaId.isEmpty ? null : resolvedArmadaId,
        'armada_manual': useManual ? armadaManualRaw : null,
        'armada_label': useManual ? armadaManualRaw : null,
        'armada_start_date': '${row['armada_start_date']}'.trim().isEmpty
            ? null
            : '${row['armada_start_date']}',
        'armada_end_date': '${row['armada_end_date']}'.trim().isEmpty
            ? null
            : '${row['armada_end_date']}',
        'tonase': _toNum(row['tonase']),
        'harga': _toNum(row['harga']),
      };
    }).toList();
    final driverNames = detailsPayload
        .map((row) => _nullableInputText(row['nama_supir']))
        .whereType<String>()
        .expand(
          (value) => value
              .split(RegExp(r'[,;/]'))
              .map((part) => _nullableInputText(part))
              .whereType<String>(),
        )
        .toSet()
        .join(', ');

    String generatedInvoiceNo;
    try {
      final effectiveDate = Formatters.parseDate(_kopDate.text) ?? _date;
      generatedInvoiceNo = await widget.repository.generateIncomeInvoiceNumber(
        issuedDate: effectiveDate,
        isCompany: _isCompanyInvoice,
      );
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.repository.createInvoice(
        customerName: customer,
        total: _subtotal,
        noInvoice: generatedInvoiceNo,
        includePph: _isCompanyInvoice,
        status: _status,
        issuedDate: Formatters.parseDate(_kopDate.text) ?? _date,
        email: _email.text,
        noTelp: _phone.text,
        kopDate: Formatters.parseDate(_kopDate.text) ?? _date,
        kopLocation: _kopLocation.text,
        dueDate: Formatters.parseDate(_dueDate.text),
        pickup: '${first['lokasi_muat']}',
        destination: '${first['lokasi_bongkar']}',
        muatan: _nullableInputText(first['muatan']),
        armadaId: firstResolvedArmadaId.isEmpty ? null : firstResolvedArmadaId,
        armadaStartDate: Formatters.parseDate(first['armada_start_date']),
        armadaEndDate: Formatters.parseDate(first['armada_end_date']),
        tonase: _toNum(first['tonase']),
        harga: _toNum(first['harga']),
        namaSupir: driverNames.isEmpty ? null : driverNames,
        acceptedBy: _acceptedBy,
        customerId: _linkedCustomerId,
        orderId: _linkedOrderId,
        details: detailsPayload,
      );
      if (!mounted) return;
      _customer.clear();
      _email.clear();
      _phone.clear();
      _kopDate.text = _toInputDate(_date);
      _kopLocation.clear();
      _dueDate.clear();
      _status = 'Unpaid';
      _acceptedBy = 'Admin';
      _linkedCustomerId = null;
      _linkedOrderId = null;
      _prefillApplied = false;
      _prefillArmadaName = '';
      _prefillArmadaResolved = false;
      _details
        ..clear()
        ..add(_newDetail());
      _selectedCustomerOptionId = _customerManualOptionId;
      _formFuture = _loadFormData();
      _refreshInvoiceNumberPreview();
      await showCvantPopup(
        context: context,
        type: CvantPopupType.success,
        title: _t('Success', 'Success'),
        message: _t(
          'Invoice income berhasil ditambahkan.',
          'Income invoice was added successfully.',
        ),
        okLabel: 'OK',
        showOkButton: true,
        showCloseButton: true,
        barrierDismissible: false,
        autoCloseAfter: const Duration(seconds: 3),
      );
      if (!mounted) return;
      widget.onCreated();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    showCvantPopup(
      context: context,
      type: error ? CvantPopupType.error : CvantPopupType.success,
      title: error ? _t('Error', 'Error') : _t('Success', 'Success'),
      message: msg,
    );
  }

  Widget _buildInvoiceModeDot({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: selected ? AppColors.sidebarActiveGradient : null,
          color: selected ? null : AppColors.controlBackground(context),
          border: Border.all(
            color:
                selected ? Colors.transparent : AppColors.cardBorder(context),
          ),
          boxShadow: selected ? AppColors.sidebarActiveShadow : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color:
                    selected ? Colors.white : AppColors.textPrimaryFor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _formFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError) {
          return _ErrorView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() {
              _formFuture = _loadFormData();
            }),
          );
        }

        final payload = snapshot.data;
        if (payload == null || payload.length < 2) {
          return _ErrorView(
            message: _t(
              'Gagal memuat data form invoice.',
              'Failed to load invoice form data.',
            ),
            onRetry: () => setState(() {
              _formFuture = _loadFormData();
            }),
          );
        }
        final armadas = (payload[0] is List
                ? (payload[0] as List)
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
                : const <Map<String, dynamic>>[])
            .cast<Map<String, dynamic>>();
        final customerOptions = (payload[1] is List
                ? (payload[1] as List)
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
                : const <Map<String, dynamic>>[])
            .cast<Map<String, dynamic>>();
        final isEn = _isEn;
        final filteredCustomerOptions =
            _filterCustomerOptionsByMode(customerOptions);
        _tryResolvePrefillArmada(armadas);
        _normalizeManualRowsToArmadaId(armadas);
        final selectedCustomerValue = filteredCustomerOptions.any(
                    (item) => '${item['id']}' == _selectedCustomerOptionId) ||
                _selectedCustomerOptionId == _customerManualOptionId
            ? _selectedCustomerOptionId
            : _customerManualOptionId;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Mode Invoice', 'Invoice Mode'),
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInvoiceModeDot(
                          label: isEn ? 'Personal' : 'Pribadi',
                          selected: !_isCompanyInvoice,
                          onTap: () =>
                              _switchInvoiceMode(false, customerOptions),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInvoiceModeDot(
                          label: isEn ? 'Company' : 'Perusahaan',
                          selected: _isCompanyInvoice,
                          onTap: () =>
                              _switchInvoiceMode(true, customerOptions),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('Nomor Invoice', 'Invoice Number'),
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 4),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: _t('Nomor Otomatis', 'Auto Number'),
                    ),
                    child: Text(
                      _invoiceNoLoading
                          ? _t('Menyiapkan nomor...', 'Preparing number...')
                          : _invoiceNoPreview,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: _t('Tanggal', 'Date'),
                            ),
                            child: Text(Formatters.dmy(_date)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: _pickDueDate,
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: _t('Jatuh Tempo', 'Due Date'),
                            ),
                            child: Text(
                              _dueDate.text.trim().isEmpty
                                  ? '-'
                                  : Formatters.dmy(_dueDate.text.trim()),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CvantDropdownField<String>(
                    initialValue: selectedCustomerValue,
                    decoration: InputDecoration(
                      labelText:
                          _t('Data Customer Tersimpan', 'Saved Customer Data'),
                    ),
                    items: [
                      ...filteredCustomerOptions.map(
                        (option) => DropdownMenuItem<String>(
                          value: '${option['id']}',
                          child: Text('${option['label'] ?? '-'}'),
                        ),
                      ),
                      DropdownMenuItem<String>(
                        value: _customerManualOptionId,
                        child: Text(
                            _t('Other (Input Manual)', 'Other (Manual Input)')),
                      ),
                    ],
                    onChanged: (value) => _applySavedCustomerOption(
                        value, filteredCustomerOptions),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _customer,
                    decoration: InputDecoration(
                      labelText: _t('Nama Customer', 'Customer Name'),
                      hintText: _t('Nama pelanggan', 'Customer name'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: _t('Email Customer', 'Customer Email'),
                      hintText: 'email@domain.com',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: _t('No. Telp', 'Phone Number'),
                      hintText: '0812xxxx',
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _pickKopDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText:
                            _t('Tanggal Kop Invoice', 'Invoice Header Date'),
                      ),
                      child: Text(
                        _kopDate.text.trim().isEmpty
                            ? '-'
                            : Formatters.dmy(_kopDate.text.trim()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _kopLocation,
                    decoration: InputDecoration(
                      labelText:
                          _t('Lokasi Kop Invoice', 'Invoice Header Location'),
                      hintText: _t('Contoh: Sidoarjo', 'Example: Sidoarjo'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('Rincian Muat / Bongkar & Armada',
                        'Loading / Unloading & Fleet Details'),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ..._details.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    final rowSubtotal = _detailSubtotal(row);
                    return Container(
                      margin: EdgeInsets.only(
                          bottom: index == _details.length - 1 ? 0 : 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: AppColors.cardBorder(context)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            key: ValueKey(
                              'lokasi_muat-$index-$_detailFieldRefreshToken',
                            ),
                            initialValue: '${row['lokasi_muat']}',
                            decoration: InputDecoration(
                              hintText: _t('Lokasi Muat', 'Loading Location'),
                            ),
                            onChanged: (value) => row['lokasi_muat'] = value,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: ValueKey(
                              'lokasi_bongkar-$index-$_detailFieldRefreshToken',
                            ),
                            initialValue: '${row['lokasi_bongkar']}',
                            decoration: InputDecoration(
                              hintText:
                                  _t('Lokasi Bongkar', 'Unloading Location'),
                            ),
                            onChanged: (value) => row['lokasi_bongkar'] = value,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: ValueKey(
                              'muatan-$index-$_detailFieldRefreshToken',
                            ),
                            initialValue: '${row['muatan'] ?? ''}',
                            decoration: InputDecoration(
                              hintText:
                                  _t('Muatan (Opsional)', 'Cargo (Optional)'),
                            ),
                            onChanged: (value) => row['muatan'] = value,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: ValueKey(
                              'nama_supir-$index-$_detailFieldRefreshToken',
                            ),
                            initialValue: '${row['nama_supir'] ?? ''}',
                            decoration: InputDecoration(
                              hintText: _t('Nama Supir (Opsional)',
                                  'Driver Name (Optional)'),
                            ),
                            onChanged: (value) => row['nama_supir'] = value,
                          ),
                          const SizedBox(height: 8),
                          CvantDropdownField<String>(
                            initialValue: () {
                              final armadaId = '${row['armada_id']}'.trim();
                              final armadaManual =
                                  '${row['armada_manual'] ?? ''}'.trim();
                              final isManual = row['armada_is_manual'] == true;
                              if (armadaId.isNotEmpty) return armadaId;
                              if (isManual || armadaManual.isNotEmpty) {
                                return _manualArmadaOptionId;
                              }
                              return '';
                            }(),
                            decoration: InputDecoration(
                              hintText: _t('Pilih Armada', 'Select Fleet'),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: '',
                                child: Text(_t('-- Pilih Armada --',
                                    '-- Select Fleet --')),
                              ),
                              ...armadas.map(
                                (a) => DropdownMenuItem(
                                  value: '${a['id']}',
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text:
                                              '${a['nama_truk'] ?? '-'} - ${a['plat_nomor'] ?? '-'} ',
                                        ),
                                        TextSpan(
                                          text: '(${a['status'] ?? 'Ready'})',
                                          style: TextStyle(
                                            color: _armadaStatusColor(
                                              '${a['status'] ?? 'Ready'}',
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: _manualArmadaOptionId,
                                child: Text(
                                  _t(
                                    'Other (Input Manual)',
                                    'Other (Manual Input)',
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                if (value == _manualArmadaOptionId) {
                                  row['armada_id'] = '';
                                  row['armada_is_manual'] = true;
                                } else {
                                  row['armada_id'] = value ?? '';
                                  row['armada_is_manual'] = false;
                                  if ('${row['armada_id']}'.trim().isNotEmpty) {
                                    row['armada_manual'] = '';
                                  }
                                }
                              });
                            },
                          ),
                          if (row['armada_is_manual'] == true ||
                              ('${row['armada_manual'] ?? ''}'
                                      .trim()
                                      .isNotEmpty &&
                                  '${row['armada_id']}'.trim().isEmpty)) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              key: ValueKey(
                                'armada_manual-$index-$_detailFieldRefreshToken',
                              ),
                              initialValue: '${row['armada_manual'] ?? ''}',
                              decoration: InputDecoration(
                                hintText: _t(
                                  'Plat Nomor Manual (Other/Gabungan)',
                                  'Manual Plate Number (Other/Combined)',
                                ),
                              ),
                              onChanged: (value) =>
                                  row['armada_manual'] = value,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickDetailDate(
                                    index,
                                    'armada_start_date',
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText:
                                          _t('Tanggal Mulai', 'Start Date'),
                                    ),
                                    child: Text(
                                      '${row['armada_start_date']}'
                                              .trim()
                                              .isEmpty
                                          ? '-'
                                          : Formatters.dmy(
                                              row['armada_start_date'],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      _pickDetailDate(index, 'armada_end_date'),
                                  borderRadius: BorderRadius.circular(8),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText:
                                          _t('Tanggal Selesai', 'End Date'),
                                    ),
                                    child: Text(
                                      '${row['armada_end_date']}'.trim().isEmpty
                                          ? '-'
                                          : Formatters.dmy(
                                              row['armada_end_date'],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  key: ValueKey(
                                    'tonase-$index-$_detailFieldRefreshToken',
                                  ),
                                  initialValue: '${row['tonase']}',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _t('Tonase', 'Tonnage'),
                                  ),
                                  onChanged: (value) {
                                    row['tonase'] = value;
                                    setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  key: ValueKey(
                                    'harga-$index-$_detailFieldRefreshToken',
                                  ),
                                  initialValue: '${row['harga']}',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _t('Harga / Ton', 'Price / Ton'),
                                  ),
                                  onChanged: (value) {
                                    row['harga'] = value;
                                    setState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '${_t('Subtotal', 'Subtotal')}: ${Formatters.rupiah(rowSubtotal)}',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              if (_details.length > 1)
                                TextButton(
                                  onPressed: () => _removeDetail(index),
                                  style: CvantButtonStyles.text(
                                    context,
                                    color: AppColors.danger,
                                  ),
                                  child: Text(_t('Hapus', 'Delete')),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _addDetail,
                    child: Text(_t('+ Tambah Rincian', '+ Add Detail')),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration:
                        InputDecoration(labelText: _t('Subtotal', 'Subtotal')),
                    child: Text(Formatters.rupiah(_subtotal)),
                  ),
                  if (_isCompanyInvoice) ...[
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'PPH (2%)'),
                      child: Text(Formatters.rupiah(_pph)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: InputDecoration(
                        labelText: _t('Total Bayar', 'Grand Total')),
                    child: Text(Formatters.rupiah(_totalBayar)),
                  ),
                  const SizedBox(height: 8),
                  CvantDropdownField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: _t('Status', 'Status'),
                    ),
                    items: const ['Unpaid', 'Paid', 'Waiting']
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _status = value ?? _status),
                  ),
                  const SizedBox(height: 8),
                  CvantDropdownField<String>(
                    initialValue: _acceptedBy,
                    decoration: InputDecoration(
                      labelText: _t('Diterima Oleh', 'Accepted By'),
                    ),
                    items: const ['Admin', 'Owner']
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _acceptedBy = value ?? _acceptedBy),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : () => _save(armadas),
                      child: Text(
                        _loading
                            ? _t('Menyimpan...', 'Saving...')
                            : _t('Simpan', 'Save'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _DashboardContentFooter(),
          ],
        );
      },
    );
  }

  String _toInputDate(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '${value.year}-$mm-$dd';
  }
}

class _AdminCreateExpenseView extends StatefulWidget {
  const _AdminCreateExpenseView({
    required this.repository,
    required this.onCreated,
  });

  final DashboardRepository repository;
  final VoidCallback onCreated;

  @override
  State<_AdminCreateExpenseView> createState() =>
      _AdminCreateExpenseViewState();
}

class _AdminCreateExpenseViewState extends State<_AdminCreateExpenseView> {
  DateTime _date = DateTime.now();
  final List<Map<String, dynamic>> _details = [];
  String _status = 'Unpaid';
  String _recordedBy = 'Admin';
  bool _loading = false;
  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  String _t(String id, String en) => _isEn ? en : id;

  @override
  void initState() {
    super.initState();
    _details.add(_newDetail());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Map<String, dynamic> _newDetail() {
    return {
      'nama': '',
      'jumlah': '',
    };
  }

  void _addDetail() {
    setState(() => _details.add(_newDetail()));
  }

  void _removeDetail(int index) {
    if (_details.length == 1) return;
    setState(() => _details.removeAt(index));
  }

  double get _totalExpense {
    return _details.fold<double>(0, (sum, row) => sum + _toNum(row['jumlah']));
  }

  String _previewExpenseNo() {
    final mm = _date.month.toString().padLeft(2, '0');
    final yy = _date.year.toString();
    return 'EXP-$mm-$yy-XXXX';
  }

  Future<void> _save() async {
    final hasName = _details.any((row) => '${row['nama']}'.trim().isNotEmpty);
    if (!hasName || _totalExpense <= 0) {
      _snack(
        _t('Rincian pengeluaran wajib diisi.', 'Expense detail is required.'),
        error: true,
      );
      return;
    }
    final detailsPayload = _details
        .map((row) => <String, dynamic>{
              'nama': '${row['nama']}'.trim(),
              'jumlah': _toNum(row['jumlah']),
            })
        .toList();
    final note = detailsPayload
        .where((row) => '${row['nama']}'.trim().isNotEmpty)
        .map((row) =>
            '${row['nama']}: ${Formatters.rupiah(_toNum(row['jumlah']))}')
        .join(', ');

    setState(() => _loading = true);
    try {
      await widget.repository.createExpense(
        total: _totalExpense,
        status: _status,
        expenseDate: _date,
        note: note,
        kategori: detailsPayload.first['nama']?.toString(),
        keterangan: note,
        recordedBy: _recordedBy,
        details: detailsPayload,
      );
      if (!mounted) return;
      _details
        ..clear()
        ..add(_newDetail());
      _status = 'Unpaid';
      _recordedBy = 'Admin';
      await showCvantPopup(
        context: context,
        type: CvantPopupType.success,
        title: _t('Success', 'Success'),
        message: _t(
            'Expense berhasil ditambahkan.', 'Expense was added successfully.'),
        okLabel: 'OK',
        showOkButton: true,
        showCloseButton: true,
        barrierDismissible: false,
        autoCloseAfter: const Duration(seconds: 3),
      );
      if (!mounted) return;
      widget.onCreated();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    showCvantPopup(
      context: context,
      type: error ? CvantPopupType.error : CvantPopupType.success,
      title: error ? _t('Error', 'Error') : _t('Success', 'Success'),
      message: msg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Nomor Expense', 'Expense Number'),
                style: TextStyle(color: AppColors.textMutedFor(context)),
              ),
              const SizedBox(height: 4),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: _t('Nomor Otomatis', 'Auto Number'),
                ),
                child: Text(_previewExpenseNo()),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _t('Tanggal', 'Date'),
                  ),
                  child: Text(Formatters.dmy(_date)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _t('Rincian Pengeluaran', 'Expense Details'),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ..._details.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return Container(
                  margin: EdgeInsets.only(
                      bottom: index == _details.length - 1 ? 0 : 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.cardBorder(context)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: '${row['nama']}',
                        decoration: InputDecoration(
                          hintText: _t('Nama Pengeluaran', 'Expense Name'),
                        ),
                        onChanged: (value) => row['nama'] = value,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: '${row['jumlah']}',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: _t('Jumlah', 'Amount'),
                        ),
                        onChanged: (value) {
                          row['jumlah'] = value;
                          setState(() {});
                        },
                      ),
                      if (_details.length > 1) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _removeDetail(index),
                            style: CvantButtonStyles.text(
                              context,
                              color: AppColors.danger,
                            ),
                            child: Text(_t('Hapus', 'Delete')),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _addDetail,
                child: Text(_t('+ Tambah Rincian', '+ Add Detail')),
              ),
              const SizedBox(height: 10),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: _t('Total Pengeluaran', 'Total Expense'),
                ),
                child: Text(Formatters.rupiah(_totalExpense)),
              ),
              const SizedBox(height: 8),
              CvantDropdownField<String>(
                initialValue: _status,
                decoration: InputDecoration(labelText: _t('Status', 'Status')),
                items: const ['Unpaid', 'Paid', 'Waiting', 'Cancelled']
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _status = value ?? _status),
              ),
              const SizedBox(height: 8),
              CvantDropdownField<String>(
                initialValue: _recordedBy,
                decoration: InputDecoration(
                  labelText: _t('Dicatat Oleh', 'Recorded By'),
                ),
                items: const ['Admin', 'Owner']
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _recordedBy = value ?? _recordedBy),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _save,
                  child: Text(
                    _loading
                        ? _t('Menyimpan...', 'Saving...')
                        : _t('Simpan', 'Save'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _DashboardContentFooter(),
      ],
    );
  }
}

class _AdminCreateFleetView extends StatefulWidget {
  const _AdminCreateFleetView({
    required this.repository,
    required this.onCreated,
  });

  final DashboardRepository repository;
  final VoidCallback onCreated;

  @override
  State<_AdminCreateFleetView> createState() => _AdminCreateFleetViewState();
}

class _AdminCreateFleetViewState extends State<_AdminCreateFleetView> {
  final _name = TextEditingController();
  final _plate = TextEditingController();
  final _capacity = TextEditingController();
  String _status = 'Ready';
  bool _loading = false;
  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  String _t(String id, String en) => _isEn ? en : id;

  @override
  void dispose() {
    _name.dispose();
    _plate.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final plate = _plate.text.trim();
    final capacity = _toNum(_capacity.text.trim());
    if (name.isEmpty || plate.isEmpty) {
      _snack(
        _t('Nama truk dan plat nomor wajib diisi.',
            'Truck name and plate number are required.'),
        error: true,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.repository.createArmada(
        name: name,
        plate: plate,
        capacity: capacity,
        status: _status,
        active: _status != 'Inactive',
      );
      if (!mounted) return;
      _name.clear();
      _plate.clear();
      _capacity.clear();
      _status = 'Ready';
      widget.onCreated();
      _snack(
          _t('Armada berhasil ditambahkan.', 'Fleet was added successfully.'));
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    showCvantPopup(
      context: context,
      type: error ? CvantPopupType.error : CvantPopupType.success,
      title: error ? _t('Error', 'Error') : _t('Success', 'Success'),
      message: msg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _PanelCard(
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: _t('Nama Truk', 'Truck Name'),
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _plate,
                decoration: InputDecoration(
                  labelText: _t('Plat Nomor', 'Plate Number'),
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _capacity,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _t('Kapasitas (Tonase)', 'Capacity (Tonnage)'),
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
              ),
              const SizedBox(height: 10),
              CvantDropdownField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: _t('Status', 'Status'),
                ),
                items: const ['Ready', 'Full', 'Inactive']
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _status = value ?? _status),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _save,
                  child: Text(
                    _loading
                        ? _t('Menyimpan...', 'Saving...')
                        : _t('Simpan', 'Save'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _DashboardContentFooter(),
      ],
    );
  }
}

class _CustomerCreateOrderView extends StatefulWidget {
  const _CustomerCreateOrderView({
    required this.repository,
    required this.onCreated,
  });

  final DashboardRepository repository;
  final VoidCallback onCreated;

  @override
  State<_CustomerCreateOrderView> createState() =>
      _CustomerCreateOrderViewState();
}

class _CustomerCreateOrderViewState extends State<_CustomerCreateOrderView> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _company = TextEditingController();
  final _cargo = TextEditingController();
  final _notes = TextEditingController();
  final _estimate = TextEditingController();
  String _service = 'regular';
  DateTime _pickupDate = DateTime.now();
  bool _loading = false;
  bool _didHydrate = false;
  late Future<List<dynamic>> _future;
  final List<Map<String, dynamic>> _details = [];
  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  String _t(String id, String en) => _isEn ? en : id;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _details.add(_newDetail());
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _company.dispose();
    _cargo.dispose();
    _notes.dispose();
    _estimate.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _load() {
    return Future.wait([
      widget.repository.fetchArmadas(),
      widget.repository.fetchMyProfile(),
    ]);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
      initialDate: _pickupDate,
    );
    if (picked != null) {
      setState(() => _pickupDate = picked);
    }
  }

  Map<String, dynamic> _newDetail() {
    return {
      'lokasi_muat': '',
      'lokasi_bongkar': '',
      'armada_id': '',
      'armada_start_date': '',
    };
  }

  void _addDetail() {
    setState(() => _details.add(_newDetail()));
  }

  void _removeDetail(int index) {
    if (_details.length == 1) return;
    setState(() => _details.removeAt(index));
  }

  Future<void> _pickDetailDate(int index, String field) async {
    final initial =
        Formatters.parseDate(_details[index][field]) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (picked == null) return;
    setState(() => _details[index][field] = _toInputDate(picked));
  }

  void _hydrate(Map<String, dynamic>? profile) {
    if (_didHydrate) return;
    _name.text = '${profile?['name'] ?? ''}';
    _email.text = '${profile?['email'] ?? ''}';
    _phone.text = '${profile?['phone'] ?? ''}';
    _company.text = '${profile?['company'] ?? ''}';
    _didHydrate = true;
  }

  Future<void> _save() async {
    final first = _details.first;
    final pickup = '${first['lokasi_muat']}'.trim();
    final destination = '${first['lokasi_bongkar']}'.trim();
    final service = _service.trim();
    final fleet = '${first['armada_id']}'.trim();
    final estimate = _toNum(_estimate.text.trim());
    final pickupDate =
        Formatters.parseDate(first['armada_start_date']) ?? _pickupDate;

    if (pickup.isEmpty ||
        destination.isEmpty ||
        service.isEmpty ||
        fleet.isEmpty ||
        estimate <= 0) {
      _snack(
        _t(
          'Lengkapi detail order dan estimasi biaya.',
          'Complete order details and estimated cost.',
        ),
        error: true,
      );
      return;
    }

    final detailsNote = _details.map((row) {
      final muat = '${row['lokasi_muat']}'.trim();
      final bongkar = '${row['lokasi_bongkar']}'.trim();
      final armada = '${row['armada_id']}'.trim();
      final date = '${row['armada_start_date']}'.trim();
      return '$muat->$bongkar [armada:$armada] [date:$date]';
    }).join(' | ');

    setState(() => _loading = true);
    try {
      await widget.repository.createCustomerOrder(
        pickup: pickup,
        destination: destination,
        pickupDate: pickupDate,
        pickupTime: '08:00',
        service: service,
        fleet: fleet,
        cargo: _cargo.text.trim(),
        notes:
            '${_notes.text.trim()}${detailsNote.isEmpty ? '' : '\n$detailsNote'}',
        insurance: false,
        estimate: estimate,
        insuranceFee: 0,
        total: estimate,
      );
      if (!mounted) return;
      _cargo.clear();
      _notes.clear();
      _estimate.clear();
      _service = 'regular';
      _details
        ..clear()
        ..add(_newDetail());
      widget.onCreated();
      _snack(_t('Order berhasil dibuat.', 'Order created successfully.'));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    showCvantPopup(
      context: context,
      type: error ? CvantPopupType.error : CvantPopupType.success,
      title: error ? _t('Error', 'Error') : _t('Success', 'Success'),
      message: msg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError) {
          return _ErrorView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() {
              _future = _load();
            }),
          );
        }

        final armadas =
            (snapshot.data![0] as List).cast<Map<String, dynamic>>();
        final profile = snapshot.data![1] as Map<String, dynamic>?;
        _hydrate(profile);
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _name,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: _t('Nama', 'Name'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _email,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: _t('Email', 'Email'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phone,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: _t('Nomor HP', 'Phone Number'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _company,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText:
                          _t('Perusahaan (opsional)', 'Company (optional)'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cargo,
                    decoration: InputDecoration(
                      labelText: _t('Jenis Barang', 'Cargo Type'),
                      hintText: _t('Contoh: material, makanan',
                          'Example: material, food'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notes,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: _t('Catatan', 'Notes'),
                      hintText: _t('Catatan tambahan', 'Additional notes'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CvantDropdownField<String>(
                    initialValue: _service,
                    decoration: InputDecoration(
                      labelText: _t('Layanan', 'Service'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'regular',
                        child: Text(_t('Regular', 'Regular')),
                      ),
                      DropdownMenuItem(
                        value: 'express',
                        child: Text(_t('Express', 'Express')),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _service = value ?? _service),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _estimate,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _t('Estimasi Biaya', 'Estimated Cost'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _t('Rincian Muat / Bongkar & Armada',
                        'Loading / Unloading & Fleet Details'),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ..._details.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    return Container(
                      margin: EdgeInsets.only(
                          bottom: index == _details.length - 1 ? 0 : 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: AppColors.cardBorder(context)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            initialValue: '${row['lokasi_muat']}',
                            decoration: InputDecoration(
                              hintText: _t('Lokasi Muat', 'Loading Location'),
                            ),
                            onChanged: (value) => row['lokasi_muat'] = value,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: '${row['lokasi_bongkar']}',
                            decoration: InputDecoration(
                              hintText:
                                  _t('Lokasi Bongkar', 'Unloading Location'),
                            ),
                            onChanged: (value) => row['lokasi_bongkar'] = value,
                          ),
                          const SizedBox(height: 8),
                          CvantDropdownField<String>(
                            initialValue: '${row['armada_id']}'.trim().isEmpty
                                ? null
                                : '${row['armada_id']}',
                            decoration: InputDecoration(
                              hintText: _t('Pilih Armada', 'Select Fleet'),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: '',
                                child: Text(_t('Pilih Armada', 'Select Fleet')),
                              ),
                              ...armadas.map(
                                (item) {
                                  final status = '${item['status'] ?? 'Ready'}';
                                  final isFull =
                                      status.toLowerCase().contains('full');
                                  final label = item['kapasitas'] == null
                                      ? '${item['nama_truk'] ?? 'Armada'} - $status'
                                      : '${item['nama_truk'] ?? 'Armada'} (${item['kapasitas']} ton) - $status';
                                  return DropdownMenuItem<String>(
                                    value: '${item['id']}',
                                    enabled: !isFull,
                                    child: Text(label),
                                  );
                                },
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => row['armada_id'] = value ?? ''),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () =>
                                _pickDetailDate(index, 'armada_start_date'),
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText:
                                    _t('Tanggal Pengiriman', 'Delivery Date'),
                              ),
                              child: Text(
                                '${row['armada_start_date']}'.trim().isEmpty
                                    ? '-'
                                    : Formatters.dmy(row['armada_start_date']),
                              ),
                            ),
                          ),
                          if (_details.length > 1) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _removeDetail(index),
                                style: CvantButtonStyles.text(
                                  context,
                                  color: AppColors.danger,
                                ),
                                child: Text(_t('Hapus', 'Remove')),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _addDetail,
                    child: Text(_t('+ Tambah Rincian', '+ Add Detail')),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText:
                            _t('Tanggal Umum Order', 'Order General Date'),
                      ),
                      child: Text(Formatters.dmy(_pickupDate)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _save,
                      child: Text(
                        _loading
                            ? _t('Menyimpan...', 'Saving...')
                            : _t('Simpan Order', 'Save Order'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _DashboardContentFooter(),
          ],
        );
      },
    );
  }

  String _toInputDate(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '${value.year}-$mm-$dd';
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
                            ? AppColors.neutralOutline
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

class _AdminInvoiceListView extends StatefulWidget {
  const _AdminInvoiceListView({
    required this.repository,
    required this.onQuickMenuSelect,
    this.isOwner = false,
    this.onDataChanged,
  });

  final DashboardRepository repository;
  final ValueChanged<int> onQuickMenuSelect;
  final bool isOwner;
  final VoidCallback? onDataChanged;

  @override
  State<_AdminInvoiceListView> createState() => _AdminInvoiceListViewState();
}

class _AdminInvoiceListViewState extends State<_AdminInvoiceListView> {
  static const _manualArmadaOptionId = '__other_manual_armada__';
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
  late Future<List<dynamic>> _future;
  final _search = TextEditingController();
  String _limit = '10';

  bool get _isEn => LanguageController.language.value == AppLanguage.en;

  String _t(String id, String en) => _isEn ? en : id;

  bool _matchesKeywordInAnyColumn(
    Map<String, dynamic> row,
    String keyword,
  ) {
    if (keyword.trim().isEmpty) return true;
    final haystack = _flattenSearchText(row).toLowerCase();
    return haystack.contains(keyword.toLowerCase());
  }

  ButtonStyle _mobileActionButtonStyle({
    required BuildContext context,
    required Color color,
  }) {
    return CvantButtonStyles.outlined(
      context,
      color: color,
      borderColor: color,
    ).copyWith(
      minimumSize: const WidgetStatePropertyAll(Size(44, 38)),
      maximumSize: const WidgetStatePropertyAll(Size(44, 38)),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Color _armadaStatusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('full')) return AppColors.warning;
    if (lower.contains('ready')) return AppColors.success;
    if (lower.contains('inactive') ||
        lower.contains('non active') ||
        lower.contains('non-active')) {
      return AppColors.neutralOutline;
    }
    return AppColors.textMutedFor(context);
  }

  String _normalizePlateText(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _extractPlateFromText(String value) {
    final match = RegExp(
      r'[A-Z]{1,2}\s?[0-9]{1,4}\s?[A-Z]{1,3}',
    ).firstMatch(value.toUpperCase());
    if (match == null) return null;
    final plate = _normalizePlateText(match.group(0) ?? '');
    return plate.isEmpty ? null : plate;
  }

  Map<String, String> _buildArmadaIdByPlate(
    List<Map<String, dynamic>> armadas,
  ) {
    final map = <String, String>{};
    for (final armada in armadas) {
      final id = '${armada['id'] ?? ''}'.trim();
      final plate = _normalizePlateText('${armada['plat_nomor'] ?? ''}');
      if (id.isEmpty || plate.isEmpty) continue;
      map[plate] = id;
    }
    return map;
  }

  String _resolveArmadaIdFromInput({
    required String armadaId,
    required String armadaManual,
    required Map<String, String> armadaIdByPlate,
  }) {
    final direct = armadaId.trim();
    if (direct.isNotEmpty) return direct;
    final manual = armadaManual.trim();
    if (manual.isEmpty) return '';
    final extracted = _extractPlateFromText(manual);
    final normalized = _normalizePlateText(manual);
    return armadaIdByPlate[extracted ?? normalized] ?? '';
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _load() {
    return Future.wait([
      widget.repository.fetchInvoices(),
      widget.repository.fetchExpenses(),
    ]);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  void _notifyDataChanged() {
    widget.onDataChanged?.call();
  }

  Future<void> _deleteInvoice(String id) async {
    try {
      await widget.repository.deleteInvoice(id);
      if (!mounted) return;
      _snack(_t('Invoice berhasil dihapus.', 'Invoice deleted successfully.'));
      await _refresh();
      _notifyDataChanged();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _deleteExpense(String id) async {
    try {
      await widget.repository.deleteExpense(id);
      if (!mounted) return;
      _snack(_t('Expense berhasil dihapus.', 'Expense deleted successfully.'));
      await _refresh();
      _notifyDataChanged();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _confirmDelete({
    required String id,
    required bool isIncome,
  }) async {
    final ok = await showCvantConfirmPopup(
      context: context,
      title: isIncome
          ? _t('Hapus Invoice', 'Delete Invoice')
          : _t('Hapus Expense', 'Delete Expense'),
      message: _t(
        'Data yang dihapus tidak bisa dikembalikan.',
        'Deleted data cannot be restored.',
      ),
      type: CvantPopupType.error,
      cancelLabel: _t('Batal', 'Cancel'),
      confirmLabel: _t('Hapus', 'Delete'),
    );
    if (!ok) return;
    if (isIncome) {
      await _deleteInvoice(id);
    } else {
      await _deleteExpense(id);
    }
  }

  Future<void> _sendInvoice(Map<String, dynamic> item) async {
    final invoiceId = '${item['id'] ?? ''}'.trim();
    final invoiceNumber =
        '${item['__number'] ?? item['no_invoice'] ?? item['id'] ?? '-'}';
    final customerName =
        '${item['__name'] ?? item['nama_pelanggan'] ?? 'customer'}';
    final ok = await showCvantConfirmPopup(
      context: context,
      type: CvantPopupType.info,
      title: _t('Kirim Invoice', 'Send Invoice'),
      message: _t(
        'Kirim invoice $invoiceNumber ke $customerName?',
        'Send invoice $invoiceNumber to $customerName?',
      ),
      cancelLabel: _t('Batal', 'Cancel'),
      confirmLabel: _t('Kirim', 'Send'),
    );
    if (!ok) return;

    try {
      if (invoiceId.isEmpty) {
        throw Exception(
          _t('ID invoice tidak ditemukan.', 'Invoice ID not found.'),
        );
      }

      final orderId = '${item['order_id'] ?? ''}'.trim();
      final invoiceStatus =
          '${item['status'] ?? item['__status'] ?? ''}'.trim().toLowerCase();
      if (orderId.isNotEmpty && !invoiceStatus.contains('paid')) {
        await widget.repository.updateOrderStatus(
          orderId: orderId,
          status: 'Pending Payment',
        );
      }

      final delivery = await widget.repository.dispatchInvoiceDelivery(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        customerName: customerName,
        customerId: item['customer_id']?.toString(),
        customerEmail: item['email']?.toString(),
      );

      if (!mounted) return;
      if (delivery.target == InvoiceDeliveryTarget.customerNotification) {
        _snack(
          _t(
            'Invoice berhasil dikirim ke notifikasi akun customer.',
            'Invoice sent to customer account notification.',
          ),
        );
      } else {
        final email = (delivery.email ?? '').trim();
        if (email.isEmpty) {
          throw Exception(
            _t(
              'Email customer tidak tersedia. Lengkapi email invoice terlebih dahulu.',
              'Customer email is missing. Complete the invoice email first.',
            ),
          );
        }
        final uri = Uri(
          scheme: 'mailto',
          path: email,
          queryParameters: {
            'subject': 'Invoice $invoiceNumber - CV ANT',
            'body':
                'Halo $customerName,\n\nInvoice $invoiceNumber sudah tersedia dari CV ANT.\nSilakan cek detail invoice dan lanjutkan proses pembayaran.\n\nTerima kasih.',
          },
        );
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          throw Exception(
            _t(
              'Aplikasi email tidak ditemukan di perangkat ini.',
              'No email app found on this device.',
            ),
          );
        }
        _snack(
          _t(
            'Invoice diarahkan ke email $email.',
            'Invoice has been directed to email $email.',
          ),
        );
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _openReportSummary({
    required List<Map<String, dynamic>> incomes,
    required List<Map<String, dynamic>> expenses,
  }) async {
    List<Map<String, dynamic>> buildRows({
      required DateTime start,
      required DateTime end,
      required bool includeIncome,
      required bool includeExpense,
      required String customerKind,
      required Set<String> allowedStatuses,
      required String keyword,
    }) {
      final rows = <Map<String, dynamic>>[];

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

      String resolveTujuan(
        Map<String, dynamic> source, {
        Map<String, dynamic>? detail,
      }) {
        final detailDestination = '${detail?['lokasi_bongkar'] ?? ''}'.trim();
        if (detailDestination.isNotEmpty) {
          return detailDestination;
        }

        final details = _toDetailList(source['rincian']);
        final tujuan = <String>{};
        for (final row in details) {
          final destination = '${row['lokasi_bongkar'] ?? ''}'.trim();
          if (destination.isNotEmpty) {
            tujuan.add(destination);
          }
        }
        if (tujuan.isNotEmpty) {
          return tujuan.join(' | ');
        }
        final fallback = '${source['lokasi_bongkar'] ?? ''}'.trim();
        return fallback.isEmpty ? '-' : fallback;
      }

      dynamic resolveKeberangkatanDate(
        Map<String, dynamic> source, {
        Map<String, dynamic>? detail,
      }) {
        return detail?['armada_start_date'] ??
            source['armada_start_date'] ??
            source['tanggal_kop'] ??
            source['tanggal'] ??
            source['created_at'];
      }

      double resolveDetailSubtotal(
        Map<String, dynamic> source, {
        Map<String, dynamic>? detail,
        int detailCount = 1,
      }) {
        final subtotalFromDetail = _toNum(detail?['subtotal']);
        if (subtotalFromDetail > 0) return subtotalFromDetail;
        final tonase = _toNum(detail?['tonase'] ?? source['tonase']);
        final harga = _toNum(detail?['harga'] ?? source['harga']);
        final computed = tonase * harga;
        if (computed > 0) return computed;
        final invoiceSubtotal = _toNum(source['total_biaya']);
        if (invoiceSubtotal <= 0) return 0;
        if (detailCount <= 1) return invoiceSubtotal;
        return invoiceSubtotal / detailCount;
      }

      bool incomeKindAllowed(Map<String, dynamic> source) {
        if (customerKind == 'all') return true;
        final customerName = '${source['nama_pelanggan'] ?? ''}'.trim();
        final invoiceNumber = '${source['no_invoice'] ?? ''}'.trim();
        final isCompany = _resolveIsCompanyInvoice(
          invoiceNumber: invoiceNumber,
          customerName: customerName,
        );
        return customerKind == 'company' ? isCompany : !isCompany;
      }

      if (includeIncome) {
        for (final item in incomes) {
          final status = '${item['status'] ?? 'Waiting'}';
          if (!statusAllowed(status)) continue;
          if (!incomeKindAllowed(item)) continue;
          final customerName = '${item['nama_pelanggan'] ?? '-'}';
          final invoiceNumber = Formatters.invoiceNumber(
            item['no_invoice'],
            item['tanggal_kop'] ?? item['tanggal'],
            customerName: customerName,
          );
          final isCompanyInvoice = _resolveIsCompanyInvoice(
            invoiceNumber: item['no_invoice'],
            customerName: customerName,
          );

          final detailRows = _toDetailList(item['rincian']);
          if (detailRows.isNotEmpty) {
            for (var i = 0; i < detailRows.length; i++) {
              final detail = detailRows[i];
              final rowSource = <String, dynamic>{...item, ...detail};
              final rowDate = resolveKeberangkatanDate(item, detail: detail);
              if (!inRange(rowDate)) continue;
              if (!keywordAllowed(rowSource)) continue;

              final subtotal = resolveDetailSubtotal(
                item,
                detail: detail,
                detailCount: detailRows.length,
              );
              final pph = isCompanyInvoice ? max(0.0, subtotal * 0.02) : 0.0;
              final total =
                  isCompanyInvoice ? max(0.0, subtotal - pph) : subtotal;

              rows.add({
                '__key':
                    'income:${item['id'] ?? item['no_invoice'] ?? item['created_at'] ?? rows.length}:$i',
                '__type': 'Income',
                '__number': invoiceNumber,
                '__date': rowDate,
                '__name': customerName,
                '__customer': customerName,
                '__status': status,
                '__amount': total,
                '__jumlah': subtotal,
                '__pph': pph,
                '__total': total,
                '__tujuan': resolveTujuan(item, detail: detail),
                '__income': total,
                '__expense': 0.0,
              });
            }
            continue;
          }

          final rowDate = resolveKeberangkatanDate(item);
          if (!inRange(rowDate)) continue;
          if (!keywordAllowed(item)) continue;

          final subtotal = _toNum(item['total_biaya']);
          final pph = isCompanyInvoice ? _toNum(item['pph']) : 0.0;
          final total = isCompanyInvoice
              ? _toNum(item['total_bayar'] ?? item['total_biaya'])
              : subtotal;

          rows.add({
            '__key':
                'income:${item['id'] ?? item['no_invoice'] ?? item['created_at'] ?? rows.length}',
            '__type': 'Income',
            '__number': invoiceNumber,
            '__date': rowDate,
            '__name': customerName,
            '__customer': customerName,
            '__status': status,
            '__amount': total,
            '__jumlah': subtotal,
            '__pph': pph,
            '__total': total,
            '__tujuan': resolveTujuan(item),
            '__income': total,
            '__expense': 0.0,
          });
        }
      }

      if (includeExpense && customerKind == 'all') {
        for (final item in expenses) {
          final status = '${item['status'] ?? 'Recorded'}';
          final amount = _toNum(item['total_pengeluaran']);
          if (!inRange(item['tanggal'] ?? item['created_at'])) continue;
          if (!statusAllowed(status)) continue;
          if (!keywordAllowed(item)) continue;
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
            '__tujuan': '-',
            '__income': 0.0,
            '__expense': amount,
          });
        }
      }

      rows.sort((a, b) {
        final aDate = Formatters.parseDate(a['__date']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = Formatters.parseDate(b['__date']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return rows;
    }

    Future<void> printReportPdf({
      required DateTime start,
      required DateTime end,
      required List<Map<String, dynamic>> rows,
      required double totalIncome,
      required double totalExpense,
      required bool includeIncome,
      required bool includeExpense,
      required String customerKind,
      required String orientation,
    }) async {
      String monthName(int month) {
        const id = [
          'Januari',
          'Februari',
          'Maret',
          'April',
          'Mei',
          'Juni',
          'Juli',
          'Agustus',
          'September',
          'Oktober',
          'November',
          'Desember',
        ];
        const en = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
        return _t(id[month - 1], en[month - 1]);
      }

      final isYearPeriod = start.month == 1 &&
          start.day == 1 &&
          end.year == start.year + 1 &&
          end.month == 1 &&
          end.day == 1;
      final periodLabel = isYearPeriod
          ? '${start.year}'
          : '${monthName(start.month)} ${start.year}';

      final reportHeader = () {
        if (includeIncome && includeExpense) {
          return _t(
            'Laporan (Pemasukkan dan Pengeluaran)',
            'Report (Income and Expense)',
          );
        }
        if (includeIncome) {
          if (customerKind == 'company') {
            return _t(
              'Laporan Pemasukkan (Perusahaan)',
              'Income Report (Company)',
            );
          }
          if (customerKind == 'personal') {
            return _t(
              'Laporan Pemasukkan (Pribadi)',
              'Income Report (Personal)',
            );
          }
          return _t('Laporan Pemasukkan', 'Income Report');
        }
        if (customerKind == 'company') {
          return _t(
            'Laporan Pengeluaran (Perusahaan)',
            'Expense Report (Company)',
          );
        }
        if (customerKind == 'personal') {
          return _t(
            'Laporan Pengeluaran (Pribadi)',
            'Expense Report (Personal)',
          );
        }
        return _t('Laporan Pengeluaran', 'Expense Report');
      }();

      await Printing.layoutPdf(
        onLayout: (format) async {
          final companyMode = customerKind == 'company';
          final maxNumberLen = rows
              .map((row) => '${row['__number'] ?? '-'}'.length)
              .fold<int>(0, (maxLen, len) => max(maxLen, len));
          final maxCustomerLen = rows
              .map((row) =>
                  '${row['__customer'] ?? row['__name'] ?? '-'}'.length)
              .fold<int>(0, (maxLen, len) => max(maxLen, len));
          final maxTujuanLen = rows
              .map((row) => '${row['__tujuan'] ?? '-'}'.length)
              .fold<int>(0, (maxLen, len) => max(maxLen, len));

          final autoLandscape = rows.length > 18 ||
              maxNumberLen > 24 ||
              maxCustomerLen > 18 ||
              maxTujuanLen > 14;
          final isLandscape = orientation == 'landscape'
              ? true
              : orientation == 'portrait'
                  ? false
                  : autoLandscape;

          double headerFont = isLandscape ? 9 : 8.5;
          double cellFont = isLandscape ? 8 : 7.5;
          if (maxNumberLen > 34 || rows.length > 28) {
            headerFont -= 0.5;
            cellFont -= 0.5;
          }
          if (maxNumberLen > 48 || rows.length > 44) {
            headerFont -= 0.5;
            cellFont -= 0.5;
          }
          headerFont = headerFont.clamp(7.0, 10.0).toDouble();
          cellFont = cellFont.clamp(6.5, 9.0).toDouble();

          final pageFormat = isLandscape ? format.landscape : format;

          String fitCell(String value, int maxLen) {
            final text = value.trim();
            if (text.length <= maxLen) return text;
            return '${text.substring(0, maxLen - 1)}...';
          }

          final customerMaxLen = isLandscape ? 26 : 18;
          final tujuanMaxLen = isLandscape ? 22 : 16;

          final headers = companyMode
              ? const [
                  'NO',
                  'TANGGAL',
                  'CUSTOMER',
                  'JUMLAH',
                  'PPH',
                  'TOTAL',
                  'TUJUAN'
                ]
              : const [
                  'NO',
                  'TANGGAL',
                  'CUSTOMER',
                  'JUMLAH',
                  'TOTAL',
                  'TUJUAN'
                ];
          final columnWidths = companyMode
              ? <int, pw.TableColumnWidth>{
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(0.95),
                  2: const pw.FlexColumnWidth(1.55),
                  3: const pw.FlexColumnWidth(1.05),
                  4: const pw.FlexColumnWidth(0.9),
                  5: const pw.FlexColumnWidth(1.05),
                  6: const pw.FlexColumnWidth(1.4),
                }
              : <int, pw.TableColumnWidth>{
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(0.95),
                  2: const pw.FlexColumnWidth(1.7),
                  3: const pw.FlexColumnWidth(1.15),
                  4: const pw.FlexColumnWidth(1.15),
                  5: const pw.FlexColumnWidth(1.55),
                };
          final cellAlignments = <int, pw.Alignment>{
            for (int i = 0; i < headers.length; i++) i: pw.Alignment.center,
          };
          final tableData = List<List<String>>.generate(rows.length, (index) {
            final row = rows[index];
            if (companyMode) {
              return [
                '${index + 1}',
                Formatters.dmy(row['__date']),
                fitCell('${row['__customer'] ?? row['__name'] ?? '-'}',
                    customerMaxLen),
                Formatters.rupiah(_toNum(row['__jumlah'])),
                Formatters.rupiah(_toNum(row['__pph'])),
                Formatters.rupiah(_toNum(row['__total'])),
                fitCell('${row['__tujuan'] ?? '-'}', tujuanMaxLen),
              ];
            }
            return [
              '${index + 1}',
              Formatters.dmy(row['__date']),
              fitCell('${row['__customer'] ?? row['__name'] ?? '-'}',
                  customerMaxLen),
              Formatters.rupiah(_toNum(row['__jumlah'])),
              Formatters.rupiah(_toNum(row['__total'])),
              fitCell('${row['__tujuan'] ?? '-'}', tujuanMaxLen),
            ];
          });

          final doc = pw.Document();
          doc.addPage(
            pw.MultiPage(
              pageFormat: pageFormat,
              margin: const pw.EdgeInsets.all(20),
              build: (context) => [
                pw.Text(
                  'CV ANT - $reportHeader',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('${_t('Periode', 'Period')}: $periodLabel'),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  cellPadding:
                      const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  cellHeight: 16,
                  headerHeight: 16,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                    fontSize: headerFont,
                  ),
                  cellStyle: pw.TextStyle(fontSize: cellFont),
                  cellAlignments: cellAlignments,
                  columnWidths: columnWidths,
                  headers: headers,
                  data: tableData,
                ),
                pw.SizedBox(height: 12),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (includeIncome && includeExpense) ...[
                        pw.Text(
                          '${_t('Total Income', 'Total Income')}: ${Formatters.rupiah(totalIncome)}',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                        pw.Text(
                          '${_t('Total Expense', 'Total Expense')}: ${Formatters.rupiah(totalExpense)}',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                        pw.Text(
                          '${_t('Selisih', 'Difference')}: ${Formatters.rupiah(totalIncome - totalExpense)}',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ] else if (includeIncome) ...[
                        pw.Text(
                          '${_t('Total Income', 'Total Income')}: ${Formatters.rupiah(totalIncome)}',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ] else if (includeExpense) ...[
                        pw.Text(
                          '${_t('Total Expense', 'Total Expense')}: ${Formatters.rupiah(totalExpense)}',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
          return doc.save();
        },
      );
    }

    final allStatuses = <String>{
      ...incomes.map((item) => '${item['status'] ?? 'Waiting'}'),
      ...expenses.map((item) => '${item['status'] ?? 'Recorded'}'),
    }.where((status) => status.trim().isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    String range = 'month';
    String orientation = 'auto';
    String customerKind = 'all';
    bool includeIncome = true;
    bool includeExpense = true;
    final selectedStatuses = <String>{...allStatuses};
    final rowSelections = <String, bool>{};
    String keywordText = '';
    final currentYear = DateTime.now().year;
    int selectedYear = currentYear;
    int selectedMonth = DateTime.now().month;
    final availableYears = <int>{
      currentYear,
      ...incomes
          .map((item) =>
              Formatters.parseDate(item['tanggal'] ?? item['created_at'])?.year)
          .whereType<int>(),
      ...expenses
          .map((item) =>
              Formatters.parseDate(item['tanggal'] ?? item['created_at'])?.year)
          .whereType<int>(),
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    String monthLabel(int month) {
      const id = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];
      const en = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return _t(id[month - 1], en[month - 1]);
    }

    final selection = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final start = range == 'year'
                ? DateTime(selectedYear, 1, 1)
                : DateTime(selectedYear, selectedMonth, 1);
            final end = range == 'year'
                ? DateTime(selectedYear + 1, 1, 1)
                : DateTime(selectedYear, selectedMonth + 1, 1);
            final previewRows = buildRows(
              start: start,
              end: end,
              includeIncome: includeIncome,
              includeExpense: includeExpense,
              customerKind: customerKind,
              allowedStatuses: selectedStatuses,
              keyword: keywordText.trim(),
            );
            final availableKeys =
                previewRows.map((row) => '${row['__key']}').toSet();
            rowSelections.removeWhere((key, _) => !availableKeys.contains(key));
            for (final key in availableKeys) {
              rowSelections.putIfAbsent(key, () => true);
            }
            final selectedCount = previewRows
                .where((row) => rowSelections['${row['__key']}'] == true)
                .length;

            return AlertDialog(
              title: Text(_t('Buat Laporan PDF', 'Generate PDF Report')),
              content: SizedBox(
                width: 560,
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
                      const SizedBox(height: 10),
                      Text(
                        _t('Orientasi Kertas', 'Page Orientation'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setDialogState(() => orientation = 'auto'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: orientation == 'auto'
                                    ? AppColors.blue
                                    : AppColors.textMutedFor(context),
                                borderColor: orientation == 'auto'
                                    ? AppColors.blue
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Otomatis', 'Auto')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setDialogState(
                                  () => orientation = 'landscape'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: orientation == 'landscape'
                                    ? AppColors.blue
                                    : AppColors.textMutedFor(context),
                                borderColor: orientation == 'landscape'
                                    ? AppColors.blue
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Landscape', 'Landscape')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setDialogState(
                                  () => orientation = 'portrait'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: orientation == 'portrait'
                                    ? AppColors.blue
                                    : AppColors.textMutedFor(context),
                                borderColor: orientation == 'portrait'
                                    ? AppColors.blue
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Portrait', 'Portrait')),
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
                                  () => customerKind = 'company'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: customerKind == 'company'
                                    ? AppColors.success
                                    : AppColors.textMutedFor(context),
                                borderColor: customerKind == 'company'
                                    ? AppColors.success
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Perusahaan', 'Company')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setDialogState(
                                  () => customerKind = 'personal'),
                              style: CvantButtonStyles.outlined(
                                context,
                                color: customerKind == 'personal'
                                    ? AppColors.warning
                                    : AppColors.textMutedFor(context),
                                borderColor: customerKind == 'personal'
                                    ? AppColors.warning
                                    : AppColors.cardBorder(context),
                              ),
                              child: Text(_t('Pribadi', 'Personal')),
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
                              flex: 2,
                              child: DropdownButtonFormField<int>(
                                initialValue: selectedMonth,
                                decoration: InputDecoration(
                                  labelText: _t('Bulan', 'Month'),
                                ),
                                items: List.generate(
                                  12,
                                  (index) => DropdownMenuItem<int>(
                                    value: index + 1,
                                    child: Text(monthLabel(index + 1)),
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
                        onChanged: (value) =>
                            setDialogState(() => includeIncome = value ?? true),
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
                          style:
                              TextStyle(color: AppColors.textMutedFor(context)),
                        )
                      else
                        SizedBox(
                          height: max(60, min(180, 36.0 * allStatuses.length)),
                          child: ListView.builder(
                            itemCount: allStatuses.length,
                            itemBuilder: (context, index) {
                              final status = allStatuses[index];
                              final checked = selectedStatuses.contains(status);
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
                          'Hasil filter: ${previewRows.length} data • Dipilih: $selectedCount',
                          'Filtered result: ${previewRows.length} rows • Selected: $selectedCount',
                        ),
                        style: TextStyle(
                          color: AppColors.textMutedFor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            _t('Pilih Invoice Manual',
                                'Manual Invoice Selection'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: previewRows.isEmpty
                                ? null
                                : () => setDialogState(() {
                                      for (final row in previewRows) {
                                        rowSelections['${row['__key']}'] = true;
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
                            child: Text(_t('Hapus Pilihan', 'Clear Selection')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (previewRows.isEmpty)
                        Text(
                          _t('Tidak ada invoice pada filter ini.',
                              'No invoices in this filter.'),
                          style:
                              TextStyle(color: AppColors.textMutedFor(context)),
                        )
                      else
                        SizedBox(
                          height: 220,
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
                              final amountLabel = income > 0
                                  ? '${_t('Income', 'Income')}: ${Formatters.rupiah(income)}'
                                  : '${_t('Expense', 'Expense')}: ${Formatters.rupiah(expense)}';
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                value: checked,
                                onChanged: (value) => setDialogState(
                                  () => rowSelections[key] = value ?? false,
                                ),
                                title: Text(
                                  '${row['__number'] ?? '-'} • ${Formatters.dmy(row['__date'])}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  amountLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
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
                      'orientation': orientation,
                      'customerKind': customerKind,
                      'month': selectedMonth,
                      'year': selectedYear,
                      'statuses': selectedStatuses.toList(),
                      'keyword': keywordText.trim(),
                      'selectedKeys': rowSelections.entries
                          .where((entry) => entry.value)
                          .map((entry) => entry.key)
                          .toList(),
                    });
                  },
                  style: CvantButtonStyles.filled(context,
                      color: AppColors.success),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(_t('Cetak PDF', 'Print PDF')),
                ),
              ],
            );
          },
        );
      },
    );
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
    final selectedOrientation = '${selection['orientation'] ?? 'auto'}';
    final statusFilters =
        (selection['statuses'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => '$item')
            .toSet();
    final selectedKeys =
        (selection['selectedKeys'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => '$item')
            .toSet();
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
      customerKind: selectedCustomerKind,
      allowedStatuses: statusFilters,
      keyword: keyword,
    );
    final rows = selectedKeys.isEmpty
        ? <Map<String, dynamic>>[]
        : allRows
            .where((row) => selectedKeys.contains('${row['__key']}'))
            .toList();

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

    final totalIncome = rows
        .where((row) => '${row['__type']}' == 'Income')
        .fold<double>(0, (sum, row) => sum + _toNum(row['__income']));
    final totalExpense = rows
        .where((row) => '${row['__type']}' == 'Expense')
        .fold<double>(0, (sum, row) => sum + _toNum(row['__expense']));

    try {
      await printReportPdf(
        start: start,
        end: end,
        rows: rows,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        includeIncome: includeIncomeSelected,
        includeExpense: includeExpenseSelected,
        customerKind: selectedCustomerKind,
        orientation: selectedOrientation,
      );
      if (!mounted) return;
      _snack(
        _t(
          'Report PDF berhasil dibuat (${rows.length} data).',
          'PDF report generated successfully (${rows.length} rows).',
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

  Future<void> _openInvoicePreview(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        final detailList = _toDetailList(item['rincian']);
        final customerName = '${item['nama_pelanggan'] ?? ''}'.trim();
        final isCompanyInvoice = _resolveIsCompanyInvoice(
          invoiceNumber: item['no_invoice'],
          customerName: customerName,
        );
        final subtotal = _toNum(item['total_biaya']);
        final pph = isCompanyInvoice ? _toNum(item['pph']) : 0.0;
        final total = isCompanyInvoice ? max(0.0, subtotal - pph) : subtotal;
        final invoiceTitle = Formatters.invoiceNumber(
          item['no_invoice'],
          item['tanggal_kop'] ?? item['tanggal'],
          customerName: item['nama_pelanggan'],
        );
        return AlertDialog(
          title: Text('${_t('Preview', 'Preview')} $invoiceTitle'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${_t('Customer', 'Customer')}: ${item['nama_pelanggan'] ?? '-'}'),
                  Text('${_t('Email', 'Email')}: ${item['email'] ?? '-'}'),
                  Text(
                      '${_t('Tanggal', 'Date')}: ${Formatters.dmy(item['tanggal'])}'),
                  Text('${_t('Status', 'Status')}: ${item['status'] ?? '-'}'),
                  const SizedBox(height: 8),
                  Text(
                    '${_t('Total', 'Total')}: ${Formatters.rupiah(total)}',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (detailList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _t('Rincian', 'Details'),
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ...detailList.map((row) {
                      final tonase = _toNum(row['tonase']);
                      final harga = _toNum(row['harga']);
                      final driver = '${row['nama_supir'] ?? ''}'.trim();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          driver.isEmpty
                              ? '- ${row['lokasi_muat'] ?? '-'} -> ${row['lokasi_bongkar'] ?? '-'} | ${tonase.toStringAsFixed(2)} x ${Formatters.rupiah(harga)}'
                              : '- ${row['lokasi_muat'] ?? '-'} -> ${row['lokasi_bongkar'] ?? '-'} | Supir: $driver | ${tonase.toStringAsFixed(2)} x ${Formatters.rupiah(harga)}',
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () => _printInvoicePdf(item, detailList),
              style: CvantButtonStyles.outlined(
                context,
                color: AppColors.blue,
                borderColor: AppColors.blue,
                minimumSize: const Size(96, 40),
              ),
              icon: const Icon(Icons.print_outlined, size: 16),
              label: Text(_t('Print', 'Print')),
            ),
            FilledButton(
              style: CvantButtonStyles.filled(
                context,
                color: AppColors.blue,
                minimumSize: const Size(96, 40),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Tutup', 'Close')),
            ),
          ],
        );
      },
    );
  }

  bool _isCompanyInvoiceNumber(String number) {
    final resolved = _companyModeFromInvoiceNumber(number);
    return resolved ?? true;
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

  bool? _companyModeFromInvoiceNumber(String number) {
    final compact = number.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return null;
    if (compact.contains('CV.ANT') || compact.contains('/CV.ANT/')) {
      return true;
    }
    if (compact.contains('/BS/') || compact.contains('/ANT/')) {
      return false;
    }
    return null;
  }

  bool _resolveIsCompanyInvoice({
    dynamic invoiceNumber,
    dynamic customerName,
    bool fallback = true,
  }) {
    final fromNumber =
        _companyModeFromInvoiceNumber('${invoiceNumber ?? ''}'.trim());
    if (fromNumber != null) return fromNumber;
    final name = '${customerName ?? ''}'.trim();
    if (name.isNotEmpty) return _isCompanyCustomerName(name);
    return fallback;
  }

  String _displayInvoiceNumber(String number) {
    return number.trim().isEmpty ? '-' : number.trim();
  }

  String _safePdfFileName(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'invoice' : safe;
  }

  Future<void> _printInvoicePdf(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> detailList,
  ) async {
    try {
      // <= 13 detail rows: print in half-sheet layout (50:50 on portrait paper).
      // > 13 detail rows: switch to full-sheet portrait layout.
      final usePortrait = detailList.length > 13;
      final invoiceRawNumber = '${item['no_invoice'] ?? '-'}';
      final customerName = '${item['nama_pelanggan'] ?? ''}';
      final isCompanyInvoice = _resolveIsCompanyInvoice(
        invoiceNumber: invoiceRawNumber,
        customerName: customerName,
      );
      final subtotal = _toNum(item['total_biaya']);
      final pph = isCompanyInvoice ? _toNum(item['pph']) : 0.0;
      final total = isCompanyInvoice
          ? _toNum(item['total_bayar'] ?? item['total_biaya'])
          : subtotal;
      final invoiceNumber = _displayInvoiceNumber(
        Formatters.invoiceNumber(
          invoiceRawNumber,
          item['tanggal_kop'] ?? item['tanggal'],
          customerName: customerName,
          isCompany: isCompanyInvoice,
        ),
      );
      pw.MemoryImage? kopLogo;
      try {
        final logoBytes = await rootBundle.load('assets/images/iconapk.png');
        kopLogo = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {
        kopLogo = null;
      }
      final armadas = await widget.repository.fetchArmadas();
      final armadaPlateById = <String, String>{
        for (final armada in armadas)
          '${armada['id'] ?? ''}':
              '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
      };

      String resolveNoPolisi(Map<String, dynamic> row) {
        final rowArmadaId = '${row['armada_id'] ?? item['armada_id'] ?? ''}';
        final byArmada = armadaPlateById[rowArmadaId.trim()];
        if (byArmada != null && byArmada.isNotEmpty && byArmada != '-') {
          return byArmada;
        }
        final direct = '${row['plat_nomor'] ?? row['no_polisi'] ?? ''}'
            .trim()
            .toUpperCase();
        if (direct.isNotEmpty && direct != '-') return direct;
        final armadaManual = '${row['armada_manual'] ?? ''}'.trim();
        final armadaLabel = armadaManual.isNotEmpty
            ? armadaManual
            : '${row['armada_label'] ?? row['armada'] ?? ''}';
        final match = RegExp(
          r'\b[A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{1,3}\b',
        ).firstMatch(armadaLabel.toUpperCase());
        return (match?.group(0) ?? '-').trim();
      }

      String formatTonase(dynamic value) {
        final tonase = _toNum(value);
        if (tonase == tonase.roundToDouble()) {
          return tonase.toStringAsFixed(0);
        }
        return tonase
            .toStringAsFixed(3)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
      }

      int extraBlankRowsForMultiSheet({
        required int dataRows,
        required int baseRowsPerSheet,
      }) {
        // Request: when invoice spans multiple sheets, add 7 blank rows
        // on each sheet while keeping row height consistent.
        if (dataRows <= baseRowsPerSheet) return 0;
        const extraPerSheet = 7;
        var sheetCount = (dataRows / baseRowsPerSheet).ceil();
        var totalRowsWithPadding = dataRows + (sheetCount * extraPerSheet);
        while ((totalRowsWithPadding / baseRowsPerSheet).ceil() != sheetCount) {
          sheetCount = (totalRowsWithPadding / baseRowsPerSheet).ceil();
          totalRowsWithPadding = dataRows + (sheetCount * extraPerSheet);
        }
        return totalRowsWithPadding - dataRows;
      }

      pw.Widget buildInvoiceContent({
        required bool compact,
      }) {
        const infoFont = 9.5;
        final signatureLeftOffset = compact ? 72.0 : 86.0;
        final signatureNameOffset = compact ? 5.0 : 6.0;
        final baseRowsPerSheet = compact
            ? (isCompanyInvoice ? 13 : 16)
            : (isCompanyInvoice ? 35 : 38);
        final extraRows = extraBlankRowsForMultiSheet(
          dataRows: detailList.length,
          baseRowsPerSheet: baseRowsPerSheet,
        );
        final minRows = max(baseRowsPerSheet, detailList.length + extraRows);
        final printableRows = detailList.length >= minRows
            ? detailList
            : <Map<String, dynamic>>[
                ...detailList,
                ...List<Map<String, dynamic>>.generate(
                  minRows - detailList.length,
                  (_) => <String, dynamic>{},
                ),
              ];
        String? printable(dynamic value) {
          final raw = value?.toString().trim() ?? '';
          if (raw.isEmpty || raw == '-' || raw.toLowerCase() == 'null') {
            return null;
          }
          return raw;
        }

        final customerName = printable(item['nama_pelanggan']) ?? '-';
        final tanggalKop = item['tanggal_kop'] ?? item['tanggal'];
        final kopLocation = printable(item['lokasi_kop']);
        String toTitleCase(String value) {
          final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
          if (normalized.isEmpty) return normalized;
          return normalized.split(' ').map((word) {
            if (word.isEmpty) return word;
            final lower = word.toLowerCase();
            return lower.substring(0, 1).toUpperCase() + lower.substring(1);
          }).join(' ');
        }

        final kopLocationTitle =
            kopLocation == null ? null : toTitleCase(kopLocation);
        final kopLocationUpper = kopLocation?.toUpperCase();
        String formatLongDateId(dynamic value) {
          final date = Formatters.parseDate(value);
          if (date == null) return '-';
          const monthNames = <String>[
            'Januari',
            'Februari',
            'Maret',
            'April',
            'Mei',
            'Juni',
            'Juli',
            'Agustus',
            'September',
            'Oktober',
            'November',
            'Desember',
          ];
          return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
        }

        final tanggalLong = formatLongDateId(tanggalKop);
        final tanggalRow = kopLocationTitle == null || kopLocationTitle.isEmpty
            ? tanggalLong
            : '$kopLocationTitle, $tanggalLong';
        final logoHeight = compact ? 42.0 : 56.0;
        const tableRowVPadding = 2.4;
        const tableBodyRowHeight = 16.0;
        final invoiceBlockWidth = compact ? 156.0 : 196.0;
        final kopWordStyle = pw.TextStyle(
          fontSize: compact ? 34.0 : 47.0,
          fontWeight: pw.FontWeight.bold,
          fontStyle: pw.FontStyle.italic,
          letterSpacing: 5.0,
          wordSpacing: 1.15,
          color: PdfColors.blue900,
        );
        pw.Widget buildUltraBoldKop(String text) {
          // Keep boldness very strong while avoiding vertical clipping.
          // We bias thickness to the right (X) and keep Y spread thinner.
          final maxX = compact ? 3.2 : 4.8;
          final maxY = compact ? 0.62 : 0.90;
          final stepX = compact ? 0.14 : 0.20;
          final stepY = compact ? 0.14 : 0.20;
          final layers = <pw.Widget>[
            // Non-positioned base text keeps Stack intrinsic size valid.
            pw.Text(text, style: kopWordStyle),
          ];
          for (double dx = 0; dx <= maxX + 0.0001; dx += stepX) {
            for (double dy = 0; dy <= maxY + 0.0001; dy += stepY) {
              if (dx.abs() < 0.0001 && dy.abs() < 0.0001) continue;
              final ellipseNorm =
                  ((dx * dx) / (maxX * maxX)) + ((dy * dy) / (maxY * maxY));
              if (ellipseNorm > 1.0) continue;
              layers.add(
                pw.Positioned(
                  left: dx,
                  top: dy,
                  child: pw.Text(text, style: kopWordStyle),
                ),
              );
            }
          }
          return pw.Padding(
            // Extra right/bottom room so ultra-bold layers never get clipped.
            padding: pw.EdgeInsets.only(right: maxX + 0.8, bottom: maxY + 0.4),
            child: pw.Stack(
              children: layers,
            ),
          );
        }

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (isCompanyInvoice) ...[
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (kopLogo != null)
                      pw.Image(
                        kopLogo,
                        height: logoHeight,
                        width: logoHeight,
                        fit: pw.BoxFit.contain,
                      )
                    else
                      pw.SizedBox(
                        height: logoHeight,
                        width: logoHeight,
                      ),
                    pw.SizedBox(width: 4),
                    pw.Expanded(
                      child: pw.Container(
                        height: logoHeight,
                        alignment: pw.Alignment.topLeft,
                        child: buildUltraBoldKop('CV AS NUSA TRANS'),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 1.5),
              pw.Container(
                width: double.infinity,
                height: 1.2,
                color: PdfColors.black,
              ),
              pw.SizedBox(height: 4),
            ],
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: invoiceBlockWidth,
                      child: pw.Center(
                        child: pw.Text(
                          'I N V O I C E',
                          style: pw.TextStyle(
                            fontSize: compact ? 18 : 23,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 1.5),
                    pw.Container(
                      width: invoiceBlockWidth,
                      height: 0.9,
                      color: PdfColors.grey700,
                    ),
                    pw.SizedBox(height: 2.5),
                    pw.SizedBox(
                      width: invoiceBlockWidth,
                      child: pw.Center(
                        child: pw.Text(
                          'NO : $invoiceNumber',
                          style: pw.TextStyle(
                            fontSize: compact ? 10 : 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      tanggalRow,
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: infoFont),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Kepada Yth:',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: infoFont),
                        ),
                        pw.SizedBox(width: 4),
                        pw.Container(
                          width: compact ? 88 : 126,
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.only(bottom: 1),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(
                                color: PdfColors.grey700,
                                width: 0.9,
                              ),
                            ),
                          ),
                          child: pw.Text(
                            customerName,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: infoFont,
                              fontWeight: pw.FontWeight.bold,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        // Keep placement consistent with previous layout, but
                        // remove visible "Lokasi:" label as requested.
                        pw.SizedBox(width: compact ? 32 : 36),
                        pw.Container(
                          width: compact ? 88 : 126,
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.only(bottom: 1),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(
                                color: PdfColors.grey700,
                                width: 0.9,
                              ),
                            ),
                          ),
                          child: pw.Text(
                            kopLocationUpper ?? '-',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: infoFont,
                              fontWeight: pw.FontWeight.bold,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: _buildIncomeTableColumnWidths(printableRows),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor(0.12, 0.13, 0.15),
                  ),
                  children: [
                    _pdfCell(
                      'NO',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 3,
                      minFontSize: 7,
                    ),
                    _pdfCell(
                      'TANGGAL',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 8,
                      minFontSize: 6.8,
                    ),
                    _pdfCell(
                      'PLAT',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 6,
                      minFontSize: 6.8,
                    ),
                    _pdfCell(
                      'MUATAN',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 8,
                      minFontSize: 6.8,
                    ),
                    _pdfCell(
                      'MUAT',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 6,
                      minFontSize: 6.8,
                    ),
                    _pdfCell(
                      'BONGKAR',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 8,
                      minFontSize: 6.8,
                    ),
                    _pdfCell(
                      'TONASE',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 8,
                      minFontSize: 6.8,
                    ),
                    _pdfCell(
                      'HARGA',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 7,
                      minFontSize: 6.8,
                    ),
                    _pdfCell(
                      'TOTAL',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 7,
                      minFontSize: 6.8,
                    ),
                  ],
                ),
                ...List<pw.TableRow>.generate(printableRows.length, (index) {
                  final row = printableRows[index];
                  final hasData = index < detailList.length;
                  const blankCell = '\u00A0';
                  final tonase = hasData ? _toNum(row['tonase']) : 0;
                  final harga = hasData ? _toNum(row['harga']) : 0;
                  final rowSubtotal = tonase * harga;
                  final armadaStartSource = row['armada_start_date'] ??
                      item['armada_start_date'] ??
                      row['tanggal'] ??
                      item['tanggal'];
                  final tanggal =
                      hasData ? Formatters.dmy(armadaStartSource) : blankCell;
                  return pw.TableRow(
                    children: [
                      _pdfCell(
                        hasData ? '${index + 1}' : blankCell,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 2,
                        minFontSize: 7,
                      ),
                      _pdfCell(
                        tanggal,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 10,
                      ),
                      _pdfCell(
                        hasData ? resolveNoPolisi(row) : blankCell,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 12,
                      ),
                      _pdfCell(
                        hasData ? '${row['muatan'] ?? '-'}' : blankCell,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 14,
                        minFontSize: 6.5,
                      ),
                      _pdfCell(
                        hasData ? '${row['lokasi_muat'] ?? '-'}' : blankCell,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 32,
                        minFontSize: 6.5,
                      ),
                      _pdfCell(
                        hasData ? '${row['lokasi_bongkar'] ?? '-'}' : blankCell,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 32,
                        minFontSize: 6.5,
                      ),
                      _pdfCell(
                        hasData ? formatTonase(tonase) : blankCell,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 8,
                      ),
                      _pdfCell(
                        hasData ? Formatters.rupiah(harga) : blankCell,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 10,
                        minFontSize: 6.2,
                      ),
                      _pdfCell(
                        hasData ? Formatters.rupiah(rowSubtotal) : blankCell,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 12,
                        minFontSize: 6.8,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Padding(
                    padding: pw.EdgeInsets.only(left: signatureLeftOffset),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Hormat kami,'),
                        pw.SizedBox(height: compact ? 72 : 102),
                        pw.Padding(
                          padding:
                              pw.EdgeInsets.only(left: signatureNameOffset),
                          child: pw.Text(
                            'A N T O K',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.SizedBox(
                  width: compact ? 200 : 220,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Subtotal',
                            style: const pw.TextStyle(fontSize: infoFont),
                          ),
                          pw.Text(
                            Formatters.rupiah(subtotal),
                            style: const pw.TextStyle(fontSize: infoFont),
                          ),
                        ],
                      ),
                      if (isCompanyInvoice) ...[
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'PPH (2%)',
                              style: const pw.TextStyle(fontSize: infoFont),
                            ),
                            pw.Text(
                              Formatters.rupiah(pph),
                              style: const pw.TextStyle(fontSize: infoFont),
                            ),
                          ],
                        ),
                      ],
                      pw.Divider(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Bayar',
                            style: pw.TextStyle(
                              fontSize: infoFont,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            Formatters.rupiah(total),
                            style: pw.TextStyle(
                              fontSize: infoFont,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      }

      await Printing.layoutPdf(
        name: 'invoice-${_safePdfFileName(invoiceRawNumber)}',
        onLayout: (format) async {
          final doc = pw.Document();
          final portraitFormat =
              format.width <= format.height ? format : format.landscape;
          final margin = usePortrait ? 24.0 : 18.0;

          if (usePortrait) {
            doc.addPage(
              pw.MultiPage(
                pageFormat: portraitFormat,
                margin: pw.EdgeInsets.all(margin),
                build: (_) => [
                  buildInvoiceContent(compact: false),
                ],
              ),
            );
          } else {
            final usableHeight = portraitFormat.height - (margin * 2);
            final halfHeight = usableHeight / 2;
            doc.addPage(
              pw.Page(
                pageFormat: portraitFormat,
                margin: pw.EdgeInsets.all(margin),
                build: (_) {
                  return pw.Column(
                    children: [
                      pw.Container(
                        height: halfHeight,
                        padding: const pw.EdgeInsets.only(bottom: 8),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                              color: PdfColors.grey400,
                              width: 0.7,
                            ),
                          ),
                        ),
                        child: buildInvoiceContent(compact: true),
                      ),
                      pw.SizedBox(
                        height: halfHeight,
                      ),
                    ],
                  );
                },
              ),
            );
          }
          return doc.save();
        },
      );
    } catch (e) {
      if (!mounted) return;
      _snack(
        'Gagal print invoice: ${e.toString().replaceFirst('Exception: ', '')}',
        error: true,
      );
    }
  }

  Map<int, pw.TableColumnWidth> _buildIncomeTableColumnWidths(
    List<Map<String, dynamic>> detailList,
  ) {
    var maxMuat = 12;
    var maxBongkar = 12;
    var maxPlate = 8;
    var maxMuatan = 8;
    var maxHarga = 10;
    var maxTotal = 10;
    for (final row in detailList) {
      maxMuat = max(maxMuat, '${row['lokasi_muat'] ?? ''}'.trim().length);
      maxBongkar = max(
        maxBongkar,
        '${row['lokasi_bongkar'] ?? ''}'.trim().length,
      );
      maxMuatan = max(maxMuatan, '${row['muatan'] ?? ''}'.trim().length);
      final plate = '${row['plat_nomor'] ?? row['no_polisi'] ?? ''}'.trim();
      maxPlate = max(maxPlate, plate.length);
      final hargaText = Formatters.rupiah(_toNum(row['harga']));
      final totalText =
          Formatters.rupiah(_toNum(row['tonase']) * _toNum(row['harga']));
      maxHarga = max(maxHarga, hargaText.length);
      maxTotal = max(maxTotal, totalText.length);
    }

    final totalRouteChars = max(1, maxMuat + maxBongkar);
    final muatShare = maxMuat / totalRouteChars;
    final bongkarShare = maxBongkar / totalRouteChars;
    const routeBudgetFlex = 2.10;
    final muatFlex = (routeBudgetFlex * muatShare).clamp(1.0, 1.55).toDouble();
    final bongkarFlex =
        (routeBudgetFlex * bongkarShare).clamp(1.0, 1.55).toDouble();
    final plateFlex = (maxPlate / 9).clamp(1.0, 1.35).toDouble();
    final muatanFlex = (maxMuatan / 8.5).clamp(0.95, 1.45).toDouble();
    final hargaFlex = (maxHarga / 13).clamp(0.58, 0.82).toDouble();
    final totalFlex = (maxTotal / 8.6).clamp(1.30, 1.90).toDouble();

    return {
      0: const pw.FixedColumnWidth(30), // No
      1: const pw.FlexColumnWidth(1.05), // Tanggal
      2: pw.FlexColumnWidth(plateFlex), // Plat
      3: pw.FlexColumnWidth(muatanFlex), // Muatan
      4: pw.FlexColumnWidth(muatFlex), // Muat
      5: pw.FlexColumnWidth(bongkarFlex), // Bongkar
      6: const pw.FlexColumnWidth(0.72), // Tonase
      7: pw.FlexColumnWidth(hargaFlex), // Harga
      8: pw.FlexColumnWidth(totalFlex), // Total
    };
  }

  Map<int, pw.TableColumnWidth> _buildExpenseTableColumnWidths(
    List<Map<String, dynamic>> detailList,
  ) {
    var maxDesc = 14;
    for (final row in detailList) {
      maxDesc =
          max(maxDesc, '${row['nama'] ?? row['name'] ?? ''}'.trim().length);
    }
    final descFlex = (maxDesc / 8).clamp(2.4, 3.5).toDouble();
    return {
      0: const pw.FixedColumnWidth(24), // No
      1: const pw.FlexColumnWidth(0.95), // Tanggal
      2: pw.FlexColumnWidth(descFlex), // Keterangan
      3: const pw.FlexColumnWidth(1.2), // Total
    };
  }

  Future<void> _printExpensePdf(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> detailList,
  ) async {
    try {
      final rows = detailList.isNotEmpty
          ? detailList
          : <Map<String, dynamic>>[
              {
                'nama': '${item['kategori'] ?? item['keterangan'] ?? '-'}',
                'jumlah': _toNum(item['total_pengeluaran']),
              },
            ];

      final usePortrait = rows.length > 13;
      final totalExpense = _toNum(item['total_pengeluaran']);
      final expenseNumber = '${item['no_expense'] ?? '-'}';

      pw.Widget buildExpenseContent({required bool compact}) {
        const infoFont = 9.5;
        const tableBodyRowHeight = 16.0;
        final minRows = compact ? 13 : 35;
        final printableRows = rows.length >= minRows
            ? rows
            : <Map<String, dynamic>>[
                ...rows,
                ...List<Map<String, dynamic>>.generate(
                  minRows - rows.length,
                  (_) => <String, dynamic>{},
                ),
              ];
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CV ANT',
                          style: pw.TextStyle(
                            fontSize: compact ? 15 : 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'AS Nusa Trans',
                          style: pw.TextStyle(
                            fontSize: compact ? 10 : 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'EXPENSE',
                        style: pw.TextStyle(
                          fontSize: compact ? 15 : 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        expenseNumber,
                        style: pw.TextStyle(
                          fontSize: compact ? 10 : 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Tanggal: ${Formatters.dmy(item['tanggal'])}',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: infoFont),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Data Expense',
                          style: pw.TextStyle(
                            fontSize: infoFont,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Kategori: ${item['kategori'] ?? '-'}',
                          style: const pw.TextStyle(fontSize: infoFont),
                        ),
                        pw.Text(
                          'Keterangan: ${item['keterangan'] ?? item['note'] ?? '-'}',
                          style: const pw.TextStyle(fontSize: infoFont),
                        ),
                        pw.Text(
                          'Dicatat oleh: ${item['dicatat_oleh'] ?? '-'}',
                          style: const pw.TextStyle(fontSize: infoFont),
                        ),
                        pw.Text(
                          'Status: ${item['status'] ?? '-'}',
                          style: const pw.TextStyle(fontSize: infoFont),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.SizedBox(width: compact ? 130 : 160),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: _buildExpenseTableColumnWidths(printableRows),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor(0.12, 0.13, 0.15),
                  ),
                  children: [
                    _pdfCell('NO', bold: true, textColor: PdfColors.white),
                    _pdfCell(
                      'TANGGAL',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                    ),
                    _pdfCell(
                      'KETERANGAN',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                    ),
                    _pdfCell(
                      'TOTAL',
                      bold: true,
                      alignRight: true,
                      textColor: PdfColors.white,
                    ),
                  ],
                ),
                ...List<pw.TableRow>.generate(printableRows.length, (index) {
                  final row = printableRows[index];
                  final hasData = index < rows.length;
                  final amount =
                      hasData ? _toNum(row['jumlah'] ?? row['amount']) : 0;
                  final tanggal = hasData
                      ? Formatters.dmy(
                          row['tanggal'] ?? item['tanggal'],
                        )
                      : '';
                  final name =
                      hasData ? '${row['nama'] ?? row['name'] ?? '-'}' : '';
                  return pw.TableRow(
                    children: [
                      _pdfCell(
                        hasData ? '${index + 1}' : '',
                        alignCenter: true,
                        hPadding: 3,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 2,
                        minFontSize: 7,
                      ),
                      _pdfCell(
                        tanggal,
                        alignCenter: true,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 10,
                      ),
                      _pdfCell(
                        name,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 34,
                        minFontSize: 6.5,
                      ),
                      _pdfCell(
                        hasData ? Formatters.rupiah(amount) : '',
                        alignRight: true,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 14,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: compact ? 200 : 220,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Pengeluaran',
                      style: pw.TextStyle(
                        fontSize: infoFont,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      Formatters.rupiah(totalExpense),
                      style: pw.TextStyle(
                        fontSize: infoFont,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Hormat kami,'),
                  pw.SizedBox(height: compact ? 72 : 102),
                  pw.Text(
                    'A N T O K',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      await Printing.layoutPdf(
        name: 'expense-$expenseNumber',
        onLayout: (format) async {
          final doc = pw.Document();
          final portraitFormat =
              format.width <= format.height ? format : format.landscape;
          final margin = usePortrait ? 24.0 : 18.0;

          if (usePortrait) {
            doc.addPage(
              pw.MultiPage(
                pageFormat: portraitFormat,
                margin: pw.EdgeInsets.all(margin),
                build: (_) => [
                  buildExpenseContent(compact: false),
                ],
              ),
            );
          } else {
            final usableHeight = portraitFormat.height - (margin * 2);
            final halfHeight = usableHeight / 2;
            doc.addPage(
              pw.Page(
                pageFormat: portraitFormat,
                margin: pw.EdgeInsets.all(margin),
                build: (_) {
                  return pw.Column(
                    children: [
                      pw.Container(
                        height: halfHeight,
                        padding: const pw.EdgeInsets.only(bottom: 8),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                              color: PdfColors.grey400,
                              width: 0.7,
                            ),
                          ),
                        ),
                        child: buildExpenseContent(compact: true),
                      ),
                      pw.SizedBox(height: halfHeight),
                    ],
                  );
                },
              ),
            );
          }
          return doc.save();
        },
      );
    } catch (e) {
      if (!mounted) return;
      _snack(
        'Gagal print expense: ${e.toString().replaceFirst('Exception: ', '')}',
        error: true,
      );
    }
  }

  pw.Widget _pdfCell(
    String text, {
    bool bold = false,
    bool alignRight = false,
    bool alignCenter = false,
    PdfColor? textColor,
    double fontSize = 9.5,
    double minFontSize = 7.0,
    double hPadding = 6,
    double vPadding = 5,
    double? fixedHeight,
    bool singleLineAutoShrink = false,
    int softLimitChars = 24,
  }) {
    final textAlign = alignRight
        ? pw.TextAlign.right
        : alignCenter
            ? pw.TextAlign.center
            : pw.TextAlign.left;
    var resolvedFontSize = fontSize;
    if (singleLineAutoShrink) {
      final safeLimit = max(1, softLimitChars);
      final textLength = text.trim().length;
      if (textLength > safeLimit) {
        final ratio = safeLimit / textLength;
        resolvedFontSize = max(minFontSize, fontSize * ratio);
      }
    }
    return pw.Container(
      height: fixedHeight,
      alignment: alignCenter
          ? pw.Alignment.center
          : alignRight
              ? pw.Alignment.centerRight
              : pw.Alignment.centerLeft,
      child: pw.Padding(
        padding:
            pw.EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
        child: pw.Text(
          text,
          maxLines: singleLineAutoShrink ? 1 : null,
          textAlign: textAlign,
          style: pw.TextStyle(
            fontSize: resolvedFontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Future<void> _openExpensePreview(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        final detailList = _toDetailList(item['rincian']);
        return AlertDialog(
          title:
              Text('${_t('Preview', 'Preview')} ${item['no_expense'] ?? '-'}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${_t('Kategori', 'Category')}: ${item['kategori'] ?? '-'}'),
                  Text(
                      '${_t('Keterangan', 'Description')}: ${item['keterangan'] ?? item['note'] ?? '-'}'),
                  Text(
                      '${_t('Tanggal', 'Date')}: ${Formatters.dmy(item['tanggal'])}'),
                  Text('${_t('Status', 'Status')}: ${item['status'] ?? '-'}'),
                  Text(
                      '${_t('Dicatat oleh', 'Recorded by')}: ${item['dicatat_oleh'] ?? '-'}'),
                  const SizedBox(height: 8),
                  Text(
                    '${_t('Total', 'Total')}: ${Formatters.rupiah(_toNum(item['total_pengeluaran']))}',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (detailList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _t('Rincian', 'Details'),
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ...detailList.map((row) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '- ${row['nama'] ?? row['name'] ?? '-'}: ${Formatters.rupiah(_toNum(row['jumlah'] ?? row['amount']))}',
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () => _printExpensePdf(item, detailList),
              style: CvantButtonStyles.outlined(
                context,
                color: AppColors.blue,
                borderColor: AppColors.blue,
                minimumSize: const Size(96, 40),
              ),
              icon: const Icon(Icons.print_outlined, size: 16),
              label: Text(_t('Print', 'Print')),
            ),
            FilledButton(
              style: CvantButtonStyles.filled(
                context,
                color: AppColors.blue,
                minimumSize: const Size(96, 40),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Tutup', 'Close')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openInvoiceEdit(Map<String, dynamic> item) async {
    final customer =
        TextEditingController(text: '${item['nama_pelanggan'] ?? ''}');
    final email = TextEditingController(text: '${item['email'] ?? ''}');
    final phone = TextEditingController(text: '${item['no_telp'] ?? ''}');
    final kopDate = TextEditingController(
      text: _toInputDate(item['tanggal_kop'] ?? item['tanggal']),
    );
    final kopLocation =
        TextEditingController(text: '${item['lokasi_kop'] ?? ''}');
    final dueDate = TextEditingController(
      text: _toInputDate(item['due_date']),
    );
    String status = '${item['status'] ?? 'Unpaid'}';
    String acceptedBy = '${item['diterima_oleh'] ?? 'Admin'}';
    String tanggal = _toInputDate(item['tanggal']);
    bool saving = false;
    bool isCompanyInvoiceMode = _resolveIsCompanyInvoice(
      invoiceNumber: item['no_invoice'],
      customerName: item['nama_pelanggan'],
    );

    List<Map<String, dynamic>> armadas = const <Map<String, dynamic>>[];
    try {
      armadas = await widget.repository.fetchArmadas();
    } catch (_) {}
    final armadaIdByPlate = _buildArmadaIdByPlate(armadas);

    Map<String, dynamic> mapDetailRow(Map<String, dynamic> row) {
      final rawArmadaId = '${row['armada_id'] ?? ''}'.trim();
      final rawManual =
          '${row['armada_manual'] ?? row['armada_label'] ?? row['armada'] ?? ''}'
              .trim();
      final resolvedArmadaId = _resolveArmadaIdFromInput(
        armadaId: rawArmadaId,
        armadaManual: rawManual,
        armadaIdByPlate: armadaIdByPlate,
      );
      final useManual = resolvedArmadaId.isEmpty && rawManual.isNotEmpty;
      return <String, dynamic>{
        'lokasi_muat': '${row['lokasi_muat'] ?? ''}',
        'lokasi_bongkar': '${row['lokasi_bongkar'] ?? ''}',
        'muatan': '${row['muatan'] ?? ''}',
        'nama_supir': '${row['nama_supir'] ?? ''}',
        'armada_id': resolvedArmadaId,
        'armada_manual': useManual ? rawManual : '',
        'armada_is_manual': useManual,
        'armada_start_date': _toInputDate(row['armada_start_date']),
        'armada_end_date': _toInputDate(row['armada_end_date']),
        'tonase': _formatEditableNumber(row['tonase']),
        'harga': _formatEditableNumber(row['harga']),
      };
    }

    final existingDetails = _toDetailList(item['rincian']);
    final details = existingDetails.isNotEmpty
        ? existingDetails.map(mapDetailRow).toList()
        : <Map<String, dynamic>>[
            mapDetailRow(item),
          ];

    double detailSubtotal(Map<String, dynamic> row) {
      return _toNum(row['tonase']) * _toNum(row['harga']);
    }

    if (!mounted) return;
    bool dialogClosed = false;

    try {
      await showDialog<void>(
        context: context,
        barrierColor: AppColors.popupOverlay,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final subtotal = details.fold<double>(
                0,
                (sum, row) => sum + detailSubtotal(row),
              );
              final pph = isCompanyInvoiceMode ? subtotal * 0.02 : 0.0;
              final totalBayar =
                  isCompanyInvoiceMode ? max(0.0, subtotal - pph) : subtotal;

              return AlertDialog(
                title: Text(_t('Edit Invoice', 'Edit Invoice')),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('Mode Invoice', 'Invoice Mode'),
                          style:
                              TextStyle(color: AppColors.textMutedFor(context)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _buildEditInvoiceModeTab(
                                label: _t('Pribadi', 'Personal'),
                                selected: !isCompanyInvoiceMode,
                                onTap: () => setDialogState(
                                  () => isCompanyInvoiceMode = false,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildEditInvoiceModeTab(
                                label: _t('Perusahaan', 'Company'),
                                selected: isCompanyInvoiceMode,
                                onTap: () => setDialogState(
                                  () => isCompanyInvoiceMode = true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _dialogField(
                            customer, _t('Nama Customer', 'Customer Name')),
                        const SizedBox(height: 8),
                        _dialogField(
                          email,
                          _t('Email Customer', 'Customer Email'),
                          type: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 8),
                        _dialogField(
                          phone,
                          _t('No. Telp', 'Phone Number'),
                          type: TextInputType.phone,
                        ),
                        const SizedBox(height: 8),
                        _dateSelect(
                          label:
                              _t('Tanggal Kop Invoice', 'Invoice Header Date'),
                          value: kopDate.text,
                          onChanged: (v) =>
                              setDialogState(() => kopDate.text = v),
                        ),
                        const SizedBox(height: 8),
                        _dialogField(
                          kopLocation,
                          _t('Lokasi Kop Invoice', 'Invoice Header Location'),
                        ),
                        const SizedBox(height: 8),
                        _dateSelect(
                          label: _t('Tanggal Invoice', 'Invoice Date'),
                          value: tanggal,
                          onChanged: (v) => setDialogState(() => tanggal = v),
                        ),
                        const SizedBox(height: 8),
                        _dialogField(
                          dueDate,
                          _t('Jatuh Tempo (dd-mm-yyyy)',
                              'Due Date (dd-mm-yyyy)'),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _t(
                            'Rincian Muat / Bongkar & Armada',
                            'Loading / Unloading & Fleet Details',
                          ),
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        ...details.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          final rowSubtotal = detailSubtotal(row);
                          return Container(
                            margin: EdgeInsets.only(
                              bottom: index == details.length - 1 ? 0 : 10,
                            ),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.cardBorder(context),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                TextFormField(
                                  initialValue: '${row['lokasi_muat']}',
                                  decoration: InputDecoration(
                                    hintText:
                                        _t('Lokasi Muat', 'Loading Location'),
                                  ),
                                  onChanged: (value) =>
                                      row['lokasi_muat'] = value,
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: '${row['lokasi_bongkar']}',
                                  decoration: InputDecoration(
                                    hintText: _t(
                                        'Lokasi Bongkar', 'Unloading Location'),
                                  ),
                                  onChanged: (value) =>
                                      row['lokasi_bongkar'] = value,
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: '${row['muatan'] ?? ''}',
                                  decoration: InputDecoration(
                                    hintText: _t('Muatan (Opsional)',
                                        'Cargo (Optional)'),
                                  ),
                                  onChanged: (value) => row['muatan'] = value,
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: '${row['nama_supir'] ?? ''}',
                                  decoration: InputDecoration(
                                    hintText: _t('Nama Supir (Opsional)',
                                        'Driver Name (Optional)'),
                                  ),
                                  onChanged: (value) =>
                                      row['nama_supir'] = value,
                                ),
                                const SizedBox(height: 8),
                                CvantDropdownField<String>(
                                  initialValue: () {
                                    final armadaId =
                                        '${row['armada_id']}'.trim();
                                    final armadaManual =
                                        '${row['armada_manual'] ?? ''}'.trim();
                                    final isManual =
                                        row['armada_is_manual'] == true;
                                    if (armadaId.isNotEmpty) return armadaId;
                                    if (isManual || armadaManual.isNotEmpty) {
                                      return _manualArmadaOptionId;
                                    }
                                    return '';
                                  }(),
                                  decoration: InputDecoration(
                                    hintText:
                                        _t('Pilih Armada', 'Select Fleet'),
                                  ),
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: '',
                                      child: Text(_t('-- Pilih Armada --',
                                          '-- Select Fleet --')),
                                    ),
                                    ...armadas.map(
                                      (a) => DropdownMenuItem(
                                        value: '${a['id']}',
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text:
                                                    '${a['nama_truk'] ?? '-'} - ${a['plat_nomor'] ?? '-'} ',
                                              ),
                                              TextSpan(
                                                text:
                                                    '(${a['status'] ?? 'Ready'})',
                                                style: TextStyle(
                                                  color: _armadaStatusColor(
                                                    '${a['status'] ?? 'Ready'}',
                                                  ),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: _manualArmadaOptionId,
                                      child: Text(
                                        _t(
                                          'Other (Input Manual)',
                                          'Other (Manual Input)',
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value == _manualArmadaOptionId) {
                                        row['armada_id'] = '';
                                        row['armada_is_manual'] = true;
                                      } else {
                                        row['armada_id'] = value ?? '';
                                        row['armada_is_manual'] = false;
                                        if ('${row['armada_id']}'
                                            .trim()
                                            .isNotEmpty) {
                                          row['armada_manual'] = '';
                                        }
                                      }
                                    });
                                  },
                                ),
                                if (row['armada_is_manual'] == true ||
                                    ('${row['armada_manual'] ?? ''}'
                                            .trim()
                                            .isNotEmpty &&
                                        '${row['armada_id']}'
                                            .trim()
                                            .isEmpty)) ...[
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue:
                                        '${row['armada_manual'] ?? ''}',
                                    decoration: InputDecoration(
                                      hintText: _t(
                                        'Plat Nomor Manual (Other/Gabungan)',
                                        'Manual Plate Number (Other/Combined)',
                                      ),
                                    ),
                                    onChanged: (value) =>
                                        row['armada_manual'] = value,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _dateSelect(
                                        label:
                                            _t('Tanggal Mulai', 'Start Date'),
                                        value:
                                            '${row['armada_start_date'] ?? ''}',
                                        onChanged: (value) => setDialogState(
                                          () =>
                                              row['armada_start_date'] = value,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _dateSelect(
                                        label:
                                            _t('Tanggal Selesai', 'End Date'),
                                        value:
                                            '${row['armada_end_date'] ?? ''}',
                                        onChanged: (value) => setDialogState(
                                          () => row['armada_end_date'] = value,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: '${row['tonase']}',
                                        keyboardType: const TextInputType
                                            .numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: _t('Tonase', 'Tonnage'),
                                        ),
                                        onChanged: (value) {
                                          row['tonase'] = value;
                                          setDialogState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: '${row['harga']}',
                                        keyboardType: const TextInputType
                                            .numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              _t('Harga / Ton', 'Price / Ton'),
                                        ),
                                        onChanged: (value) {
                                          row['harga'] = value;
                                          setDialogState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      '${_t('Subtotal', 'Subtotal')}: ${Formatters.rupiah(rowSubtotal)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const Spacer(),
                                    if (details.length > 1)
                                      TextButton(
                                        onPressed: () => setDialogState(
                                          () => details.removeAt(index),
                                        ),
                                        style: CvantButtonStyles.text(
                                          context,
                                          color: AppColors.danger,
                                        ),
                                        child: Text(_t('Hapus', 'Delete')),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => setDialogState(() {
                            details.add(
                              <String, dynamic>{
                                'lokasi_muat': '',
                                'lokasi_bongkar': '',
                                'muatan': '',
                                'nama_supir': '',
                                'armada_id': '',
                                'armada_manual': '',
                                'armada_is_manual': false,
                                'armada_start_date': '',
                                'armada_end_date': '',
                                'tonase': '',
                                'harga': '',
                              },
                            );
                          }),
                          child: Text(_t('+ Tambah Rincian', '+ Add Detail')),
                        ),
                        const SizedBox(height: 10),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: _t('Subtotal', 'Subtotal'),
                          ),
                          child: Text(Formatters.rupiah(subtotal)),
                        ),
                        if (isCompanyInvoiceMode) ...[
                          const SizedBox(height: 8),
                          InputDecorator(
                            decoration:
                                const InputDecoration(labelText: 'PPH (2%)'),
                            child: Text(Formatters.rupiah(pph)),
                          ),
                        ],
                        const SizedBox(height: 8),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: _t('Total Bayar', 'Grand Total'),
                          ),
                          child: Text(Formatters.rupiah(totalBayar)),
                        ),
                        const SizedBox(height: 8),
                        CvantDropdownField<String>(
                          initialValue: status,
                          decoration: InputDecoration(
                            labelText: _t('Status', 'Status'),
                          ),
                          items:
                              const ['Unpaid', 'Paid', 'Waiting', 'Cancelled']
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(item),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) =>
                              setDialogState(() => status = value ?? status),
                        ),
                        const SizedBox(height: 8),
                        CvantDropdownField<String>(
                          initialValue: acceptedBy,
                          decoration: InputDecoration(
                            labelText: _t('Diterima Oleh', 'Accepted By'),
                          ),
                          items: const ['Admin', 'Owner']
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setDialogState(
                            () => acceptedBy = value ?? acceptedBy,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: saving
                                    ? null
                                    : () {
                                        dialogClosed = true;
                                        Navigator.of(context).pop();
                                      },
                                style: CvantButtonStyles.outlined(
                                  context,
                                  color: AppColors.isLight(context)
                                      ? AppColors.textSecondaryLight
                                      : const Color(0xFFE2E8F0),
                                  borderColor: AppColors.neutralOutline,
                                ),
                                child: Text(_t('Batal', 'Cancel')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        final first = details.first;
                                        if (customer.text.trim().isEmpty ||
                                            subtotal <= 0 ||
                                            tanggal.trim().isEmpty) {
                                          _snack(
                                            _t(
                                              'Nama customer, tanggal, dan total wajib diisi.',
                                              'Customer name, date, and total are required.',
                                            ),
                                            error: true,
                                          );
                                          return;
                                        }
                                        final firstArmadaId =
                                            '${first['armada_id']}'.trim();
                                        final firstArmadaManual =
                                            '${first['armada_manual'] ?? ''}'
                                                .trim();
                                        final firstResolvedArmadaId =
                                            _resolveArmadaIdFromInput(
                                          armadaId: firstArmadaId,
                                          armadaManual: firstArmadaManual,
                                          armadaIdByPlate: armadaIdByPlate,
                                        );
                                        final hasArmadaSelection =
                                            firstResolvedArmadaId.isNotEmpty ||
                                                firstArmadaManual.isNotEmpty;
                                        if ('${first['lokasi_muat']}'
                                                .trim()
                                                .isEmpty ||
                                            '${first['lokasi_bongkar']}'
                                                .trim()
                                                .isEmpty ||
                                            !hasArmadaSelection) {
                                          _snack(
                                            _t(
                                              'Lokasi muat, lokasi bongkar, dan armada wajib diisi.',
                                              'Loading location, unloading location, and fleet are required.',
                                            ),
                                            error: true,
                                          );
                                          return;
                                        }

                                        String? normalizeNullable(
                                          dynamic value,
                                        ) {
                                          final raw =
                                              value?.toString().trim() ?? '';
                                          if (raw.isEmpty) return null;
                                          final lowered = raw.toLowerCase();
                                          if (lowered == 'null' ||
                                              lowered == 'undefined' ||
                                              lowered == '-') {
                                            return null;
                                          }
                                          return raw;
                                        }

                                        final detailsPayload =
                                            details.map((row) {
                                          final armadaId =
                                              '${row['armada_id']}'.trim();
                                          final armadaManualRaw =
                                              normalizeNullable(
                                                    row['armada_manual'],
                                                  ) ??
                                                  '';
                                          final resolvedArmadaId =
                                              _resolveArmadaIdFromInput(
                                            armadaId: armadaId,
                                            armadaManual: armadaManualRaw,
                                            armadaIdByPlate: armadaIdByPlate,
                                          );
                                          final useManual =
                                              resolvedArmadaId.isEmpty &&
                                                  armadaManualRaw.isNotEmpty;
                                          return <String, dynamic>{
                                            'lokasi_muat':
                                                '${row['lokasi_muat']}'.trim(),
                                            'lokasi_bongkar':
                                                '${row['lokasi_bongkar']}'
                                                    .trim(),
                                            'muatan': normalizeNullable(
                                              row['muatan'],
                                            ),
                                            'nama_supir': normalizeNullable(
                                              row['nama_supir'],
                                            ),
                                            'armada_id':
                                                resolvedArmadaId.isEmpty
                                                    ? null
                                                    : resolvedArmadaId,
                                            'armada_manual': useManual
                                                ? armadaManualRaw
                                                : null,
                                            'armada_label': useManual
                                                ? armadaManualRaw
                                                : null,
                                            'armada_start_date':
                                                '${row['armada_start_date']}'
                                                        .trim()
                                                        .isEmpty
                                                    ? null
                                                    : _toDbDate(
                                                        '${row['armada_start_date']}',
                                                      ),
                                            'armada_end_date':
                                                '${row['armada_end_date']}'
                                                        .trim()
                                                        .isEmpty
                                                    ? null
                                                    : _toDbDate(
                                                        '${row['armada_end_date']}',
                                                      ),
                                            'tonase': _toNum(row['tonase']),
                                            'harga': _toNum(row['harga']),
                                          };
                                        }).toList();
                                        final driverNames = detailsPayload
                                            .map(
                                              (row) =>
                                                  '${row['nama_supir'] ?? ''}'
                                                      .trim(),
                                            )
                                            .where((value) => value.isNotEmpty)
                                            .expand(
                                              (value) => value
                                                  .split(RegExp(r'[,;/]'))
                                                  .map((part) => part.trim()),
                                            )
                                            .where((value) => value.isNotEmpty)
                                            .toSet()
                                            .join(', ');

                                        setDialogState(() => saving = true);
                                        try {
                                          String? regeneratedInvoiceNo;
                                          final editedDate =
                                              Formatters.parseDate(tanggal);
                                          final originalDate =
                                              Formatters.parseDate(
                                            item['tanggal'],
                                          );
                                          final editedKopDate =
                                              Formatters.parseDate(
                                                    kopDate.text.trim(),
                                                  ) ??
                                                  editedDate;
                                          final originalKopDate =
                                              Formatters.parseDate(
                                                    item['tanggal_kop'],
                                                  ) ??
                                                  originalDate;
                                          final effectiveDate = editedKopDate ??
                                              editedDate ??
                                              originalKopDate ??
                                              originalDate ??
                                              DateTime.now();
                                          final editedCustomer =
                                              customer.text.trim();
                                          final currentRawInvoiceNo =
                                              '${item['no_invoice'] ?? ''}'
                                                  .trim();
                                          final isCompanyInvoice =
                                              isCompanyInvoiceMode;

                                          final monthOrYearChanged =
                                              editedKopDate != null &&
                                                  originalKopDate != null &&
                                                  (editedKopDate.year !=
                                                          originalKopDate
                                                              .year ||
                                                      editedKopDate.month !=
                                                          originalKopDate
                                                              .month);
                                          final typeChanged =
                                              currentRawInvoiceNo.isNotEmpty &&
                                                  (_isCompanyInvoiceNumber(
                                                        currentRawInvoiceNo,
                                                      ) !=
                                                      isCompanyInvoice);
                                          final normalizedExisting =
                                              Formatters.invoiceNumber(
                                            currentRawInvoiceNo,
                                            effectiveDate,
                                            customerName: editedCustomer,
                                            isCompany: isCompanyInvoice,
                                          );
                                          final needsFreshSequence =
                                              currentRawInvoiceNo.isEmpty ||
                                                  normalizedExisting == '-' ||
                                                  monthOrYearChanged ||
                                                  typeChanged;

                                          if (needsFreshSequence) {
                                            regeneratedInvoiceNo = await widget
                                                .repository
                                                .generateIncomeInvoiceNumber(
                                              issuedDate: effectiveDate,
                                              isCompany: isCompanyInvoice,
                                            );
                                          } else if (normalizedExisting
                                                  .trim() !=
                                              currentRawInvoiceNo) {
                                            regeneratedInvoiceNo =
                                                normalizedExisting.trim();
                                          }

                                          await widget.repository.updateInvoice(
                                            id: '${item['id']}',
                                            customerName: customer.text.trim(),
                                            date: kopDate.text.trim().isEmpty
                                                ? _toDbDate(tanggal)
                                                : _toDbDate(kopDate.text),
                                            status: status,
                                            totalBiaya: subtotal,
                                            pph: pph,
                                            totalBayar: totalBayar,
                                            email: email.text,
                                            noTelp: phone.text,
                                            kopDate: kopDate.text.trim().isEmpty
                                                ? _toDbDate(tanggal)
                                                : _toDbDate(kopDate.text),
                                            kopLocation: kopLocation.text,
                                            dueDate: dueDate.text.trim().isEmpty
                                                ? null
                                                : _toDbDate(dueDate.text),
                                            pickup: '${first['lokasi_muat']}',
                                            destination:
                                                '${first['lokasi_bongkar']}',
                                            muatan: normalizeNullable(
                                              first['muatan'],
                                            ),
                                            armadaId:
                                                firstResolvedArmadaId.isEmpty
                                                    ? null
                                                    : firstResolvedArmadaId,
                                            armadaStartDate:
                                                '${first['armada_start_date']}'
                                                        .trim()
                                                        .isEmpty
                                                    ? null
                                                    : _toDbDate(
                                                        '${first['armada_start_date']}',
                                                      ),
                                            armadaEndDate:
                                                '${first['armada_end_date']}'
                                                        .trim()
                                                        .isEmpty
                                                    ? null
                                                    : _toDbDate(
                                                        '${first['armada_end_date']}',
                                                      ),
                                            tonase: _toNum(first['tonase']),
                                            harga: _toNum(first['harga']),
                                            namaSupir: driverNames.isEmpty
                                                ? null
                                                : driverNames,
                                            noInvoice: regeneratedInvoiceNo,
                                            details: detailsPayload,
                                            acceptedBy: acceptedBy,
                                          );
                                          if (!mounted || !context.mounted) {
                                            return;
                                          }
                                          dialogClosed = true;
                                          Navigator.of(context).pop();
                                          _snack(_t(
                                              'Invoice berhasil diperbarui.',
                                              'Invoice updated successfully.'));
                                          await _refresh();
                                          _notifyDataChanged();
                                        } catch (e) {
                                          if (!mounted) return;
                                          _snack(
                                            e.toString().replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                ),
                                            error: true,
                                          );
                                        } finally {
                                          if (mounted && !dialogClosed) {
                                            setDialogState(
                                                () => saving = false);
                                          }
                                        }
                                      },
                                child: Text(
                                  saving
                                      ? _t('Menyimpan...', 'Saving...')
                                      : _t('Simpan', 'Save'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      customer.dispose();
      email.dispose();
      phone.dispose();
      kopDate.dispose();
      kopLocation.dispose();
      dueDate.dispose();
    }
  }

  Future<void> _openExpenseEdit(Map<String, dynamic> item) async {
    String status = '${item['status'] ?? 'Unpaid'}';
    const statusOptions = <String>['Unpaid', 'Paid', 'Waiting', 'Cancelled'];
    if (!statusOptions
        .any((option) => option.toLowerCase() == status.toLowerCase())) {
      status = 'Unpaid';
    }
    String recordedBy = '${item['dicatat_oleh'] ?? 'Admin'}';
    String tanggal = _toInputDate(item['tanggal']);
    bool saving = false;
    bool dialogClosed = false;

    final noExpense =
        TextEditingController(text: '${item['no_expense'] ?? ''}');
    final existingDetails = _toDetailList(item['rincian']);
    final details = existingDetails.isNotEmpty
        ? existingDetails
            .map(
              (row) => <String, dynamic>{
                'nama': '${row['nama'] ?? row['name'] ?? ''}',
                'jumlah': _formatEditableNumber(row['jumlah'] ?? row['amount']),
              },
            )
            .toList()
        : <Map<String, dynamic>>[
            {
              'nama': '${item['kategori'] ?? ''}',
              'jumlah': _formatEditableNumber(item['total_pengeluaran']),
            },
          ];

    double expenseTotal() {
      return details.fold<double>(0, (sum, row) => sum + _toNum(row['jumlah']));
    }

    try {
      await showDialog<void>(
        context: context,
        barrierColor: AppColors.popupOverlay,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final totalAmount = expenseTotal();
              return AlertDialog(
                title: Text(_t('Edit Expense', 'Edit Expense')),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogField(
                          noExpense,
                          _t('Nomor Expense', 'Expense Number'),
                          readOnly: true,
                        ),
                        const SizedBox(height: 8),
                        _dateSelect(
                          label: _t('Tanggal Expense', 'Expense Date'),
                          value: tanggal,
                          onChanged: (v) => setDialogState(() => tanggal = v),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _t('Rincian Pengeluaran', 'Expense Details'),
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        ...details.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          return Container(
                            margin: EdgeInsets.only(
                              bottom: index == details.length - 1 ? 0 : 10,
                            ),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.cardBorder(context),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                TextFormField(
                                  initialValue: '${row['nama']}',
                                  decoration: InputDecoration(
                                    hintText:
                                        _t('Nama Pengeluaran', 'Expense Name'),
                                  ),
                                  onChanged: (value) => row['nama'] = value,
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: '${row['jumlah']}',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _t('Jumlah', 'Amount'),
                                  ),
                                  onChanged: (value) {
                                    row['jumlah'] = value;
                                    setDialogState(() {});
                                  },
                                ),
                                if (details.length > 1) ...[
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => setDialogState(
                                        () => details.removeAt(index),
                                      ),
                                      style: CvantButtonStyles.text(
                                        context,
                                        color: AppColors.danger,
                                      ),
                                      child: Text(_t('Hapus', 'Delete')),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => setDialogState(() {
                            details.add(<String, dynamic>{
                              'nama': '',
                              'jumlah': '',
                            });
                          }),
                          child: Text(_t('+ Tambah Rincian', '+ Add Detail')),
                        ),
                        const SizedBox(height: 10),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: _t('Total Pengeluaran', 'Total Expense'),
                          ),
                          child: Text(Formatters.rupiah(totalAmount)),
                        ),
                        const SizedBox(height: 8),
                        CvantDropdownField<String>(
                          initialValue: status,
                          decoration: InputDecoration(
                            labelText: _t('Status', 'Status'),
                          ),
                          items:
                              const ['Unpaid', 'Paid', 'Waiting', 'Cancelled']
                                  .map(
                                    (item) => DropdownMenuItem<String>(
                                      value: item,
                                      child: Text(item),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) => setDialogState(
                            () => status = value ?? status,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CvantDropdownField<String>(
                          initialValue: recordedBy,
                          decoration: InputDecoration(
                            labelText: _t('Dicatat Oleh', 'Recorded By'),
                          ),
                          items: const ['Admin', 'Owner']
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setDialogState(
                            () => recordedBy = value ?? recordedBy,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: saving
                                    ? null
                                    : () {
                                        dialogClosed = true;
                                        Navigator.of(context).pop();
                                      },
                                style: CvantButtonStyles.outlined(
                                  context,
                                  color: AppColors.isLight(context)
                                      ? AppColors.textSecondaryLight
                                      : const Color(0xFFE2E8F0),
                                  borderColor: AppColors.neutralOutline,
                                ),
                                child: Text(_t('Batal', 'Cancel')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        final hasName = details.any(
                                          (row) => '${row['nama']}'
                                              .trim()
                                              .isNotEmpty,
                                        );
                                        if (!hasName ||
                                            totalAmount <= 0 ||
                                            tanggal.trim().isEmpty) {
                                          _snack(
                                            _t(
                                              'Tanggal dan rincian pengeluaran wajib diisi.',
                                              'Date and expense details are required.',
                                            ),
                                            error: true,
                                          );
                                          return;
                                        }

                                        final detailsPayload = details
                                            .map(
                                              (row) => <String, dynamic>{
                                                'nama': '${row['nama']}'.trim(),
                                                'jumlah': _toNum(row['jumlah']),
                                              },
                                            )
                                            .toList();

                                        final note = detailsPayload
                                            .where((row) => '${row['nama']}'
                                                .trim()
                                                .isNotEmpty)
                                            .map(
                                              (row) =>
                                                  '${row['nama']}: ${Formatters.rupiah(_toNum(row['jumlah']))}',
                                            )
                                            .join(', ');

                                        final firstNamedRow =
                                            detailsPayload.firstWhere(
                                          (row) => '${row['nama']}'
                                              .trim()
                                              .isNotEmpty,
                                          orElse: () => detailsPayload.first,
                                        );

                                        setDialogState(() => saving = true);
                                        try {
                                          String? regeneratedNoExpense;
                                          final editedDate =
                                              Formatters.parseDate(tanggal);
                                          final originalDate =
                                              Formatters.parseDate(
                                            item['tanggal'],
                                          );
                                          final monthChanged =
                                              editedDate != null &&
                                                  originalDate != null &&
                                                  (editedDate.year !=
                                                          originalDate.year ||
                                                      editedDate.month !=
                                                          originalDate.month);
                                          if (monthChanged) {
                                            regeneratedNoExpense = widget
                                                .repository
                                                .generateExpenseNumberForDate(
                                              editedDate,
                                            );
                                            noExpense.text =
                                                regeneratedNoExpense;
                                          }

                                          await widget.repository.updateExpense(
                                            id: '${item['id']}',
                                            date: _toDbDate(tanggal),
                                            status: status,
                                            total: totalAmount,
                                            noExpense: regeneratedNoExpense,
                                            kategori:
                                                '${firstNamedRow['nama']}',
                                            keterangan: note,
                                            note: note,
                                            recordedBy: recordedBy,
                                            details: detailsPayload,
                                          );
                                          if (!mounted || !context.mounted) {
                                            return;
                                          }
                                          dialogClosed = true;
                                          Navigator.of(context).pop();
                                          _snack(_t(
                                              'Expense berhasil diperbarui.',
                                              'Expense updated successfully.'));
                                          await _refresh();
                                          _notifyDataChanged();
                                        } catch (e) {
                                          if (!mounted) return;
                                          _snack(
                                            e.toString().replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                ),
                                            error: true,
                                          );
                                        } finally {
                                          if (mounted && !dialogClosed) {
                                            setDialogState(
                                                () => saving = false);
                                          }
                                        }
                                      },
                                child: Text(
                                  saving
                                      ? _t('Menyimpan...', 'Saving...')
                                      : _t('Simpan', 'Save'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      noExpense.dispose();
    }
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    TextInputType? type,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _buildEditInvoiceModeTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: selected ? AppColors.sidebarActiveGradient : null,
          color: selected ? null : AppColors.controlBackground(context),
          border: Border.all(
            color:
                selected ? Colors.transparent : AppColors.cardBorder(context),
          ),
          boxShadow: selected ? AppColors.sidebarActiveShadow : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color:
                  selected ? Colors.white : AppColors.textPrimaryFor(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateSelect({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final initial = Formatters.parseDate(value) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          initialDate: initial,
        );
        if (picked == null) return;
        onChanged(_toInputDate(picked));
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value.isEmpty ? '-' : Formatters.dmy(value)),
      ),
    );
  }

  List<Map<String, dynamic>> _toDetailList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  String _toInputDate(dynamic value) {
    final date = Formatters.parseDate(value);
    if (date == null) return '';
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd-$mm-${date.year}';
  }

  String _toDbDate(dynamic value) {
    final date = Formatters.parseDate(value);
    if (date == null) return '';
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  String _formatEditableNumber(dynamic value) {
    final number = _toNum(value);
    if (number == 0) return '';
    return number % 1 == 0
        ? number.toStringAsFixed(0)
        : number.toStringAsFixed(2);
  }

  void _snack(String msg, {bool error = false}) {
    showCvantPopup(
      context: context,
      type: error ? CvantPopupType.error : CvantPopupType.success,
      title: error ? _t('Error', 'Error') : _t('Success', 'Success'),
      message: msg,
    );
  }

  List<Map<String, dynamic>> _buildCombinedRows(
    List<Map<String, dynamic>> incomes,
    List<Map<String, dynamic>> expenses,
  ) {
    String resolveRoute(Map<String, dynamic> source) {
      final details = _toDetailList(source['rincian']);
      String build(dynamic muatValue, dynamic bongkarValue) {
        final muat = '${muatValue ?? ''}'.trim();
        final bongkar = '${bongkarValue ?? ''}'.trim();
        if (muat.isEmpty && bongkar.isEmpty) return '-';
        return '${muat.isEmpty ? '-' : muat}-${bongkar.isEmpty ? '-' : bongkar}';
      }

      for (final row in details) {
        final route = build(row['lokasi_muat'], row['lokasi_bongkar']);
        if (route != '-') return route;
      }
      return build(source['lokasi_muat'], source['lokasi_bongkar']);
    }

    final rows = <Map<String, dynamic>>[
      ...incomes.map(
        (item) {
          final invoiceNumber = Formatters.invoiceNumber(
            item['no_invoice'],
            item['tanggal_kop'] ?? item['tanggal'] ?? item['created_at'],
            customerName: item['nama_pelanggan'],
          );
          final customerName = '${item['nama_pelanggan'] ?? ''}'.trim();
          final isCompanyInvoice = _resolveIsCompanyInvoice(
            invoiceNumber: item['no_invoice'],
            customerName: customerName,
          );
          final subtotal = _toNum(item['total_biaya']);
          final pph = _toNum(item['pph']);
          final totalBayar = _toNum(item['total_bayar']);
          final effectiveTotal = isCompanyInvoice
              ? (totalBayar > 0 ? totalBayar : max(0.0, subtotal - pph))
              : subtotal;
          return {
            ...item,
            '__type': 'Income',
            '__number': invoiceNumber,
            '__name': item['nama_pelanggan'],
            '__total': effectiveTotal,
            '__date':
                item['tanggal_kop'] ?? item['tanggal'] ?? item['created_at'],
            '__status': item['status'],
            '__recorded_by': item['diterima_oleh'] ?? '-',
            '__route': resolveRoute(item),
          };
        },
      ),
      ...expenses.map(
        (item) => {
          ...item,
          '__type': 'Expense',
          '__number': item['no_expense'],
          '__name': item['kategori'] ?? item['keterangan'] ?? '-',
          '__total': item['total_pengeluaran'],
          '__date': item['tanggal'] ?? item['created_at'],
          '__status': item['status'],
          '__recorded_by': item['dicatat_oleh'] ?? '-',
        },
      ),
    ];
    rows.sort((a, b) {
      final aDate = Formatters.parseDate(a['__date']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = Formatters.parseDate(b['__date']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return rows;
  }

  List<Map<String, dynamic>> _applyFilterAndLimit(
      List<Map<String, dynamic>> rows) {
    final q = _search.text.trim().toLowerCase();
    final filtered = rows.where((item) {
      return _matchesKeywordInAnyColumn(item, q);
    }).toList();

    if (_limit == 'all') {
      return filtered;
    }
    final maxRows = int.tryParse(_limit) ?? 10;
    if (filtered.length <= maxRows) return filtered;
    return filtered.take(maxRows).toList();
  }

  Widget _buildCombinedList(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return _SimplePlaceholderView(
        title: _t('Data invoice kosong', 'No invoice data'),
        message: _t(
          'Belum ada data income atau expense.',
          'No income or expense data yet.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(10),
        itemCount: rows.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == rows.length) {
            return const _DashboardContentFooter();
          }
          final item = rows[index];
          final isIncome = '${item['__type']}' == 'Income';
          final isEn = LanguageController.language.value == AppLanguage.en;
          final isCompanyInvoice = isIncome
              ? _resolveIsCompanyInvoice(
                  invoiceNumber: item['no_invoice'] ?? item['__number'],
                  customerName: item['__name'],
                )
              : false;
          final invoiceTypeLabel = isCompanyInvoice
              ? (isEn ? 'Company' : 'Perusahaan')
              : (isEn ? 'Personal' : 'Pribadi');
          final invoiceTypeColor =
              isCompanyInvoice ? AppColors.success : AppColors.warning;
          final total = _toNum(item['__total']);
          return _PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item['__number'] ?? '-'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isIncome ? AppColors.blue : AppColors.danger,
                        ),
                      ),
                    ),
                    _StatusPill(label: '${item['__status'] ?? '-'}'),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${item['__type']} • ${Formatters.dmy(item['__date'])}',
                  style: TextStyle(color: AppColors.textMutedFor(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_t('Nama', 'Name')}: ${isIncome ? item['__name'] ?? '-' : '-'}',
                  style: TextStyle(color: AppColors.textMutedFor(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  isIncome
                      ? '${item['__route'] ?? '-'}'
                      : '${_t('Dicatat oleh', 'Recorded by')}: ${item['__recorded_by'] ?? '-'}',
                  style: TextStyle(color: AppColors.textMutedFor(context)),
                ),
                const SizedBox(height: 6),
                Text(
                  Formatters.rupiah(total),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isIncome)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            invoiceTypeLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: invoiceTypeColor,
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => isIncome
                              ? _openInvoiceEdit(item)
                              : _openExpenseEdit(item),
                          style: _mobileActionButtonStyle(
                            context: context,
                            color: AppColors.blue,
                          ),
                          child: const Icon(Icons.edit_outlined, size: 18),
                        ),
                        OutlinedButton(
                          onPressed: () => isIncome
                              ? _openInvoicePreview(item)
                              : _openExpensePreview(item),
                          style: _mobileActionButtonStyle(
                            context: context,
                            color: AppColors.warning,
                          ),
                          child:
                              const Icon(Icons.visibility_outlined, size: 18),
                        ),
                        if (isIncome)
                          OutlinedButton(
                            onPressed: () => _sendInvoice(item),
                            style: _mobileActionButtonStyle(
                              context: context,
                              color: const Color(0xFF2563EB),
                            ),
                            child: const Icon(Icons.send_outlined, size: 18),
                          ),
                        OutlinedButton(
                          onPressed: () => _confirmDelete(
                            id: '${item['id']}',
                            isIncome: isIncome,
                          ),
                          style: _mobileActionButtonStyle(
                            context: context,
                            color: AppColors.danger,
                          ),
                          child: const Icon(Icons.delete_outline, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _ErrorView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() {
              _future = _load();
            }),
          );
        }

        final incomes =
            (snapshot.data![0] as List).cast<Map<String, dynamic>>();
        final expenses =
            (snapshot.data![1] as List).cast<Map<String, dynamic>>();
        final rows =
            _applyFilterAndLimit(_buildCombinedRows(incomes, expenses));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(
                children: [
                  Text(
                    _t('Tampil', 'Show'),
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 86,
                    child: CvantDropdownField<String>(
                      initialValue: _limit,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.zero,
                      ),
                      items: const [
                        '10',
                        '20',
                        '50',
                        '100',
                        '200',
                        '500',
                        '1000',
                        'all'
                      ]
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item == 'all' ? _t('Semua', 'All') : item,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _limit = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: _t(
                          'Cari income atau expense...',
                          'Search income or expense...',
                        ),
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => _openReportSummary(
                          incomes: incomes,
                          expenses: expenses,
                        ),
                        style: CvantButtonStyles.outlined(
                          context,
                          color: AppColors.success,
                          borderColor: AppColors.success,
                        ).copyWith(
                          alignment: const Alignment(0, 0),
                        ),
                        child: Center(
                          child: Text(
                            _t('Cetak\nLaporan', 'Print\nReport'),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => widget.onQuickMenuSelect(2),
                        style: CvantButtonStyles.outlined(
                          context,
                          color: AppColors.blue,
                          borderColor: AppColors.blue,
                        ).copyWith(
                          alignment: const Alignment(0, 0),
                        ),
                        child: Center(
                          child: Text(
                            _t('Tambah\nPemasukkan', 'Add\nIncome'),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => widget.onQuickMenuSelect(3),
                        style: CvantButtonStyles.outlined(
                          context,
                          color: AppColors.warning,
                          borderColor: AppColors.warning,
                        ).copyWith(
                          alignment: const Alignment(0, 0),
                        ),
                        child: Center(
                          child: Text(
                            _t('Tambah\nPengeluaran', 'Add\nExpense'),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildCombinedList(rows)),
          ],
        );
      },
    );
  }
}

class _AdminFleetListView extends StatefulWidget {
  const _AdminFleetListView({
    required this.repository,
    required this.onQuickMenuSelect,
  });

  final DashboardRepository repository;
  final ValueChanged<int> onQuickMenuSelect;

  @override
  State<_AdminFleetListView> createState() => _AdminFleetListViewState();
}

class _AdminFleetListViewState extends State<_AdminFleetListView> {
  late Future<List<dynamic>> _future;
  final _search = TextEditingController();
  int _limit = 10;

  bool get _isEn => LanguageController.language.value == AppLanguage.en;

  String _t(String id, String en) => _isEn ? en : id;

  String _normalizePlate(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _extractPlate(String value) {
    final match = RegExp(
      r'[A-Z]{1,2}\s?[0-9]{1,4}\s?[A-Z]{1,3}',
    ).firstMatch(value.toUpperCase());
    if (match == null) return null;
    final plate = _normalizePlate(match.group(0) ?? '');
    return plate.isEmpty ? null : plate;
  }

  Map<String, int> _buildUsageMap({
    required List<Map<String, dynamic>> armadas,
    required List<Map<String, dynamic>> invoices,
  }) {
    final usage = <String, int>{};
    final armadaByPlate = <String, String>{};

    for (final armada in armadas) {
      final armadaId = '${armada['id'] ?? ''}'.trim();
      final plate = _normalizePlate('${armada['plat_nomor'] ?? ''}');
      if (armadaId.isEmpty || plate.isEmpty) continue;
      armadaByPlate[plate] = armadaId;
    }

    void increment(String armadaId) {
      if (armadaId.isEmpty) return;
      usage[armadaId] = (usage[armadaId] ?? 0) + 1;
    }

    String resolveArmadaId({
      dynamic directArmadaId,
      List<dynamic> candidates = const <dynamic>[],
    }) {
      final direct = '${directArmadaId ?? ''}'.trim();
      if (direct.isNotEmpty) return direct;
      for (final raw in candidates) {
        final text = '${raw ?? ''}'.trim();
        if (text.isEmpty) continue;
        final plate = _extractPlate(text);
        if (plate == null) continue;
        final mapped = armadaByPlate[plate];
        if (mapped != null && mapped.isNotEmpty) return mapped;
      }
      return '';
    }

    List<Map<String, dynamic>> detailRows(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return const <Map<String, dynamic>>[];
    }

    for (final invoice in invoices) {
      final details = detailRows(invoice['rincian']);
      if (details.isNotEmpty) {
        for (final row in details) {
          final armadaId = resolveArmadaId(
            directArmadaId: row['armada_id'],
            candidates: [
              row['armada_manual'],
              row['armada_label'],
              row['armada'],
              row['plat_nomor'],
              row['no_polisi'],
            ],
          );
          increment(armadaId);
        }
        continue;
      }

      final armadaId = resolveArmadaId(
        directArmadaId: invoice['armada_id'],
        candidates: [
          invoice['armada_manual'],
          invoice['armada_label'],
          invoice['armada'],
          invoice['plat_nomor'],
          invoice['no_polisi'],
        ],
      );
      increment(armadaId);
    }

    return usage;
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _load() {
    return Future.wait([
      widget.repository.fetchArmadas(),
      widget.repository.fetchInvoiceArmadaUsage(),
    ]);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _openEdit(Map<String, dynamic> item) async {
    final name = TextEditingController(text: '${item['nama_truk'] ?? ''}');
    final plate = TextEditingController(text: '${item['plat_nomor'] ?? ''}');
    final capacity = TextEditingController(
      text: _toNum(item['kapasitas']).toStringAsFixed(0),
    );
    bool isActive = item['is_active'] != false;
    bool saving = false;
    bool dialogClosed = false;

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(_t('Edit Armada', 'Edit Fleet')),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: name,
                        decoration: InputDecoration(
                            labelText: _t('Nama Truk', 'Truck Name')),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: plate,
                        decoration: InputDecoration(
                            labelText: _t('Plat Nomor', 'Plate Number')),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: capacity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                            labelText: _t('Kapasitas', 'Capacity')),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        title: Text(_t('Status Aktif', 'Active Status')),
                        onChanged: (value) {
                          setDialogState(() => isActive = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          dialogClosed = true;
                          Navigator.of(context).pop();
                        },
                  style: CvantButtonStyles.outlined(
                    context,
                    color: AppColors.isLight(context)
                        ? AppColors.textSecondaryLight
                        : const Color(0xFFE2E8F0),
                    borderColor: AppColors.neutralOutline,
                  ),
                  child: Text(_t('Batal', 'Cancel')),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (name.text.trim().isEmpty ||
                              plate.text.trim().isEmpty) {
                            _snack(
                                _t('Nama dan plat nomor wajib diisi.',
                                    'Truck name and plate number are required.'),
                                error: true);
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            await widget.repository.updateArmada(
                              id: '${item['id']}',
                              name: name.text,
                              plate: plate.text,
                              capacity: _toNum(capacity.text),
                              active: isActive,
                              status: isActive ? 'Ready' : 'Inactive',
                            );
                            if (!mounted || !context.mounted) return;
                            dialogClosed = true;
                            Navigator.of(context).pop();
                            _snack(_t('Armada berhasil diperbarui.',
                                'Fleet updated successfully.'));
                            await _refresh();
                          } catch (e) {
                            if (!mounted) return;
                            _snack(e.toString().replaceFirst('Exception: ', ''),
                                error: true);
                          } finally {
                            if (mounted && !dialogClosed) {
                              setDialogState(() => saving = false);
                            }
                          }
                        },
                  child: Text(saving
                      ? _t('Menyimpan...', 'Saving...')
                      : _t('Simpan', 'Save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _delete(String id) async {
    final ok = await showCvantConfirmPopup(
      context: context,
      title: _t('Hapus Armada', 'Delete Fleet'),
      message: _t(
        'Armada akan dihapus permanen. Lanjutkan?',
        'Fleet will be permanently deleted. Continue?',
      ),
      type: CvantPopupType.error,
      cancelLabel: _t('Batal', 'Cancel'),
      confirmLabel: _t('Hapus', 'Delete'),
    );
    if (!ok) return;

    try {
      await widget.repository.deleteArmada(id);
      if (!mounted) return;
      _snack(_t('Armada berhasil dihapus.', 'Fleet deleted successfully.'));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    showCvantPopup(
      context: context,
      type: error ? CvantPopupType.error : CvantPopupType.success,
      title: error ? _t('Error', 'Error') : _t('Success', 'Success'),
      message: msg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        final payload = snapshot.data;
        if (snapshot.hasError || payload == null || payload.length < 2) {
          return _ErrorView(
            message:
                snapshot.error?.toString().replaceFirst('Exception: ', '') ??
                    'Gagal memuat data fleet.',
            onRetry: () => setState(() {
              _future = _load();
            }),
          );
        }

        final armadas = (payload[0] is List
                ? (payload[0] as List)
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
                : const <Map<String, dynamic>>[])
            .cast<Map<String, dynamic>>();
        final invoices = (payload[1] is List
                ? (payload[1] as List)
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
                : const <Map<String, dynamic>>[])
            .cast<Map<String, dynamic>>();
        final usage = _buildUsageMap(armadas: armadas, invoices: invoices);

        final q = _search.text.trim().toLowerCase();
        final filtered = armadas
            .where((item) {
              if (q.isEmpty) return true;
              final armadaId = '${item['id'] ?? ''}';
              final used = usage[armadaId] ?? 0;
              final text = '${_flattenSearchText(item)} $used';
              return text.toLowerCase().contains(q);
            })
            .take(_limit)
            .toList();

        final data = filtered;
        if (data.isEmpty) {
          if (armadas.isEmpty) {
            return _SimplePlaceholderView(
              title: _t('Fleet belum tampil', 'Fleet is not available yet'),
              message: _t(
                'Data armada kosong atau role akun belum memiliki akses staff (admin/owner).',
                'Fleet data is empty or current role has no staff access (admin/owner).',
              ),
            );
          }
          return _SimplePlaceholderView(
            title: _t('Fleet tidak ditemukan', 'Fleet not found'),
            message: _t(
              'Coba ubah keyword pencarian fleet.',
              'Try changing the fleet search keyword.',
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(
                children: [
                  Text(
                    _t('Tampil', 'Show'),
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 86,
                    child: CvantDropdownField<int>(
                      initialValue: _limit,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.zero,
                      ),
                      items: const [10, 15, 20]
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text('$item'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _limit = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: _t('Cari armada...', 'Search fleet...'),
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => widget.onQuickMenuSelect(6),
                  style: CvantButtonStyles.outlined(
                    context,
                    color: AppColors.blue,
                    borderColor: AppColors.blue,
                  ).copyWith(
                    alignment: const Alignment(0, 0),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(_t('Tambah Armada', 'Add Fleet')),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(10),
                  itemCount: data.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == data.length) {
                      return const _DashboardContentFooter();
                    }
                    final item = data[index];
                    final status = (item['is_active'] == false) ||
                            '${item['status']}'.toLowerCase() == 'inactive'
                        ? 'Inactive'
                        : '${item['status'] ?? 'Ready'}';
                    final used = usage['${item['id']}'] ?? 0;
                    return _PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.local_shipping_outlined,
                                color: AppColors.cyan,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${item['nama_truk'] ?? '-'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _StatusPill(label: status),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.only(left: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_t('Plat', 'Plate')}: ${item['plat_nomor'] ?? '-'}',
                                  style: TextStyle(
                                    color: AppColors.textMutedFor(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_t('Kapasitas', 'Capacity')}: ${_toNum(item['kapasitas']).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: AppColors.textMutedFor(context),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_t('Penggunaan', 'Usage')}: ${used}x',
                                  style: TextStyle(
                                    color: AppColors.textMutedFor(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _openEdit(item),
                                style: CvantButtonStyles.outlined(
                                  context,
                                  color: AppColors.blue,
                                  borderColor: AppColors.blue,
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: Text(_t('Edit', 'Edit')),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _delete('${item['id']}'),
                                style: CvantButtonStyles.outlined(
                                  context,
                                  color: AppColors.danger,
                                  borderColor: AppColors.danger,
                                ),
                                icon:
                                    const Icon(Icons.delete_outline, size: 16),
                                label: Text(_t('Hapus', 'Delete')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AdminOrderAcceptanceView extends StatefulWidget {
  const _AdminOrderAcceptanceView({
    required this.repository,
    required this.onCreateInvoice,
  });

  final DashboardRepository repository;
  final ValueChanged<_InvoicePrefillData> onCreateInvoice;

  @override
  State<_AdminOrderAcceptanceView> createState() =>
      _AdminOrderAcceptanceViewState();
}

class _AdminOrderAcceptanceViewState extends State<_AdminOrderAcceptanceView> {
  late Future<List<dynamic>> _future;
  String? _updatingOrderId;
  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  String _t(String id, String en) => _isEn ? en : id;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() {
    return Future.wait([
      widget.repository.fetchOrders(),
      widget.repository.fetchCustomerProfiles(),
    ]);
  }

  Future<void> _updateStatus(String orderId, String status) async {
    setState(() => _updatingOrderId = orderId);
    try {
      await widget.repository
          .updateOrderStatus(orderId: orderId, status: status);
      if (!mounted) return;
      showCvantPopup(
        context: context,
        type: CvantPopupType.success,
        title: _t('Success', 'Success'),
        message: _t('Status order berhasil diupdate.',
            'Order status updated successfully.'),
      );
      setState(() {
        _future = _load();
      });
    } catch (e) {
      if (!mounted) return;
      showCvantPopup(
        context: context,
        type: CvantPopupType.error,
        title: _t('Error', 'Error'),
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  Future<void> _openInvoiceCreateForm(
    Map<String, dynamic> order,
    Map<String, dynamic>? customer,
  ) async {
    final customerName = (customer?['name'] ??
            customer?['username'] ??
            _t('Customer', 'Customer'))
        .toString();
    final total = _toNum(order['total']);
    if (total <= 0) {
      showCvantPopup(
        context: context,
        type: CvantPopupType.error,
        title: _t('Error', 'Error'),
        message: _t(
          'Total order belum valid untuk dibuat invoice.',
          'Order total is not valid yet for invoice creation.',
        ),
      );
      return;
    }

    try {
      final existing =
          await widget.repository.findInvoiceForOrder('${order['id']}');
      if (existing != null) {
        if (!mounted) return;
        final existingNo = Formatters.invoiceNumber(
          existing['no_invoice'],
          existing['tanggal_kop'] ??
              existing['tanggal'] ??
              existing['created_at'],
          customerName: customerName,
        );
        showCvantPopup(
          context: context,
          type: CvantPopupType.warning,
          title: _t('Warning', 'Warning'),
          message: _t(
            'Invoice sudah ada: ${existingNo == '-' ? (existing['id'] ?? '-') : existingNo}',
            'Invoice already exists: ${existingNo == '-' ? (existing['id'] ?? '-') : existingNo}',
          ),
        );
        return;
      }

      widget.onCreateInvoice(
        _InvoicePrefillData(
          orderId: order['id']?.toString(),
          customerId: customer?['id']?.toString(),
          customerName: customerName,
          customerEmail: customer?['email']?.toString(),
          customerPhone: customer?['phone']?.toString(),
          pickup: order['pickup']?.toString(),
          destination: order['destination']?.toString(),
          pickupDate: Formatters.parseDate(order['pickup_date']),
          armadaName: order['fleet']?.toString(),
        ),
      );
      if (!mounted) return;
      showCvantPopup(
        context: context,
        type: CvantPopupType.info,
        title: _t('Invoice Add', 'Invoice Add'),
        message: _t(
          'Membuka halaman Invoice Add dengan data order terpilih.',
          'Opening Invoice Add page with selected order data.',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showCvantPopup(
        context: context,
        type: CvantPopupType.error,
        title: _t('Error', 'Error'),
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _ErrorView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() {
              _future = _load();
            }),
          );
        }

        final orders = (snapshot.data![0] as List).cast<Map<String, dynamic>>();
        final customers =
            (snapshot.data![1] as List).cast<Map<String, dynamic>>();
        final customerMap = <String, Map<String, dynamic>>{
          for (final customer in customers) '${customer['id']}': customer,
        };

        if (orders.isEmpty) {
          return _SimplePlaceholderView(
            title: _t('Order belum ada', 'No orders yet'),
            message: _t(
              'Belum ada order customer yang perlu diproses.',
              'There are no customer orders to process yet.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == orders.length) {
              return const _DashboardContentFooter();
            }
            final order = orders[index];
            final status = '${order['status'] ?? 'Pending'}';
            final statusLower = status.toLowerCase();
            final isUpdating = _updatingOrderId == '${order['id']}';
            final customer = customerMap['${order['customer_id']}'];
            final isPaid =
                statusLower.contains('paid') && !statusLower.contains('unpaid');
            final canCreateInvoice = statusLower.contains('accepted');
            final customerName =
                customer?['name'] ?? customer?['username'] ?? '-';

            return _PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${order['order_code'] ?? order['id'] ?? '-'}',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _StatusPill(label: status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_t('Customer', 'Customer')}: $customerName',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_t('Rute', 'Route')}: ${order['pickup'] ?? '-'} -> ${order['destination'] ?? '-'}',
                    style:
                        TextStyle(color: AppColors.textSecondaryFor(context)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_t('Jadwal', 'Schedule')}: ${Formatters.dmy(order['pickup_date'] ?? order['created_at'])}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 120,
                        child: FilledButton(
                          onPressed: (isUpdating || isPaid)
                              ? null
                              : () =>
                                  _updateStatus('${order['id']}', 'Accepted'),
                          style: CvantButtonStyles.filled(
                            context,
                            color: AppColors.success,
                          ),
                          child: Text(_t('Terima', 'Accept')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: FilledButton(
                          onPressed: (isUpdating || isPaid)
                              ? null
                              : () =>
                                  _updateStatus('${order['id']}', 'Rejected'),
                          style: CvantButtonStyles.filled(
                            context,
                            color: AppColors.danger,
                          ),
                          child: Text(_t('Tolak', 'Reject')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: (isUpdating || !canCreateInvoice)
                          ? null
                          : () => _openInvoiceCreateForm(order, customer),
                      style: CvantButtonStyles.outlined(
                        context,
                        minimumSize: const Size(120, 44),
                      ),
                      child: Text(_t('Buat', 'Create')),
                    ),
                  ),
                  if (isUpdating) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminCustomerRegistrationsView extends StatefulWidget {
  const _AdminCustomerRegistrationsView({required this.repository});

  final DashboardRepository repository;

  @override
  State<_AdminCustomerRegistrationsView> createState() =>
      _AdminCustomerRegistrationsViewState();
}

class _AdminCustomerRegistrationsViewState
    extends State<_AdminCustomerRegistrationsView> {
  late Future<List<Map<String, dynamic>>> _future;
  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  String _t(String id, String en) => _isEn ? en : id;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchCustomerProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError) {
          return _ErrorView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() {
              _future = widget.repository.fetchCustomerProfiles();
            }),
          );
        }

        final customers = snapshot.data ?? [];
        if (customers.isEmpty) {
          return _SimplePlaceholderView(
            title: _t('Belum ada customer', 'No customers yet'),
            message: _t(
              'Data registrasi customer belum tersedia.',
              'Customer registration data is not available yet.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: customers.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == customers.length) {
              return const _DashboardContentFooter();
            }
            final customer = customers[index];
            return _PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${customer['name'] ?? '-'}',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _StatusPill(label: '${customer['role'] ?? 'customer'}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_t('Username', 'Username')}: ${customer['username'] ?? '-'}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_t('Email', 'Email')}: ${customer['email'] ?? '-'}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_t('HP', 'Phone')}: ${customer['phone'] ?? '-'}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_t('Alamat', 'Address')}: ${customer['address'] ?? '-'}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_t('Kota', 'City')}: ${customer['city'] ?? '-'}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_t('Perusahaan', 'Company')}: ${customer['company'] ?? '-'}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_t('Terdaftar', 'Registered')}: ${Formatters.dmy(customer['created_at'])}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CustomerOrderHistoryView extends StatefulWidget {
  const _CustomerOrderHistoryView({required this.repository});

  final DashboardRepository repository;

  @override
  State<_CustomerOrderHistoryView> createState() =>
      _CustomerOrderHistoryViewState();
}

class _CustomerOrderHistoryViewState extends State<_CustomerOrderHistoryView> {
  late Future<List<Map<String, dynamic>>> _future;
  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  String _t(String id, String en) => _isEn ? en : id;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchOrders(currentUserOnly: true);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.repository.fetchOrders(currentUserOnly: true);
    });
    await _future;
  }

  Future<void> _pay(Map<String, dynamic> order) async {
    String method = 'va';
    bool processing = false;
    bool dialogClosed = false;

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(_t('Pembayaran Order', 'Order Payment')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      '${_t('Order', 'Order')}: ${order['order_code'] ?? '-'}'),
                  const SizedBox(height: 10),
                  CvantDropdownField<String>(
                    initialValue: method,
                    decoration: InputDecoration(
                      labelText: _t('Metode Pembayaran', 'Payment Method'),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: 'va', child: Text('Virtual Account')),
                      DropdownMenuItem(
                          value: 'transfer',
                          child: Text(_t('Transfer Bank', 'Bank Transfer'))),
                      DropdownMenuItem(
                          value: 'cash', child: Text(_t('Cash', 'Cash'))),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => method = value ?? method),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: processing
                      ? null
                      : () {
                          dialogClosed = true;
                          Navigator.of(context).pop();
                        },
                  style: CvantButtonStyles.outlined(
                    context,
                    color: AppColors.isLight(context)
                        ? AppColors.textSecondaryLight
                        : const Color(0xFFE2E8F0),
                    borderColor: AppColors.neutralOutline,
                  ),
                  child: Text(_t('Batal', 'Cancel')),
                ),
                FilledButton(
                  onPressed: processing
                      ? null
                      : () async {
                          setDialogState(() => processing = true);
                          try {
                            final invoice = await widget.repository
                                .findInvoiceForOrder('${order['id']}');
                            await widget.repository.payOrder(
                              orderId: '${order['id']}',
                              method: method,
                              invoiceId: invoice?['id']?.toString(),
                            );
                            if (!mounted || !context.mounted) return;
                            dialogClosed = true;
                            Navigator.of(context).pop();
                            showCvantPopup(
                              context: this.context,
                              type: CvantPopupType.success,
                              title: _t('Success', 'Success'),
                              message: _t('Pembayaran berhasil diproses.',
                                  'Payment was processed successfully.'),
                            );
                            await _refresh();
                          } catch (e) {
                            if (!mounted) return;
                            showCvantPopup(
                              context: this.context,
                              type: CvantPopupType.error,
                              title: _t('Error', 'Error'),
                              message:
                                  e.toString().replaceFirst('Exception: ', ''),
                            );
                          } finally {
                            if (mounted && !dialogClosed) {
                              setDialogState(() => processing = false);
                            }
                          }
                        },
                  child: Text(
                    processing
                        ? _t('Memproses...', 'Processing...')
                        : _t('Bayar', 'Pay'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError) {
          return _ErrorView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() {
              _future = widget.repository.fetchOrders(currentUserOnly: true);
            }),
          );
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return _SimplePlaceholderView(
            title: _t('Belum ada order', 'No orders yet'),
            message: _t(
              'Order customer masih kosong.',
              'Customer orders are still empty.',
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: orders.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == orders.length) {
                return const _DashboardContentFooter();
              }
              final order = orders[index];
              final status = '${order['status'] ?? 'Pending Payment'}';
              final statusLower = status.toLowerCase();
              final canPay = (statusLower.contains('accepted') ||
                      statusLower.contains('pending payment') ||
                      statusLower == 'pending') &&
                  !statusLower.contains('paid') &&
                  !statusLower.contains('rejected');

              return _PanelCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${order['order_code'] ?? '-'}',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _StatusPill(label: status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order['pickup'] ?? '-'} -> ${order['destination'] ?? '-'}',
                      style:
                          TextStyle(color: AppColors.textSecondaryFor(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_t('Jadwal', 'Schedule')}: ${Formatters.dmy(order['pickup_date'] ?? order['created_at'])}',
                      style: TextStyle(color: AppColors.textMutedFor(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_t('Armada', 'Fleet')}: ${order['fleet'] ?? '-'}',
                      style: TextStyle(color: AppColors.textMutedFor(context)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Formatters.rupiah(_toNum(order['total'])),
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: canPay ? () => _pay(order) : null,
                        style: CvantButtonStyles.outlined(
                          context,
                          minimumSize: const Size(128, 44),
                        ),
                        icon: const Icon(Icons.payment_outlined),
                        label: Text(
                          canPay
                              ? _t('Bayar', 'Pay')
                              : statusLower.contains('paid')
                                  ? _t('Paid', 'Paid')
                                  : _t('Waiting', 'Waiting'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CustomerSettingsView extends StatefulWidget {
  const _CustomerSettingsView({
    required this.repository,
    required this.session,
    required this.biometricService,
  });

  final DashboardRepository repository;
  final AuthSession session;
  final BiometricLoginService biometricService;

  @override
  State<_CustomerSettingsView> createState() => _CustomerSettingsViewState();
}

class _CustomerSettingsViewState extends State<_CustomerSettingsView> {
  late Future<Map<String, dynamic>?> _future;
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _avatarUrl = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _company = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _didHydrate = false;
  bool _biometricEnabled = false;
  bool _biometricLoading = true;
  bool _biometricSaving = false;
  bool _biometricSupported = false;
  bool _biometricEnrolled = false;
  bool _biometricManualBound = false;
  String _biometricLabel = 'Fingerprint';
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  String _t(String id, String en) => _isEn ? en : id;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchMyProfile();
    _loadBiometricSettings();
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _avatarUrl.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _company.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic>? profile) {
    if (_didHydrate) return;
    _name.text = '${profile?['name'] ?? widget.session.displayName}';
    _username.text = '${profile?['username'] ?? ''}';
    _email.text = '${profile?['email'] ?? ''}';
    _avatarUrl.text = '${profile?['avatar_url'] ?? ''}';
    _phone.text = '${profile?['phone'] ?? ''}';
    _address.text = '${profile?['address'] ?? ''}';
    _city.text = '${profile?['city'] ?? ''}';
    _company.text = '${profile?['company'] ?? ''}';
    _didHydrate = true;
  }

  Future<void> _loadBiometricSettings() async {
    final state = await widget.biometricService.getSignInAvailability();
    if (!mounted) return;
    setState(() {
      _biometricEnabled = state.enabledInSettings;
      _biometricSupported = state.deviceSupported;
      _biometricEnrolled = state.hasEnrolledBiometrics;
      _biometricManualBound = state.hasManualBinding;
      _biometricLabel = state.label;
      _biometricLoading = false;
    });
  }

  String _biometricHint() {
    if (_biometricLoading) {
      return _t('Memuat status biometrik...', 'Loading biometric status...');
    }
    if (!_biometricSupported) {
      return _t(
        'Perangkat tidak mendukung autentikasi biometrik.',
        'Device does not support biometric authentication.',
      );
    }
    if (!_biometricEnrolled) {
      return _t(
        'Daftarkan $_biometricLabel di pengaturan perangkat terlebih dahulu.',
        'Please enroll $_biometricLabel in device settings first.',
      );
    }
    if (!_biometricManualBound) {
      return _t(
        'Login manual wajib dilakukan minimal sekali sebelum biometrik bisa dipakai.',
        'Manual login must be completed at least once before biometric sign-in can be used.',
      );
    }
    if (_biometricEnabled) {
      return _t(
        'Biometrik aktif. Saat aplikasi dibuka ulang, Anda bisa sign in dengan $_biometricLabel.',
        'Biometric is active. When the app is reopened, you can sign in with $_biometricLabel.',
      );
    }
    return _t(
      'Aktifkan untuk login cepat menggunakan $_biometricLabel.',
      'Enable this for quick login using $_biometricLabel.',
    );
  }

  Future<void> _toggleBiometric(bool enabled) async {
    setState(() => _biometricSaving = true);
    try {
      if (enabled) {
        await widget.biometricService.enableBiometric();
        if (!mounted) return;
        _snack(_t(
          'Sign in with $_biometricLabel berhasil diaktifkan.',
          'Sign in with $_biometricLabel was enabled.',
        ));
      } else {
        await widget.biometricService.setBiometricEnabled(false);
        if (!mounted) return;
        _snack(_t(
          'Sign in biometrik dinonaktifkan.',
          'Biometric sign-in was disabled.',
        ));
      }
      await _loadBiometricSettings();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) {
        setState(() => _biometricSaving = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_name.text.trim().isEmpty ||
        _username.text.trim().isEmpty ||
        _email.text.trim().isEmpty) {
      _snack(
        _t('Nama, username, dan email wajib diisi.',
            'Name, username, and email are required.'),
        error: true,
      );
      return;
    }
    setState(() => _savingProfile = true);
    try {
      await widget.repository.updateMyProfile(
        name: _name.text,
        username: _username.text,
        email: _email.text,
        avatarUrl: _avatarUrl.text,
        phone: _phone.text,
        address: _address.text,
        city: _city.text,
        company: _company.text,
      );
      if (!mounted) return;
      _snack(
          _t('Profil berhasil diperbarui.', 'Profile updated successfully.'));
      setState(() {
        _didHydrate = false;
        _future = widget.repository.fetchMyProfile();
      });
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword() async {
    if (_currentPassword.text.trim().isEmpty ||
        _newPassword.text.trim().isEmpty ||
        _confirmPassword.text.trim().isEmpty) {
      _snack(
        _t('Lengkapi semua field password.',
            'Please complete all password fields.'),
        error: true,
      );
      return;
    }
    if (_newPassword.text.trim().length < 6) {
      _snack(
        _t('Password baru minimal 6 karakter.',
            'New password must be at least 6 characters.'),
        error: true,
      );
      return;
    }
    if (_newPassword.text.trim() != _confirmPassword.text.trim()) {
      _snack(
        _t('Konfirmasi password tidak sama.',
            'Password confirmation does not match.'),
        error: true,
      );
      return;
    }

    setState(() => _savingPassword = true);
    try {
      await widget.repository.updateMyPassword(
        currentPassword: _currentPassword.text.trim(),
        newPassword: _newPassword.text.trim(),
      );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      _snack(_t(
          'Password berhasil diperbarui.', 'Password updated successfully.'));
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    showCvantPopup(
      context: context,
      type: error ? CvantPopupType.error : CvantPopupType.success,
      title: error ? _t('Error', 'Error') : _t('Success', 'Success'),
      message: msg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError) {
          return _ErrorView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() {
              _future = widget.repository.fetchMyProfile();
            }),
          );
        }

        final profile = snapshot.data;
        _hydrate(profile);
        final avatar = _avatarUrl.text.trim();
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Profil Akun', 'Account Profile'),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: AppColors.surfaceSoft(context),
                      backgroundImage:
                          avatar.isEmpty ? null : NetworkImage(avatar),
                      child: avatar.isEmpty
                          ? const Icon(Icons.person_outline, size: 34)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _avatarUrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _t('Foto (URL)', 'Photo (URL)'),
                      hintText: 'https://.../foto.png',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(labelText: _t('Nama', 'Name')),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _username,
                    decoration:
                        InputDecoration(labelText: _t('Username', 'Username')),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        InputDecoration(labelText: _t('Email', 'Email')),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                        labelText: _t('Nomor HP', 'Phone Number')),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _address,
                    decoration:
                        InputDecoration(labelText: _t('Alamat', 'Address')),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _city,
                    decoration: InputDecoration(labelText: _t('Kota', 'City')),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _company,
                    decoration:
                        InputDecoration(labelText: _t('Perusahaan', 'Company')),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_t('Role', 'Role')}: ${profile?['role'] ?? widget.session.role}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _savingProfile ? null : _saveProfile,
                      child: Text(
                        _savingProfile
                            ? _t('Menyimpan...', 'Saving...')
                            : _t('Simpan Perubahan', 'Save Changes'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _PanelCard(
              child: ValueListenableBuilder<AppLanguage>(
                valueListenable: LanguageController.language,
                builder: (context, language, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('Language / Bahasa', 'Language / Bahasa'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t('Pilih bahasa tampilan dashboard.',
                            'Choose dashboard display language.'),
                        style:
                            TextStyle(color: AppColors.textMutedFor(context)),
                      ),
                      const SizedBox(height: 8),
                      CvantDropdownField<AppLanguage>(
                        initialValue: language,
                        decoration: InputDecoration(
                          labelText: _t('Bahasa', 'Language'),
                        ),
                        items: [
                          DropdownMenuItem<AppLanguage>(
                            value: AppLanguage.id,
                            child: Text(_t('Bahasa Indonesia', 'Indonesian')),
                          ),
                          DropdownMenuItem<AppLanguage>(
                            value: AppLanguage.en,
                            child: Text(_t('English', 'English')),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          await LanguageController.setLanguage(value);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            _PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Keamanan Login', 'Login Security'),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_t(
                      'Sign in with $_biometricLabel',
                      'Sign in with $_biometricLabel',
                    )),
                    subtitle: Text(
                      _biometricHint(),
                      style: TextStyle(color: AppColors.textMutedFor(context)),
                    ),
                    value: _biometricEnabled,
                    onChanged: (_biometricLoading || _biometricSaving)
                        ? null
                        : _toggleBiometric,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Ganti Password', 'Change Password'),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _currentPassword,
                    obscureText: !_showCurrentPassword,
                    decoration: InputDecoration(
                      labelText: _t('Password Lama', 'Current Password'),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() {
                          _showCurrentPassword = !_showCurrentPassword;
                        }),
                        icon: Icon(
                          _showCurrentPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMutedFor(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newPassword,
                    obscureText: !_showNewPassword,
                    decoration: InputDecoration(
                      labelText: _t('Password Baru', 'New Password'),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() {
                          _showNewPassword = !_showNewPassword;
                        }),
                        icon: Icon(
                          _showNewPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMutedFor(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPassword,
                    obscureText: !_showConfirmPassword,
                    decoration: InputDecoration(
                      labelText: _t('Konfirmasi Password', 'Confirm Password'),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() {
                          _showConfirmPassword = !_showConfirmPassword;
                        }),
                        icon: Icon(
                          _showConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMutedFor(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _savingPassword ? null : _savePassword,
                      child: Text(
                        _savingPassword
                            ? _t('Memperbarui...', 'Updating...')
                            : _t('Perbarui Password', 'Update Password'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _DashboardContentFooter(),
          ],
        );
      },
    );
  }
}

double _toNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) {
    final number = value.toDouble();
    return number.isFinite ? number : 0;
  }

  final raw = value.toString().trim();
  if (raw.isEmpty) return 0;

  // Keep numeric punctuation only so values like "Rp 1.250.000" stay parseable.
  final sanitized = raw.replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (sanitized.isEmpty ||
      sanitized == '-' ||
      sanitized == '.' ||
      sanitized == ',') {
    return 0;
  }

  double? parsed = double.tryParse(sanitized);

  if (parsed == null) {
    // 1.250.000,50 -> 1250000.50
    if (sanitized.contains('.') && sanitized.contains(',')) {
      parsed = double.tryParse(
        sanitized.replaceAll('.', '').replaceAll(',', '.'),
      );
    }
  }
  if (parsed == null) {
    // 1.250.000 -> 1250000
    if (sanitized.contains('.') && sanitized.split('.').length > 2) {
      parsed = double.tryParse(sanitized.replaceAll('.', ''));
    }
  }
  if (parsed == null) {
    // 1,250,000 -> 1250000
    if (sanitized.contains(',') && sanitized.split(',').length > 2) {
      parsed = double.tryParse(sanitized.replaceAll(',', ''));
    }
  }
  if (parsed == null) {
    // 1250,50 -> 1250.50
    if (sanitized.contains(',') && !sanitized.contains('.')) {
      parsed = double.tryParse(sanitized.replaceAll(',', '.'));
    }
  }

  if (parsed == null || !parsed.isFinite) return 0;
  return parsed;
}
