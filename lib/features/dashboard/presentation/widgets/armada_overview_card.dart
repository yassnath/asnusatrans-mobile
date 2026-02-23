import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/dashboard_models.dart';

class ArmadaOverviewCard extends StatelessWidget {
  const ArmadaOverviewCard({
    super.key,
    required this.items,
    this.onViewAll,
  });

  final List<ArmadaUsage> items;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(6).toList();
    final totalArmada = items.length;
    final totalUsage = visible.fold<int>(0, (sum, item) => sum + item.count);
    final colors = _palette(visible.length);
    final muted = AppColors.textMutedFor(context);

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
                    'Armada Overview',
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
            if (visible.isEmpty)
              SizedBox(
                height: 210,
                child: Center(
                  child: Text(
                    'Fleet data is empty.',
                    style: TextStyle(color: muted),
                  ),
                ),
              )
            else
              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 52,
                        borderData: FlBorderData(show: false),
                        sections: List.generate(visible.length, (index) {
                          final item = visible[index];
                          final value = item.count.toDouble();
                          return PieChartSectionData(
                            value: value <= 0 ? 0.1 : value,
                            title: '',
                            radius: 42,
                            color: colors[index],
                          );
                        }),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Fleet Usage',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${totalUsage}x',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Total Armada: $totalArmada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _palette(int n) {
    if (n <= 0) return const [];
    const base = [
      AppColors.blue,
      AppColors.success,
      AppColors.warning,
      AppColors.danger,
      AppColors.cyan,
      AppColors.purple,
    ];
    if (n <= base.length) return base.take(n).toList();

    final list = <Color>[...base];
    for (var i = base.length; i < n; i++) {
      final h = (360 * i / max(n, 8)).roundToDouble();
      list.add(HSLColor.fromAHSL(1, h, 0.78, 0.52).toColor());
    }
    return list;
  }
}
