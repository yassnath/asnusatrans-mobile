import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CvantAssetImage extends StatelessWidget {
  const CvantAssetImage({
    super.key,
    required this.assetPath,
    this.fallbackAssetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
  });

  final String assetPath;
  final String? fallbackAssetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    return _buildImage(assetPath, allowFallback: true);
  }

  Widget _buildImage(
    String path, {
    required bool allowFallback,
  }) {
    if (!kIsWeb && Platform.isWindows) {
      final bundledFile = _resolveBundledAssetFile(path);
      if (bundledFile != null) {
        return Image.file(
          bundledFile,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(allowFallback),
        );
      }
    }

    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _buildFallback(allowFallback),
    );
  }

  Widget _buildFallback(bool allowFallback) {
    final fallback = fallbackAssetPath;
    if (allowFallback &&
        fallback != null &&
        fallback.isNotEmpty &&
        fallback != assetPath) {
      return _buildImage(fallback, allowFallback: false);
    }
    return placeholder ??
        SizedBox(
          width: width,
          height: height,
        );
  }

  File? _resolveBundledAssetFile(String relativeAssetPath) {
    final normalizedRelative =
        relativeAssetPath.replaceAll('/', Platform.pathSeparator);
    final candidatePaths = <String>[
      _joinPath(
          Directory.current.path, 'data', 'flutter_assets', normalizedRelative),
      _joinPath(
        File(Platform.resolvedExecutable).parent.path,
        'data',
        'flutter_assets',
        normalizedRelative,
      ),
      _joinPath(Directory.current.path, normalizedRelative),
    ];

    for (final candidate in candidatePaths) {
      final file = File(candidate);
      if (file.existsSync()) {
        return file;
      }
    }
    return null;
  }

  String _joinPath(String base, String next, [String? third, String? fourth]) {
    final segments = <String>[
      base,
      next,
      if (third != null) third,
      if (fourth != null) fourth,
    ].where((segment) => segment.isNotEmpty).toList(growable: false);
    return segments.join(Platform.pathSeparator);
  }
}

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
    return CvantAssetImage(
      assetPath: 'assets/images/logo.webp',
      fallbackAssetPath: 'assets/images/iconapk.png',
      width: width,
      height: height,
      fit: fit,
    );
  }
}
