part of 'dashboard_page.dart';

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
