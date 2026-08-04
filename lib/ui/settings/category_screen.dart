import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../providers.dart';
import '../../util/icons.dart';
import '../../util/money_input.dart';
import '../theme/app_theme.dart';

/// Özel kategori seçiminde sunulan ikon paleti.
const List<IconData> kCategoryIcons = [
  Icons.shopping_cart,
  Icons.restaurant,
  Icons.home,
  Icons.receipt_long,
  Icons.directions_bus,
  Icons.local_hospital,
  Icons.subscriptions,
  Icons.checkroom,
  Icons.content_cut,
  Icons.movie,
  Icons.school,
  Icons.chair,
  Icons.fitness_center,
  Icons.pets,
  Icons.child_care,
  Icons.card_giftcard,
  Icons.flight,
  Icons.shield,
  Icons.account_balance,
  Icons.gavel,
  Icons.payments,
  Icons.work,
  Icons.trending_up,
  Icons.emoji_events,
  Icons.savings,
  Icons.coffee,
  Icons.phone_android,
  Icons.sports_esports,
  Icons.category,
];

const List<int> kCategoryColors = [
  0xFF66BB6A,
  0xFFEF5350,
  0xFF42A5F5,
  0xFFFFA726,
  0xFFAB47BC,
  0xFF26C6DA,
  0xFFFF7043,
  0xFF7E57C2,
  0xFF5C6BC0,
  0xFF8D6E63,
  0xFFEC407A,
  0xFF26A69A,
  0xFF78909C,
  0xFFFFCA28,
];

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allCategoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kategoriler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref, type: TransactionType.expense),
        icon: const Icon(Icons.add),
        label: const Text('Kategori'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (all) {
          final expense =
              all.where((c) => c.type == TransactionType.expense).toList();
          final income =
              all.where((c) => c.type == TransactionType.income).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _sectionHeader(context, 'Giderler'),
              ...expense.map((c) => _CategoryTile(category: c)),
              _sectionHeader(context, 'Gelirler'),
              ...income.map((c) => _CategoryTile(category: c)),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.scheme.primary,
          ),
        ),
      );
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(category.colorValue);
    final archived = category.isArchived;
    return Opacity(
      opacity: archived ? 0.45 : 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(iconFromCodePoint(category.iconCodePoint), color: color),
        ),
        title: Text(category.name),
        subtitle: archived ? const Text('Arşivli') : null,
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            final repo = ref.read(categoryRepoProvider);
            switch (v) {
              case 'edit':
                _openEditor(context, ref, existing: category);
              case 'archive':
                await repo.setArchived(category.id, true);
              case 'unarchive':
                await repo.setArchived(category.id, false);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
            if (archived)
              const PopupMenuItem(value: 'unarchive', child: Text('Arşivden çıkar'))
            else
              const PopupMenuItem(value: 'archive', child: Text('Arşivle')),
          ],
        ),
        onTap: () => _openEditor(context, ref, existing: category),
      ),
    );
  }
}

void _openEditor(
  BuildContext context,
  WidgetRef ref, {
  Category? existing,
  TransactionType? type,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CategoryEditSheet(
      existing: existing,
      type: existing?.type ?? type ?? TransactionType.expense,
    ),
  );
}

class _CategoryEditSheet extends ConsumerStatefulWidget {
  const _CategoryEditSheet({this.existing, required this.type});

  final Category? existing;
  final TransactionType type;

  @override
  ConsumerState<_CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<_CategoryEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _budget;
  late int _iconCodePoint;
  late int _colorValue;
  late TransactionType _type;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    final b = widget.existing?.budgetMinor;
    _budget = TextEditingController(
      text: b != null ? (b / 100).toStringAsFixed(2) : '',
    );
    _iconCodePoint = widget.existing?.iconCodePoint ?? kCategoryIcons.first.codePoint;
    _colorValue = widget.existing?.colorValue ?? kCategoryColors.first;
    _type = widget.existing?.type ?? widget.type;
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  int? _parseBudget() {
    final k = parseMoneyToMinor(_budget.text);
    return k > 0 ? k : null;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (name.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Bir ad gir')));
      return;
    }
    final all = ref.read(allCategoriesProvider).value ?? const [];
    final dup = all.any((c) =>
        c.type == _type &&
        c.id != widget.existing?.id &&
        c.name.trim().toLowerCase() == name.toLowerCase());
    if (dup) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Bu isimde bir kategori zaten var')),
      );
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final budget = _type == TransactionType.expense ? _parseBudget() : null;
    final repo = ref.read(categoryRepoProvider);
    try {
      if (_isEditing) {
        await repo.updateCategory(
          widget.existing!.id,
          name: name,
          iconCodePoint: _iconCodePoint,
          colorValue: _colorValue,
        );
        await repo.setBudget(widget.existing!.id, budget);
      } else {
        final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
        await repo.addCustom(
          id: id,
          name: name,
          type: _type,
          iconCodePoint: _iconCodePoint,
          colorValue: _colorValue,
        );
        await repo.setBudget(id, budget);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_colorValue);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Kategoriyi Düzenle' : 'Yeni Kategori',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (!_isEditing) ...[
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
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _name,
              autofocus: !_isEditing,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Ad',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            const Text('İkon'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final icon in kCategoryIcons)
                  GestureDetector(
                    onTap: () => setState(() => _iconCodePoint = icon.codePoint),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: _iconCodePoint == icon.codePoint
                          ? color
                          : color.withValues(alpha: 0.12),
                      child: Icon(
                        icon,
                        color: _iconCodePoint == icon.codePoint
                            ? Colors.white
                            : color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Renk'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final col in kCategoryColors)
                  GestureDetector(
                    onTap: () => setState(() => _colorValue = col),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(col),
                        shape: BoxShape.circle,
                        border: _colorValue == col
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            if (_type == TransactionType.expense) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _budget,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: moneyInputFormatters,
                decoration: const InputDecoration(
                  labelText: 'Aylık bütçe (opsiyonel)',
                  prefixText: '₺ ',
                  helperText: 'Aşınca ana ekranda uyarı görürsün',
                ),
              ),
            ],
            const SizedBox(height: 20),
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
      ),
    );
  }
}
