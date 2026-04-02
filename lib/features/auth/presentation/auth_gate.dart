import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/page_fade_in.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../data/auth_repository.dart';
import '../data/biometric_login_service.dart';
import '../models/auth_session.dart';
import 'sign_in_page.dart';
import 'sign_up_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const _loadingDuration = Duration(seconds: 5);

  late final AuthRepository _authRepository;
  late final DashboardRepository _dashboardRepository;
  late final BiometricLoginService _biometricService;

  AuthSession? _session;
  bool _loading = true;
  bool _showSignUp = false;
  int _splashCycle = 0;

  @override
  void initState() {
    super.initState();
    _authRepository = AuthRepository(Supabase.instance.client);
    _dashboardRepository = DashboardRepository(Supabase.instance.client);
    _biometricService = BiometricLoginService();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      _session = await _authRepository
          .restoreSession()
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      _session = null;
    }
    await Future<void>.delayed(_loadingDuration);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _showSignUp = false;
    });
  }

  Future<void> _onSignedIn(AuthSession session) async {
    if (!mounted) return;
    setState(() {
      _session = session;
      _showSignUp = false;
    });
  }

  Future<void> _logout() async {
    await _authRepository.signOut();
    await _biometricService.clearManualBinding();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _session = null;
      _showSignUp = false;
      _splashCycle++;
    });
    await Future<void>.delayed(_loadingDuration);
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _SplashScreen(key: ValueKey('splash-$_splashCycle'));
    }

    Widget page;
    String key;

    if (_session == null) {
      if (_showSignUp) {
        page = SignUpPage(
          repository: _authRepository,
          onBackToSignIn: () => setState(() => _showSignUp = false),
        );
        key = 'auth-sign-up';
      } else {
        page = SignInPage(
          repository: _authRepository,
          biometricService: _biometricService,
          onSignedIn: _onSignedIn,
          onOpenSignUp: () => setState(() => _showSignUp = true),
        );
        key = 'auth-sign-in';
      }
    } else {
      page = DashboardPage(
        session: _session!,
        repository: _dashboardRepository,
        biometricService: _biometricService,
        onLogout: _logout,
      );
      key = 'auth-dashboard-${_session!.role}-${_session!.displayName}';
    }

    return PageFadeIn(
      key: ValueKey<String>(key),
      child: page,
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen({super.key});

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();

    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 18,
      ),
    ]).animate(_controller);

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.72, end: 2.00)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 80,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 2.00, end: 16)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 20,
      ),
    ]).animate(_controller);

    _textOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.76, 0.82, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        color: Colors.white,
        child: Center(
          child: SizedBox(
            width: 320,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  child: Image.asset(
                    'assets/images/iconapk.png',
                    width: 112,
                    height: 112,
                    fit: BoxFit.contain,
                  ),
                  builder: (context, child) {
                    return Opacity(
                      opacity: _opacity.value.clamp(0, 1),
                      child: Transform.scale(
                        scale: _scale.value,
                        child: child,
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: const Text(
                      'Dashboard CV ANT by Solvix Studio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
