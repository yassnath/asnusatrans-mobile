import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cvant_logo.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxWidth = size.width > 460 ? 430.0 : size.width - 24;
    final isLight = AppColors.isLight(context);
    final bgTop = AppColors.pageBackground(context);
    final bgBottom = AppColors.pageBackgroundDeep(context);
    final panelBorder = AppColors.cardBorder(context);
    final panelGradient = isLight
        ? const [Color(0xFFFFFFFF), Color(0xFFF8FAFC)]
        : const [Color(0xC6273142), Color(0xB81B2431)];
    final panelShadow = isLight
        ? const Color.fromRGBO(15, 23, 42, 0.12)
        : const Color(0x73000000);
    final badgeBackground = Theme.of(context).inputDecorationTheme.fillColor ??
        (isLight ? const Color(0xFFF8FAFC) : AppColors.surfaceSoft(context));
    const badgeSize = 88.0;
    const badgeOverlap = badgeSize / 2;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgBottom],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _BackgroundGlow(isLight: isLight),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(
                            left: 12,
                            top: badgeOverlap,
                            right: 12,
                          ),
                          padding: const EdgeInsets.fromLTRB(
                            24,
                            badgeOverlap + 24,
                            24,
                            24,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: panelBorder),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: panelGradient,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: panelShadow,
                                blurRadius: 48,
                                offset: const Offset(0, 24),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  subtitle!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textMutedFor(context),
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              child,
                            ],
                          ),
                        ),
                        Positioned(
                          top: 0,
                          child: _AuthHeroBadge(
                            size: badgeSize,
                            backgroundColor: badgeBackground,
                            borderColor: panelBorder,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text(
                    'Solvix Studio \u00a9 2026',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMutedFor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthHeroBadge extends StatelessWidget {
  const _AuthHeroBadge({
    required this.size,
    required this.backgroundColor,
    required this.borderColor,
  });

  final double size;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'CV AS Nusa Trans notification mascot',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
        child: const ClipOval(
          child: CvantAssetImage(
            assetPath: 'assets/images/notif.png',
            width: 68,
            height: 68,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow({required this.isLight});

  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GlowPainter(isLight: isLight),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({required this.isLight});

  final bool isLight;

  @override
  void paint(Canvas canvas, Size size) {
    final first = isLight ? const Color(0x335B8CFF) : const Color(0x665B8CFF);
    final second = isLight ? const Color(0x22A855F7) : const Color(0x55A855F7);
    final third = isLight ? const Color(0x1522D3EE) : const Color(0x3322D3EE);

    final paintOne = Paint()
      ..shader = RadialGradient(
        colors: [first, const Color(0x005B8CFF)],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.2, size.height * 0.2),
        radius: size.width * 0.75,
      ));
    canvas.drawRect(Offset.zero & size, paintOne);

    final paintTwo = Paint()
      ..shader = RadialGradient(
        colors: [second, const Color(0x00A855F7)],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.86, size.height * 0.34),
        radius: size.width * 0.62,
      ));
    canvas.drawRect(Offset.zero & size, paintTwo);

    final paintThree = Paint()
      ..shader = RadialGradient(
        colors: [third, const Color(0x0022D3EE)],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.56, size.height * 0.92),
        radius: size.width * 0.7,
      ));
    canvas.drawRect(Offset.zero & size, paintThree);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) =>
      oldDelegate.isLight != isLight;
}
