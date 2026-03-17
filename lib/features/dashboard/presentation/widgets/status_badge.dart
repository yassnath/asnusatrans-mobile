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
    final isCancelled = normalized.contains('cancel') ||
        normalized.contains('rejected') ||
        normalized.contains('failed');
    final isUnpaid = normalized.contains('unpaid');
    final isWaiting =
        normalized.contains('waiting') || normalized.contains('pending');
    final isFull = normalized.contains('full');
    final isInactive = normalized.contains('inactive') ||
        normalized.contains('non active') ||
        normalized.contains('non-active');
    final isReady = normalized.contains('ready') ||
        (normalized.contains('active') && !isInactive);
    final isPaid = normalized.contains('paid') && !isUnpaid;
    final isRecorded = normalized.contains('recorded');

    if (isCancelled) {
      bg = const Color(0x22EF4444);
      fg = AppColors.danger;
    } else if (isUnpaid || isInactive) {
      bg = const Color(0x2264748B);
      fg = AppColors.neutralOutline;
    } else if (isWaiting || isFull) {
      bg = const Color(0x22F59E0B);
      fg = AppColors.warning;
    } else if (isPaid ||
        isReady ||
        isRecorded ||
        normalized.contains('accepted')) {
      bg = const Color(0x2222C55E);
      fg = AppColors.success;
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
