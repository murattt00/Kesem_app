import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/recurring_service.dart';
import '../domain/enums.dart';
import '../providers.dart';
import '../recurring/recurring_engine.dart';
import '../util/format.dart';
import '../util/icons.dart';
import 'recurring_edit_screen.dart';
import 'theme/app_theme.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recurringTemplatesProvider);
    final catMap = ref.watch(categoryMapProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (list) {
        if (list.isEmpty) return const _EmptyRecurring();
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, indent: 72, endIndent: 16),
          itemBuilder: (context, i) =>
              _RecurringTile(template: list[i], category: catMap[list[i].categoryId]),
        );
      },
    );
  }
}

class _RecurringTile extends ConsumerWidget {
  const _RecurringTile({required this.template, required this.category});

  final RecurringTemplate template;
  final Category? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final isIncome = template.type == TransactionType.income;
    final color = category != null ? Color(category!.colorValue) : Colors.grey;
    final icon = category != null
        ? iconFromCodePoint(category!.iconCodePoint)
        : Icons.category;

    final subtitle = StringBuffer(_describe(template));
    if (template.active) {
      final now = DateTime.now();
      final next = nextOccurrence(
        RecurringService.scheduleOf(template),
        after: DateTime(now.year, now.month, now.day),
      );
      subtitle.write(next == null
          ? ' · bitti'
          : ' · sonraki ${formatDayShort(next)}');
    } else {
      subtitle.write(' · pasif');
    }

    return Opacity(
      opacity: template.active ? 1 : 0.5,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                category?.name ?? template.categoryId,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              formatMoney(template.amountMinor),
              style: TextStyle(
                color: isIncome ? c.income : c.expense,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Text(subtitle.toString()),
        trailing: Switch(
          value: template.active,
          onChanged: (v) =>
              ref.read(recurringRepoProvider).setActive(template.id, v),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecurringEditScreen(template: template),
          ),
        ),
      ),
    );
  }

  String _describe(RecurringTemplate t) {
    switch (t.frequency) {
      case RecurringFrequency.weekly:
        return 'Haftalık · ${weekdayName(t.weekday ?? 1)}';
      case RecurringFrequency.monthly:
        return 'Aylık · her ayın ${t.dayOfMonth ?? 1}\'i';
      case RecurringFrequency.yearly:
        return 'Yıllık · ${t.dayOfMonth ?? 1} ${monthName(t.monthOfYear ?? 1)}';
    }
  }
}

class _EmptyRecurring extends StatelessWidget {
  const _EmptyRecurring();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat_rounded,
                size: 64, color: scheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('Henüz tekrarlayan yok'),
            const SizedBox(height: 4),
            Text(
              'Kira, maaş, abonelik gibi sabit kalemleri\nbir kez tanımla, her ay otomatik düşsün.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
