import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../providers.dart';
import '../../util/format.dart';
import '../../util/icons.dart';
import '../../util/money_input.dart';
import '../theme/app_theme.dart';

/// Ana ekranda tek dokunuşla işlem ekleyen hızlı şablon çipleri.
class QuickTemplatesRow extends ConsumerWidget {
  const QuickTemplatesRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(quickTemplatesProvider).value ?? const [];
    final catMap = ref.watch(categoryMapProvider);

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final t in templates)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TemplateChip(
                template: t,
                category: catMap[t.categoryId],
              ),
            ),
          _AddChip(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => const _QuickTemplateSheet(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateChip extends ConsumerWidget {
  const _TemplateChip({required this.template, required this.category});

  final QuickTemplate template;
  final Category? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final color = category != null ? Color(category!.colorValue) : Colors.grey;
    final isIncome = template.type == TransactionType.income;
    final title = (template.label != null && template.label!.isNotEmpty)
        ? template.label!
        : (category?.name ?? template.categoryId);

    return InkWell(
      onTap: () => _apply(context, ref, title),
      onLongPress: () => _confirmDelete(context, ref, title),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: color.withValues(alpha: 0.18),
              child: Icon(
                category != null
                    ? iconFromCodePoint(category!.iconCodePoint)
                    : Icons.category,
                color: color,
                size: 15,
              ),
            ),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text(
              formatMoney(template.amountMinor),
              style: TextStyle(
                color: isIncome ? c.income : c.expense,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _apply(BuildContext context, WidgetRef ref, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final id = await ref.read(transactionRepoProvider).add(
          type: template.type,
          amountMinor: template.amountMinor,
          categoryId: template.categoryId,
          date: DateTime(now.year, now.month, now.day),
        );
    messenger.showSnackBar(
      SnackBar(
        content: Text('$name eklendi'),
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () => ref.read(transactionRepoProvider).delete(id),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şablon silinsin mi?'),
        content: Text('"$name" hızlı şablonu silinecek.'),
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
      await ref.read(quickTemplateRepoProvider).delete(template.id);
    }
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18, color: context.scheme.primary),
            const SizedBox(width: 4),
            Text(
              'Hızlı ekle',
              style: TextStyle(
                color: context.scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yeni hızlı şablon oluşturma alt sayfası.
class _QuickTemplateSheet extends ConsumerStatefulWidget {
  const _QuickTemplateSheet();

  @override
  ConsumerState<_QuickTemplateSheet> createState() =>
      _QuickTemplateSheetState();
}

class _QuickTemplateSheetState extends ConsumerState<_QuickTemplateSheet> {
  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  final _amount = TextEditingController();
  final _label = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kurus = parseMoneyToMinor(_amount.text);
    if (kurus <= 0 || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tutar ve kategori gir')),
      );
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final label = _label.text.trim();
    try {
      await ref.read(quickTemplateRepoProvider).add(
            type: _type,
            amountMinor: kurus,
            categoryId: _categoryId!,
            label: label.isEmpty ? null : label,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(orderedCategoriesByTypeProvider(_type));
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hızlı Şablon',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(
                value: TransactionType.expense,
                label: Text('Gider'),
                icon: Icon(Icons.north_east_rounded),
              ),
              ButtonSegment(
                value: TransactionType.income,
                label: Text('Gelir'),
                icon: Icon(Icons.south_west_rounded),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: moneyInputFormatters,
            decoration: const InputDecoration(
              labelText: 'Tutar',
              prefixText: '₺ ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _label,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: 'Ad (opsiyonel)',
              hintText: 'ör. Kahve',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: cats.when(
              loading: () => const SizedBox(),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) => ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = list[i];
                  final color = Color(cat.colorValue);
                  final selected = cat.id == _categoryId;
                  return GestureDetector(
                    onTap: () => setState(() => _categoryId = cat.id),
                    child: SizedBox(
                      width: 68,
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: selected
                                ? color
                                : color.withValues(alpha: 0.15),
                            child: Icon(
                              iconFromCodePoint(cat.iconCodePoint),
                              color: selected ? Colors.white : color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}
