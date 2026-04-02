import 'package:flutter/material.dart';

import '../../../../core/i18n/language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../models/dashboard_models.dart';
import 'status_badge.dart';

class LatestCustomersCard extends StatefulWidget {
  const LatestCustomersCard({
    super.key,
    required this.latestCustomers,
    required this.biggestTransactions,
    this.onViewAll,
  });

  final List<TransactionItem> latestCustomers;
  final List<TransactionItem> biggestTransactions;
  final VoidCallback? onViewAll;

  @override
  State<LatestCustomersCard> createState() => _LatestCustomersCardState();
}

class _LatestCustomersCardState extends State<LatestCustomersCard> {
  bool _showLatest = true;

  String _typeLabel(String rawType, bool isEn) {
    final lower = rawType.toLowerCase();
    if (lower.contains('expense')) {
      return 'Expense';
    }
    return 'Income';
  }

  @override
  Widget build(BuildContext context) {
    final source =
        _showLatest ? widget.latestCustomers : widget.biggestTransactions;
    final muted = AppColors.textMutedFor(context);
    final border = AppColors.cardBorder(context);
    final inner = AppColors.innerSurface(context);
    final isEn = LanguageController.language.value == AppLanguage.en;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _TabButton(
                          label: isEn ? 'Latest' : 'Terbaru',
                          active: _showLatest,
                          count: widget.latestCustomers.length,
                          onTap: () => setState(() => _showLatest = true),
                        ),
                        const SizedBox(width: 8),
                        _TabButton(
                          label: isEn ? 'Biggest' : 'Terbesar',
                          active: !_showLatest,
                          count: widget.biggestTransactions.length,
                          onTap: () => setState(() => _showLatest = false),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: widget.onViewAll,
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
            if (source.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  isEn ? 'No data available yet.' : 'Data belum tersedia.',
                  style: TextStyle(color: muted),
                ),
              )
            else
              Column(
                children: source.map((item) {
                  final accent = item.type == 'Expense'
                      ? AppColors.danger
                      : AppColors.blue;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: inner,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                  const SizedBox(height: 2),
                                  Text(
                                    item.customer,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: muted,
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
                            const Spacer(),
                            Text(
                              Formatters.rupiah(item.total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.count,
    required this.onTap,
  });

  final String label;
  final bool active;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = AppColors.isLight(context);
    final labelColor = active
        ? AppColors.textPrimaryFor(context)
        : AppColors.textSecondaryFor(context);
    final bg = active
        ? AppColors.sidebarSelection(context)
        : (isLight ? const Color(0xFFF5F6FA) : const Color(0x12222D3E));
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: active ? AppColors.blue : const Color(0xFF6B7280),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
