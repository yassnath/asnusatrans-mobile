import 'package:flutter/material.dart';

import '../../../../core/i18n/language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/dashboard_models.dart';

class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({
    super.key,
    required this.items,
    this.onViewAll,
  });

  final List<ActivityItem> items;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textMutedFor(context);
    final divider = AppColors.divider(context);
    final isEn = LanguageController.language.value == AppLanguage.en;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEn ? 'Recent Activity' : 'Aktivitas Terbaru',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                InkWell(
                  onTap: onViewAll,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Text(
                      isEn ? 'View All' : 'Lihat Semua',
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  isEn ? 'No activity yet.' : 'Tidak ada aktivitas.',
                  style: TextStyle(color: muted),
                ),
              )
            else
              ...items.map((item) {
                final accent = _accent(item.kind);
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: divider)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            item.dateLabel,
                            style: TextStyle(
                              color: muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Color _accent(String kind) {
    switch (kind) {
      case 'expense':
        return AppColors.danger;
      case 'armada_start':
        return AppColors.warning;
      case 'armada_done':
        return AppColors.success;
      case 'armada':
        return AppColors.success;
      default:
        return AppColors.blue;
    }
  }
}
