import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/enums.dart';
import '../providers.dart';
import '../util/format.dart';
import '../util/icons.dart';
import 'theme/app_theme.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.transaction});

  /// Verilirse düzenleme modu; yoksa yeni işlem.
  final Transaction? transaction;

  bool get isEditing => transaction != null;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  TransactionType _type = TransactionType.expense;
  int _kurus = 0; // girilen tutar, kuruş
  String? _categoryId;
  DateTime _date = _today();
  final _noteController = TextEditingController();
  bool _saving = false;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    if (t != null) {
      _type = t.type;
      _kurus = t.amountMinor;
      _categoryId = t.categoryId;
      _date = DateTime(t.date.year, t.date.month, t.date.day);
      _noteController.text = t.note ?? '';
    }
  }

  static const int _maxKurus = 100000000000; // 1 milyar TL üst sınır

  bool get _canSave => _kurus > 0 && _categoryId != null;

  void _tapDigit(int digit) {
    setState(() {
      final next = _kurus * 10 + digit;
      if (next <= _maxKurus) _kurus = next;
    });
  }

  void _tapDoubleZero() {
    setState(() {
      final next = _kurus * 100;
      if (next <= _maxKurus) _kurus = next;
    });
  }

  void _backspace() => setState(() => _kurus ~/= 10);

  void _onTypeChanged(TransactionType type) {
    setState(() {
      _type = type;
      _categoryId = null; // kategori seti değişti
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    final note = _noteController.text.trim();
    final repo = ref.read(transactionRepoProvider);
    try {
      if (widget.isEditing) {
        await repo.edit(
          widget.transaction!.id,
          type: _type,
          amountMinor: _kurus,
          categoryId: _categoryId!,
          date: _date,
          note: Value(note.isEmpty ? null : note),
        );
      } else {
        await repo.add(
          type: _type,
          amountMinor: _kurus,
          categoryId: _categoryId!,
          date: _date,
          note: note.isEmpty ? null : note,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
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
      await ref.read(transactionRepoProvider).delete(widget.transaction!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isIncome = _type == TransactionType.income;
    final amountColor = isIncome ? c.income : c.expense;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'İşlemi Düzenle' : 'İşlem Ekle'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<TransactionType>(
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
              onSelectionChanged: (s) => _onTypeChanged(s.first),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(_kurus),
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: _kurus == 0
                  ? amountColor.withValues(alpha: 0.35)
                  : amountColor,
            ),
          ),
          const SizedBox(height: 8),
          _CategoryPicker(
            type: _type,
            selectedId: _categoryId,
            onSelected: (id) => setState(() => _categoryId = id),
          ),
          _DateNoteRow(
            date: _date,
            noteController: _noteController,
            onPickDate: _pickDate,
          ),
          const Divider(height: 1),
          Expanded(
            child: _Keypad(
              onDigit: _tapDigit,
              onDoubleZero: _tapDoubleZero,
              onBackspace: _backspace,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_canSave && !_saving) ? _save : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Kaydet'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({
    required this.type,
    required this.selectedId,
    required this.onSelected,
  });

  final TransactionType type;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(orderedCategoriesByTypeProvider(type));
    return cats.when(
      loading: () => const SizedBox(height: 96),
      error: (e, _) => SizedBox(height: 96, child: Center(child: Text('$e'))),
      data: (list) => SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final cat = list[i];
            final color = Color(cat.colorValue);
            final selected = cat.id == selectedId;
            return GestureDetector(
              onTap: () => onSelected(cat.id),
              child: SizedBox(
                width: 70,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color:
                            selected ? color : color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: color, width: 2)
                            : null,
                      ),
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
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DateNoteRow extends StatelessWidget {
  const _DateNoteRow({
    required this.date,
    required this.noteController,
    required this.onPickDate,
  });

  final DateTime date;
  final TextEditingController noteController;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: onPickDate,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(formatFullDate(date)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: noteController,
              maxLength: 80,
              decoration: const InputDecoration(
                hintText: 'Not (opsiyonel)',
                counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onDoubleZero,
    required this.onBackspace,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onDoubleZero;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(child: child),
        ),
      );
    }

    Widget digit(int n) => key(
          Text('$n', style: const TextStyle(fontSize: 26)),
          () => onDigit(n),
        );

    Widget row(List<Widget> children) => Expanded(child: Row(children: children));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          row([digit(1), digit(2), digit(3)]),
          row([digit(4), digit(5), digit(6)]),
          row([digit(7), digit(8), digit(9)]),
          row([
            key(const Text('00', style: TextStyle(fontSize: 24)), onDoubleZero),
            digit(0),
            key(const Icon(Icons.backspace_outlined, size: 24), onBackspace),
          ]),
        ],
      ),
    );
  }
}
