import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_session.dart';
import '../models/sign_up_payload.dart';

class AuthRepository {
  AuthRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<AuthSession?> restoreSession() async {
    final session = _supabase.auth.currentSession;
    final user = _supabase.auth.currentUser;
    if (session == null || user == null) return null;

    try {
      Map<String, dynamic>? profile;
      try {
        profile = await _readProfile(user.id);
      } on PostgrestException {
        // Jangan gagalkan login jika tabel/policy profile belum siap.
        profile = null;
      }
      final role =
          (profile?['role'] ?? user.userMetadata?['role'] ?? 'customer')
              .toString()
              .trim()
              .toLowerCase();
      final displayName = (profile?['name'] ??
              user.userMetadata?['name'] ??
              user.email ??
              'User')
          .toString();

      return AuthSession(
        token: session.accessToken,
        role: role,
        displayName: displayName,
        isCustomer: role == 'customer',
        userId: user.id,
      );
    } catch (_) {
      return null;
    }
  }

  Future<AuthSession> signIn({
    required String login,
    required String password,
  }) async {
    final normalizedLogin = login.trim();
    final rawPassword = password;

    try {
      final candidates = await _buildEmailCandidates(normalizedLogin);
      AuthException? lastAuthException;
      AuthResponse? success;

      for (final email in candidates) {
        try {
          success = await _supabase.auth.signInWithPassword(
            email: email,
            password: rawPassword,
          );
          break;
        } on AuthException catch (e) {
          lastAuthException = e;
          final isInvalid = _isInvalidCredentialsMessage(e.message);
          if (!isInvalid) {
            rethrow;
          }
        }
      }

      if (success == null) {
        if (lastAuthException != null) {
          throw lastAuthException;
        }
        throw Exception('Login gagal. Session tidak ditemukan.');
      }

      final session = success.session;
      final user = success.user;
      if (session == null || user == null) {
        throw Exception('Login gagal. Session tidak ditemukan.');
      }

      final profile = await _readProfile(user.id);
      final role =
          (profile?['role'] ?? user.userMetadata?['role'] ?? 'customer')
              .toString()
              .trim()
              .toLowerCase();
      final displayName = (profile?['name'] ??
              user.userMetadata?['name'] ??
              user.email ??
              'User')
          .toString();

      return AuthSession(
        token: session.accessToken,
        role: role,
        displayName: displayName,
        isCustomer: role == 'customer',
        userId: user.id,
      );
    } on AuthException catch (e) {
      throw Exception(
        _mapAuthError(
          e.message,
          loginHint: normalizedLogin.toLowerCase(),
        ),
      );
    } catch (e) {
      throw Exception(
        _sanitizeLoginError(
          e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> registerCustomer(SignUpPayload payload) async {
    try {
      final email = payload.email.trim().toLowerCase();
      final username = payload.username.trim().toLowerCase();

      final existsByUsername = await _lookupEmailByUsername(username);
      if (existsByUsername != null && existsByUsername.isNotEmpty) {
        throw Exception('Username sudah terdaftar. Gunakan username lain.');
      }

      final response = await _supabase.auth.signUp(
        email: email,
        password: payload.password,
        data: payload.toSupabaseMetadata(),
      );

      final user = response.user;
      final currentSession = _supabase.auth.currentSession;
      if (user != null && currentSession != null) {
        await _upsertProfile(payload.toProfileRow(user.id));
      }

      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      throw Exception(_mapAuthError(e.message));
    } on PostgrestException {
      throw Exception(
        'Struktur tabel Supabase belum siap. Jalankan SQL schema terlebih dahulu.',
      );
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut(scope: SignOutScope.local);
  }

  Future<List<String>> _buildEmailCandidates(String login) async {
    final values = <String>[];
    void add(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty) return;
      if (!values.contains(normalized)) {
        values.add(normalized);
      }
    }

    final normalized = login.trim().toLowerCase();
    _addLegacyLoginFallback(normalized, add);
    if (normalized.contains('@')) {
      add(login.trim());
      add(normalized);
      final localPart = normalized.split('@').first.trim();
      if (localPart.isNotEmpty) {
        try {
          final resolved = await _lookupEmailByUsername(localPart);
          if (resolved != null && resolved.isNotEmpty) {
            add(resolved);
            add(resolved.toLowerCase());
          }
        } catch (_) {
          // Optional fallback only. Tetap lanjut dengan email input user.
        }
      }
      return values;
    }

    String? email;
    try {
      email = await _lookupEmailByUsername(normalized);
    } on PostgrestException {
      throw Exception(
        'Login dengan username belum aktif. Jalankan SQL schema Supabase lalu coba lagi.',
      );
    }
    if (email == null || email.isEmpty) {
      if (values.isNotEmpty) {
        return values;
      }
      throw Exception(
        'Username tidak ditemukan. Silakan login dengan email yang terdaftar.',
      );
    }
    add(email);
    add(email.toLowerCase());
    return values;
  }

  void _addLegacyLoginFallback(String normalized, void Function(String) add) {
    switch (normalized) {
      case 'admin':
        add('admin@cvant.local');
        break;
      case 'owner':
        add('owner@cvant.local');
        break;
      default:
        break;
    }
  }

  Future<String?> _lookupEmailByUsername(String username) async {
    final res = await _supabase.rpc(
      'get_email_for_login',
      params: {'login_input': username},
    );

    if (res == null) return null;
    final email = res.toString().trim().toLowerCase();
    if (email.isEmpty || email == 'null') return null;
    return email;
  }

  Future<Map<String, dynamic>?> _readProfile(String userId) async {
    final row = await _supabase
        .from('profiles')
        .select('name, role')
        .eq('id', userId)
        .maybeSingle();
    return row;
  }

  Future<void> _upsertProfile(Map<String, dynamic> payload) async {
    final row = Map<String, dynamic>.from(payload);
    row['username'] = (row['username'] ?? '').toString().trim().toLowerCase();

    final birthDate = row['birth_date']?.toString().trim();
    if (birthDate != null && birthDate.isNotEmpty) {
      row['birth_date'] = birthDate;
    } else {
      row.remove('birth_date');
    }

    await _supabase.from('profiles').upsert(row, onConflict: 'id');
  }

  String _mapAuthError(String message, {String? loginHint}) {
    final text = message.toLowerCase();
    if (text.contains('invalid api key') || text.contains('apikey')) {
      return 'SUPABASE_ANON_KEY tidak valid atau tidak sesuai project URL. '
          'Cek ulang --dart-define SUPABASE_URL dan SUPABASE_ANON_KEY.';
    }
    if (_isInvalidCredentialsMessage(text)) {
      if (_isLegacyDefaultLogin(loginHint)) {
        return 'Login gagal. Akun default belum sinkron di Supabase Auth. '
            'Jalankan scripts/bootstrap_supabase_users.ps1 lalu coba lagi.';
      }
      return 'Login gagal. Periksa email/username dan password.';
    }
    if (text.contains('email not confirmed')) {
      return 'Email belum diverifikasi. Cek inbox email Anda.';
    }
    if (text.contains('already registered')) {
      return 'Email sudah terdaftar. Silakan login.';
    }
    return message;
  }

  String _sanitizeLoginError(String raw) {
    final text = raw.toLowerCase();
    final isNetworkIssue = text.contains('failed host lookup') ||
        text.contains('socketexception') ||
        text.contains('network is unreachable') ||
        text.contains('connection refused') ||
        text.contains('connection timed out') ||
        text.contains('clientexception with socketexception');
    if (isNetworkIssue) {
      return 'Tidak bisa terhubung ke server Supabase. '
          'Cek koneksi internet/DNS di perangkat, matikan VPN/Private DNS, '
          'lalu coba lagi.';
    }

    final isServerIssue = text.contains('502') ||
        text.contains('bad gateway') ||
        text.contains('502 bad gateway') ||
        text.contains('gateway timeout');
    if (isServerIssue) {
      return 'Server sedang tidak tersedia (502 Bad Gateway). Coba lagi beberapa saat atau hubungi admin.';
    }

    if ((text.contains('username') || text.contains('email')) ||
        text.contains('password')) {
      return 'Login gagal. Periksa email/username dan password.';
    }
    return raw;
  }

  bool _isInvalidCredentialsMessage(String message) {
    final text = message.toLowerCase();
    return text.contains('invalid login credentials') ||
        text.contains('invalid email or password') ||
        text.contains('email or password is invalid') ||
        text.contains('invalid_credentials');
  }

  bool _isLegacyDefaultLogin(String? loginHint) {
    final value = (loginHint ?? '').trim().toLowerCase();
    return value == 'admin' ||
        value == 'owner' ||
        value == 'admin@cvant.local' ||
        value == 'owner@cvant.local';
  }
}
