import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.iconBg,
  });

  final String title;
  final String value;
  final String subtitle;
  final Gradient gradient;
  final IconData icon;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    final isLight = AppColors.isLight(context);
    final textTheme = Theme.of(context).textTheme;
    final titleColor = isLight
        ? AppColors.textPrimaryLight.withValues(alpha: 0.9)
        : const Color(0xFFE2E8F0);
    final subtitleColor = isLight
        ? AppColors.textSecondaryLight.withValues(alpha: 0.92)
        : const Color(0xFFCBD5E1);
    final valueColor = isLight ? AppColors.textPrimaryLight : Colors.white;
    final borderColor = AppColors.cardBorder(context);
    return Container(
      height: double.infinity,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          (textTheme.titleMedium ?? const TextStyle()).copyWith(
                        color: titleColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (textTheme.headlineMedium ?? const TextStyle())
                          .copyWith(
                        color: valueColor,
                        fontSize: 22,
                        height: 1.06,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ],
          ),
          Text(
            subtitle,
            style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
              color: subtitleColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
