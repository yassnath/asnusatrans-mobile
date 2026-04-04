part of 'dashboard_page.dart';

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
