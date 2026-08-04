import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../util/format.dart';
import 'category_detail_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/month_selector_bar.dart';

class ChartsScreen extends ConsumerWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: const [
        MonthSelectorBar(),
        SizedBox(height: 4),
        _BudgetCard(),
        _SectionCard(title: 'Gider Dağılımı', child: _CategoryDonut()),
        SizedBox(height: 12),
        _ComparisonCard(),
        SizedBox(height: 12),
        _SectionCard(title: 'Aylık Trend', child: _TrendBars()),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: context.scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Gider kategorilerinin donut dağılımı + altında lejant listesi.
class _CategoryDonut extends ConsumerWidget {
  const _CategoryDonut();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slices = ref.watch(expenseByCategoryProvider);
    if (slices.isEmpty) return const _EmptyHint('Bu ay gider yok');

    final total = slices.fold<int>(0, (a, s) => a + s.totalMinor);

    Color colorFor(int i) {
      final cat = slices[i].category;
      return cat != null
          ? Color(cat.colorValue)
          : kChartPalette[i % kChartPalette.length];
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 62,
                  startDegreeOffset: -90,
                  sections: [
                    for (var i = 0; i < slices.length; i++)
                      PieChartSectionData(
                        value: slices[i].totalMinor.toDouble(),
                        color: colorFor(i),
                        radius: 26,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Toplam Gider',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formatMoney(total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < slices.length; i++)
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    CategoryDetailScreen(categoryId: slices[i].categoryId),
              ),
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colorFor(i),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      slices[i].category?.name ?? slices[i].categoryId,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '%${(slices[i].fraction * 100).toStringAsFixed(0)}',
                    style: TextStyle(color: context.scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatMoney(slices[i].totalMinor),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 18, color: context.scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Geçen aya göre gelir/gider değişimi.
class _ComparisonCard extends ConsumerWidget {
  const _ComparisonCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trendProvider);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (points) {
        if (points.length < 2) return const SizedBox.shrink();
        final cur = points[points.length - 1];
        final prev = points[points.length - 2];
        return _SectionCard(
          title: 'Geçen Aya Göre',
          child: Column(
            children: [
              _CompareRow(
                label: 'Gider',
                current: cur.expenseMinor,
                previous: prev.expenseMinor,
                increaseIsBad: true,
              ),
              const SizedBox(height: 8),
              _CompareRow(
                label: 'Gelir',
                current: cur.incomeMinor,
                previous: prev.incomeMinor,
                increaseIsBad: false,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.current,
    required this.previous,
    required this.increaseIsBad,
  });

  final String label;
  final int current;
  final int previous;
  final bool increaseIsBad;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final diff = current - previous;
    final up = diff > 0;
    final flat = diff == 0 || previous == 0 && current == 0;

    final pct = previous == 0
        ? (current == 0 ? '—' : 'yeni')
        : '%${((diff / previous) * 100).abs().toStringAsFixed(0)}';

    // "İyi/kötü" rengi: gider artışı kötü (kırmızı), gelir artışı iyi (yeşil).
    final good = flat ? false : (up ? !increaseIsBad : increaseIsBad);
    final color = flat
        ? context.scheme.onSurfaceVariant
        : (good ? c.positive : c.negative);
    final icon = flat
        ? Icons.remove
        : (up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);

    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          formatMoney(current),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 2),
        SizedBox(
          width: 52,
          child: Text(
            pct,
            textAlign: TextAlign.end,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Son 6 ayın gelir/gider trendi — gruplu bar.
class _TrendBars extends ConsumerWidget {
  const _TrendBars();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trendProvider);
    final c = context.appColors;

    return async.when(
      loading: () => const _EmptyHint('...'),
      error: (e, _) => _EmptyHint('Hata: $e'),
      data: (points) {
        final hasData =
            points.any((p) => p.incomeMinor > 0 || p.expenseMinor > 0);
        if (!hasData) return const _EmptyHint('Yeterli veri yok');

        final maxMinor = points
            .map((p) => max(p.incomeMinor, p.expenseMinor))
            .fold<int>(0, max);
        final maxY = (maxMinor / 100.0) * 1.25;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: c.income, label: 'Gelir'),
                const SizedBox(width: 16),
                _LegendDot(color: c.expense, label: 'Gider'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => context.scheme.inverseSurface,
                      getTooltipItem: (group, _, rod, rodIndex) {
                        final label = rodIndex == 0 ? 'Gelir' : 'Gider';
                        return BarTooltipItem(
                          '$label\n${formatMoney((rod.toY * 100).round())}',
                          TextStyle(
                            color: context.scheme.onInverseSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: context.scheme.outlineVariant.withValues(alpha: 0.4),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            formatCompactMoney((value * 100).round()),
                            style: TextStyle(
                              fontSize: 10,
                              color: context.scheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              formatMonthAbbr(points[i].month),
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 3,
                        barRods: [
                          BarChartRodData(
                            toY: points[i].incomeMinor / 100.0,
                            color: c.income,
                            width: 8,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: points[i].expenseMinor / 100.0,
                            color: c.expense,
                            width: 8,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bütçeli kategorilerin seçili aydaki durumu (ilerleme çubukları).
class _BudgetCard extends ConsumerWidget {
  const _BudgetCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(categoryBudgetsProvider);
    if (budgets.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _SectionCard(
        title: 'Bütçeler',
        child: Column(
          children: [
            for (final b in budgets) _BudgetRow(budget: b),
          ],
        ),
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.budget});

  final CategoryBudget budget;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final near = budget.ratio >= 0.8 && !budget.over;
    final color = budget.over
        ? c.negative
        : (near ? const Color(0xFFF59E0B) : context.scheme.primary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  budget.category.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${formatMoney(budget.spentMinor)} / ${formatMoney(budget.budgetMinor)}',
                style: TextStyle(
                  fontSize: 13,
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: budget.ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                budget.over
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                budget.over
                    ? 'Bütçeyi ${formatMoney(-budget.remainingMinor)} aştın'
                    : '${formatMoney(budget.remainingMinor)} kaldı',
                style: TextStyle(fontSize: 12, color: color),
              ),
              const Spacer(),
              Text(
                '%${(budget.ratio * 100).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
