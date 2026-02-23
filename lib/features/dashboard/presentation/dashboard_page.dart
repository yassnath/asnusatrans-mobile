import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/cvant_button_styles.dart';
import '../../../core/theme/theme_controller.dart';
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
  int _adminIndex = 0;
  int _customerIndex = 0;
  _InvoicePrefillData? _invoicePrefill;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _adminFuture = widget.repository.loadAdminDashboard();
    _customerFuture = widget.repository.loadCustomerDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final isCustomer = widget.session.isCustomer;
    final menus = isCustomer ? _customerMenus : _adminMenus;
    final selected = isCustomer ? _customerIndex : _adminIndex;
    final isLightMode = AppColors.isLight(context);
    final bodyKey = ValueKey<String>(
      isCustomer ? 'customer-page-$_customerIndex' : 'admin-page-$_adminIndex',
    );
    final pageBody = isCustomer ? _buildCustomerBody() : _buildAdminBody();

    return Scaffold(
      backgroundColor: AppColors.pageBackground(context),
      drawer: _DashboardDrawer(
        items: menus,
        selectedIndex: selected,
        onSelect: (index) {
          setState(() {
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
          menus[selected],
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
          onQuickMenuSelect: (index) {
            setState(() => _adminIndex = index);
          },
        );
      case 2:
        return _AdminCreateIncomeView(
          repository: widget.repository,
          onCreated: () => setState(_reload),
          prefill: _invoicePrefill,
          onPrefillConsumed: () {
            if (!mounted || _invoicePrefill == null) return;
            setState(() => _invoicePrefill = null);
          },
        );
      case 3:
        return _AdminCreateExpenseView(
          repository: widget.repository,
          onCreated: () => setState(_reload),
        );
      case 4:
        return _AdminCalendarView(repository: widget.repository);
      case 5:
        return _AdminFleetListView(repository: widget.repository);
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
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
            const SizedBox(height: 12),
            IncomeExpenseChartCard(
              income: data.monthlySeries.income,
              expense: data.monthlySeries.expense,
            ),
            const SizedBox(height: 12),
            ArmadaOverviewCard(
              items: data.armadaUsages,
              onViewAll: () => setState(() => _adminIndex = 5),
            ),
            const SizedBox(height: 12),
            LatestCustomersCard(
              latestCustomers: data.latestCustomers,
              biggestTransactions: data.biggestTransactions,
              onViewAll: () => setState(() => _adminIndex = 1),
            ),
            const SizedBox(height: 12),
            RecentActivityCard(
              items: data.recentActivities,
              onViewAll: () => setState(() => _adminIndex = 4),
            ),
            const SizedBox(height: 12),
            RecentTransactionsCard(
              items: data.recentTransactions,
              onViewAll: () => setState(() => _adminIndex = 1),
            ),
            const SizedBox(height: 12),
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
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
            const SizedBox(height: 12),
            CustomerOrdersCard(
              orders: data.latestOrders,
              onViewAll: () => setState(() => _customerIndex = 2),
            ),
            const SizedBox(height: 12),
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
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  final List<String> items;
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
                        items[index],
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
                      title: 'Konfirmasi Logout',
                      message:
                          'Anda akan keluar dari aplikasi. Lanjutkan logout?',
                      type: CvantPopupType.error,
                      cancelLabel: 'Batal',
                      confirmLabel: 'Logout',
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
                  label: Text('Log Out'),
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
    setState(() => _future = _load());
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

    for (final invoice in invoices) {
      final invoiceId = '${invoice['id'] ?? ''}';
      final invoiceDate =
          Formatters.parseDate(invoice['tanggal'] ?? invoice['created_at']);
      events.add(
        _CalendarEvent(
          id: invoiceId,
          type: 'income',
          title: Formatters.invoiceNumber(
              invoice['no_invoice'], invoice['tanggal']),
          subtitle: '${invoice['nama_pelanggan'] ?? '-'}',
          status: '${invoice['status'] ?? 'Waiting'}',
          total: _toNum(invoice['total_bayar'] ?? invoice['total_biaya']),
          date: invoiceDate,
          dotColor: AppColors.blue,
        ),
      );

      final startDate = Formatters.parseDate(invoice['armada_start_date']);
      final endDate = Formatters.parseDate(invoice['armada_end_date']);
      if (startDate == null || endDate == null) {
        continue;
      }

      final armadaId = '${invoice['armada_id'] ?? ''}';
      final armada = armadaById[armadaId];
      final armadaName = '${armada?['nama_truk'] ?? 'Armada'}';
      final armadaPlate = '${armada?['plat_nomor'] ?? '-'}';
      final normalizedStart =
          DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);
      final statusColor = todayOnly.isAfter(normalizedEnd)
          ? AppColors.success
          : (todayOnly.isBefore(normalizedStart)
              ? AppColors.blue
              : AppColors.warning);

      for (var day = normalizedStart;
          !day.isAfter(normalizedEnd);
          day = day.add(const Duration(days: 1))) {
        events.add(
          _CalendarEvent(
            id: invoiceId,
            type: 'armada',
            title: '$armadaName - $armadaPlate',
            subtitle:
                '${Formatters.dmy(normalizedStart)} -> ${Formatters.dmy(normalizedEnd)}',
            status: 'Fleet Schedule',
            total: 0,
            date: day,
            startDate: normalizedStart,
            endDate: normalizedEnd,
            dotColor: statusColor,
          ),
        );
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
          subtitle: '${expense['keterangan'] ?? expense['note'] ?? 'Expense'}',
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
    const names = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    return names[date.weekday % 7];
  }

  int _daysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  String _monthYearLabel(DateTime month) {
    const names = <String>[
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
      helpText: 'Pilih Bulan',
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
        ? 'Income'
        : (event.type == 'expense' ? 'Expense' : 'Armada');
    final dateLabel = event.date == null ? '-' : Formatters.dmy(event.date);
    final rangeLabel = event.startDate != null && event.endDate != null
        ? '\nRange: ${Formatters.dmy(event.startDate)} -> ${Formatters.dmy(event.endDate)}'
        : '';
    final totalLabel = event.type == 'armada'
        ? ''
        : '\nTotal: ${Formatters.rupiah(event.total)}';
    await showCvantPopup(
      context: context,
      type: CvantPopupType.info,
      title: '$typeLabel Detail',
      message:
          '${event.title}\n${event.subtitle}\nStatus: ${event.status}\nTanggal: $dateLabel$totalLabel$rangeLabel',
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
            onRetry: () => setState(() => _future = _load()),
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
            padding: const EdgeInsets.all(12),
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
                  padding: const EdgeInsets.only(bottom: 10),
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
                        const SizedBox(height: 8),
                        if (items.isEmpty)
                          Text(
                            'No data',
                            style: TextStyle(
                              color: AppColors.textMutedFor(context),
                              fontSize: 12,
                            ),
                          )
                        else
                          ...items.map((event) {
                            final color = _eventColor(event);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
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
              const SizedBox(height: 12),
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
    setState(() => _future = _load());
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

      String title = 'Order menunggu konfirmasi';
      String message =
          'Order $code untuk rute $pickup -> $destination sedang diproses.';
      IconData icon = Icons.hourglass_bottom_outlined;
      Color color = AppColors.warning;

      if (statusLower.contains('paid')) {
        title = 'Pembayaran dikonfirmasi';
        message = 'Order $code sudah dibayar. Terima kasih.';
        icon = Icons.check_circle_outline;
        color = AppColors.success;
      } else if (statusLower.contains('accept')) {
        title = 'Order diterima';
        message =
            'Order $code diterima admin. Jadwal pengiriman akan diproses.';
        icon = Icons.task_alt_outlined;
        color = AppColors.blue;
      } else if (statusLower.contains('reject')) {
        title = 'Order ditolak';
        message = 'Order $code ditolak. Silakan cek detail dan ajukan ulang.';
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
          title: (row['title'] ?? 'Notifikasi').toString(),
          message: (row['message'] ?? '-').toString(),
          status: rawStatus.isEmpty ? 'Info' : rawStatus,
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
            onRetry: () => setState(() => _future = _load()),
          );
        }

        final orderRows = snapshot.data == null
            ? <Map<String, dynamic>>[]
            : (snapshot.data![0] as List).cast<Map<String, dynamic>>();
        final directRows = snapshot.data == null
            ? <Map<String, dynamic>>[]
            : (snapshot.data![1] as List).cast<Map<String, dynamic>>();
        if (orderRows.isEmpty && directRows.isEmpty) {
          return const _SimplePlaceholderView(
            title: 'Belum ada notifikasi',
            message:
                'Notifikasi akan muncul setelah order diproses atau invoice dikirim.',
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
                                child: Text(isRead ? 'Read' : 'Mark as read'),
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
  final _customer = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _dueDate = TextEditingController();
  DateTime _date = DateTime.now();
  String _status = 'Unpaid';
  String _acceptedBy = 'Admin';
  bool _loading = false;
  late Future<List<Map<String, dynamic>>> _armadaFuture;
  final List<Map<String, dynamic>> _details = [];
  bool _prefillApplied = false;
  bool _prefillArmadaResolved = false;
  String _prefillArmadaName = '';
  String? _linkedCustomerId;
  String? _linkedOrderId;

  @override
  void initState() {
    super.initState();
    _armadaFuture = widget.repository.fetchArmadas();
    _details.add(_newDetail());
    _applyPrefill(widget.prefill);
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
      setState(() => _date = picked);
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

  Map<String, dynamic> _newDetail() {
    return {
      'lokasi_muat': '',
      'lokasi_bongkar': '',
      'armada_id': '',
      'armada_start_date': '',
      'armada_end_date': '',
      'tonase': '',
      'harga': '',
    };
  }

  double _detailSubtotal(Map<String, dynamic> row) {
    return _toNum(row['tonase']) * _toNum(row['harga']);
  }

  double get _subtotal {
    return _details.fold<double>(
      0,
      (sum, row) => sum + _detailSubtotal(row),
    );
  }

  double get _pph => _subtotal * 0.02;
  double get _totalBayar => max(0, _subtotal - _pph);

  String _previewInvoiceNo() {
    final mm = _date.month.toString().padLeft(2, '0');
    final yy = _date.year.toString();
    return 'INC-$mm-$yy-XXXX';
  }

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
      _snack('Nama customer dan rincian wajib diisi.', error: true);
      return;
    }
    final first = _details.first;
    if ('${first['lokasi_muat']}'.trim().isEmpty ||
        '${first['lokasi_bongkar']}'.trim().isEmpty ||
        '${first['armada_id']}'.trim().isEmpty) {
      _snack('Lokasi muat, lokasi bongkar, dan armada wajib diisi.',
          error: true);
      return;
    }

    final selectedArmadaIds = _details
        .map((row) => '${row['armada_id']}'.trim())
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
        title: 'Warning',
        message:
            'Armada $armadaLabel masih on the way. Apakah customer ingin menunggu?',
        cancelLabel: 'No',
        confirmLabel: 'Yes',
      );
      if (!proceed) return;
    }

    final detailsPayload = _details.map((row) {
      return <String, dynamic>{
        'lokasi_muat': '${row['lokasi_muat']}'.trim(),
        'lokasi_bongkar': '${row['lokasi_bongkar']}'.trim(),
        'armada_id':
            '${row['armada_id']}'.trim().isEmpty ? null : '${row['armada_id']}',
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

    setState(() => _loading = true);
    try {
      await widget.repository.createInvoice(
        customerName: customer,
        total: _subtotal,
        status: _status,
        issuedDate: _date,
        email: _email.text,
        noTelp: _phone.text,
        dueDate: Formatters.parseDate(_dueDate.text),
        pickup: '${first['lokasi_muat']}',
        destination: '${first['lokasi_bongkar']}',
        armadaId: '${first['armada_id']}',
        armadaStartDate: Formatters.parseDate(first['armada_start_date']),
        armadaEndDate: Formatters.parseDate(first['armada_end_date']),
        tonase: _toNum(first['tonase']),
        harga: _toNum(first['harga']),
        acceptedBy: _acceptedBy,
        customerId: _linkedCustomerId,
        orderId: _linkedOrderId,
        details: detailsPayload,
      );
      if (!mounted) return;
      _customer.clear();
      _email.clear();
      _phone.clear();
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
      _armadaFuture = widget.repository.fetchArmadas();
      widget.onCreated();
      _snack('Invoice income berhasil ditambahkan.');
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
      title: error ? 'Error' : 'Success',
      message: msg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _armadaFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError) {
          return _ErrorView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(
                () => _armadaFuture = widget.repository.fetchArmadas()),
          );
        }

        final armadas = snapshot.data ?? [];
        _tryResolvePrefillArmada(armadas);
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nomor Invoice',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 4),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Auto Number',
                    ),
                    child: Text(_previewInvoiceNo()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Tanggal',
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
                            decoration: const InputDecoration(
                              labelText: 'Jatuh Tempo',
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
                  TextField(
                    controller: _customer,
                    decoration: const InputDecoration(
                      labelText: 'Nama Customer',
                      hintText: 'Nama pelanggan',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Customer',
                      hintText: 'email@domain.com',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'No. Telp',
                      hintText: '0812xxxx',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Rincian Muat / Bongkar & Armada',
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
                            initialValue: '${row['lokasi_muat']}',
                            decoration:
                                const InputDecoration(hintText: 'Lokasi Muat'),
                            onChanged: (value) => row['lokasi_muat'] = value,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: '${row['lokasi_bongkar']}',
                            decoration: const InputDecoration(
                              hintText: 'Lokasi Bongkar',
                            ),
                            onChanged: (value) => row['lokasi_bongkar'] = value,
                          ),
                          const SizedBox(height: 8),
                          CvantDropdownField<String>(
                            initialValue: '${row['armada_id']}'.trim().isEmpty
                                ? null
                                : '${row['armada_id']}',
                            decoration:
                                const InputDecoration(hintText: 'Pilih Armada'),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('-- Pilih Armada --'),
                              ),
                              ...armadas.map(
                                (a) => DropdownMenuItem(
                                  value: '${a['id']}',
                                  child: Text(
                                    '${a['nama_truk'] ?? '-'} - ${a['plat_nomor'] ?? '-'} (${a['status'] ?? 'Ready'})',
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => row['armada_id'] = value ?? ''),
                          ),
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
                                    decoration: const InputDecoration(
                                      labelText: 'Start Date',
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
                                    decoration: const InputDecoration(
                                      labelText: 'End Date',
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
                                  initialValue: '${row['tonase']}',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration:
                                      const InputDecoration(hintText: 'Tonase'),
                                  onChanged: (value) {
                                    row['tonase'] = value;
                                    setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: '${row['harga']}',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                      hintText: 'Harga / Ton'),
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
                                'Subtotal: ${Formatters.rupiah(rowSubtotal)}',
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
                                  child: Text('Hapus'),
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
                    child: Text('+ Tambah Rincian'),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Subtotal'),
                    child: Text(Formatters.rupiah(_subtotal)),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'PPH (2%)'),
                    child: Text(Formatters.rupiah(_pph)),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Total Bayar'),
                    child: Text(Formatters.rupiah(_totalBayar)),
                  ),
                  const SizedBox(height: 8),
                  CvantDropdownField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
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
                    decoration:
                        const InputDecoration(labelText: 'Diterima Oleh'),
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
                      child: Text(_loading ? 'Menyimpan...' : 'Simpan'),
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
  bool _loading = false;

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
      _snack('Rincian pengeluaran wajib diisi.', error: true);
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
        status: 'Recorded',
        expenseDate: _date,
        note: note,
        kategori: detailsPayload.first['nama']?.toString(),
        keterangan: note,
        details: detailsPayload,
      );
      if (!mounted) return;
      _details
        ..clear()
        ..add(_newDetail());
      widget.onCreated();
      _snack('Expense berhasil ditambahkan.');
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
      title: error ? 'Error' : 'Success',
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
                'Nomor Expense',
                style: TextStyle(color: AppColors.textMutedFor(context)),
              ),
              const SizedBox(height: 4),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Auto Number'),
                child: Text(_previewExpenseNo()),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal',
                  ),
                  child: Text(Formatters.dmy(_date)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Rincian Pengeluaran',
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
                        decoration:
                            const InputDecoration(hintText: 'Nama Pengeluaran'),
                        onChanged: (value) => row['nama'] = value,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: '${row['jumlah']}',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(hintText: 'Jumlah'),
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
                            child: Text('Hapus'),
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
                child: Text('+ Tambah Rincian'),
              ),
              const SizedBox(height: 10),
              InputDecorator(
                decoration:
                    const InputDecoration(labelText: 'Total Pengeluaran'),
                child: Text(Formatters.rupiah(_totalExpense)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _save,
                  child: Text(_loading ? 'Menyimpan...' : 'Simpan'),
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
      _snack('Nama truk dan plat nomor wajib diisi.', error: true);
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
      _snack('Armada berhasil ditambahkan.');
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
      title: error ? 'Error' : 'Success',
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
                decoration: const InputDecoration(
                  labelText: 'Nama Truk',
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _plate,
                decoration: const InputDecoration(
                  labelText: 'Plat Nomor',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _capacity,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Kapasitas (Tonase)',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
              ),
              const SizedBox(height: 10),
              CvantDropdownField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
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
                  child: Text(_loading ? 'Menyimpan...' : 'Simpan'),
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
      _snack('Lengkapi detail order dan estimasi biaya.', error: true);
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
      _snack('Order berhasil dibuat.');
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
      title: error ? 'Error' : 'Success',
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
            onRetry: () => setState(() => _future = _load()),
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
                    decoration: const InputDecoration(
                      labelText: 'Nama',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _email,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phone,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Nomor HP',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _company,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Perusahaan (opsional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cargo,
                    decoration: const InputDecoration(
                      labelText: 'Jenis Barang',
                      hintText: 'Contoh: material, makanan',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Catatan',
                      hintText: 'Catatan tambahan',
                    ),
                  ),
                  const SizedBox(height: 10),
                  CvantDropdownField<String>(
                    initialValue: _service,
                    decoration: const InputDecoration(
                      labelText: 'Service',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'regular',
                        child: Text('Regular'),
                      ),
                      DropdownMenuItem(
                        value: 'express',
                        child: Text('Express'),
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
                    decoration: const InputDecoration(
                      labelText: 'Estimasi Biaya',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Rincian Muat / Bongkar & Armada',
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
                            decoration:
                                const InputDecoration(hintText: 'Lokasi Muat'),
                            onChanged: (value) => row['lokasi_muat'] = value,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: '${row['lokasi_bongkar']}',
                            decoration: const InputDecoration(
                              hintText: 'Lokasi Bongkar',
                            ),
                            onChanged: (value) => row['lokasi_bongkar'] = value,
                          ),
                          const SizedBox(height: 8),
                          CvantDropdownField<String>(
                            initialValue: '${row['armada_id']}'.trim().isEmpty
                                ? null
                                : '${row['armada_id']}',
                            decoration: const InputDecoration(
                              hintText: 'Pilih Armada',
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('Pilih Armada'),
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
                              decoration: const InputDecoration(
                                labelText: 'Tanggal Pengiriman',
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
                                child: Text('Remove'),
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
                    child: Text('+ Add Detail'),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tanggal Umum Order',
                      ),
                      child: Text(Formatters.dmy(_pickupDate)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _save,
                      child: Text(_loading ? 'Saving...' : 'Save Order'),
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
    final color = lower.contains('ready')
        ? AppColors.success
        : lower.contains('full')
            ? AppColors.warning
            : isActive
                ? AppColors.success
                : isNonActive
                    ? AppColors.neutralOutline
                    : lower.contains('paid')
                        ? AppColors.success
                        : lower.contains('accept')
                            ? AppColors.blue
                            : lower.contains('reject')
                                ? AppColors.danger
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
  });

  final DashboardRepository repository;
  final ValueChanged<int> onQuickMenuSelect;
  final bool isOwner;

  @override
  State<_AdminInvoiceListView> createState() => _AdminInvoiceListViewState();
}

class _AdminInvoiceListViewState extends State<_AdminInvoiceListView> {
  late Future<List<dynamic>> _future;
  final _search = TextEditingController();
  String _limit = '10';

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
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _deleteInvoice(String id) async {
    try {
      await widget.repository.deleteInvoice(id);
      if (!mounted) return;
      _snack('Invoice berhasil dihapus.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _deleteExpense(String id) async {
    try {
      await widget.repository.deleteExpense(id);
      if (!mounted) return;
      _snack('Expense berhasil dihapus.');
      await _refresh();
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
      title: isIncome ? 'Hapus Invoice' : 'Hapus Expense',
      message: 'Data yang dihapus tidak bisa dikembalikan.',
      type: CvantPopupType.error,
      cancelLabel: 'Batal',
      confirmLabel: 'Hapus',
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
      title: 'Send Invoice',
      message: 'Kirim invoice $invoiceNumber ke $customerName?',
      cancelLabel: 'Cancel',
      confirmLabel: 'Send',
    );
    if (!ok) return;

    try {
      if (invoiceId.isEmpty) {
        throw Exception('ID invoice tidak ditemukan.');
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
        _snack('Invoice berhasil dikirim ke notifikasi akun customer.');
      } else {
        final email = (delivery.email ?? '').trim();
        if (email.isEmpty) {
          throw Exception(
            'Email customer tidak tersedia. Lengkapi email invoice terlebih dahulu.',
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
            'Aplikasi email tidak ditemukan di perangkat ini.',
          );
        }
        _snack('Invoice diarahkan ke email $email.');
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
    final range = await showDialog<String>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        return AlertDialog(
          title: Text('Generate Report'),
          content: Text(
            'Pilih range report yang ingin dibuat.',
            style: TextStyle(color: AppColors.textMutedFor(context)),
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
              child: Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, 'month'),
              style: CvantButtonStyles.outlined(
                context,
                color: AppColors.blue,
                borderColor: AppColors.blue,
              ),
              child: Text('Monthly'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'year'),
              style:
                  CvantButtonStyles.filled(context, color: AppColors.success),
              child: Text('Yearly'),
            ),
          ],
        );
      },
    );
    if (range == null) return;

    final now = DateTime.now();
    final start = range == 'year'
        ? DateTime(now.year, 1, 1)
        : DateTime(now.year, now.month, 1);
    final end = range == 'year'
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);

    bool inRange(dynamic value) {
      final date = Formatters.parseDate(value);
      if (date == null) return false;
      return !date.isBefore(start) && date.isBefore(end);
    }

    final incomeRows = incomes
        .where((item) => inRange(item['tanggal'] ?? item['created_at']))
        .toList();
    final expenseRows = expenses
        .where((item) => inRange(item['tanggal'] ?? item['created_at']))
        .toList();

    final totalIncome = incomeRows.fold<double>(
      0,
      (sum, item) => sum + _toNum(item['total_bayar'] ?? item['total_biaya']),
    );
    final totalExpense = expenseRows.fold<double>(
      0,
      (sum, item) => sum + _toNum(item['total_pengeluaran']),
    );

    if (!mounted) return;
    await showCvantPopup(
      context: context,
      type: CvantPopupType.success,
      title: range == 'year' ? 'Yearly Report' : 'Monthly Report',
      message:
          'Income: ${incomeRows.length} data (${Formatters.rupiah(totalIncome)})\n'
          'Expense: ${expenseRows.length} data (${Formatters.rupiah(totalExpense)})',
    );
  }

  Future<void> _openInvoicePreview(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        final detailList = _toDetailList(item['rincian']);
        return AlertDialog(
          title: Text('Preview ${item['no_invoice'] ?? '-'}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: ${item['nama_pelanggan'] ?? '-'}'),
                  Text('Email: ${item['email'] ?? '-'}'),
                  Text('Tanggal: ${Formatters.dmy(item['tanggal'])}'),
                  Text('Status: ${item['status'] ?? '-'}'),
                  const SizedBox(height: 8),
                  Text(
                    'Total: ${Formatters.rupiah(_toNum(item['total_bayar'] ?? item['total_biaya']))}',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (detailList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Rincian',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ...detailList.map((row) {
                      final tonase = _toNum(row['tonase']);
                      final harga = _toNum(row['harga']);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '- ${row['lokasi_muat'] ?? '-'} -> ${row['lokasi_bongkar'] ?? '-'} | ${tonase.toStringAsFixed(2)} x ${Formatters.rupiah(harga)}',
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openExpensePreview(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        final detailList = _toDetailList(item['rincian']);
        return AlertDialog(
          title: Text('Preview ${item['no_expense'] ?? '-'}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kategori: ${item['kategori'] ?? '-'}'),
                  Text(
                      'Keterangan: ${item['keterangan'] ?? item['note'] ?? '-'}'),
                  Text('Tanggal: ${Formatters.dmy(item['tanggal'])}'),
                  Text('Status: ${item['status'] ?? '-'}'),
                  const SizedBox(height: 8),
                  Text(
                    'Total: ${Formatters.rupiah(_toNum(item['total_pengeluaran']))}',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (detailList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Rincian',
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
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Tutup'),
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
    final dueDate = TextEditingController(
      text: _toInputDate(item['due_date']),
    );
    String status = '${item['status'] ?? 'Unpaid'}';
    String acceptedBy = '${item['diterima_oleh'] ?? 'Admin'}';
    String tanggal = _toInputDate(item['tanggal']);
    bool saving = false;

    List<Map<String, dynamic>> armadas = const <Map<String, dynamic>>[];
    try {
      armadas = await widget.repository.fetchArmadas();
    } catch (_) {}

    final existingDetails = _toDetailList(item['rincian']);
    final details = existingDetails.isNotEmpty
        ? existingDetails
            .map(
              (row) => <String, dynamic>{
                'lokasi_muat': '${row['lokasi_muat'] ?? ''}',
                'lokasi_bongkar': '${row['lokasi_bongkar'] ?? ''}',
                'armada_id': '${row['armada_id'] ?? ''}',
                'armada_start_date': _toInputDate(row['armada_start_date']),
                'armada_end_date': _toInputDate(row['armada_end_date']),
                'tonase': _formatEditableNumber(row['tonase']),
                'harga': _formatEditableNumber(row['harga']),
              },
            )
            .toList()
        : <Map<String, dynamic>>[
            {
              'lokasi_muat': '${item['lokasi_muat'] ?? ''}',
              'lokasi_bongkar': '${item['lokasi_bongkar'] ?? ''}',
              'armada_id': '${item['armada_id'] ?? ''}',
              'armada_start_date': _toInputDate(item['armada_start_date']),
              'armada_end_date': _toInputDate(item['armada_end_date']),
              'tonase': _formatEditableNumber(item['tonase']),
              'harga': _formatEditableNumber(item['harga']),
            },
          ];

    double detailSubtotal(Map<String, dynamic> row) {
      return _toNum(row['tonase']) * _toNum(row['harga']);
    }

    if (!mounted) return;

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
              final pph = subtotal * 0.02;
              final totalBayar = max(0.0, subtotal - pph);

              return AlertDialog(
                title: Text('Edit Invoice'),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogField(customer, 'Nama Customer'),
                        const SizedBox(height: 8),
                        _dialogField(
                          email,
                          'Email Customer',
                          type: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 8),
                        _dialogField(
                          phone,
                          'No. Telp',
                          type: TextInputType.phone,
                        ),
                        const SizedBox(height: 8),
                        _dateSelect(
                          label: 'Tanggal Invoice',
                          value: tanggal,
                          onChanged: (v) => setDialogState(() => tanggal = v),
                        ),
                        const SizedBox(height: 8),
                        _dialogField(dueDate, 'Jatuh Tempo (dd-mm-yyyy)'),
                        const SizedBox(height: 12),
                        Text(
                          'Rincian Muat / Bongkar & Armada',
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
                                  decoration: const InputDecoration(
                                    hintText: 'Lokasi Muat',
                                  ),
                                  onChanged: (value) =>
                                      row['lokasi_muat'] = value,
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: '${row['lokasi_bongkar']}',
                                  decoration: const InputDecoration(
                                    hintText: 'Lokasi Bongkar',
                                  ),
                                  onChanged: (value) =>
                                      row['lokasi_bongkar'] = value,
                                ),
                                const SizedBox(height: 8),
                                CvantDropdownField<String>(
                                  initialValue:
                                      '${row['armada_id']}'.trim().isEmpty
                                          ? null
                                          : '${row['armada_id']}',
                                  decoration: const InputDecoration(
                                    hintText: 'Pilih Armada',
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: '',
                                      child: Text('-- Pilih Armada --'),
                                    ),
                                    ...armadas.map(
                                      (a) => DropdownMenuItem(
                                        value: '${a['id']}',
                                        child: Text(
                                          '${a['nama_truk'] ?? '-'} - ${a['plat_nomor'] ?? '-'} (${a['status'] ?? 'Ready'})',
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) => setDialogState(
                                    () => row['armada_id'] = value ?? '',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _dateSelect(
                                        label: 'Start Date',
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
                                        label: 'End Date',
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
                                        decoration: const InputDecoration(
                                          hintText: 'Tonase',
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
                                        decoration: const InputDecoration(
                                          hintText: 'Harga / Ton',
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
                                      'Subtotal: ${Formatters.rupiah(rowSubtotal)}',
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
                                        child: Text('Hapus'),
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
                                'armada_id': '',
                                'armada_start_date': '',
                                'armada_end_date': '',
                                'tonase': '',
                                'harga': '',
                              },
                            );
                          }),
                          child: Text('+ Tambah Rincian'),
                        ),
                        const SizedBox(height: 10),
                        InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Subtotal'),
                          child: Text(Formatters.rupiah(subtotal)),
                        ),
                        const SizedBox(height: 8),
                        InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'PPH (2%)'),
                          child: Text(Formatters.rupiah(pph)),
                        ),
                        const SizedBox(height: 8),
                        InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Total Bayar'),
                          child: Text(Formatters.rupiah(totalBayar)),
                        ),
                        const SizedBox(height: 8),
                        CvantDropdownField<String>(
                          initialValue: status,
                          decoration:
                              const InputDecoration(labelText: 'Status'),
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
                          decoration:
                              const InputDecoration(labelText: 'Diterima Oleh'),
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
                                    : () => Navigator.pop(context),
                                style: CvantButtonStyles.outlined(
                                  context,
                                  color: AppColors.isLight(context)
                                      ? AppColors.textSecondaryLight
                                      : const Color(0xFFE2E8F0),
                                  borderColor: AppColors.neutralOutline,
                                ),
                                child: Text('Batal'),
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
                                            'Nama customer, tanggal, dan total wajib diisi.',
                                            error: true,
                                          );
                                          return;
                                        }
                                        if ('${first['lokasi_muat']}'
                                                .trim()
                                                .isEmpty ||
                                            '${first['lokasi_bongkar']}'
                                                .trim()
                                                .isEmpty ||
                                            '${first['armada_id']}'
                                                .trim()
                                                .isEmpty) {
                                          _snack(
                                            'Lokasi muat, lokasi bongkar, dan armada wajib diisi.',
                                            error: true,
                                          );
                                          return;
                                        }

                                        final detailsPayload =
                                            details.map((row) {
                                          return <String, dynamic>{
                                            'lokasi_muat':
                                                '${row['lokasi_muat']}'.trim(),
                                            'lokasi_bongkar':
                                                '${row['lokasi_bongkar']}'
                                                    .trim(),
                                            'armada_id': '${row['armada_id']}'
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : '${row['armada_id']}',
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

                                        setDialogState(() => saving = true);
                                        try {
                                          await widget.repository.updateInvoice(
                                            id: '${item['id']}',
                                            customerName: customer.text.trim(),
                                            date: _toDbDate(tanggal),
                                            status: status,
                                            totalBiaya: subtotal,
                                            pph: pph,
                                            totalBayar: totalBayar,
                                            email: email.text,
                                            noTelp: phone.text,
                                            dueDate: dueDate.text.trim().isEmpty
                                                ? null
                                                : _toDbDate(dueDate.text),
                                            pickup: '${first['lokasi_muat']}',
                                            destination:
                                                '${first['lokasi_bongkar']}',
                                            armadaId: '${first['armada_id']}',
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
                                            details: detailsPayload,
                                            acceptedBy: acceptedBy,
                                          );
                                          if (!mounted) return;
                                          Navigator.of(this.context).pop();
                                          _snack(
                                              'Invoice berhasil diperbarui.');
                                          await _refresh();
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
                                          if (mounted) {
                                            setDialogState(
                                                () => saving = false);
                                          }
                                        }
                                      },
                                child: Text(saving ? 'Menyimpan...' : 'Simpan'),
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
      dueDate.dispose();
    }
  }

  Future<void> _openExpenseEdit(Map<String, dynamic> item) async {
    String status = '${item['status'] ?? 'Recorded'}';
    String tanggal = _toInputDate(item['tanggal']);
    bool saving = false;

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
                title: Text('Edit Expense'),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogField(
                          noExpense,
                          'Nomor Expense',
                          readOnly: true,
                        ),
                        const SizedBox(height: 8),
                        _dateSelect(
                          label: 'Tanggal Expense',
                          value: tanggal,
                          onChanged: (v) => setDialogState(() => tanggal = v),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Rincian Pengeluaran',
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
                                  decoration: const InputDecoration(
                                    hintText: 'Nama Pengeluaran',
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
                                  decoration:
                                      const InputDecoration(hintText: 'Jumlah'),
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
                                      child: Text('Hapus'),
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
                          child: Text('+ Tambah Rincian'),
                        ),
                        const SizedBox(height: 10),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Total Pengeluaran',
                          ),
                          child: Text(Formatters.rupiah(totalAmount)),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.pop(context),
                                style: CvantButtonStyles.outlined(
                                  context,
                                  color: AppColors.isLight(context)
                                      ? AppColors.textSecondaryLight
                                      : const Color(0xFFE2E8F0),
                                  borderColor: AppColors.neutralOutline,
                                ),
                                child: Text('Batal'),
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
                                            'Tanggal dan rincian pengeluaran wajib diisi.',
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
                                          await widget.repository.updateExpense(
                                            id: '${item['id']}',
                                            date: _toDbDate(tanggal),
                                            status: status,
                                            total: totalAmount,
                                            kategori:
                                                '${firstNamedRow['nama']}',
                                            keterangan: note,
                                            note: note,
                                            details: detailsPayload,
                                          );
                                          if (!mounted) return;
                                          Navigator.of(this.context).pop();
                                          _snack(
                                              'Expense berhasil diperbarui.');
                                          await _refresh();
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
                                          if (mounted) {
                                            setDialogState(
                                                () => saving = false);
                                          }
                                        }
                                      },
                                child: Text(saving ? 'Menyimpan...' : 'Simpan'),
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
      title: error ? 'Error' : 'Success',
      message: msg,
    );
  }

  List<Map<String, dynamic>> _buildCombinedRows(
    List<Map<String, dynamic>> incomes,
    List<Map<String, dynamic>> expenses,
  ) {
    final rows = <Map<String, dynamic>>[
      ...incomes.map(
        (item) => {
          ...item,
          '__type': 'Income',
          '__number': item['no_invoice'],
          '__name': item['nama_pelanggan'],
          '__total': item['total_bayar'] ?? item['total_biaya'],
          '__date': item['tanggal'] ?? item['created_at'],
          '__status': item['status'],
          '__recorded_by': item['diterima_oleh'] ?? '-',
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
      if (q.isEmpty) return true;
      final values = [
        item['__number'],
        item['__type'],
        item['__name'],
        item['__status'],
        item['__recorded_by'],
        item['__date'],
      ];
      return values.any((value) => value.toString().toLowerCase().contains(q));
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
      return const _SimplePlaceholderView(
        title: 'Data invoice kosong',
        message: 'Belum ada data income atau expense.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: rows.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == rows.length) {
            return const _DashboardContentFooter();
          }
          final item = rows[index];
          final isIncome = '${item['__type']}' == 'Income';
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
                const SizedBox(height: 4),
                Text(
                  '${item['__type']} • ${Formatters.dmy(item['__date'])}',
                  style: TextStyle(color: AppColors.textMutedFor(context)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nama: ${isIncome ? item['__name'] ?? '-' : '-'}',
                  style: TextStyle(color: AppColors.textMutedFor(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dicatat oleh: ${item['__recorded_by'] ?? '-'}',
                  style: TextStyle(color: AppColors.textMutedFor(context)),
                ),
                const SizedBox(height: 8),
                Text(
                  Formatters.rupiah(total),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
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
                        child: const Icon(Icons.visibility_outlined, size: 18),
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
            onRetry: () => setState(() => _future = _load()),
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Text(
                    'Show',
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
                              child: Text(item == 'all' ? 'All' : item),
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
                      decoration: const InputDecoration(
                        hintText: 'Search income or expense...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  if (widget.isOwner) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openReportSummary(
                          incomes: incomes,
                          expenses: expenses,
                        ),
                        style: CvantButtonStyles.outlined(
                          context,
                          color: const Color(0xFF2765EC),
                          borderColor: const Color(0xFF2765EC),
                        ),
                        icon: const Icon(Icons.print_outlined),
                        label: Text('Report PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onQuickMenuSelect(2),
                      style: CvantButtonStyles.outlined(
                        context,
                        color: AppColors.blue,
                        borderColor: AppColors.blue,
                      ),
                      icon: const Icon(Icons.add),
                      label: Text('Add Income'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onQuickMenuSelect(3),
                      style: CvantButtonStyles.outlined(
                        context,
                        color: AppColors.warning,
                        borderColor: AppColors.warning,
                      ),
                      icon: const Icon(Icons.remove_circle_outline),
                      label: Text('Add Expense'),
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
  const _AdminFleetListView({required this.repository});

  final DashboardRepository repository;

  @override
  State<_AdminFleetListView> createState() => _AdminFleetListViewState();
}

class _AdminFleetListViewState extends State<_AdminFleetListView> {
  late Future<List<dynamic>> _future;
  final _search = TextEditingController();
  int _limit = 10;

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
    setState(() => _future = _load());
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

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Armada'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: name,
                        decoration:
                            const InputDecoration(labelText: 'Nama Truk'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: plate,
                        decoration:
                            const InputDecoration(labelText: 'Plat Nomor'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: capacity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Kapasitas'),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        title: Text('Status Aktif'),
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
                  onPressed: saving ? null : () => Navigator.pop(context),
                  style: CvantButtonStyles.outlined(
                    context,
                    color: AppColors.isLight(context)
                        ? AppColors.textSecondaryLight
                        : const Color(0xFFE2E8F0),
                    borderColor: AppColors.neutralOutline,
                  ),
                  child: Text('Batal'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (name.text.trim().isEmpty ||
                              plate.text.trim().isEmpty) {
                            _snack('Nama dan plat nomor wajib diisi.',
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
                            if (!mounted) return;
                            Navigator.of(this.context).pop();
                            _snack('Armada berhasil diperbarui.');
                            await _refresh();
                          } catch (e) {
                            if (!mounted) return;
                            _snack(e.toString().replaceFirst('Exception: ', ''),
                                error: true);
                          } finally {
                            if (mounted) {
                              setDialogState(() => saving = false);
                            }
                          }
                        },
                  child: Text(saving ? 'Menyimpan...' : 'Simpan'),
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
      title: 'Hapus Armada',
      message: 'Armada akan dihapus permanen. Lanjutkan?',
      type: CvantPopupType.error,
      cancelLabel: 'Batal',
      confirmLabel: 'Hapus',
    );
    if (!ok) return;

    try {
      await widget.repository.deleteArmada(id);
      if (!mounted) return;
      _snack('Armada berhasil dihapus.');
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
      title: error ? 'Error' : 'Success',
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
            onRetry: () => setState(() => _future = _load()),
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
        final usage = <String, int>{};
        for (final invoice in invoices) {
          final armadaId = invoice['armada_id']?.toString();
          if (armadaId == null || armadaId.isEmpty) continue;
          usage[armadaId] = (usage[armadaId] ?? 0) + 1;
        }

        final q = _search.text.trim().toLowerCase();
        final filtered = armadas
            .where((item) {
              if (q.isEmpty) return true;
              final text = [
                item['nama_truk'],
                item['plat_nomor'],
                item['status'],
              ].join(' ').toLowerCase();
              return text.contains(q);
            })
            .take(_limit)
            .toList();

        final data = filtered;
        if (data.isEmpty) {
          if (armadas.isEmpty) {
            return const _SimplePlaceholderView(
              title: 'Fleet belum tampil',
              message:
                  'Data armada kosong atau role akun belum memiliki akses staff (admin/owner).',
            );
          }
          return const _SimplePlaceholderView(
            title: 'Fleet tidak ditemukan',
            message: 'Coba ubah keyword pencarian fleet.',
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Text(
                    'Show',
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
                      decoration: const InputDecoration(
                        hintText: 'Search fleet...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: data.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.local_shipping_outlined,
                                color: AppColors.cyan,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['nama_truk'] ?? '-'}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Plat: ${item['plat_nomor'] ?? '-'}',
                                      style: TextStyle(
                                        color: AppColors.textMutedFor(context),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Kapasitas: ${_toNum(item['kapasitas']).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: AppColors.textMutedFor(context),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Penggunaan: ${used}x',
                                      style: TextStyle(
                                        color: AppColors.textMutedFor(context),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _StatusPill(label: status),
                            ],
                          ),
                          const SizedBox(height: 8),
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
                                label: Text('Edit'),
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
                                label: Text('Hapus'),
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
        title: 'Success',
        message: 'Status order berhasil diupdate.',
      );
      setState(() => _future = _load());
    } catch (e) {
      if (!mounted) return;
      showCvantPopup(
        context: context,
        type: CvantPopupType.error,
        title: 'Error',
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
    final customerName =
        (customer?['name'] ?? customer?['username'] ?? 'Customer').toString();
    final total = _toNum(order['total']);
    if (total <= 0) {
      showCvantPopup(
        context: context,
        type: CvantPopupType.error,
        title: 'Error',
        message: 'Total order belum valid untuk dibuat invoice.',
      );
      return;
    }

    try {
      final existing =
          await widget.repository.findInvoiceForOrder('${order['id']}');
      if (existing != null) {
        if (!mounted) return;
        showCvantPopup(
          context: context,
          type: CvantPopupType.warning,
          title: 'Warning',
          message:
              'Invoice sudah ada: ${existing['no_invoice'] ?? existing['id']}',
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
        title: 'Invoice Add',
        message: 'Membuka halaman Invoice Add dengan data order terpilih.',
      );
    } catch (e) {
      if (!mounted) return;
      showCvantPopup(
        context: context,
        type: CvantPopupType.error,
        title: 'Error',
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
            onRetry: () => setState(() => _future = _load()),
          );
        }

        final orders = (snapshot.data![0] as List).cast<Map<String, dynamic>>();
        final customers =
            (snapshot.data![1] as List).cast<Map<String, dynamic>>();
        final customerMap = <String, Map<String, dynamic>>{
          for (final customer in customers) '${customer['id']}': customer,
        };

        if (orders.isEmpty) {
          return const _SimplePlaceholderView(
            title: 'Order belum ada',
            message: 'Belum ada order customer yang perlu diproses.',
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
                    'Customer: $customerName',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rute: ${order['pickup'] ?? '-'} -> ${order['destination'] ?? '-'}',
                    style:
                        TextStyle(color: AppColors.textSecondaryFor(context)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jadwal: ${Formatters.dmy(order['pickup_date'] ?? order['created_at'])}',
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
                          child: Text('Accept'),
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
                          child: Text('Reject'),
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
                      child: Text('Create'),
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
            onRetry: () => setState(
                () => _future = widget.repository.fetchCustomerProfiles()),
          );
        }

        final customers = snapshot.data ?? [];
        if (customers.isEmpty) {
          return const _SimplePlaceholderView(
            title: 'Belum ada customer',
            message: 'Data registrasi customer belum tersedia.',
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
                    'Username: ${customer['username'] ?? '-'}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Email: ${customer['email'] ?? '-'}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'HP: ${customer['phone'] ?? '-'}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Alamat: ${customer['address'] ?? '-'}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kota: ${customer['city'] ?? '-'}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Perusahaan: ${customer['company'] ?? '-'}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Terdaftar: ${Formatters.dmy(customer['created_at'])}',
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

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchOrders(currentUserOnly: true);
  }

  Future<void> _refresh() async {
    setState(
        () => _future = widget.repository.fetchOrders(currentUserOnly: true));
    await _future;
  }

  Future<void> _pay(Map<String, dynamic> order) async {
    String method = 'va';
    bool processing = false;

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Pembayaran Order'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Order: ${order['order_code'] ?? '-'}'),
                  const SizedBox(height: 10),
                  CvantDropdownField<String>(
                    initialValue: method,
                    decoration:
                        const InputDecoration(labelText: 'Metode Pembayaran'),
                    items: const [
                      DropdownMenuItem(
                          value: 'va', child: Text('Virtual Account')),
                      DropdownMenuItem(
                          value: 'transfer', child: Text('Transfer Bank')),
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => method = value ?? method),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: processing ? null : () => Navigator.pop(context),
                  style: CvantButtonStyles.outlined(
                    context,
                    color: AppColors.isLight(context)
                        ? AppColors.textSecondaryLight
                        : const Color(0xFFE2E8F0),
                    borderColor: AppColors.neutralOutline,
                  ),
                  child: Text('Batal'),
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
                            if (!mounted) return;
                            Navigator.of(this.context).pop();
                            showCvantPopup(
                              context: this.context,
                              type: CvantPopupType.success,
                              title: 'Success',
                              message: 'Pembayaran berhasil diproses.',
                            );
                            await _refresh();
                          } catch (e) {
                            if (!mounted) return;
                            showCvantPopup(
                              context: this.context,
                              type: CvantPopupType.error,
                              title: 'Error',
                              message:
                                  e.toString().replaceFirst('Exception: ', ''),
                            );
                          } finally {
                            if (mounted) {
                              setDialogState(() => processing = false);
                            }
                          }
                        },
                  child: Text(processing ? 'Memproses...' : 'Bayar'),
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
            onRetry: () => setState(
              () => _future =
                  widget.repository.fetchOrders(currentUserOnly: true),
            ),
          );
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const _SimplePlaceholderView(
            title: 'Belum ada order',
            message: 'Order customer masih kosong.',
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
                      'Schedule: ${Formatters.dmy(order['pickup_date'] ?? order['created_at'])}',
                      style: TextStyle(color: AppColors.textMutedFor(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Fleet: ${order['fleet'] ?? '-'}',
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
                              ? 'Pay'
                              : statusLower.contains('paid')
                                  ? 'Paid'
                                  : 'Waiting',
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
      return 'Memuat status biometrik...';
    }
    if (!_biometricSupported) {
      return 'Perangkat tidak mendukung autentikasi biometrik.';
    }
    if (!_biometricEnrolled) {
      return 'Daftarkan $_biometricLabel di pengaturan perangkat terlebih dahulu.';
    }
    if (!_biometricManualBound) {
      return 'Login manual wajib dilakukan minimal sekali sebelum biometrik bisa dipakai.';
    }
    if (_biometricEnabled) {
      return 'Biometrik aktif. Saat aplikasi dibuka ulang, Anda bisa sign in dengan $_biometricLabel.';
    }
    return 'Aktifkan untuk login cepat menggunakan $_biometricLabel.';
  }

  Future<void> _toggleBiometric(bool enabled) async {
    setState(() => _biometricSaving = true);
    try {
      if (enabled) {
        await widget.biometricService.enableBiometric();
        if (!mounted) return;
        _snack('Sign in with $_biometricLabel berhasil diaktifkan.');
      } else {
        await widget.biometricService.setBiometricEnabled(false);
        if (!mounted) return;
        _snack('Sign in biometrik dinonaktifkan.');
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
      _snack('Nama, username, dan email wajib diisi.', error: true);
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
      _snack('Profil berhasil diperbarui.');
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
      _snack('Lengkapi semua field password.', error: true);
      return;
    }
    if (_newPassword.text.trim().length < 6) {
      _snack('Password baru minimal 6 karakter.', error: true);
      return;
    }
    if (_newPassword.text.trim() != _confirmPassword.text.trim()) {
      _snack('Konfirmasi password tidak sama.', error: true);
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
      _snack('Password berhasil diperbarui.');
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
      title: error ? 'Error' : 'Success',
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
            onRetry: () =>
                setState(() => _future = widget.repository.fetchMyProfile()),
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
                    'Profil Akun',
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
                    decoration: const InputDecoration(
                      labelText: 'Foto (URL)',
                      hintText: 'https://.../foto.png',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nama'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _username,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Nomor HP'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'Alamat'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'Kota'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _company,
                    decoration: const InputDecoration(labelText: 'Perusahaan'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Role: ${profile?['role'] ?? widget.session.role}',
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _savingProfile ? null : _saveProfile,
                      child: Text(
                        _savingProfile ? 'Menyimpan...' : 'Simpan Perubahan',
                      ),
                    ),
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
                    'Keamanan Login',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Sign in with $_biometricLabel'),
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
                    'Ganti Password',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _currentPassword,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Password Lama'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newPassword,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Password Baru'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Konfirmasi Password',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _savingPassword ? null : _savePassword,
                      child: Text(
                        _savingPassword
                            ? 'Memperbarui...'
                            : 'Perbarui Password',
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
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
