part of 'dashboard_repository.dart';

extension DashboardRepositorySupportExtension on DashboardRepository {
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
          invoice['tanggal_kop'] ?? invoice['tanggal'],
          customerName: invoice['nama_pelanggan'],
        ),
        customer: (invoice['nama_pelanggan'] ?? '-').toString(),
        displayName: (invoice['nama_pelanggan'] ?? '-').toString(),
        routeLabel: _invoiceRouteLabel(invoice),
        dateLabel: Formatters.dmy(_invoiceReferenceDateValue(invoice)),
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
            invoice['tanggal_kop'] ?? invoice['tanggal'],
            customerName: invoice['nama_pelanggan'],
          ),
          customer: (invoice['nama_pelanggan'] ?? '-').toString(),
          displayName: (invoice['nama_pelanggan'] ?? '-').toString(),
          routeLabel: _invoiceRouteLabel(invoice),
          dateLabel: Formatters.dmy(_invoiceReferenceDateValue(invoice)),
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
          displayName: _expenseDisplayName(expense),
          routeLabel: _expenseRouteLabel(expense),
          dateLabel:
              Formatters.dmy(expense['tanggal'] ?? expense['created_at']),
          total: _expenseTotal(expense),
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
    DateTime resolveCreatedAt(dynamic value) {
      return Formatters.parseDate(value) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    bool isAutoSanguExpense(Map<String, dynamic> expense) {
      final note = '${expense['note'] ?? ''}'.trim().toUpperCase();
      if (note.startsWith('AUTO_SANGU:')) return true;
      final description = '${expense['keterangan'] ?? ''}'.trim().toLowerCase();
      return description.startsWith('auto sangu sopir -');
    }

    String expenseDashboardLabel(Map<String, dynamic> expense) {
      if (isAutoSanguExpense(expense)) {
        return _expenseRouteLabel(expense);
      }
      final category = '${expense['kategori'] ?? ''}'.trim();
      if (category.isNotEmpty) return category;
      final description = '${expense['keterangan'] ?? ''}'.trim();
      if (description.isNotEmpty) return description;
      return _expenseRouteLabel(expense);
    }

    void ensureEntry({
      required List<Map<String, dynamic>> selected,
      required bool Function(Map<String, dynamic> row) predicate,
      required Map<String, dynamic> candidate,
      int Function(List<Map<String, dynamic>> selected)? replaceIndexBuilder,
    }) {
      if (candidate.isEmpty || selected.any(predicate)) return;
      if (selected.length < 6) {
        selected.add(candidate);
        return;
      }
      final replaceIndex = replaceIndexBuilder?.call(selected) ?? -1;
      selected[replaceIndex >= 0 ? replaceIndex : selected.length - 1] =
          candidate;
    }

    void ensureMinimumCount({
      required List<Map<String, dynamic>> selected,
      required Iterable<Map<String, dynamic>> candidates,
      required bool Function(Map<String, dynamic> row) predicate,
      required int minimum,
      required int Function(List<Map<String, dynamic>> selected)
          replaceIndexBuilder,
    }) {
      if (minimum <= 0) return;
      final presentCount = selected.where(predicate).length;
      if (presentCount >= minimum) return;
      final needed = minimum - presentCount;
      final missingCandidates = candidates
          .where((candidate) => candidate.isNotEmpty)
          .where(
            (candidate) =>
                !selected.any((row) => row['item'] == candidate['item']),
          )
          .take(needed)
          .toList();
      for (final candidate in missingCandidates) {
        ensureEntry(
          selected: selected,
          predicate: (row) => row['item'] == candidate['item'],
          candidate: candidate,
          replaceIndexBuilder: replaceIndexBuilder,
        );
      }
    }

    final entries = <Map<String, dynamic>>[
      ...invoices.map((invoice) {
        final id = (invoice['id'] ?? '').toString();
        final dateValue = _invoiceReferenceDateValue(invoice);
        return {
          'type': 'income',
          'date': _invoiceReferenceDate(invoice),
          'timestamp': resolveCreatedAt(invoice['created_at'] ?? dateValue),
          'item': TransactionItem(
            id: id,
            type: 'Income',
            number: Formatters.invoiceNumber(
              invoice['no_invoice'],
              invoice['tanggal_kop'] ?? invoice['tanggal'],
              customerName: invoice['nama_pelanggan'],
            ),
            customer: (invoice['nama_pelanggan'] ?? '-').toString(),
            dateLabel: Formatters.dmy(dateValue),
            total: _invoiceTotal(invoice),
            status: (invoice['status'] ?? 'Waiting').toString(),
            link: '/invoice-preview?id=$id',
          ),
        };
      }),
      ...expenses.map((expense) {
        final id = (expense['id'] ?? '').toString();
        final dateValue = expense['tanggal'] ?? expense['created_at'];
        final autoSangu = isAutoSanguExpense(expense);
        return {
          'type': 'expense',
          'isAutoSangu': autoSangu,
          'date': Formatters.parseDate(dateValue),
          'timestamp': resolveCreatedAt(expense['created_at'] ?? dateValue),
          'item': TransactionItem(
            id: id,
            type: 'Expense',
            number: Formatters.invoiceNumber(
              expense['no_expense'],
              expense['tanggal'],
            ),
            customer: expenseDashboardLabel(expense),
            dateLabel: Formatters.dmy(dateValue),
            total: _expenseTotal(expense),
            status: (expense['status'] ?? 'Recorded').toString(),
            link: '/expense-preview?id=$id',
            isAutoSangu: autoSangu,
          ),
        };
      }),
    ];

    entries.sort((a, b) {
      final ad =
          (a['date'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd =
          (b['date'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byDate = bd.compareTo(ad);
      if (byDate != 0) return byDate;
      final at = (a['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bt = (b['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final byTimestamp = bt.compareTo(at);
      if (byTimestamp != 0) return byTimestamp;
      if (a['type'] == b['type']) return 0;
      if (a['type'] == 'expense') return -1;
      return 1;
    });

    final selected = entries.take(6).toList();
    final expenseEntries = entries
        .where((row) => row['type'] == 'expense')
        .toList(growable: false);
    final autoSanguEntries = entries
        .where((row) => row['type'] == 'expense' && row['isAutoSangu'] == true)
        .toList(growable: false);
    final incomeEntries =
        entries.where((row) => row['type'] == 'income').toList(growable: false);
    final latestExpense = expenseEntries.isEmpty
        ? const <String, dynamic>{}
        : expenseEntries.first;
    final latestAutoSanguExpense = autoSanguEntries.isEmpty
        ? const <String, dynamic>{}
        : autoSanguEntries.first;
    final latestIncome =
        incomeEntries.isEmpty ? const <String, dynamic>{} : incomeEntries.first;

    ensureEntry(
      selected: selected,
      predicate: (row) => row['type'] == 'expense',
      candidate: latestExpense,
      replaceIndexBuilder: (rows) => rows.lastIndexWhere(
        (row) => row['type'] != 'income',
      ),
    );
    ensureEntry(
      selected: selected,
      predicate: (row) => row['isAutoSangu'] == true,
      candidate: latestAutoSanguExpense,
      replaceIndexBuilder: (rows) {
        final regularExpenseIndex = rows.lastIndexWhere(
          (row) => row['type'] == 'expense' && row['isAutoSangu'] != true,
        );
        if (regularExpenseIndex >= 0) return regularExpenseIndex;
        return rows.lastIndexWhere((row) => row['type'] != 'income');
      },
    );
    ensureMinimumCount(
      selected: selected,
      candidates: expenseEntries,
      predicate: (row) => row['type'] == 'expense',
      minimum: min(2, expenseEntries.length),
      replaceIndexBuilder: (rows) => rows.lastIndexWhere(
        (row) => row['type'] == 'income' && row['isAutoSangu'] != true,
      ),
    );
    ensureEntry(
      selected: selected,
      predicate: (row) => row['type'] == 'income',
      candidate: latestIncome,
      replaceIndexBuilder: (rows) => rows.lastIndexWhere(
        (row) => row['type'] == 'expense' && row['isAutoSangu'] != true,
      ),
    );

    selected.sort((a, b) {
      final ad =
          (a['date'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd =
          (b['date'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byDate = bd.compareTo(ad);
      if (byDate != 0) return byDate;
      final at = (a['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bt = (b['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final byTimestamp = bt.compareTo(at);
      if (byTimestamp != 0) return byTimestamp;
      if (a['type'] == b['type']) return 0;
      if (a['type'] == 'expense') return -1;
      return 1;
    });
    return selected
        .map((row) => row['item'] as TransactionItem)
        .take(6)
        .toList();
  }

  String _expenseRouteLabel(Map<String, dynamic> expense) {
    final details = _toMapList(expense['rincian']);
    final routes = <String>[];
    final seen = <String>{};

    String normalizeKey(String value) {
      return value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    String buildRoute(String muat, String bongkar) {
      final left = muat.trim().isEmpty ? '-' : muat.trim();
      final right = bongkar.trim().isEmpty ? '-' : bongkar.trim();
      return '$left-$right';
    }

    for (final detail in details) {
      var muat = '${detail['lokasi_muat'] ?? ''}'.trim();
      var bongkar = '${detail['lokasi_bongkar'] ?? ''}'.trim();

      if (muat.isEmpty || bongkar.isEmpty) {
        final rawName = '${detail['nama'] ?? detail['name'] ?? ''}'.trim();
        final routeRaw = RegExp(r'\(([^()]*)\)').firstMatch(rawName)?.group(1);
        if (routeRaw != null && routeRaw.trim().isNotEmpty) {
          final parts = routeRaw.split('-');
          if (muat.isEmpty && parts.isNotEmpty) {
            muat = parts.first.trim();
          }
          if (bongkar.isEmpty && parts.length >= 2) {
            bongkar = parts.sublist(1).join('-').trim();
          }
        }
      }

      if (muat.isEmpty && bongkar.isEmpty) continue;
      final route = buildRoute(muat, bongkar);
      final key = normalizeKey(route);
      if (key.isEmpty) continue;
      if (seen.add(key)) routes.add(route);
    }

    if (routes.isNotEmpty) return routes.join(' | ');

    final fromDescription = '${expense['keterangan'] ?? ''}'.trim();
    if (fromDescription.contains('-')) return fromDescription;

    return '-';
  }

  String _invoiceRouteLabel(Map<String, dynamic> invoice) {
    final details = _toMapList(invoice['rincian']);
    final routes = <String>[];
    final seen = <String>{};

    String normalizeKey(String value) {
      return value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    String buildRoute(String muat, String bongkar) {
      final left = muat.trim().isEmpty ? '-' : muat.trim();
      final right = bongkar.trim().isEmpty ? '-' : bongkar.trim();
      return '$left-$right';
    }

    void pushRoute(String muat, String bongkar) {
      if (muat.trim().isEmpty && bongkar.trim().isEmpty) return;
      final route = buildRoute(muat, bongkar);
      final key = normalizeKey(route);
      if (key.isEmpty) return;
      if (seen.add(key)) routes.add(route);
    }

    if (details.isNotEmpty) {
      for (final detail in details) {
        pushRoute(
          '${detail['lokasi_muat'] ?? invoice['lokasi_muat'] ?? ''}',
          '${detail['lokasi_bongkar'] ?? invoice['lokasi_bongkar'] ?? ''}',
        );
      }
    } else {
      pushRoute(
        '${invoice['lokasi_muat'] ?? ''}',
        '${invoice['lokasi_bongkar'] ?? ''}',
      );
    }

    if (routes.isEmpty) return '-';
    return routes.join(' | ');
  }

  String _expenseDisplayName(Map<String, dynamic> expense) {
    final details = _toMapList(expense['rincian']);
    final names = <String>[];
    final seen = <String>{};

    void pushName(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty || normalized == '-') return;
      final key = normalized.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (seen.add(key)) names.add(normalized);
    }

    for (final detail in details) {
      final explicitDriver = _extractSingleDriverName(detail);
      if ((explicitDriver ?? '').trim().isNotEmpty) {
        pushName(explicitDriver!);
        continue;
      }
      final rawName = '${detail['nama'] ?? detail['name'] ?? ''}'.trim();
      final label = rawName.split('(').first.trim();
      if (label.isNotEmpty) {
        pushName(label);
      }
    }

    if (names.isNotEmpty) return names.join(' | ');

    final category = '${expense['kategori'] ?? ''}'.trim();
    if (category.isNotEmpty) return category;
    final description = '${expense['keterangan'] ?? ''}'.trim();
    if (description.isNotEmpty) return description;
    return '-';
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
      final tanggal = _invoiceReferenceDateValue(invoice);
      final customerName = (invoice['nama_pelanggan'] ?? '-').toString();
      items.add({
        'id': 'inc-$id',
        'date': Formatters.parseDate(tanggal) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        'title': 'Pembuatan Income Invoice',
        'subtitle': customerName,
        'dateLabel': Formatters.dmy(tanggal),
        'kind': 'income',
      });
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
              'subtitle': armadaLabel,
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
              'subtitle': armadaLabel,
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
            'subtitle': armadaLabel,
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
            'subtitle': armadaLabel,
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
        'subtitle': Formatters.rupiah(_expenseTotal(expense)),
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

  Map<String, dynamic> _normalizeFixedInvoiceBatchRow(
    Map<String, dynamic> row,
  ) {
    final invoiceIds = (row['invoice_ids'] as List<dynamic>? ?? const [])
        .map((id) => '$id'.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final rawInvoiceNumber = '${row['invoice_number'] ?? ''}'.trim();
    final normalizedInvoiceNumber = rawInvoiceNumber.isEmpty
        ? rawInvoiceNumber
        : (() {
            final normalized = Formatters.invoiceNumber(
              rawInvoiceNumber,
              row['kop_date'] ?? row['created_at'],
              customerName: row['customer_name'],
            );
            return normalized == '-' ? rawInvoiceNumber : normalized;
          })();
    return <String, dynamic>{
      'batch_id': '${row['batch_id'] ?? ''}'.trim(),
      'invoice_ids': invoiceIds,
      'invoice_number': normalizedInvoiceNumber,
      'customer_name': '${row['customer_name'] ?? ''}'.trim(),
      'kop_date': '${row['kop_date'] ?? ''}'.trim(),
      'kop_location': '${row['kop_location'] ?? ''}'.trim(),
      'status': '${row['status'] ?? 'Unpaid'}'.trim(),
      'paid_at': '${row['paid_at'] ?? ''}'.trim(),
      'created_at': '${row['created_at'] ?? ''}'.trim(),
      'updated_at': '${row['updated_at'] ?? ''}'.trim(),
    };
  }

  bool _selectColumnsInclude(String columns, String target) {
    final normalizedTarget = target.trim().toLowerCase();
    return columns
        .split(',')
        .map((column) => column.trim().toLowerCase())
        .any((column) => column == normalizedTarget);
  }

  String _removeSelectColumn(String columns, String target) {
    final normalizedTarget = target.trim().toLowerCase();
    return columns
        .split(',')
        .map((column) => column.trim())
        .where(
          (column) =>
              column.isNotEmpty && column.toLowerCase() != normalizedTarget,
        )
        .join(',');
  }

  String _removeSelectColumns(String columns, Iterable<String> targets) {
    final normalizedTargets =
        targets.map((target) => target.trim().toLowerCase()).toSet();
    if (normalizedTargets.isEmpty) return columns;
    return columns
        .split(',')
        .map((column) => column.trim())
        .where(
          (column) =>
              column.isNotEmpty &&
              !normalizedTargets.contains(column.toLowerCase()),
        )
        .join(',');
  }

  bool _isMissingInvoiceNumberColumnError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('no_invoice') &&
        (message.contains('does not exist') ||
            message.contains('could not find') ||
            message.contains('schema cache'));
  }

  bool _isMissingColumnError(PostgrestException error, String column) {
    final message = error.message.toLowerCase();
    final normalizedColumn = column.trim().toLowerCase();
    if (!message.contains(normalizedColumn)) return false;
    return message.contains('does not exist') ||
        message.contains('could not find') ||
        message.contains('schema cache');
  }

  Set<String> _invoiceColumnsToDisableForMissing(String missingColumn) {
    final normalized = missingColumn.trim().toLowerCase();
    return <String>{normalized};
  }

  String? _missingOptionalInvoiceColumnFromError(
    PostgrestException error,
    String columns,
  ) {
    for (final column in DashboardRepository._optionalInvoiceColumns) {
      if (!_selectColumnsInclude(columns, column)) continue;
      if (_isMissingColumnError(error, column)) {
        return column;
      }
    }
    return null;
  }

  String? _missingOptionalInvoicePayloadColumnFromError(
    PostgrestException error,
    Map<String, dynamic> payload,
    String selectColumns,
  ) {
    for (final column in DashboardRepository._optionalInvoiceColumns) {
      if (!payload.containsKey(column) &&
          !_selectColumnsInclude(selectColumns, column)) {
        continue;
      }
      if (_isMissingColumnError(error, column)) {
        return column;
      }
    }
    return null;
  }

  String? _missingOptionalExpenseColumnFromError(
    PostgrestException error,
    String columns,
  ) {
    for (final column in DashboardRepository._optionalExpenseColumns) {
      if (!_selectColumnsInclude(columns, column)) continue;
      if (_isMissingColumnError(error, column)) {
        return column;
      }
    }
    return null;
  }

  bool _isMissingFixedInvoiceBatchTableError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('fixed_invoice_batches') &&
        (message.contains('does not exist') ||
            message.contains('could not find') ||
            message.contains('schema cache') ||
            message.contains('relation'));
  }

  String _invoiceSelectColumnsForCurrentSchema(String columns) {
    final unavailable = <String>{
      ..._unavailableInvoiceColumns,
      if (_invoiceNumberColumnAvailable == false) 'no_invoice',
    };
    return _removeSelectColumns(columns, unavailable);
  }

  Future<T> _runInvoiceSelectWithFallback<T>(
    String columns,
    Future<T> Function(String columns) request,
  ) async {
    var preferredColumns = _invoiceSelectColumnsForCurrentSchema(columns);
    while (true) {
      try {
        final result = await request(preferredColumns);
        if (_selectColumnsInclude(preferredColumns, 'no_invoice')) {
          _invoiceNumberColumnAvailable = true;
        }
        return result;
      } on PostgrestException catch (error) {
        final missingColumn = _missingOptionalInvoiceColumnFromError(
          error,
          preferredColumns,
        );
        if (missingColumn == null) rethrow;

        final disabledColumns = _invoiceColumnsToDisableForMissing(
          missingColumn,
        );
        _unavailableInvoiceColumns.addAll(disabledColumns);
        final fallbackColumns = _removeSelectColumns(
          preferredColumns,
          disabledColumns,
        );
        if (fallbackColumns == preferredColumns) rethrow;
        if (missingColumn == 'no_invoice') {
          _invoiceNumberColumnAvailable = false;
        }
        preferredColumns = fallbackColumns;
      }
    }
  }

  Future<T> _runExpenseSelectWithFallback<T>(
    String columns,
    Future<T> Function(String columns) request,
  ) async {
    var preferredColumns = _removeSelectColumns(
      columns,
      _unavailableExpenseColumns,
    );
    while (true) {
      try {
        return await request(preferredColumns);
      } on PostgrestException catch (error) {
        final missingColumn = _missingOptionalExpenseColumnFromError(
          error,
          preferredColumns,
        );
        if (missingColumn == null) rethrow;
        _unavailableExpenseColumns.add(missingColumn);
        final fallbackColumns = _removeSelectColumn(
          preferredColumns,
          missingColumn,
        );
        if (fallbackColumns == preferredColumns) rethrow;
        preferredColumns = fallbackColumns;
      }
    }
  }

  Future<Map<String, dynamic>?> _insertInvoiceWithFallback(
    Map<String, dynamic> payload, {
    String selectColumns = 'id,no_invoice',
  }) async {
    var preferredPayload = Map<String, dynamic>.from(payload);
    preferredPayload
        .removeWhere((key, _) => _unavailableInvoiceColumns.contains(key));
    if (_invoiceNumberColumnAvailable == false) {
      preferredPayload.remove('no_invoice');
    }
    var preferredColumns = _invoiceSelectColumnsForCurrentSchema(
      selectColumns,
    );

    while (true) {
      try {
        if (preferredColumns.trim().isEmpty) {
          await _supabase.from('invoices').insert(preferredPayload);
          return null;
        }

        final result = await _supabase
            .from('invoices')
            .insert(preferredPayload)
            .select(preferredColumns)
            .maybeSingle();
        if (_selectColumnsInclude(preferredColumns, 'no_invoice')) {
          _invoiceNumberColumnAvailable = true;
        }
        return result == null ? null : Map<String, dynamic>.from(result);
      } on PostgrestException catch (error) {
        final missingColumn = _missingOptionalInvoicePayloadColumnFromError(
          error,
          preferredPayload,
          preferredColumns,
        );
        if (missingColumn == null) rethrow;

        final disabledColumns = _invoiceColumnsToDisableForMissing(
          missingColumn,
        );
        _unavailableInvoiceColumns.addAll(disabledColumns);
        final nextPayload = Map<String, dynamic>.from(preferredPayload)
          ..removeWhere((key, _) => disabledColumns.contains(key));
        final nextColumns = _removeSelectColumns(
          preferredColumns,
          disabledColumns,
        );
        if (nextPayload.length == preferredPayload.length &&
            nextColumns == preferredColumns) {
          rethrow;
        }
        if (missingColumn == 'no_invoice') {
          _invoiceNumberColumnAvailable = false;
        }
        preferredPayload = nextPayload;
        preferredColumns = nextColumns;
      }
    }
  }

  Future<void> _insertExpenseWithFallback(Map<String, dynamic> payload) async {
    var preferredPayload = Map<String, dynamic>.from(payload)
      ..removeWhere((key, _) => _unavailableExpenseColumns.contains(key));
    while (preferredPayload.isNotEmpty) {
      try {
        await _supabase.from('expenses').insert(preferredPayload);
        return;
      } on PostgrestException catch (error) {
        String? missingColumn;
        for (final column in DashboardRepository._optionalExpenseColumns) {
          if (!preferredPayload.containsKey(column)) continue;
          if (_isMissingColumnError(error, column)) {
            missingColumn = column;
            break;
          }
        }
        if (missingColumn == null) rethrow;
        _unavailableExpenseColumns.add(missingColumn);
        preferredPayload = Map<String, dynamic>.from(preferredPayload)
          ..remove(missingColumn);
      }
    }
  }

  Future<void> _updateInvoiceWithFallback(
    String id,
    Map<String, dynamic> payload,
  ) async {
    var preferredPayload = Map<String, dynamic>.from(payload);
    preferredPayload
        .removeWhere((key, _) => _unavailableInvoiceColumns.contains(key));
    if (_invoiceNumberColumnAvailable == false) {
      preferredPayload.remove('no_invoice');
    }

    while (preferredPayload.isNotEmpty) {
      try {
        await _supabase.from('invoices').update(preferredPayload).eq('id', id);
        if (preferredPayload.containsKey('no_invoice')) {
          _invoiceNumberColumnAvailable = true;
        }
        return;
      } on PostgrestException catch (error) {
        String? missingColumn;
        for (final column in DashboardRepository._optionalInvoiceColumns) {
          if (!preferredPayload.containsKey(column)) continue;
          if (_isMissingColumnError(error, column)) {
            missingColumn = column;
            break;
          }
        }
        if (missingColumn == null) rethrow;
        final disabledColumns = _invoiceColumnsToDisableForMissing(
          missingColumn,
        );
        _unavailableInvoiceColumns.addAll(disabledColumns);
        if (missingColumn == 'no_invoice') {
          _invoiceNumberColumnAvailable = false;
        }
        preferredPayload = Map<String, dynamic>.from(preferredPayload)
          ..removeWhere((key, _) => disabledColumns.contains(key));
      }
    }
  }

  double _num(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _firstNonEmptyText(Iterable<dynamic> values) {
    for (final value in values) {
      final text = '${value ?? ''}'.trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return '';
  }

  double _expenseDetailAmount(Map<String, dynamic> detail) {
    final candidates = <dynamic>[
      detail['jumlah'],
      detail['amount'],
      detail['total'],
      detail['nominal'],
      detail['biaya'],
    ];
    for (final candidate in candidates) {
      final parsed = _num(candidate);
      if (parsed > 0) return parsed;
    }
    return 0;
  }

  double _expenseTotal(Map<String, dynamic> expense) {
    final direct = _num(expense['total_pengeluaran']);
    if (direct > 0) return direct;
    final details = _toMapList(expense['rincian']);
    if (details.isEmpty) return 0;
    var sum = 0.0;
    for (final detail in details) {
      sum += _expenseDetailAmount(detail);
    }
    return sum > 0 ? sum : 0;
  }

  Map<String, dynamic> _normalizeExpenseRow(Map<String, dynamic> expense) {
    final normalized = Map<String, dynamic>.from(expense);
    final total = _expenseTotal(normalized);
    if (total > 0) {
      normalized['total_pengeluaran'] = total;
    }
    return normalized;
  }

  double _invoiceTotal(Map<String, dynamic> invoice) {
    final totalBayar = _num(invoice['total_bayar']);
    if (totalBayar > 0) return totalBayar;
    final totalBiaya = _num(invoice['total_biaya']);
    final pph = _num(invoice['pph']);
    final fallback = totalBiaya - pph;
    return fallback > 0 ? fallback : 0;
  }

  dynamic _invoiceReferenceDateValue(Map<String, dynamic> invoice) {
    final detailRows = _toMapList(invoice['rincian']);
    for (final row in detailRows) {
      final raw = row['armada_start_date'];
      if (Formatters.parseDate(raw) != null) return raw;
    }
    if (Formatters.parseDate(invoice['armada_start_date']) != null) {
      return invoice['armada_start_date'];
    }
    return invoice['tanggal_kop'] ??
        invoice['tanggal'] ??
        invoice['created_at'];
  }

  DateTime? _invoiceReferenceDate(Map<String, dynamic> invoice) {
    return Formatters.parseDate(_invoiceReferenceDateValue(invoice));
  }

  dynamic _expenseReferenceDateValueFromDetails(
    List<Map<String, dynamic>> details, {
    dynamic fallbackDate,
  }) {
    for (final row in details) {
      final raw = row['armada_start_date'];
      if (Formatters.parseDate(raw) != null) return raw;
    }
    return fallbackDate;
  }

  DateTime _resolveExpenseReferenceDateFromDetails(
    List<Map<String, dynamic>> details, {
    dynamic fallbackDate,
  }) {
    return Formatters.parseDate(
          _expenseReferenceDateValueFromDetails(
            details,
            fallbackDate: fallbackDate,
          ),
        ) ??
        DateTime.now();
  }

  DateTime _safeDate(String dmy) {
    final parts = dmy.split('-');
    if (parts.length != 3) return DateTime.fromMillisecondsSinceEpoch(0);
    final day = int.tryParse(parts[0]) ?? 1;
    final month = int.tryParse(parts[1]) ?? 1;
    final year = int.tryParse(parts[2]) ?? 1970;
    return DateTime(year, month, day);
  }

  String _makeDocumentCode(
    String prefix, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final yy = now.year.toString();
    final tail =
        (now.microsecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return '$prefix-$mm-$yy-$tail';
  }

  bool _isCompanyInvoiceNumber(String number) {
    return Formatters.isCompanyInvoiceEntity(
      Formatters.normalizeInvoiceEntity(
        null,
        invoiceNumber: number,
      ),
    );
  }

  String _resolveInvoiceEntity({
    String? invoiceEntity,
    dynamic invoiceNumber,
    dynamic customerName,
    bool? isCompany,
  }) {
    return Formatters.normalizeInvoiceEntity(
      invoiceEntity,
      invoiceNumber: invoiceNumber,
      customerName: customerName,
      isCompany: isCompany,
    );
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
    for (final keyword in DashboardRepository._companyKeywords) {
      if (RegExp(keyword).hasMatch(normalized)) {
        return true;
      }
    }
    return false;
  }

  String _normalizeIncomePricingText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _incomePricingLocationMatches(String inputKey, String ruleKey) {
    if (inputKey.isEmpty || ruleKey.isEmpty) return false;
    if (inputKey == ruleKey) return true;

    final inputCompact = inputKey.replaceAll(' ', '');
    final ruleCompact = ruleKey.replaceAll(' ', '');
    if (inputCompact.isNotEmpty && inputCompact == ruleCompact) return true;

    final inputList = inputKey
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final ruleList = ruleKey
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (inputList.contains(ruleKey) || ruleList.contains(inputKey)) {
      return true;
    }
    if (ruleList.length == 1 && ruleList.first.length >= 2) {
      return inputList.contains(ruleList.first);
    }
    if (inputList.length == 1 && inputList.first.length >= 2) {
      return ruleList.contains(inputList.first);
    }

    if (inputList.length < 2 || ruleList.isEmpty) return false;
    final shorter = inputList.length <= ruleList.length ? inputList : ruleList;
    final longer = inputList.length <= ruleList.length ? ruleList : inputList;
    return shorter.length >= 2 &&
        shorter.every((token) => longer.contains(token));
  }

  bool _incomePricingCustomerMatches(String customerName, String ruleCustomer) {
    final inputKey = _normalizeCompanyText(customerName);
    final ruleKey = _normalizeCompanyText(ruleCustomer);
    if (ruleKey.isEmpty) return true;
    if (inputKey.isEmpty) return false;
    if (inputKey == ruleKey) return true;
    if (inputKey.contains(ruleKey) || ruleKey.contains(inputKey)) {
      return true;
    }

    final inputTokens = inputKey
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final ruleTokens = ruleKey
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (inputTokens.isEmpty || ruleTokens.isEmpty) return false;
    return ruleTokens.every(inputTokens.contains);
  }

  Map<String, dynamic>? _findHargaPerTonRuleMatch(
    List<Map<String, dynamic>> rules, {
    required String customerName,
    required String pickup,
    required String destination,
  }) {
    if (rules.isEmpty) return null;
    final destinationKey = _normalizeIncomePricingText(destination);
    if (destinationKey.isEmpty) return null;
    final pickupKey = _normalizeIncomePricingText(pickup);

    int specificityScore(String value) {
      if (value.isEmpty) return 0;
      final tokenCount =
          value.split(' ').where((part) => part.isNotEmpty).length;
      return (tokenCount * 100) + value.length;
    }

    int customerScore(String ruleCustomer) {
      final normalizedRuleCustomer = _normalizeCompanyText(ruleCustomer);
      if (normalizedRuleCustomer.isEmpty) return 100;
      if (!_incomePricingCustomerMatches(customerName, ruleCustomer)) {
        return -1;
      }
      final normalizedCustomerName = _normalizeCompanyText(customerName);
      if (normalizedCustomerName == normalizedRuleCustomer) {
        return 5000 + specificityScore(normalizedRuleCustomer);
      }
      return 4200 + specificityScore(normalizedRuleCustomer);
    }

    int lokasiScore(String inputKey, String ruleKey) {
      if (ruleKey.isEmpty) return 120;
      if (inputKey.isEmpty) return 0;
      if (!_incomePricingLocationMatches(inputKey, ruleKey)) return 0;
      final inputCompact = inputKey.replaceAll(' ', '');
      final ruleCompact = ruleKey.replaceAll(' ', '');
      if (inputKey == ruleKey || inputCompact == ruleCompact) {
        return 1500 + specificityScore(ruleKey);
      }
      return 900 + specificityScore(ruleKey);
    }

    Map<String, dynamic>? bestRule;
    var bestScore = -1;
    for (final rule in rules) {
      final ruleBongkarKey =
          _normalizeIncomePricingText('${rule['lokasi_bongkar'] ?? ''}');
      if (!_incomePricingLocationMatches(destinationKey, ruleBongkarKey)) {
        continue;
      }

      final currentCustomerScore =
          customerScore('${rule['customer_name'] ?? ''}');
      if (currentCustomerScore < 0) continue;

      final ruleMuatKey =
          _normalizeIncomePricingText('${rule['lokasi_muat'] ?? ''}');
      if (pickupKey.isNotEmpty &&
          ruleMuatKey.isNotEmpty &&
          !_incomePricingLocationMatches(pickupKey, ruleMuatKey)) {
        continue;
      }

      final priority = int.tryParse('${rule['priority'] ?? ''}') ??
          _num(rule['priority']).toInt();
      final score = currentCustomerScore +
          lokasiScore(pickupKey, ruleMuatKey) +
          lokasiScore(destinationKey, ruleBongkarKey) +
          priority;
      if (score > bestScore) {
        bestScore = score;
        bestRule = rule;
      }
    }
    return bestRule;
  }

  double? _resolveHargaPerTonRuleNominal(
    Map<String, dynamic>? rule, {
    required String muatan,
  }) {
    if (rule == null) return null;
    final base = _num(rule['harga_per_ton'] ?? rule['harga']);
    if (base <= 0) return null;
    return _isTolakanCargo(muatan) ? base / 2 : base;
  }

  double? _resolveHargaPerTonRuleFlatTotal(
    Map<String, dynamic>? rule, {
    required String muatan,
  }) {
    if (rule == null) return null;
    final base = _num(rule['flat_total'] ?? rule['subtotal'] ?? rule['total']);
    if (base <= 0) return null;
    return _isTolakanCargo(muatan) ? base / 2 : base;
  }

  bool _isSpecialIncomePricingBackfillCandidate(
    Map<String, dynamic>? rule, {
    required String destination,
  }) {
    if (rule == null) return false;
    final destinationKey = _normalizeIncomePricingText(destination);
    if (destinationKey.contains('batang')) return true;
    return _num(rule['flat_total']) > 0;
  }

  Map<String, dynamic>? _applySpecialIncomePricingRuleToDetail(
    Map<String, dynamic> detail, {
    required List<Map<String, dynamic>> rules,
    required String customerName,
    String? fallbackPickup,
    String? fallbackDestination,
  }) {
    final pickup = '${detail['lokasi_muat'] ?? fallbackPickup ?? ''}'.trim();
    final destination =
        '${detail['lokasi_bongkar'] ?? fallbackDestination ?? ''}'.trim();
    final matchedRule = _findHargaPerTonRuleMatch(
      rules,
      customerName: customerName,
      pickup: pickup,
      destination: destination,
    );
    if (!_isSpecialIncomePricingBackfillCandidate(
      matchedRule,
      destination: destination,
    )) {
      return null;
    }

    final muatan = '${detail['muatan'] ?? ''}'.trim();
    final nextHarga = _resolveHargaPerTonRuleNominal(
      matchedRule,
      muatan: muatan,
    );
    final nextFlatTotal = _resolveHargaPerTonRuleFlatTotal(
      matchedRule,
      muatan: muatan,
    );
    final nextDetail = Map<String, dynamic>.from(detail);
    var changed = false;

    void clearExplicitTotals() {
      for (final key in const <String>['subtotal', 'total', 'jumlah']) {
        if (!nextDetail.containsKey(key)) continue;
        final currentValue = nextDetail[key];
        if (currentValue == null) continue;
        if ('$currentValue'.trim().isEmpty) continue;
        nextDetail.remove(key);
        changed = true;
      }
    }

    if (nextFlatTotal != null && nextFlatTotal > 0) {
      clearExplicitTotals();
      final currentHarga = _num(nextDetail['harga']);
      if (currentHarga != 0) {
        nextDetail['harga'] = 0;
        changed = true;
      }
      final currentSubtotal = _num(nextDetail['subtotal']);
      if ((currentSubtotal - nextFlatTotal).abs() > 0.0001) {
        nextDetail['subtotal'] = nextFlatTotal;
        changed = true;
      }
      return changed ? nextDetail : null;
    }

    if (nextHarga == null || nextHarga <= 0) {
      return null;
    }

    clearExplicitTotals();
    final currentHarga = _num(nextDetail['harga']);
    if ((currentHarga - nextHarga).abs() > 0.0001) {
      nextDetail['harga'] = nextHarga;
      changed = true;
    }
    return changed ? nextDetail : null;
  }

  int _romanToMonth(String roman) {
    const map = <String, int>{
      'I': 1,
      'II': 2,
      'III': 3,
      'IV': 4,
      'V': 5,
      'VI': 6,
      'VII': 7,
      'VIII': 8,
      'IX': 9,
      'X': 10,
      'XI': 11,
      'XII': 12,
    };
    return map[roman.trim().toUpperCase()] ?? 0;
  }

  int _extractInvoiceSequenceForMonth({
    required String noInvoice,
    required int month,
    required int yearTwoDigits,
    required String invoiceEntity,
    DateTime? referenceDate,
  }) {
    final cleaned = noInvoice
        .replaceFirst(RegExp(r'^\s*NO\s*:\s*', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) return 0;
    final normalizedEntity = _resolveInvoiceEntity(
      invoiceEntity: invoiceEntity,
      invoiceNumber: noInvoice,
    );

    final compactPattern = RegExp(
      r'^(CV\.ANT|PT\.ANT|BS)(\d{2})(\d{2})(\d{2,})$',
      caseSensitive: false,
    );
    final compactMatch = compactPattern.firstMatch(cleaned);
    if (compactMatch != null) {
      final prefix = (compactMatch.group(1) ?? '').toUpperCase().trim();
      final rowYear = int.tryParse(compactMatch.group(2) ?? '') ?? -1;
      final rowMonth = int.tryParse(compactMatch.group(3) ?? '') ?? 0;
      final seq = int.tryParse(compactMatch.group(4) ?? '') ?? 0;
      final sameType = prefix == Formatters.invoiceEntityCode(normalizedEntity);
      if (sameType && rowMonth == month && rowYear == yearTwoDigits) {
        return seq;
      }
      return 0;
    }

    // Legacy pattern:
    // 017 / BS / I / 26
    // 017 / CV.ANT / I / 26
    final newPattern = RegExp(
      r'^(\d{1,4})\s*\/\s*(CV\.ANT|PT\.ANT|BS|ANT)\s*\/\s*([IVX]+)\s*\/\s*(\d{2})\s*$',
      caseSensitive: false,
    );
    final newMatch = newPattern.firstMatch(cleaned);
    if (newMatch != null) {
      final seq = int.tryParse(newMatch.group(1) ?? '') ?? 0;
      final prefix = (newMatch.group(2) ?? '').toUpperCase().trim();
      final rowMonth = _romanToMonth(newMatch.group(3) ?? '');
      final rowYear = int.tryParse(newMatch.group(4) ?? '') ?? -1;
      final sameType = normalizedEntity == Formatters.invoiceEntityPersonal
          ? (prefix == 'BS' || prefix == 'ANT')
          : prefix == Formatters.invoiceEntityCode(normalizedEntity);
      if (sameType && rowMonth == month && rowYear == yearTwoDigits) {
        return seq;
      }
      return 0;
    }

    // Legacy converted pattern (without year):
    final legacyPattern = RegExp(
      r'^(480\s*\/\s*CV\.ANT|268\s*\/\s*ANT)\s*\/\s*([IVX]+)\s*\/\s*(\d+)\s*$',
      caseSensitive: false,
    );
    final legacyMatch = legacyPattern.firstMatch(cleaned);
    if (legacyMatch != null) {
      final prefix =
          (legacyMatch.group(1) ?? '').toUpperCase().replaceAll(' ', '');
      final sameType = normalizedEntity == Formatters.invoiceEntityCvAnt
          ? prefix.startsWith('480/CV.ANT')
          : normalizedEntity == Formatters.invoiceEntityPersonal
              ? prefix.startsWith('268/ANT')
              : false;
      if (!sameType) return 0;

      final rowMonth = _romanToMonth(legacyMatch.group(2) ?? '');
      if (rowMonth != month) return 0;
      final rowYear =
          referenceDate == null ? yearTwoDigits : (referenceDate.year % 100);
      if (rowYear != yearTwoDigits) return 0;

      return int.tryParse(legacyMatch.group(3) ?? '') ?? 0;
    }

    // Older INC-MM-YYYY-SEQ pattern.
    final oldInc =
        RegExp(r'^INC-(\d{2})-(\d{4})-(\d{1,})$', caseSensitive: false)
            .firstMatch(cleaned.toUpperCase());
    if (oldInc != null) {
      final rowMonth = int.tryParse(oldInc.group(1) ?? '') ?? 0;
      final rowYear = (int.tryParse(oldInc.group(2) ?? '') ?? 0) % 100;
      if (rowMonth != month || rowYear != yearTwoDigits) return 0;
      return int.tryParse(oldInc.group(3) ?? '') ?? 0;
    }

    return 0;
  }

  String _dateOnly(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool _isLikelyUuid(String value) {
    final normalized = value.trim().toLowerCase();
    final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    return pattern.hasMatch(normalized);
  }
}
