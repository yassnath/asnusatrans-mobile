import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static TextTheme _withFontFamily(TextTheme theme, String fontFamily) {
    return theme.copyWith(
      displayLarge: theme.displayLarge?.copyWith(fontFamily: fontFamily),
      displayMedium: theme.displayMedium?.copyWith(fontFamily: fontFamily),
      displaySmall: theme.displaySmall?.copyWith(fontFamily: fontFamily),
      headlineLarge: theme.headlineLarge?.copyWith(fontFamily: fontFamily),
      headlineMedium: theme.headlineMedium?.copyWith(fontFamily: fontFamily),
      headlineSmall: theme.headlineSmall?.copyWith(fontFamily: fontFamily),
      titleLarge: theme.titleLarge?.copyWith(fontFamily: fontFamily),
      titleMedium: theme.titleMedium?.copyWith(fontFamily: fontFamily),
      titleSmall: theme.titleSmall?.copyWith(fontFamily: fontFamily),
      bodyLarge: theme.bodyLarge?.copyWith(fontFamily: fontFamily),
      bodyMedium: theme.bodyMedium?.copyWith(fontFamily: fontFamily),
      bodySmall: theme.bodySmall?.copyWith(fontFamily: fontFamily),
      labelLarge: theme.labelLarge?.copyWith(fontFamily: fontFamily),
      labelMedium: theme.labelMedium?.copyWith(fontFamily: fontFamily),
      labelSmall: theme.labelSmall?.copyWith(fontFamily: fontFamily),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue,
        secondary: AppColors.purple,
        surface: AppColors.panel,
        error: AppColors.danger,
      ),
    );
    return _build(
      base: base,
      scaffold: AppColors.bg,
      surface: AppColors.panel,
      border: const Color(0x1FFFFFFF),
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      textMuted: AppColors.textMuted,
      inputFill: AppColors.panelSoft,
      inputBorder: AppColors.controlBorderDark,
      popupBackground: AppColors.panel,
      divider: const Color(0x24FFFFFF),
    );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.blue,
        secondary: AppColors.purple,
        surface: AppColors.panelLight,
        error: AppColors.danger,
      ),
    );
    return _build(
      base: base,
      scaffold: AppColors.bgLight,
      surface: AppColors.panelLight,
      border: const Color.fromRGBO(148, 163, 184, 0.35),
      textPrimary: AppColors.textPrimaryLight,
      textSecondary: AppColors.textSecondaryLight,
      textMuted: AppColors.textMutedLight,
      inputFill: AppColors.panelLight,
      inputBorder: AppColors.borderLight,
      popupBackground: AppColors.panelLight,
      divider: const Color.fromRGBO(148, 163, 184, 0.35),
    );
  }

  static ThemeData _build({
    required ThemeData base,
    required Color scaffold,
    required Color surface,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required Color inputFill,
    required Color inputBorder,
    required Color popupBackground,
    required Color divider,
  }) {
    final filledOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
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
    });
    final outlinedOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return AppColors.blue.withValues(alpha: 0.2);
      }
      if (states.contains(WidgetState.hovered)) {
        return AppColors.blue.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.focused)) {
        return AppColors.blue.withValues(alpha: 0.15);
      }
      return null;
    });
    final textOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return AppColors.blue.withValues(alpha: 0.2);
      }
      if (states.contains(WidgetState.hovered)) {
        return AppColors.blue.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.focused)) {
        return AppColors.blue.withValues(alpha: 0.14);
      }
      return null;
    });
    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      splashColor: AppColors.blue.withValues(alpha: 0.15),
      splashFactory: InkRipple.splashFactory,
      textTheme: _withFontFamily(base.textTheme, 'Inter').apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerColor: divider,
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: popupBackground,
        textStyle: TextStyle(color: textPrimary),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(46)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.blue.withValues(alpha: 0.45);
            }
            return AppColors.blue;
          }),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.blue, width: 1.6),
          ),
          overlayColor: filledOverlay,
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(46)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.blue.withValues(alpha: 0.45);
            }
            return AppColors.blue;
          }),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.blue, width: 1.6),
          ),
          overlayColor: filledOverlay,
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return textSecondary.withValues(alpha: 0.45);
            }
            return textSecondary;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(
                  color: border.withValues(alpha: 0.45), width: 2);
            }
            return BorderSide(color: inputBorder, width: 2);
          }),
          overlayColor: outlinedOverlay,
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          foregroundColor: const WidgetStatePropertyAll(AppColors.blue),
          overlayColor: textOverlay,
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          overlayColor: outlinedOverlay,
          side: const WidgetStatePropertyAll(BorderSide.none),
        ),
      ),
      iconTheme: IconThemeData(color: textPrimary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        labelStyle: TextStyle(color: textMuted),
        hintStyle: TextStyle(color: textMuted),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.2),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputFill,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: inputBorder),
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(inputFill),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStatePropertyAll(BorderSide(color: inputBorder)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(inputFill),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStatePropertyAll(BorderSide(color: inputBorder)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: border),
        labelStyle: TextStyle(color: textSecondary),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textMuted,
        textColor: textPrimary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: popupBackground,
        surfaceTintColor: Colors.transparent,
        barrierColor: AppColors.popupOverlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: popupBackground,
        contentTextStyle: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
    );
  }
}
