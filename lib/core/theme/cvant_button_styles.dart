import 'package:flutter/material.dart';

import 'app_colors.dart';

class CvantButtonStyles {
  const CvantButtonStyles._();

  static ButtonStyle filled(
    BuildContext context, {
    Color? color,
    bool strongBorder = true,
    Size minimumSize = const Size(0, 46),
  }) {
    final accent = color ?? AppColors.blue;
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(minimumSize),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      elevation: const WidgetStatePropertyAll(0),
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return accent.withValues(alpha: 0.45);
        }
        return accent;
      }),
      side: WidgetStatePropertyAll(
        BorderSide(color: accent, width: strongBorder ? 2 : 1.2),
      ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.white.withValues(alpha: 0.18);
        }
        if (states.contains(WidgetState.hovered)) {
          return Colors.white.withValues(alpha: 0.1);
        }
        if (states.contains(WidgetState.focused)) {
          return Colors.white.withValues(alpha: 0.14);
        }
        return null;
      }),
    );
  }

  static ButtonStyle outlined(
    BuildContext context, {
    Color? color,
    Color? borderColor,
    double borderWidth = 2,
    Size minimumSize = const Size(0, 44),
  }) {
    final foreground = color ?? AppColors.textPrimaryFor(context);
    final border = borderColor ?? AppColors.controlBorder(context);
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(minimumSize),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return foreground.withValues(alpha: 0.45);
        }
        return foreground;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(
            color: border.withValues(alpha: 0.45),
            width: borderWidth,
          );
        }
        return BorderSide(color: border, width: borderWidth);
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return foreground.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.hovered)) {
          return foreground.withValues(alpha: 0.1);
        }
        if (states.contains(WidgetState.focused)) {
          return foreground.withValues(alpha: 0.12);
        }
        return null;
      }),
    );
  }

  static ButtonStyle text(
    BuildContext context, {
    Color? color,
  }) {
    final foreground = color ?? AppColors.blue;
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return foreground.withValues(alpha: 0.45);
        }
        return foreground;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return foreground.withValues(alpha: 0.18);
        }
        if (states.contains(WidgetState.hovered)) {
          return foreground.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.focused)) {
          return foreground.withValues(alpha: 0.14);
        }
        return null;
      }),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
