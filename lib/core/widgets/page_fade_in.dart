import 'package:flutter/material.dart';

class PageFadeIn extends StatelessWidget {
  const PageFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
    this.beginOffsetY = 10,
  });

  final Widget child;
  final Duration duration;
  final double beginOffsetY;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        final offsetY = (1 - value) * beginOffsetY;
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, offsetY),
            child: child,
          ),
        );
      },
    );
  }
}
