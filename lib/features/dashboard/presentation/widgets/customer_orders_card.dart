import 'package:flutter/material.dart';

import '../../../../core/i18n/language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../models/dashboard_models.dart';
import 'status_badge.dart';

class CustomerOrdersCard extends StatelessWidget {
  const CustomerOrdersCard({
    super.key,
    required this.orders,
    this.onViewAll,
  });

  final List<CustomerOrderSummary> orders;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textMutedFor(context);
    final border = AppColors.cardBorder(context);
    final inner = AppColors.innerSurface(context);
    final isEn = LanguageController.language.value == AppLanguage.en;
    final routeLabel = isEn ? 'Route' : 'Rute';
    final scheduleLabel = isEn ? 'Schedule' : 'Jadwal';
    final totalLabel = isEn ? 'Total' : 'Total';

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
                    isEn ? 'Latest Orders' : 'Order Terbaru',
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
            if (orders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  isEn ? 'No orders yet.' : 'Belum ada order.',
                  style: TextStyle(color: muted),
                ),
              )
            else
              ...orders.map((order) {
                final isPaid = order.status.toLowerCase().contains('paid');
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  order.service,
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: _statusLabel(order.status, isEn)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _MetaRow(label: routeLabel, value: order.routeLabel),
                      _MetaRow(
                          label: scheduleLabel, value: order.scheduleLabel),
                      _MetaRow(
                        label: totalLabel,
                        value: isPaid ? Formatters.rupiah(order.total) : '-',
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

  String _statusLabel(String raw, bool isEn) {
    final s = raw.toLowerCase();
    if (s.contains('pending')) return isEn ? 'Pending' : 'Menunggu';
    if (s.contains('accepted')) return isEn ? 'Accepted' : 'Diterima';
    if (s.contains('rejected')) return isEn ? 'Rejected' : 'Ditolak';
    if (s.contains('paid')) return isEn ? 'Paid' : 'Lunas';
    return raw;
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textMutedFor(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const Spacer(),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
