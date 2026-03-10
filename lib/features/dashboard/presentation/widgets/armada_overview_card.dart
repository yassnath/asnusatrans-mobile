import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/i18n/language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/dashboard_models.dart';

class ArmadaOverviewCard extends StatefulWidget {
  const ArmadaOverviewCard({
    super.key,
    required this.items,
    this.onViewAll,
  });

  final List<ArmadaUsage> items;
  final VoidCallback? onViewAll;

  @override
  State<ArmadaOverviewCard> createState() => _ArmadaOverviewCardState();
}

class _ArmadaOverviewCardState extends State<ArmadaOverviewCard> {
  int? _touchedIndex;
  Offset? _touchPosition;

  @override
  Widget build(BuildContext context) {
    final visible = widget.items.where((item) => item.count > 0).toList();
    final totalArmada = widget.items.length;
    final totalUsage = visible.fold<int>(0, (sum, item) => sum + item.count);
    final colors = _palette(max(visible.length, 1));
    final muted = AppColors.textMutedFor(context);
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
                    isEn ? 'Fleet Overview' : 'Ringkasan Armada',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                InkWell(
                  onTap: widget.onViewAll,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
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
            if (visible.isEmpty)
              SizedBox(
                height: 210,
                child: Center(
                  child: Text(
                    isEn
                        ? 'No fleet usage recorded yet.'
                        : 'Belum ada penggunaan armada.',
                    style: TextStyle(color: muted),
                  ),
                ),
              )
            else
              SizedBox(
                height: 220,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final chartSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 52,
                            borderData: FlBorderData(show: false),
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                final touched = response
                                    ?.touchedSection?.touchedSectionIndex;
                                final local = event.localPosition;
                                if (!event.isInterestedForInteractions ||
                                    touched == null) {
                                  if (_touchedIndex != null ||
                                      _touchPosition != null) {
                                    setState(() {
                                      _touchedIndex = null;
                                      _touchPosition = null;
                                    });
                                  }
                                  return;
                                }
                                if (_touchedIndex != touched ||
                                    _touchPosition != local) {
                                  setState(() {
                                    _touchedIndex = touched;
                                    _touchPosition = local;
                                  });
                                }
                              },
                            ),
                            sections: List.generate(visible.length, (index) {
                              final item = visible[index];
                              final value = item.count.toDouble();
                              final selected = _touchedIndex == index;
                              return PieChartSectionData(
                                value: value <= 0 ? 0.1 : value,
                                title: '',
                                radius: selected ? 47 : 42,
                                color: _itemColor(item, colors, index),
                              );
                            }),
                          ),
                        ),
                        _buildCenterText(
                          totalUsage: totalUsage,
                          isEn: isEn,
                          muted: muted,
                        ),
                        if (_touchedIndex != null &&
                            _touchPosition != null &&
                            _touchedIndex! >= 0 &&
                            _touchedIndex! < visible.length)
                          _buildHoverBadge(
                            context: context,
                            chartSize: chartSize,
                            item: visible[_touchedIndex!],
                            color: _itemColor(
                              visible[_touchedIndex!],
                              colors,
                              _touchedIndex!,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                isEn
                    ? 'Total Fleet: $totalArmada'
                    : 'Total Armada: $totalArmada',
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

  Widget _buildCenterText({
    required int totalUsage,
    required bool isEn,
    required Color muted,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isEn ? 'Fleet Usage' : 'Penggunaan Armada',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        Text(
          '${totalUsage}x',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildHoverBadge({
    required BuildContext context,
    required Size chartSize,
    required ArmadaUsage item,
    required Color color,
  }) {
    const bubbleWidth = 210.0;
    const bubbleHeight = 90.0;
    final local =
        _touchPosition ?? Offset(chartSize.width / 2, chartSize.height / 2);

    final left =
        (local.dx + 12).clamp(8.0, max(8.0, chartSize.width - bubbleWidth - 8));
    final top = (local.dy - bubbleHeight - 12)
        .clamp(8.0, max(8.0, chartSize.height - bubbleHeight - 8));

    return Positioned(
      left: left.toDouble(),
      top: top.toDouble(),
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: bubbleWidth,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface(context).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.9), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.plate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryFor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Penggunaan: ${item.count}x',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryFor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _itemColor(ArmadaUsage item, List<Color> palette, int index) {
    return palette[index % palette.length];
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
      Color(0xFF0EA5A4),
      Color(0xFFEC4899),
    ];
    if (n <= base.length) return base.take(n).toList();

    final list = <Color>[...base];
    for (var i = base.length; i < n; i++) {
      final h = (360 * i / max(n, 8)).roundToDouble();
      list.add(HSLColor.fromAHSL(1, h, 0.76, 0.52).toColor());
    }
    return list;
  }
}
