import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricLoginAvailability {
  const BiometricLoginAvailability({
    required this.canUseLogin,
    required this.deviceSupported,
    required this.hasEnrolledBiometrics,
    required this.enabledInSettings,
    required this.hasManualBinding,
    required this.label,
    required this.reason,
  });

  final bool canUseLogin;
  final bool deviceSupported;
  final bool hasEnrolledBiometrics;
  final bool enabledInSettings;
  final bool hasManualBinding;
  final String label;
  final String reason;
}

class BiometricCredentials {
  const BiometricCredentials({
    required this.login,
    required this.password,
  });

  final String login;
  final String password;
}

class BiometricLoginService {
  BiometricLoginService({
    LocalAuthentication? localAuth,
    FlutterSecureStorage? secureStorage,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _enabledKey = 'auth.biometric.enabled';
  static const _manualBoundKey = 'auth.biometric.manual_bound';
  static const _loginKey = 'auth.biometric.login';
  static const _passwordKey = 'auth.biometric.password';

  final LocalAuthentication _localAuth;
  final FlutterSecureStorage _secureStorage;

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<bool> isBiometricEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<void> saveManualLogin({
    required String login,
    required String password,
  }) async {
    try {
      await _secureStorage.write(key: _loginKey, value: login.trim());
      await _secureStorage.write(key: _passwordKey, value: password.trim());
    } catch (_) {
      final prefs = await _prefs();
      await prefs.setBool(_manualBoundKey, false);
      return;
    }
    final prefs = await _prefs();
    await prefs.setBool(_manualBoundKey, true);
  }

  Future<void> clearManualBinding() async {
    try {
      await _secureStorage.delete(key: _loginKey);
      await _secureStorage.delete(key: _passwordKey);
    } catch (_) {
      // ignore
    }
    final prefs = await _prefs();
    await prefs.setBool(_manualBoundKey, false);
  }

  Future<bool> hasManualBinding() async {
    final prefs = await _prefs();
    final manualBound = prefs.getBool(_manualBoundKey) ?? false;
    if (!manualBound) return false;
    String? login;
    String? password;
    try {
      login = await _secureStorage.read(key: _loginKey);
      password = await _secureStorage.read(key: _passwordKey);
    } catch (_) {
      return false;
    }
    return login != null &&
        login.trim().isNotEmpty &&
        password != null &&
        password.trim().isNotEmpty;
  }

  Future<List<BiometricType>> _availableBiometrics() async {
    if (kIsWeb) return const <BiometricType>[];
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return const <BiometricType>[];
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return const <BiometricType>[];
    } catch (_) {
      return const <BiometricType>[];
    }
  }

  String _labelFromTypes(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) return 'Face ID';
    return 'Fingerprint';
  }

  Future<BiometricLoginAvailability> getSignInAvailability() async {
    final enabled = await isBiometricEnabled();
    final manualBound = await hasManualBinding();
    final types = await _availableBiometrics();
    final hasEnrollment = types.isNotEmpty;
    var supported = false;
    if (!kIsWeb) {
      try {
        supported = await _localAuth.isDeviceSupported();
      } catch (_) {
        supported = false;
      }
    }
    final label = _labelFromTypes(types);
    final canUse = enabled && manualBound && supported && hasEnrollment;

    String reason;
    if (!supported) {
      reason = 'Perangkat tidak mendukung autentikasi biometrik.';
    } else if (!hasEnrollment) {
      reason = 'Biometrik belum terdaftar di perangkat.';
    } else if (!manualBound) {
      reason = 'Silakan login manual dulu minimal sekali.';
    } else if (!enabled) {
      reason = 'Aktifkan login biometrik di menu Settings.';
    } else {
      reason = '$label siap digunakan untuk sign in.';
    }

    return BiometricLoginAvailability(
      canUseLogin: canUse,
      deviceSupported: supported,
      hasEnrolledBiometrics: hasEnrollment,
      enabledInSettings: enabled,
      hasManualBinding: manualBound,
      label: label,
      reason: reason,
    );
  }

  Future<void> enableBiometric() async {
    final state = await getSignInAvailability();
    if (!state.deviceSupported) {
      throw Exception('Perangkat tidak mendukung biometrik.');
    }
    if (!state.hasEnrolledBiometrics) {
      throw Exception('Biometrik belum terdaftar di perangkat.');
    }
    if (!state.hasManualBinding) {
      throw Exception('Login manual wajib dilakukan terlebih dahulu.');
    }
    await setBiometricEnabled(true);
  }

  Future<BiometricCredentials> authenticateAndGetCredentials() async {
    final state = await getSignInAvailability();
    if (!state.canUseLogin) {
      throw Exception(state.reason);
    }

    bool ok;
    try {
      ok = await _localAuth.authenticate(
        localizedReason: 'Verifikasi ${state.label} untuk masuk aplikasi',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Autentikasi biometrik gagal.');
    } catch (_) {
      throw Exception('Autentikasi biometrik gagal.');
    }

    if (!ok) {
      throw Exception('Autentikasi biometrik dibatalkan.');
    }

    String? login;
    String? password;
    try {
      login = await _secureStorage.read(key: _loginKey);
      password = await _secureStorage.read(key: _passwordKey);
    } catch (_) {
      throw Exception('Data login biometrik tidak ditemukan.');
    }
    if (login == null ||
        login.trim().isEmpty ||
        password == null ||
        password.trim().isEmpty) {
      throw Exception('Data login biometrik tidak ditemukan.');
    }

    return BiometricCredentials(login: login, password: password);
  }
}
