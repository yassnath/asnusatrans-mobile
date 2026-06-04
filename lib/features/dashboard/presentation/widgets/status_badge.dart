import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../utils/fleet_status_logic.dart';
import '../../utils/payment_status_logic.dart';

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
    final isUnpaid = isUnpaidPaymentStatus(status);
    final isPartial = isPartialPaymentStatus(status);
    final isWaiting =
        normalized.contains('waiting') || normalized.contains('pending');
    final fleetStatusText = normalizeFleetStatusText(status);
    final isFleetLike = fleetStatusText.contains('ready') ||
        fleetStatusText.contains('full') ||
        fleetStatusText.contains('inactive') ||
        fleetStatusText.contains('non active') ||
        fleetStatusText.contains('active');
    final isFull = isFleetLike && isFullFleetStatus(status);
    final isInactive = isFleetLike && isInactiveFleetStatus(status);
    final isReady = isFleetLike &&
        (fleetStatusText.contains('ready') ||
            (fleetStatusText.contains('active') && !isInactive));
    final isPaid = isPaidPaymentStatus(status);
    final isRecorded = normalized.contains('recorded');

    if (isCancelled) {
      bg = const Color(0x22EF4444);
      fg = AppColors.danger;
    } else if (isInactive) {
      bg = const Color(0x2264748B);
      fg = AppColors.neutralOutline;
    } else if (isUnpaid || isWaiting || isFull) {
      bg = const Color(0x22F59E0B);
      fg = AppColors.warning;
    } else if (isPartial) {
      bg = const Color(0x223B82F6);
      fg = AppColors.blue;
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
