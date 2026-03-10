import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/i18n/language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';

class IncomeExpenseChartCard extends StatelessWidget {
  const IncomeExpenseChartCard({
    super.key,
    required this.income,
    required this.expense,
  });

  final List<double> income;
  final List<double> expense;

  @override
  Widget build(BuildContext context) {
    final maxY = _maxY(income, expense);
    final muted = AppColors.textMutedFor(context);
    final border = AppColors.cardBorder(context);
    final isEn = LanguageController.language.value == AppLanguage.en;
    final chartTitle = isEn ? 'Income Vs Expense' : 'Pemasukan vs Pengeluaran';
    final incomeLabel = isEn ? 'Income' : 'Pemasukan';
    final expenseLabel = isEn ? 'Expense' : 'Pengeluaran';
    final months = isEn
        ? const [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec'
          ]
        : const [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'Mei',
            'Jun',
            'Jul',
            'Agu',
            'Sep',
            'Okt',
            'Nov',
            'Des'
          ];
    final grid = AppColors.isLight(context)
        ? const Color.fromRGBO(148, 163, 184, 0.2)
        : const Color(0x1FFFFFFF);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chartTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _Legend(color: AppColors.blue, label: incomeLabel),
                const SizedBox(width: 18),
                _Legend(color: AppColors.warning, label: expenseLabel),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 11,
                  minY: 0,
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.surface(context),
                      tooltipRoundedRadius: 10,
                      tooltipBorder: BorderSide(color: border),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          final label =
                              spot.barIndex == 0 ? incomeLabel : expenseLabel;
                          return LineTooltipItem(
                            '$label\n${Formatters.rupiah(spot.y)}',
                            TextStyle(
                              color: AppColors.textPrimaryFor(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: border),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: grid,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx > 11) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              months[idx],
                              style: TextStyle(
                                color: muted,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: maxY / 4,
                        getTitlesWidget: (value, meta) {
                          final isMillion = value >= 1000000;
                          final label = isMillion
                              ? 'Rp ${(value / 1000000).toStringAsFixed(0)}jt'
                              : 'Rp ${value.toStringAsFixed(0)}';
                          return Text(
                            label,
                            style: TextStyle(
                              color: muted,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _spotsFrom(income),
                      isCurved: true,
                      preventCurveOverShooting: true,
                      barWidth: 3,
                      color: AppColors.blue,
                      belowBarData: BarAreaData(
                        show: true,
                        cutOffY: 0,
                        applyCutOffY: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.blue.withValues(alpha: 0.35),
                            AppColors.blue.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: _spotsFrom(expense),
                      isCurved: true,
                      preventCurveOverShooting: true,
                      barWidth: 3,
                      color: AppColors.warning,
                      belowBarData: BarAreaData(
                        show: true,
                        cutOffY: 0,
                        applyCutOffY: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.warning.withValues(alpha: 0.30),
                            AppColors.warning.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _spotsFrom(List<double> values) {
    return List.generate(12, (index) {
      final v = index < values.length ? values[index] : 0.0;
      return FlSpot(index.toDouble(), v);
    });
  }

  double _maxY(List<double> a, List<double> b) {
    var maxValue = 0.0;
    for (final v in [...a, ...b]) {
      if (v > maxValue) maxValue = v;
    }
    if (maxValue <= 0) return 1000000;
    return (maxValue * 1.2).clamp(500000.0, 9999999999.0).toDouble();
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textMutedFor(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: muted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
