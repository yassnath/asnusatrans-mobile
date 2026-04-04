part of 'dashboard_page.dart';

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
