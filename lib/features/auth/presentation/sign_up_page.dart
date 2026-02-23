import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/cvant_button_styles.dart';
import '../../../core/widgets/cvant_dropdown_field.dart';
import '../../../core/widgets/cvant_popup.dart';
import '../data/auth_repository.dart';
import '../models/sign_up_payload.dart';
import 'auth_shell.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({
    super.key,
    required this.repository,
    required this.onBackToSignIn,
  });

  final AuthRepository repository;
  final VoidCallback onBackToSignIn;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _birthDate = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _company = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  String _gender = '';
  bool _showPassword = false;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _birthDate.dispose();
    _address.dispose();
    _city.dispose();
    _company.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 10, 12, 31),
      initialDate: DateTime(now.year - 20, now.month, now.day),
      helpText: 'Pilih tanggal lahir',
    );
    if (picked == null) return;
    _birthDate.text = DateFormat('dd-MM-yyyy').format(picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final name = _name.text.trim();
    final username = _username.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    final gender = _gender.trim();
    final birthDateRaw = _birthDate.text.trim();
    final address = _address.text.trim();
    final city = _city.text.trim();
    final company = _company.text.trim();
    final password = _password.text.trim();
    final confirmPassword = _confirmPassword.text.trim();

    final hasMissingRequired = name.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        gender.isEmpty ||
        birthDateRaw.isEmpty ||
        address.isEmpty ||
        city.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty;

    if (hasMissingRequired) {
      await showCvantPopup(
        context: context,
        type: CvantPopupType.warning,
        title: 'Validasi Form',
        message: 'Lengkapi semua biodata wajib.',
      );
      return;
    }

    try {
      final parsedBirthDate = DateFormat('dd-MM-yyyy').parseStrict(
        birthDateRaw,
      );
      final payload = SignUpPayload(
        name: name,
        username: username,
        email: email,
        phone: phone,
        gender: gender,
        birthDate: DateFormat('yyyy-MM-dd').format(parsedBirthDate),
        address: address,
        city: city,
        company: company,
        password: password,
        confirmPassword: confirmPassword,
      );

      if (payload.password.trim().length < 6) {
        await showCvantPopup(
          context: context,
          type: CvantPopupType.warning,
          title: 'Validasi Form',
          message: 'Password minimal 6 karakter.',
        );
        return;
      }

      if (payload.password.trim() != payload.confirmPassword.trim()) {
        await showCvantPopup(
          context: context,
          type: CvantPopupType.warning,
          title: 'Validasi Form',
          message: 'Konfirmasi password tidak sama.',
        );
        return;
      }

      setState(() => _loading = true);
      try {
        await widget.repository.registerCustomer(payload);
        if (!mounted) return;
        await showCvantPopup(
          context: context,
          type: CvantPopupType.success,
          title: 'Registrasi Berhasil',
          message: 'Akun berhasil dibuat. Silakan login.',
        );
        if (!mounted) return;
        widget.onBackToSignIn();
      } catch (e) {
        if (!mounted) return;
        await showCvantPopup(
          context: context,
          type: CvantPopupType.error,
          title: 'Registrasi Gagal',
          message: e.toString().replaceFirst('Exception: ', ''),
        );
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      await showCvantPopup(
        context: context,
        type: CvantPopupType.warning,
        title: 'Validasi Form',
        message: 'Format tanggal lahir wajib dd-mm-yyyy.',
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Sign Up Customer',
      subtitle: 'Lengkapi data customer agar dapat menggunakan layanan.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Input(
              controller: _name,
              hint: 'Nama lengkap',
              icon: Icons.person_outline),
          const SizedBox(height: 10),
          _Input(
              controller: _username,
              hint: 'Username',
              icon: Icons.alternate_email),
          const SizedBox(height: 10),
          _Input(
            controller: _email,
            hint: 'nama@email.com',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _Input(
            controller: _phone,
            hint: '08xxxxxxxxxx',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          _SelectInput(
            value: _gender,
            hint: 'Pilih jenis kelamin',
            icon: Icons.person_outline,
            items: const ['Laki-laki', 'Perempuan', 'Lainnya'],
            onChanged: (value) => setState(() => _gender = value ?? ''),
          ),
          const SizedBox(height: 10),
          _Input(
            controller: _birthDate,
            hint: 'Tanggal lahir (dd-mm-yyyy)',
            icon: Icons.calendar_today_outlined,
            readOnly: true,
            onTap: _pickBirthDate,
          ),
          const SizedBox(height: 10),
          _Input(
            controller: _address,
            hint: 'Alamat lengkap',
            icon: Icons.place_outlined,
          ),
          const SizedBox(height: 10),
          _Input(
              controller: _city,
              hint: 'Nama kota',
              icon: Icons.location_city_outlined),
          const SizedBox(height: 10),
          _Input(
            controller: _company,
            hint: 'Nama perusahaan',
            icon: Icons.apartment_outlined,
          ),
          const SizedBox(height: 10),
          _Input(
            controller: _password,
            hint: 'Password',
            icon: Icons.lock_outline,
            obscureText: !_showPassword,
            trailing: IconButton(
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _Input(
            controller: _confirmPassword,
            hint: 'Konfirmasi password',
            icon: Icons.lock_outline,
            obscureText: !_showPassword,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: CvantButtonStyles.filled(
                  context,
                  color: Colors.transparent,
                  strongBorder: false,
                ),
                child: Text(_loading ? 'Mendaftar...' : 'Daftar'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                const Text(
                  'Sudah punya akun? ',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                GestureDetector(
                  onTap: widget.onBackToSignIn,
                  child: const Text(
                    'Masuk di sini',
                    style: TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.trailing,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? trailing;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(
            color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
          suffixIcon: trailing,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.blue, width: 1.2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }
}

class _SelectInput extends StatelessWidget {
  const _SelectInput({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final String hint;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: CvantDropdownField<String>(
        initialValue: value.isEmpty ? null : value,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF64748B),
          size: 20,
        ),
        borderRadius: BorderRadius.circular(12),
        menuMaxHeight: 280,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.blue, width: 1.2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        dropdownColor: Colors.white,
        style: const TextStyle(
            color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
        hint: Text(
          hint,
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
