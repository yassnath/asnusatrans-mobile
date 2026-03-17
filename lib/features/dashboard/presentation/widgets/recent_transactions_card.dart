import 'package:flutter/material.dart';

import '../../../../core/i18n/language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../models/dashboard_models.dart';
import 'status_badge.dart';

class RecentTransactionsCard extends StatelessWidget {
  const RecentTransactionsCard({
    super.key,
    required this.items,
    this.onViewAll,
  });

  final List<TransactionItem> items;
  final VoidCallback? onViewAll;

  String _typeLabel(String rawType, bool isEn) {
    final lower = rawType.toLowerCase();
    if (lower.contains('expense')) {
      return isEn ? 'Expense' : 'Pengeluaran';
    }
    return isEn ? 'Income' : 'Pemasukkan';
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textMutedFor(context);
    final border = AppColors.cardBorder(context);
    final inner = AppColors.innerSurface(context);
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
                    isEn ? 'Recent Transactions' : 'Transaksi Terbaru',
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
                  isEn
                      ? 'No recent transactions found.'
                      : 'Belum ada transaksi terbaru.',
                  style: TextStyle(color: muted),
                ),
              )
            else
              ...items.map((item) {
                final accent =
                    item.type == 'Expense' ? AppColors.danger : AppColors.blue;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                    color: inner,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_typeLabel(item.type, isEn)} • ${item.dateLabel}',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: item.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isEn
                                  ? 'Customer: ${item.customer}'
                                  : 'Pelanggan: ${item.customer}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Formatters.rupiah(item.total),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
}
