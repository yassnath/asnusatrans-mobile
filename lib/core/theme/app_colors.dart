import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color bg = Color(0xFF0F1623);
  static const Color bgDeep = Color(0xFF0B1220);
  static const Color panel = Color(0xFF1B2431);
  static const Color panelSoft = Color(0xFF273142);
  static const Color borderDark = Color(0xFF273142);
  static const Color controlBorderDark = Color(0xFF6C757D);

  static const Color textPrimary = Color(0xFFE5E7EB);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color bgLight = Color(0xFFF5F6FA);
  static const Color bgDeepLight = Color(0xFFE9EEF6);
  static const Color panelLight = Color(0xFFFFFFFF);
  static const Color panelSoftLight = Color(0xFFF5F6FA);
  static const Color borderLight = Color(0xFFC7C8CA);
  static const Color textPrimaryLight = Color(0xFF0B1220);
  static const Color textSecondaryLight = Color(0xFF334155);
  static const Color textMutedLight = Color(0xFF64748B);

  static const Color blue = Color(0xFF5B8CFF);
  static const Color purple = Color(0xFFA855F7);
  static const Color cyan = Color(0xFF22D3EE);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color neutralOutline = Color(0xFF64748B);
  static const Color popupOverlay = Color.fromRGBO(0, 0, 0, 0.55);

  static const Gradient authBackground = RadialGradient(
    center: Alignment.topLeft,
    radius: 1.4,
    colors: [
      Color(0x2E5B8CFF),
      Color(0x24000000),
    ],
  );

  static const Gradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [blue, purple],
  );

  static const Gradient sidebarActiveGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xF05B8CFF),
      Color(0xECA855F7),
    ],
  );

  static const List<BoxShadow> sidebarActiveShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.25),
      blurRadius: 26,
      offset: Offset(0, 10),
    ),
    BoxShadow(
      color: Color.fromRGBO(91, 140, 255, 0.18),
      blurRadius: 14,
      offset: Offset(0, 0),
    ),
    BoxShadow(
      color: Color.fromRGBO(168, 85, 247, 0.14),
      blurRadius: 16,
      offset: Offset(0, 0),
    ),
  ];

  static const Gradient cardGradientCyan = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2A3B82F6), Color(0x2222D3EE)],
  );

  static const Gradient cardGradientGreen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2A22C55E), Color(0x2234D399)],
  );

  static const Gradient cardGradientRed = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2AEF4444), Color(0x22FB7185)],
  );

  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color pageBackground(BuildContext context) =>
      isLight(context) ? bgLight : bg;

  static Color pageBackgroundDeep(BuildContext context) =>
      isLight(context) ? bgDeepLight : bgDeep;

  static Color surface(BuildContext context) =>
      isLight(context) ? panelLight : panel;

  static Color surfaceSoft(BuildContext context) =>
      isLight(context) ? panelSoftLight : panelSoft;

  static Color cardBorder(BuildContext context) =>
      isLight(context) ? const Color.fromRGBO(148, 163, 184, 0.35) : borderDark;

  static Color divider(BuildContext context) => isLight(context)
      ? const Color.fromRGBO(148, 163, 184, 0.2)
      : const Color.fromRGBO(148, 163, 184, 0.2);

  static Color dividerSoft(BuildContext context) => isLight(context)
      ? const Color.fromRGBO(148, 163, 184, 0.12)
      : const Color.fromRGBO(148, 163, 184, 0.12);

  static Color innerSurface(BuildContext context) =>
      isLight(context) ? const Color(0xFFF8FAFC) : const Color(0x0FFFFFFF);

  static Color controlBackground(BuildContext context) =>
      isLight(context) ? panelLight : panelSoft;

  static Color controlBorder(BuildContext context) =>
      isLight(context) ? borderLight : controlBorderDark;

  static Color textPrimaryFor(BuildContext context) =>
      isLight(context) ? textPrimaryLight : textPrimary;

  static Color textSecondaryFor(BuildContext context) =>
      isLight(context) ? textSecondaryLight : textSecondary;

  static Color textMutedFor(BuildContext context) =>
      isLight(context) ? textMutedLight : textMuted;

  static Color sidebarSelection(BuildContext context) => isLight(context)
      ? const Color.fromRGBO(91, 140, 255, 0.18)
      : const Color(0x335B8CFF);

  static Color invoiceEntityAccent(String entity) {
    switch (entity.trim().toLowerCase()) {
      case 'cv_ant':
        return success;
      case 'pt_ant':
        return cyan;
      case 'personal':
      default:
        return blue;
    }
  }
}

