part of 'dashboard_repository.dart';

extension DashboardRepositoryDashboardExtension on DashboardRepository {
  Future<FinanceReminderSummary> loadMonthlyFinanceReminderSummary({
    DateTime? targetMonth,
  }) async {
    final focus = targetMonth ?? DateTime.now();
    final monthStart = DateTime(focus.year, focus.month, 1);
    final monthEnd = DateTime(focus.year, focus.month + 1, 1);
    return loadFinanceReminderSummary(
      periodStart: monthStart,
      periodEndExclusive: monthEnd,
    );
  }

  Future<FinanceReminderSummary> loadFinanceReminderSummary({
    required DateTime periodStart,
    required DateTime periodEndExclusive,
  }) async {
    final start = DateTime(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    );
    final end = DateTime(
      periodEndExclusive.year,
      periodEndExclusive.month,
      periodEndExclusive.day,
    );

    try {
      const invoiceColumns =
          'id,no_invoice,invoice_entity,tanggal,tanggal_kop,nama_pelanggan,'
          'total_bayar,total_biaya,pph,created_at,armada_start_date,rincian,'
          'submission_role,approval_status';
      final response = await Future.wait<dynamic>([
        _runInvoiceSelectWithFallback(
          invoiceColumns,
          (columns) => _supabase.from('invoices').select(columns),
        ),
        _supabase.from('expenses').select(
              'id,tanggal,kategori,total_pengeluaran,keterangan,note,rincian,created_at',
            ),
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

      bool isWithinPeriod(DateTime? date) {
        if (date == null) return false;
        return !date.isBefore(start) && date.isBefore(end);
      }

      DateTime? detailReferenceDate(
        Map<String, dynamic> detail,
        Map<String, dynamic> invoice,
      ) {
        for (final value in [
          detail['armada_start_date'],
          detail['tanggal'],
          invoice['armada_start_date'],
          invoice['tanggal_kop'],
          invoice['tanggal'],
          invoice['created_at'],
        ]) {
          final parsed = Formatters.parseDate(value);
          if (parsed != null) return parsed;
        }
        return null;
      }

      double invoiceSubtotalInPeriod(Map<String, dynamic> invoice) {
        final details = _toMapList(invoice['rincian']);
        if (details.isNotEmpty) {
          var total = 0.0;
          for (final detail in details) {
            if (!isWithinPeriod(detailReferenceDate(detail, invoice))) {
              continue;
            }
            total += resolveInvoiceDetailExcelSubtotal(
              detail,
              fallback: details.length == 1 ? invoice : null,
              fallbackSubtotal:
                  details.length == 1 ? _num(invoice['total_biaya']) : 0,
            );
          }
          return total;
        }

        if (!isWithinPeriod(_invoiceReferenceDate(invoice))) return 0;
        final grossTotal = _num(invoice['total_biaya']);
        if (grossTotal > 0) return grossTotal;
        return _invoiceTotal(invoice);
      }

      DateTime? expenseDetailReferenceDate(
        Map<String, dynamic> detail,
        Map<String, dynamic> expense,
      ) {
        for (final value in [
          detail['armada_start_date'],
          detail['tanggal'],
          expense['tanggal'],
          expense['created_at'],
        ]) {
          final parsed = Formatters.parseDate(value);
          if (parsed != null) return parsed;
        }
        return null;
      }

      double expenseTotalInPeriod(Map<String, dynamic> expense) {
        final details = _toMapList(expense['rincian']);
        if (details.isNotEmpty) {
          var total = 0.0;
          for (final detail in details) {
            if (!isWithinPeriod(expenseDetailReferenceDate(detail, expense))) {
              continue;
            }
            total += _expenseDetailAmount(detail);
          }
          if (total > 0) return total;
        }

        final date =
            Formatters.parseDate(expense['tanggal'] ?? expense['created_at']);
        return isWithinPeriod(date) ? _expenseTotal(expense) : 0;
      }

      String normalizeMarker(String value) {
        return value
            .toUpperCase()
            .replaceAll(RegExp(r'[^A-Z0-9.]+'), '')
            .trim();
      }

      String invoiceEntityOf(Map<String, dynamic> invoice) {
        return Formatters.normalizeInvoiceEntity(
          '${invoice['invoice_entity'] ?? ''}',
          invoiceNumber: invoice['no_invoice'],
          customerName: invoice['nama_pelanggan'],
        );
      }

      bool isCompanyReminderInvoice(Map<String, dynamic> invoice) {
        return Formatters.isCompanyInvoiceEntity(invoiceEntityOf(invoice));
      }

      bool isPersonalInvoice(Map<String, dynamic> invoice) {
        return invoiceEntityOf(invoice) == Formatters.invoiceEntityPersonal;
      }

      String? expenseEntityHint(Map<String, dynamic> expense) {
        for (final value in [
          expense['invoice_entity'],
          expense['entity'],
          expense['tipe_invoice'],
          expense['type'],
          expense['kategori'],
          expense['keterangan'],
          expense['note'],
        ]) {
          final text = '${value ?? ''}'.trim();
          if (text.isEmpty) continue;
          final lower = text.toLowerCase();
          final compact = text.toUpperCase().replaceAll(RegExp(r'\s+'), '');
          if (lower.contains('pribadi') ||
              lower.contains('personal') ||
              compact.contains('/BS/') ||
              compact.startsWith('BS')) {
            return Formatters.invoiceEntityPersonal;
          }
          if (compact.contains('CV.ANT') ||
              compact.contains('PT.ANT') ||
              RegExp(r'^(CV|PT)[.\s]').hasMatch(text.toUpperCase())) {
            return Formatters.invoiceEntityCvAnt;
          }
        }
        return null;
      }

      final invoiceByMarker = <String, Map<String, dynamic>>{};
      for (final invoice in invoices) {
        final id = '${invoice['id'] ?? ''}'.trim();
        final rawNumber = '${invoice['no_invoice'] ?? ''}'.trim();
        final normalizedNumber = Formatters.invoiceNumber(
          rawNumber,
          invoice['tanggal_kop'] ?? invoice['tanggal'],
          customerName: invoice['nama_pelanggan'],
          invoiceEntity: '${invoice['invoice_entity'] ?? ''}',
        );
        for (final marker in <String>[id, rawNumber, normalizedNumber]) {
          final key = normalizeMarker(marker);
          if (key.isNotEmpty) {
            invoiceByMarker[key] = invoice;
          }
        }
      }

      final cvIncome = invoices.fold<double>(0, (sum, invoice) {
        if (!isCompanyReminderInvoice(invoice)) {
          return sum;
        }
        return sum +
            calculateInvoiceTotalAfterPph(
              invoiceSubtotalInPeriod(invoice),
            );
      });
      final personalIncome = invoices.fold<double>(0, (sum, invoice) {
        if (!isPersonalInvoice(invoice)) {
          return sum;
        }
        return sum + invoiceSubtotalInPeriod(invoice);
      });

      var cvAutoSanguExpense = 0.0;
      var personalAutoSanguExpense = 0.0;
      for (final expense in expenses) {
        final expenseTotal = expenseTotalInPeriod(expense);
        if (expenseTotal <= 0) continue;

        final isAutoExpense =
            isAutoSanguExpense(expense) || isAutoGabunganExpense(expense);
        final linkedInvoice = isAutoExpense
            ? invoiceByMarker[normalizeMarker(
                extractAutoExpenseMarker(expense),
              )]
            : null;
        final hintedEntity = linkedInvoice == null
            ? expenseEntityHint(expense)
            : invoiceEntityOf(linkedInvoice);
        final isPersonalExpense =
            hintedEntity == Formatters.invoiceEntityPersonal;
        final isCompanyExpense = hintedEntity == null ||
            Formatters.isCompanyInvoiceEntity(hintedEntity);
        if (isCompanyExpense) {
          cvAutoSanguExpense += expenseTotal;
        } else if (isPersonalExpense) {
          personalAutoSanguExpense += expenseTotal;
        }
      }

      return FinanceReminderSummary(
        periodStart: start,
        periodEndExclusive: end,
        cv: FinanceReminderEntitySummary(
          income: cvIncome,
          autoSanguExpense: cvAutoSanguExpense,
        ),
        personal: FinanceReminderEntitySummary(
          income: personalIncome,
          autoSanguExpense: personalAutoSanguExpense,
        ),
      );
    } on PostgrestException catch (e) {
      throw Exception(
        'Gagal memuat ringkasan keuangan reminder: ${e.message}',
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
