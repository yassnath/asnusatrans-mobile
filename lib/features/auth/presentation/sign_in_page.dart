import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/cvant_button_styles.dart';
import '../../../core/widgets/cvant_popup.dart';
import '../data/auth_repository.dart';
import '../data/biometric_login_service.dart';
import '../models/auth_session.dart';
import 'auth_shell.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
    required this.repository,
    required this.biometricService,
    required this.onSignedIn,
    required this.onOpenSignUp,
  });

  final AuthRepository repository;
  final BiometricLoginService biometricService;
  final ValueChanged<AuthSession> onSignedIn;
  final VoidCallback onOpenSignUp;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _loading = false;
  bool _biometricLoading = false;
  bool _showBiometricButton = false;
  bool _didAutoPromptBiometric = false;
  String _biometricLabel = 'Fingerprint';

  @override
  void initState() {
    super.initState();
    _refreshBiometricState();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _refreshBiometricState() async {
    final state = await widget.biometricService.getSignInAvailability();
    if (!mounted) return;
    setState(() {
      _showBiometricButton = state.canUseLogin;
      _biometricLabel = state.label;
    });
    if (state.canUseLogin && !_didAutoPromptBiometric) {
      _didAutoPromptBiometric = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 250), () async {
            if (!mounted || _loading || _biometricLoading) return;
            await _submitBiometric(showCancelPopup: false);
          }),
        );
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final login = _loginController.text.trim();
    final password = _passwordController.text;

    if (login.isEmpty && password.isEmpty) {
      await showCvantPopup(
        context: context,
        type: CvantPopupType.warning,
        title: 'Validasi Login',
        message: 'Mohon isi username dan password terlebih dahulu!',
      );
      return;
    }
    if (login.isEmpty) {
      await showCvantPopup(
        context: context,
        type: CvantPopupType.warning,
        title: 'Validasi Login',
        message: 'Mohon isi username terlebih dahulu!',
      );
      return;
    }
    if (password.isEmpty) {
      await showCvantPopup(
        context: context,
        type: CvantPopupType.warning,
        title: 'Validasi Login',
        message: 'Mohon isi password terlebih dahulu!',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final session = await widget.repository.signIn(
        login: login,
        password: password,
      );
      await widget.biometricService.saveManualLogin(
        login: login,
        password: password,
      );
      if (!mounted) return;
      await showCvantPopup(
        context: context,
        type: CvantPopupType.success,
        title: 'Login Success',
        message: session.isCustomer
            ? 'Login berhasil! Mengarahkan ke dashboard customer...'
            : 'Login berhasil! Mengarahkan ke dashboard...',
        okLabel: 'OK',
        showOkButton: true,
        showCloseButton: true,
        barrierDismissible: false,
        autoCloseAfter: const Duration(seconds: 3),
      );
      widget.onSignedIn(session);
    } catch (e) {
      if (!mounted) return;
      final rawMessage = e.toString().replaceFirst('Exception: ', '');
      await showCvantPopup(
        context: context,
        type: CvantPopupType.error,
        title: 'Login Failed',
        message: _mapLoginErrorMessage(rawMessage),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapLoginErrorMessage(String rawMessage) {
    final normalized = rawMessage.trim().toLowerCase();
    const invalidCredentialMessages = <String>[
      'login gagal. periksa email/username dan password.',
      'invalid login credentials',
      'invalid email or password',
      'email or password is invalid',
      'invalid_credentials',
    ];
    final isInvalidCredentials = invalidCredentialMessages.any(
      (message) => normalized.contains(message),
    );
    if (isInvalidCredentials) {
      return 'Username/Password tidak valid, Mohon dicek kembali!';
    }
    return rawMessage;
  }

  Future<void> _submitBiometric({bool showCancelPopup = true}) async {
    setState(() => _biometricLoading = true);
    try {
      final credentials =
          await widget.biometricService.authenticateAndGetCredentials();
      final session = await widget.repository.signIn(
        login: credentials.login,
        password: credentials.password,
      );
      if (!mounted) return;
      await showCvantPopup(
        context: context,
        type: CvantPopupType.success,
        title: 'Login Success',
        message: session.isCustomer
            ? 'Login berhasil! Mengarahkan ke dashboard customer...'
            : 'Login berhasil! Mengarahkan ke dashboard...',
        okLabel: 'OK',
        showOkButton: true,
        showCloseButton: true,
        barrierDismissible: false,
        autoCloseAfter: const Duration(seconds: 3),
      );
      if (!mounted) return;
      widget.onSignedIn(session);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      final isCanceled = message.toLowerCase().contains('dibatalkan');
      if (isCanceled && !showCancelPopup) {
        return;
      }
      await showCvantPopup(
        context: context,
        type: CvantPopupType.warning,
        title: 'Biometric Sign In',
        message: message,
      );
      await _refreshBiometricState();
    } finally {
      if (mounted) setState(() => _biometricLoading = false);
    }
  }

  Future<void> _openWhatsapp() async {
    final uri = Uri.parse('https://wa.me/+6285771753354');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Sign In',
      subtitle: 'Masukkan email atau username dan password Anda.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthField(
            controller: _loginController,
            hintText: 'Email / Username',
            icon: Icons.person_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _passwordController,
            hintText: 'Password',
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
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x5529346A),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: CvantButtonStyles.filled(
                  context,
                  color: Colors.transparent,
                  strongBorder: false,
                ),
                child: Text(_loading ? 'Memproses...' : 'Login'),
              ),
            ),
          ),
          if (_showBiometricButton) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed:
                    (_loading || _biometricLoading) ? null : _submitBiometric,
                style: CvantButtonStyles.outlined(
                  context,
                  color: AppColors.blue,
                  borderColor: AppColors.blue,
                ),
                icon: Icon(
                  _biometricLabel == 'Face ID'
                      ? Icons.face_unlock_outlined
                      : Icons.fingerprint,
                ),
                label: Text(
                  _biometricLoading
                      ? 'Memverifikasi...'
                      : 'Sign in with $_biometricLabel',
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              runSpacing: 2,
              children: [
                const Text(
                  'Forgot Password? ',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                GestureDetector(
                  onTap: _openWhatsapp,
                  child: const Text(
                    'Click here!',
                    style: TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                const Text(
                  'Belum punya akun? ',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                GestureDetector(
                  onTap: widget.onOpenSignUp,
                  child: const Text(
                    'Daftar sekarang',
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

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.trailing,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? trailing;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onSubmitted: onSubmitted,
        style: const TextStyle(
            color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
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
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}
