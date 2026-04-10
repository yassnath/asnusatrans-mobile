part of 'dashboard_page.dart';

class _AdminCreateExpenseView extends StatefulWidget {
  const _AdminCreateExpenseView({
    required this.repository,
    required this.session,
    required this.onCreated,
  });

  final DashboardRepository repository;
  final AuthSession session;
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
  String? _nextExpenseNo;
  bool get _isEn => LanguageController.language.value == AppLanguage.en;
  String _t(String id, String en) => _isEn ? en : id;

  @override
  void initState() {
    super.initState();
    _details.add(_newDetail());
    _recordedBy = widget.session.isOwner
        ? 'Owner'
        : (widget.session.isPengurus ? 'Pengurus' : 'Admin');
    _refreshNextExpenseNo();
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
      await _refreshNextExpenseNo();
    }
  }

  Future<void> _refreshNextExpenseNo() async {
    try {
      final next = await widget.repository.generateExpenseNumberForDate(_date);
      if (!mounted) return;
      setState(() => _nextExpenseNo = next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _nextExpenseNo = _previewExpenseNo());
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
    return 'EXP-$mm-$yy-0001';
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
      _recordedBy = widget.session.isOwner
          ? 'Owner'
          : (widget.session.isPengurus ? 'Pengurus' : 'Admin');
      await _refreshNextExpenseNo();
      if (!mounted) return;
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
                child: Text(_nextExpenseNo ?? _previewExpenseNo()),
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
                items: (widget.session.isPengurus
                        ? const ['Pengurus']
                        : const ['Admin', 'Owner'])
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
