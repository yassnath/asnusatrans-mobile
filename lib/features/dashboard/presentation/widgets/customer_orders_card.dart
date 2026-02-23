import 'package:flutter/material.dart';

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Latest Orders',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                InkWell(
                  onTap: onViewAll,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Text(
                      'View All',
                      style: TextStyle(
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
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No orders yet.',
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
                          StatusBadge(status: _statusLabel(order.status)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _MetaRow(label: 'Route', value: order.routeLabel),
                      _MetaRow(label: 'Schedule', value: order.scheduleLabel),
                      _MetaRow(
                        label: 'Total',
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

  String _statusLabel(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('pending')) return 'Pending';
    if (s.contains('accepted')) return 'Accepted';
    if (s.contains('rejected')) return 'Rejected';
    if (s.contains('paid')) return 'Paid';
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
