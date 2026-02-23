import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    Color bg = const Color(0x2238BDF8);
    Color fg = AppColors.cyan;

    if (normalized.contains('ready') ||
        (normalized.contains('active') && !normalized.contains('inactive')) ||
        normalized.contains('paid') ||
        normalized.contains('accepted')) {
      bg = const Color(0x2222C55E);
      fg = AppColors.success;
    } else if (normalized.contains('full') ||
        normalized.contains('pending') ||
        normalized.contains('waiting')) {
      bg = const Color(0x22F59E0B);
      fg = AppColors.warning;
    } else if (normalized.contains('inactive') ||
        normalized.contains('non active') ||
        normalized.contains('non-active')) {
      bg = const Color(0x2264748B);
      fg = AppColors.neutralOutline;
    } else if (normalized.contains('unpaid') ||
        normalized.contains('rejected') ||
        normalized.contains('cancel')) {
      bg = const Color(0x22EF4444);
      fg = AppColors.danger;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
