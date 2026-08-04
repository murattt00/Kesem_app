import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../util/format.dart';

/// Ay seçici çubuk (‹ Temmuz 2026 ›) — ana ekran ve grafikler ortak kullanır.
class MonthSelectorBar extends ConsumerWidget {
  const MonthSelectorBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final notifier = ref.read(selectedMonthProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filledTonal(
            icon: const Icon(Icons.chevron_left),
            onPressed: notifier.previous,
          ),
          SizedBox(
            width: 180,
            child: Text(
              formatMonthYear(month),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.chevron_right),
            onPressed: notifier.next,
          ),
        ],
      ),
    );
  }
}
