import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/enums.dart';
import '../providers.dart';
import '../util/format.dart';
import '../util/icons.dart';
import 'add_transaction_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/month_selector_bar.dart';
import 'widgets/quick_templates_row.dart';

/// Ana sekme: ay seçici + özet kart + işlem listesi.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: const [
        MonthSelectorBar(),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: _SummaryCard(),
        ),
        QuickTemplatesRow(),
        SizedBox(height: 8),
        Expanded(child: _TransactionList()),
      ],
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(monthSummaryProvider);
    final c = context.appColors;
    final negative = s.netMinor < 0;
    final netColor = negative ? c.negative : c.positive;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kalan',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                ),
                _SavingsBadge(
                  rate: s.savingsRate,
                  negative: negative,
                  hasIncome: s.incomeMinor > 0,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              formatMoney(s.netMinor),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: netColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Gelir',
                    value: formatMoney(s.incomeMinor),
                    icon: Icons.south_west_rounded,
                    fg: c.income,
                    bg: c.incomeSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                    label: 'Gider',
                    value: formatMoney(s.expenseMinor),
                    icon: Icons.north_east_rounded,
                    fg: c.expense,
                    bg: c.expenseSurface,
                  ),
                ),
              ],
            ),
            if (negative) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: c.negative, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Bu ay gideri gelirini aştı',
                      style: TextStyle(color: c.negative, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SavingsBadge extends StatelessWidget {
  const _SavingsBadge({
    required this.rate,
    required this.negative,
    required this.hasIncome,
  });

  final double rate;
  final bool negative;
  final bool hasIncome;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final scheme = context.scheme;
    final color = !hasIncome
        ? scheme.onSurfaceVariant
        : (negative ? c.negative : c.positive);
    final bg = !hasIncome
        ? scheme.surfaceContainerHighest
        : (negative ? c.expenseSurface : c.incomeSurface);
    final label = hasIncome ? 'Tasarruf %${rate.toStringAsFixed(0)}' : 'Tasarruf —';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.fg,
    required this.bg,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: fg, fontSize: 12)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionList extends ConsumerWidget {
  const _TransactionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(monthTransactionsProvider);
    final catMap = ref.watch(categoryMapProvider);

    return txnsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (list) {
        if (list.isEmpty) return const _EmptyState();
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, indent: 72, endIndent: 16),
          itemBuilder: (context, i) {
            final t = list[i];
            return _TransactionTile(txn: t, category: catMap[t.categoryId]);
          },
        );
      },
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.txn, required this.category});

  final Transaction txn;
  final Category? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final isIncome = txn.type == TransactionType.income;
    final color = category != null ? Color(category!.colorValue) : Colors.grey;
    final icon = category != null
        ? iconFromCodePoint(category!.iconCodePoint)
        : Icons.category;
    final isRecurring = txn.source == TransactionSource.recurring;

    final subtitleParts = <String>[
      formatDayShort(txn.date),
      if (txn.note != null && txn.note!.isNotEmpty) txn.note!,
      if (isRecurring) 'Tekrarlayan',
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        category?.name ?? txn.categoryId,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: Text(
        formatSignedMoney(txn.amountMinor, isIncome: isIncome),
        style: TextStyle(
          color: isIncome ? c.income : c.expense,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddTransactionScreen(transaction: txn),
        ),
      ),
      onLongPress: () => _confirmDelete(context, ref),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İşlem silinsin mi?'),
        content: const Text('Bu işlem kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(transactionRepoProvider).delete(txn.id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 64, color: scheme.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('Bu ay henüz işlem yok'),
          const SizedBox(height: 4),
          Text(
            'Sağ alttaki + ile ekle',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
