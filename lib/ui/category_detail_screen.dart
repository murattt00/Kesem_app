import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums.dart';
import '../providers.dart';
import '../util/format.dart';
import '../util/icons.dart';
import 'add_transaction_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/month_selector_bar.dart';

class CategoryDetailScreen extends ConsumerWidget {
  const CategoryDetailScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryMapProvider)[categoryId];
    final color = category != null ? Color(category.colorValue) : Colors.grey;
    final txns = ref.watch(categoryMonthTransactionsProvider(categoryId));
    final total = txns.fold<int>(0, (a, t) => a + t.amountMinor);
    final c = context.appColors;
    final isIncome = category?.type == TransactionType.income;

    return Scaffold(
      appBar: AppBar(title: Text(category?.name ?? categoryId)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const MonthSelectorBar(),
          // Başlık kartı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(
                        category != null
                            ? iconFromCodePoint(category.iconCodePoint)
                            : Icons.category,
                        color: color,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bu ay',
                          style: TextStyle(
                            color: context.scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          formatMoney(total),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: isIncome ? c.income : c.expense,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Trend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Son 6 ay',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _CategoryTrend(categoryId: categoryId, color: color),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'İşlemler',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (txns.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Bu ay bu kategoride işlem yok',
                  style: TextStyle(color: context.scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ...txns.map((t) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(
                      category != null
                          ? iconFromCodePoint(category.iconCodePoint)
                          : Icons.category,
                      color: color,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    (t.note != null && t.note!.isNotEmpty)
                        ? t.note!
                        : formatFullDate(t.date),
                  ),
                  subtitle: (t.note != null && t.note!.isNotEmpty)
                      ? Text(formatDayShort(t.date))
                      : null,
                  trailing: Text(
                    formatMoney(t.amountMinor),
                    style: TextStyle(
                      color: isIncome ? c.income : c.expense,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddTransactionScreen(transaction: t),
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class _CategoryTrend extends ConsumerWidget {
  const _CategoryTrend({required this.categoryId, required this.color});

  final String categoryId;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoryTrendProvider(categoryId));
    return async.when(
      loading: () => const SizedBox(height: 160),
      error: (e, _) => SizedBox(height: 160, child: Center(child: Text('$e'))),
      data: (points) {
        final maxMinor = points.map((p) => p.totalMinor).fold<int>(0, max);
        if (maxMinor == 0) {
          return SizedBox(
            height: 160,
            child: Center(
              child: Text(
                'Yeterli veri yok',
                style: TextStyle(color: context.scheme.onSurfaceVariant),
              ),
            ),
          );
        }
        final maxY = (maxMinor / 100.0) * 1.25;
        return SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => context.scheme.inverseSurface,
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    formatMoney((rod.toY * 100).round()),
                    TextStyle(
                      color: context.scheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
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
                    barRods: [
                      BarChartRodData(
                        toY: points[i].totalMinor / 100.0,
                        color: color,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
