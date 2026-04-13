part of 'dashboard_page.dart';

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
                  onPressed: () => widget.onQuickMenuSelect(7),
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
    required this.session,
    required this.onCreateInvoice,
    this.onDataChanged,
  });

  final DashboardRepository repository;
  final AuthSession session;
  final ValueChanged<_InvoicePrefillData> onCreateInvoice;
  final VoidCallback? onDataChanged;

  @override
  State<_AdminOrderAcceptanceView> createState() =>
      _AdminOrderAcceptanceViewState();
}

class _AdminOrderAcceptanceViewState extends State<_AdminOrderAcceptanceView> {
  late Future<List<dynamic>> _future;
  String? _updatingItemId;
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
      widget.repository.fetchPengurusApprovalQueue(),
    ]);
  }

  Future<void> _updateStatus(String orderId, String status) async {
    setState(() => _updatingItemId = 'order:$orderId');
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
      widget.onDataChanged?.call();
    } catch (e) {
      if (!mounted) return;
      showCvantPopup(
        context: context,
        type: CvantPopupType.error,
        title: _t('Error', 'Error'),
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _updatingItemId = null);
    }
  }

  Future<void> _processPengurusApproval(
    Map<String, dynamic> item, {
    required bool approve,
  }) async {
    final invoiceId = '${item['id'] ?? ''}'.trim();
    if (invoiceId.isEmpty) return;
    final requestType =
        '${item['__request_type'] ?? 'new_income'}'.trim().toLowerCase();
    setState(() => _updatingItemId = 'pengurus:$invoiceId');
    try {
      if (requestType == 'edit_request') {
        if (approve) {
          await widget.repository.approvePengurusInvoiceEdit(invoiceId);
        } else {
          await widget.repository.rejectPengurusInvoiceEdit(invoiceId);
        }
      } else {
        if (approve) {
          await widget.repository.approvePengurusIncome(invoiceId);
        } else {
          await widget.repository.rejectPengurusIncome(invoiceId);
        }
      }
      if (!mounted) return;
      showCvantPopup(
        context: context,
        type: CvantPopupType.success,
        title: _t('Success', 'Success'),
        message: _t(
          approve
              ? 'Request pengurus berhasil disetujui.'
              : 'Request pengurus berhasil ditolak.',
          approve
              ? 'Pengurus request has been approved successfully.'
              : 'Pengurus request has been rejected successfully.',
        ),
      );
      setState(() {
        _future = _load();
      });
      widget.onDataChanged?.call();
    } catch (e) {
      if (!mounted) return;
      showCvantPopup(
        context: context,
        type: CvantPopupType.error,
        title: _t('Error', 'Error'),
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _updatingItemId = null);
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
        final pengurusQueue =
            (snapshot.data![2] as List).cast<Map<String, dynamic>>();
        final customerMap = <String, Map<String, dynamic>>{
          for (final customer in customers) '${customer['id']}': customer,
        };

        if (orders.isEmpty && pengurusQueue.isEmpty) {
          return _SimplePlaceholderView(
            title: _t('Belum ada data masuk', 'No incoming data yet'),
            message: _t(
              'Belum ada order customer atau income pengurus yang perlu diproses.',
              'There are no customer orders or pengurus incomes to process yet.',
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (pengurusQueue.isNotEmpty) ...[
              Text(
                _t('Approval Income Pengurus', 'Pengurus Income Approval'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...pengurusQueue.map((item) {
                final invoiceId = '${item['id'] ?? ''}'.trim();
                final isUpdating = _updatingItemId == 'pengurus:$invoiceId';
                final requestType =
                    '${item['__request_type'] ?? 'new_income'}'.trim();
                final isEditRequest =
                    requestType.toLowerCase() == 'edit_request';
                final route =
                    '${item['lokasi_muat'] ?? '-'} -> ${item['lokasi_bongkar'] ?? '-'}';
                final detailCount = item['rincian'] is List
                    ? (item['rincian'] as List).whereType<Map>().length
                    : 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PanelCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isEditRequest
                                    ? _t(
                                        'Request Edit Income Pengurus',
                                        'Pengurus Income Edit Request',
                                      )
                                    : _t(
                                        'Income Baru dari Pengurus',
                                        'New Income from Pengurus',
                                      ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _StatusPill(
                              label: isEditRequest
                                  ? _t('Request Edit', 'Edit Request')
                                  : _t('Pending ACC', 'Pending Approval'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_t('Pengurus', 'Pengurus')}: ${item['__creator_name'] ?? '-'}',
                          style:
                              TextStyle(color: AppColors.textMutedFor(context)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_t('Customer', 'Customer')}: ${item['nama_pelanggan'] ?? '-'}',
                          style:
                              TextStyle(color: AppColors.textMutedFor(context)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_t('Rute', 'Route')}: $route',
                          style: TextStyle(
                            color: AppColors.textSecondaryFor(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_t('Tanggal', 'Date')}: ${Formatters.dmy(item['armada_start_date'] ?? item['tanggal'] ?? item['created_at'])}',
                          style:
                              TextStyle(color: AppColors.textMutedFor(context)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_t('Rincian', 'Details')}: ${detailCount <= 0 ? 1 : detailCount} ${_t('keberangkatan', 'departures')}',
                          style:
                              TextStyle(color: AppColors.textMutedFor(context)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          Formatters.rupiah(
                            _toNum(item['total_bayar'] ?? item['total_biaya']),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 130,
                              child: FilledButton(
                                onPressed: isUpdating
                                    ? null
                                    : () => _processPengurusApproval(
                                          item,
                                          approve: true,
                                        ),
                                style: CvantButtonStyles.filled(
                                  context,
                                  color: AppColors.success,
                                ),
                                child: Text(
                                  isEditRequest
                                      ? _t('Terima Edit', 'Accept Edit')
                                      : _t('Terima', 'Accept'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 130,
                              child: FilledButton(
                                onPressed: isUpdating
                                    ? null
                                    : () => _processPengurusApproval(
                                          item,
                                          approve: false,
                                        ),
                                style: CvantButtonStyles.filled(
                                  context,
                                  color: AppColors.danger,
                                ),
                                child: Text(
                                  isEditRequest
                                      ? _t('Tolak Edit', 'Reject Edit')
                                      : _t('Tolak', 'Reject'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isUpdating) ...[
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(minHeight: 2),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (orders.isNotEmpty) ...[
              if (pengurusQueue.isNotEmpty) const SizedBox(height: 4),
              Text(
                _t('Order Customer', 'Customer Orders'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...orders.map((order) {
                final status = '${order['status'] ?? 'Pending'}';
                final statusLower = status.toLowerCase();
                final isUpdating = _updatingItemId == 'order:${order['id']}';
                final customer = customerMap['${order['customer_id']}'];
                final isPaid = statusLower.contains('paid') &&
                    !statusLower.contains('unpaid');
                final canCreateInvoice = statusLower.contains('accepted');
                final customerName =
                    customer?['name'] ?? customer?['username'] ?? '-';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PanelCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${order['order_code'] ?? order['id'] ?? '-'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _StatusPill(label: status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_t('Customer', 'Customer')}: $customerName',
                          style:
                              TextStyle(color: AppColors.textMutedFor(context)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_t('Rute', 'Route')}: ${order['pickup'] ?? '-'} -> ${order['destination'] ?? '-'}',
                          style: TextStyle(
                            color: AppColors.textSecondaryFor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_t('Jadwal', 'Schedule')}: ${Formatters.dmy(order['pickup_date'] ?? order['created_at'])}',
                          style:
                              TextStyle(color: AppColors.textMutedFor(context)),
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
                                    : () => _updateStatus(
                                          '${order['id']}',
                                          'Accepted',
                                        ),
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
                                    : () => _updateStatus(
                                          '${order['id']}',
                                          'Rejected',
                                        ),
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
                  ),
                );
              }),
            ],
            const _DashboardContentFooter(),
          ],
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
