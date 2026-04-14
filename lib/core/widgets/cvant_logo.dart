import 'package:flutter/material.dart';

class CvantLogo extends StatelessWidget {
  const CvantLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.webp',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/iconapk.png',
          width: width,
          height: height,
          fit: fit,
        );
      },
    );
  }
}
