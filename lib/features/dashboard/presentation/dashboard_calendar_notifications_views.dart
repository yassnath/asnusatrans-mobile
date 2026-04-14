part of 'dashboard_page.dart';

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
            const CvantLogo(width: 96),
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
    final pendingArmadaEvents = <_CalendarEvent>[];
    final armadaById = <String, Map<String, dynamic>>{
      for (final armada in armadas)
        '${armada['id'] ?? ''}': Map<String, dynamic>.from(armada),
    };
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final nextSortIndexByDay = <String, int>{};

    List<Map<String, dynamic>> detailRows(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return const <Map<String, dynamic>>[];
    }

    bool isAutoSanguExpense(Map<String, dynamic> expense) {
      final note = '${expense['note'] ?? ''}'.trim().toUpperCase();
      if (note.startsWith('AUTO_SANGU:')) return true;
      final ket = '${expense['keterangan'] ?? ''}'.trim().toLowerCase();
      return ket.startsWith('auto sangu sopir -');
    }

    String normalizeToken(String value) {
      return value
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(' /', '/')
          .replaceAll('/ ', '/');
    }

    DateTime? normalizeDay(DateTime? value) {
      if (value == null) return null;
      return DateTime(value.year, value.month, value.day);
    }

    DateTime? resolveEventDay({
      dynamic dateValue,
      dynamic createdAtValue,
    }) {
      return normalizeDay(
        Formatters.parseDate(dateValue) ?? Formatters.parseDate(createdAtValue),
      );
    }

    DateTime resolveCreatedMoment(Map<String, dynamic> item,
        {dynamic fallback}) {
      return Formatters.parseDate(item['created_at']) ??
          Formatters.parseDate(fallback) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    int compareByDayThenCreated(
      Map<String, dynamic> a,
      Map<String, dynamic> b, {
      required dynamic Function(Map<String, dynamic> item) dateValueOf,
    }) {
      final aDay = resolveEventDay(
            dateValue: dateValueOf(a),
            createdAtValue: a['created_at'],
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDay = resolveEventDay(
            dateValue: dateValueOf(b),
            createdAtValue: b['created_at'],
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final byDay = bDay.compareTo(aDay);
      if (byDay != 0) return byDay;

      final byCreated = resolveCreatedMoment(b, fallback: dateValueOf(b))
          .compareTo(resolveCreatedMoment(a, fallback: dateValueOf(a)));
      if (byCreated != 0) return byCreated;

      return '${b['id'] ?? ''}'.compareTo('${a['id'] ?? ''}');
    }

    int takeSortIndex(DateTime date) {
      final key = _dateKey(date);
      final next = nextSortIndexByDay[key] ?? 0;
      nextSortIndexByDay[key] = next + 1;
      return next;
    }

    bool isSameDay(DateTime? a, DateTime? b) {
      if (a == null || b == null) return false;
      return a.year == b.year && a.month == b.month && a.day == b.day;
    }

    String extractExpenseMarker(Map<String, dynamic> expense) {
      final note = '${expense['note'] ?? ''}'.trim();
      if (note.toUpperCase().startsWith('AUTO_SANGU:')) {
        return note.substring('AUTO_SANGU:'.length).trim();
      }

      final ket = '${expense['keterangan'] ?? ''}'.trim();
      final lowerKet = ket.toLowerCase();
      const prefix = 'auto sangu sopir -';
      if (lowerKet.startsWith(prefix)) {
        return ket.substring(prefix.length).trim();
      }

      return '';
    }

    ({String driver, String route}) extractAutoSanguEntry(
      Map<String, dynamic> row,
    ) {
      String driver = '${row['nama_supir'] ?? row['supir'] ?? ''}'.trim();
      String muat = '${row['lokasi_muat'] ?? ''}'.trim();
      String bongkar = '${row['lokasi_bongkar'] ?? ''}'.trim();
      final rawName = '${row['nama'] ?? row['name'] ?? ''}'.trim();
      if (driver.isEmpty && rawName.isNotEmpty) {
        driver = rawName.split('(').first.trim();
      }
      if (muat.isEmpty || bongkar.isEmpty) {
        final routeRaw = RegExp(r'\(([^()]*)\)').firstMatch(rawName)?.group(1);
        if (routeRaw != null && routeRaw.trim().isNotEmpty) {
          final parts = routeRaw.split('-');
          if (parts.isNotEmpty && muat.isEmpty) {
            muat = parts.first.trim();
          }
          if (parts.length >= 2 && bongkar.isEmpty) {
            bongkar = parts.sublist(1).join('-').trim();
          }
        }
      }
      final route =
          '${muat.isEmpty ? '-' : muat}-${bongkar.isEmpty ? '-' : bongkar}';
      return (driver: driver, route: route);
    }

    String buildIncomeSubtitle(Map<String, dynamic> invoice) {
      final number = Formatters.invoiceNumber(
        invoice['no_invoice'],
        invoice['tanggal_kop'] ?? invoice['tanggal'],
        customerName: invoice['nama_pelanggan'],
      );
      final customer = '${invoice['nama_pelanggan'] ?? '-'}'.trim();
      if (number == '-' || number.isEmpty) {
        return customer.isEmpty ? '-' : customer;
      }
      if (customer.isEmpty || customer == '-') return number;
      return '$number • $customer';
    }

    String buildExpenseSubtitle(Map<String, dynamic> expense) {
      if (isAutoSanguExpense(expense)) {
        final details = detailRows(expense['rincian']);
        final labels = <String>[];
        final seen = <String>{};
        for (final row in details) {
          final entry = extractAutoSanguEntry(row);
          final label = entry.driver.isEmpty
              ? entry.route
              : '${entry.driver}: ${entry.route}';
          final key =
              label.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
          if (label.trim().isNotEmpty && seen.add(key)) {
            labels.add(label);
          }
        }
        if (labels.isNotEmpty) return labels.join(' | ');
      }

      final number =
          Formatters.invoiceNumber(expense['no_expense'], expense['tanggal']);
      final description =
          '${expense['keterangan'] ?? expense['note'] ?? _t('Expense', 'Expense')}'
              .trim();
      if (number == '-' || number.isEmpty) {
        return description.isEmpty ? _t('Expense', 'Expense') : description;
      }
      if (description.isEmpty || description == '-') return number;
      return '$number • $description';
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

    final sortedInvoices = invoices
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false)
      ..sort(
        (a, b) => compareByDayThenCreated(
          a,
          b,
          dateValueOf: (item) => item['tanggal'],
        ),
      );
    final sortedExpenses = expenses
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false)
      ..sort(
        (a, b) => compareByDayThenCreated(
          a,
          b,
          dateValueOf: (item) => item['tanggal'],
        ),
      );

    final incomeIdByToken = <String, String>{};
    for (final invoice in sortedInvoices) {
      final invoiceId = '${invoice['id'] ?? ''}'.trim();
      if (invoiceId.isEmpty) continue;
      incomeIdByToken[normalizeToken(invoiceId)] = invoiceId;

      final rawNumber = '${invoice['no_invoice'] ?? ''}'.trim();
      if (rawNumber.isNotEmpty) {
        incomeIdByToken[normalizeToken(rawNumber)] = invoiceId;
      }

      final formattedNumber = Formatters.invoiceNumber(
        invoice['no_invoice'],
        invoice['tanggal_kop'] ?? invoice['tanggal'],
        customerName: invoice['nama_pelanggan'],
      );
      if (formattedNumber.trim().isNotEmpty && formattedNumber.trim() != '-') {
        incomeIdByToken[normalizeToken(formattedNumber)] = invoiceId;
      }
    }

    final linkedExpensesByIncomeId = <String, List<Map<String, dynamic>>>{};
    for (final expense in sortedExpenses) {
      final markerKey = normalizeToken(extractExpenseMarker(expense));
      if (markerKey.isEmpty) continue;
      final linkedIncomeId = incomeIdByToken[markerKey];
      if (linkedIncomeId == null || linkedIncomeId.isEmpty) continue;
      linkedExpensesByIncomeId
          .putIfAbsent(linkedIncomeId, () => <Map<String, dynamic>>[])
          .add(expense);
    }

    final renderedExpenseIds = <String>{};
    for (final invoice in sortedInvoices) {
      final invoiceId = '${invoice['id'] ?? ''}';
      final invoiceDate = resolveEventDay(
        dateValue: invoice['tanggal'],
        createdAtValue: invoice['created_at'],
      );
      if (invoiceDate == null) continue;

      events.add(
        _CalendarEvent(
          id: invoiceId,
          type: 'income',
          title: _t('Income', 'Income'),
          subtitle: buildIncomeSubtitle(invoice),
          status: '${invoice['status'] ?? 'Waiting'}',
          total: _toNum(invoice['total_bayar'] ?? invoice['total_biaya']),
          date: invoiceDate,
          sortIndex: takeSortIndex(invoiceDate),
          dotColor: AppColors.blue,
        ),
      );

      final linkedExpenses = linkedExpensesByIncomeId[invoiceId] ?? const [];
      for (final expense in linkedExpenses) {
        final expenseDate = resolveEventDay(
          dateValue: expense['tanggal'],
          createdAtValue: expense['created_at'],
        );
        final expenseId = '${expense['id'] ?? ''}'.trim();
        if (!isSameDay(invoiceDate, expenseDate) || expenseId.isEmpty) {
          continue;
        }
        renderedExpenseIds.add(expenseId);
        events.add(
          _CalendarEvent(
            id: expenseId,
            type: 'expense',
            title: _t('Expense', 'Expense'),
            subtitle: buildExpenseSubtitle(expense),
            status: '${expense['status'] ?? 'Recorded'}',
            total: _toNum(expense['total_pengeluaran']),
            date: expenseDate,
            sortIndex: takeSortIndex(expenseDate!),
            dotColor: AppColors.danger,
          ),
        );
      }

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
          final armadaEvent = _CalendarEvent(
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
            sortIndex: 0,
            dotColor: statusColor,
          );
          if (isSameDay(invoiceDate, day)) {
            events.add(
              _CalendarEvent(
                id: armadaEvent.id,
                type: armadaEvent.type,
                title: armadaEvent.title,
                subtitle: armadaEvent.subtitle,
                status: armadaEvent.status,
                total: armadaEvent.total,
                date: day,
                startDate: armadaEvent.startDate,
                endDate: armadaEvent.endDate,
                sortIndex: takeSortIndex(day),
                dotColor: armadaEvent.dotColor,
              ),
            );
          } else {
            pendingArmadaEvents.add(armadaEvent);
          }
        }
      }
    }

    for (final expense in sortedExpenses) {
      final expenseId = '${expense['id'] ?? ''}'.trim();
      if (expenseId.isNotEmpty && renderedExpenseIds.contains(expenseId)) {
        continue;
      }
      final expenseDate = resolveEventDay(
        dateValue: expense['tanggal'],
        createdAtValue: expense['created_at'],
      );
      if (expenseDate == null) continue;
      events.add(
        _CalendarEvent(
          id: expenseId,
          type: 'expense',
          title: _t('Expense', 'Expense'),
          subtitle: buildExpenseSubtitle(expense),
          status: '${expense['status'] ?? 'Recorded'}',
          total: _toNum(expense['total_pengeluaran']),
          date: expenseDate,
          sortIndex: takeSortIndex(expenseDate),
          dotColor: AppColors.danger,
        ),
      );
    }

    pendingArmadaEvents.sort((a, b) {
      final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byDate = aDate.compareTo(bDate);
      if (byDate != 0) return byDate;
      final aStart = a.startDate ?? aDate;
      final bStart = b.startDate ?? bDate;
      final byStart = aStart.compareTo(bStart);
      if (byStart != 0) return byStart;
      return a.title.compareTo(b.title);
    });

    for (final armadaEvent in pendingArmadaEvents) {
      final date = armadaEvent.date;
      if (date == null) continue;
      events.add(
        _CalendarEvent(
          id: armadaEvent.id,
          type: armadaEvent.type,
          title: armadaEvent.title,
          subtitle: armadaEvent.subtitle,
          status: armadaEvent.status,
          total: armadaEvent.total,
          date: date,
          startDate: armadaEvent.startDate,
          endDate: armadaEvent.endDate,
          sortIndex: takeSortIndex(date),
          dotColor: armadaEvent.dotColor,
        ),
      );
    }

    events.sort((a, b) {
      final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byDate = bd.compareTo(ad);
      if (byDate != 0) return byDate;
      return a.sortIndex.compareTo(b.sortIndex);
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
      entry.value.sort(_compareCalendarEvents);
    }

    return result;
  }

  int _compareCalendarEvents(_CalendarEvent a, _CalendarEvent b) {
    final bySortIndex = a.sortIndex.compareTo(b.sortIndex);
    if (bySortIndex != 0) return bySortIndex;

    final aStart =
        a.startDate ?? a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bStart =
        b.startDate ?? b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
    final byStart = aStart.compareTo(bStart);
    if (byStart != 0) return byStart;

    return a.title.compareTo(b.title);
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
                final isSunday = dayDate.weekday == DateTime.sunday;
                final dayHeaderColor = isSunday
                    ? AppColors.danger
                    : AppColors.textMutedFor(context);
                final items = [
                  ...(eventsByDate[key] ?? const <_CalendarEvent>[])
                ]..sort(_compareCalendarEvents);
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
                                color: isSunday ? AppColors.danger : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _weekdayLabel(dayDate),
                                style: TextStyle(
                                  color: dayHeaderColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              Formatters.dmy(dayDate),
                              style: TextStyle(
                                color: dayHeaderColor,
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
    required this.sortIndex,
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
  final int sortIndex;
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
