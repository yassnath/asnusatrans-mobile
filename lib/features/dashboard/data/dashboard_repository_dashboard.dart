part of 'dashboard_repository.dart';

extension DashboardRepositoryDashboardExtension on DashboardRepository {
  Future<MonthlyFinanceReminderSummary> loadMonthlyFinanceReminderSummary({
    DateTime? targetMonth,
  }) async {
    final focus = targetMonth ?? DateTime.now();
    final monthStart = DateTime(focus.year, focus.month, 1);
    final monthEnd = DateTime(focus.year, focus.month + 1, 1);

    try {
      const invoiceColumns =
          'id,tanggal,tanggal_kop,total_bayar,total_biaya,pph,created_at,'
          'armada_start_date,rincian,submission_role,approval_status';
      final response = await Future.wait<dynamic>([
        _runInvoiceSelectWithFallback(
          invoiceColumns,
          (columns) => _supabase.from('invoices').select(columns),
        ),
        _supabase
            .from('expenses')
            .select('id,tanggal,total_pengeluaran,rincian,created_at'),
      ]);

      final currentRole = await _loadCurrentRole();
      final invoices = _toMapList(response[0]).where((row) {
        if (currentRole == 'admin' || currentRole == 'owner') {
          return _isApprovedForBackoffice(row);
        }
        return true;
      }).toList();
      final expenses = _toMapList(response[1])
          .map(_normalizeExpenseRow)
          .where((row) => _expenseTotal(row) > 0)
          .toList();

      final totalIncome = invoices.fold<double>(0, (sum, invoice) {
        final date = _invoiceReferenceDate(invoice);
        if (date == null ||
            date.isBefore(monthStart) ||
            !date.isBefore(monthEnd)) {
          return sum;
        }
        return sum + _invoiceTotal(invoice);
      });
      final totalExpense = expenses.fold<double>(0, (sum, expense) {
        final date =
            Formatters.parseDate(expense['tanggal'] ?? expense['created_at']);
        if (date == null ||
            date.isBefore(monthStart) ||
            !date.isBefore(monthEnd)) {
          return sum;
        }
        return sum + _expenseTotal(expense);
      });

      return MonthlyFinanceReminderSummary(
        month: monthStart,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
      );
    } on PostgrestException catch (e) {
      throw Exception(
        'Gagal memuat ringkasan keuangan bulanan: ${e.message}',
      );
    }
  }

  Future<DashboardBundle> loadAdminDashboard() async {
    try {
      const invoiceColumns =
          'id,no_invoice,invoice_entity,tanggal,tanggal_kop,nama_pelanggan,status,total_bayar,total_biaya,pph,'
          'armada_id,armada_start_date,armada_end_date,muatan,created_at,rincian,'
          'created_by,submission_role,approval_status';
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

      final currentRole = await _loadCurrentRole();
      final invoices = _toMapList(response[0]).where((row) {
        if (currentRole == 'admin' || currentRole == 'owner') {
          return _isApprovedForBackoffice(row);
        }
        return true;
      }).toList();
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
      const invoiceColumns =
          'id,no_invoice,invoice_entity,tanggal,tanggal_kop,nama_pelanggan,'
          'armada_id,armada_start_date,armada_end_date,created_at,rincian,'
          'created_by,submission_role,approval_status';
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

      final currentRole = await _loadCurrentRole();
      final invoices = _toMapList(response[0]).where((row) {
        if (currentRole == 'admin' || currentRole == 'owner') {
          return _isApprovedForBackoffice(row);
        }
        return true;
      }).toList();
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
}
