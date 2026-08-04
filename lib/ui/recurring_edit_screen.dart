import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/enums.dart';
import '../providers.dart';
import '../recurring/recurring_engine.dart';
import '../util/format.dart';
import '../util/icons.dart';
import '../util/money_input.dart';
import 'theme/app_theme.dart';

/// Tekrarlayan şablon ekleme/düzenleme formu. [template] verilirse düzenleme.
class RecurringEditScreen extends ConsumerStatefulWidget {
  const RecurringEditScreen({super.key, this.template});

  final RecurringTemplate? template;

  bool get isEditing => template != null;

  @override
  ConsumerState<RecurringEditScreen> createState() =>
      _RecurringEditScreenState();
}

class _RecurringEditScreenState extends ConsumerState<RecurringEditScreen> {
  late TransactionType _type;
  late RecurringFrequency _frequency;
  String? _categoryId;
  int _dayOfMonth = 1;
  int _weekday = DateTime.monday;
  int _monthOfYear = 1;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _active = true;

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    if (t != null) {
      _type = t.type;
      _frequency = t.frequency;
      _categoryId = t.categoryId;
      _dayOfMonth = t.dayOfMonth ?? 1;
      _weekday = t.weekday ?? DateTime.monday;
      _monthOfYear = t.monthOfYear ?? 1;
      _startDate = t.startDate;
      _endDate = t.endDate;
      _active = t.active;
      _amountController.text = (t.amountMinor / 100).toStringAsFixed(2);
      _noteController.text = t.note ?? '';
    } else {
      _type = TransactionType.expense;
      _frequency = RecurringFrequency.monthly;
      final n = DateTime.now();
      _startDate = DateTime(n.year, n.month, n.day);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final d = DateTime(picked.year, picked.month, picked.day);
      setState(() {
        if (isStart) {
          _startDate = d;
        } else {
          _endDate = d;
        }
      });
    }
  }

  Future<void> _save() async {
    final kurus = parseMoneyToMinor(_amountController.text);
    if (kurus <= 0) {
      _snack('Geçerli bir tutar gir');
      return;
    }
    if (_categoryId == null) {
      _snack('Bir kategori seç');
      return;
    }
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      _snack('Bitiş tarihi başlangıçtan önce olamaz');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final note = _noteController.text.trim();
    final entry = RecurringTemplatesCompanion(
      type: Value(_type),
      amountMinor: Value(kurus),
      categoryId: Value(_categoryId!),
      frequency: Value(_frequency),
      dayOfMonth: Value(
        _frequency == RecurringFrequency.weekly ? null : _dayOfMonth,
      ),
      weekday: Value(
        _frequency == RecurringFrequency.weekly ? _weekday : null,
      ),
      monthOfYear: Value(
        _frequency == RecurringFrequency.yearly ? _monthOfYear : null,
      ),
      startDate: Value(_startDate),
      endDate: Value(_endDate),
      active: Value(_active),
      note: Value(note.isEmpty ? null : note),
    );

    final repo = ref.read(recurringRepoProvider);
    try {
      if (widget.isEditing) {
        await repo.update(widget.template!.id, entry);
      } else {
        await repo.add(entry);
      }
      // Vadesi gelmiş varsa hemen işleme dönüşsün.
      await ref.read(recurringServiceProvider).materializeDue();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şablon silinsin mi?'),
        content: const Text(
          'Bu tekrarlayan silinecek. Daha önce oluşturduğu işlemler kalır.',
        ),
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
      await ref.read(recurringRepoProvider).delete(widget.template!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Tekrarlayanı Düzenle' : 'Yeni Tekrarlayan'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: moneyInputFormatters,
            decoration: const InputDecoration(
              labelText: 'Tutar',
              prefixText: '₺ ',
            ),
          ),
          const SizedBox(height: 16),
          _label(context, 'Kategori'),
          _CategoryStrip(
            type: _type,
            selectedId: _categoryId,
            onSelected: (id) => setState(() => _categoryId = id),
          ),
          const SizedBox(height: 16),
          _label(context, 'Sıklık'),
          const SizedBox(height: 8),
          SegmentedButton<RecurringFrequency>(
            segments: const [
              ButtonSegment(
                value: RecurringFrequency.weekly,
                label: Text('Haftalık'),
              ),
              ButtonSegment(
                value: RecurringFrequency.monthly,
                label: Text('Aylık'),
              ),
              ButtonSegment(
                value: RecurringFrequency.yearly,
                label: Text('Yıllık'),
              ),
            ],
            selected: {_frequency},
            onSelectionChanged: (s) => setState(() => _frequency = s.first),
          ),
          const SizedBox(height: 12),
          ..._scheduleFields(),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Başlangıç'),
            trailing: Text(formatFullDate(_startDate)),
            onTap: () => _pickDate(isStart: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy),
            title: const Text('Bitiş (opsiyonel)'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_endDate == null ? 'Süresiz' : formatFullDate(_endDate!)),
                if (_endDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _endDate = null),
                  ),
              ],
            ),
            onTap: () => _pickDate(isStart: false),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aktif'),
            subtitle: const Text('Kapalıysa otomatik işlem üretmez'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Not (opsiyonel)',
              counterText: '',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  List<Widget> _scheduleFields() {
    switch (_frequency) {
      case RecurringFrequency.weekly:
        return [
          _dropdown<int>(
            label: 'Haftanın günü',
            value: _weekday,
            items: [
              for (var w = 1; w <= 7; w++)
                DropdownMenuItem(value: w, child: Text(weekdayName(w))),
            ],
            onChanged: (v) => setState(() => _weekday = v!),
          ),
        ];
      case RecurringFrequency.monthly:
        return [
          _dropdown<int>(
            label: 'Ayın günü',
            value: _dayOfMonth,
            items: [
              for (var d = 1; d <= 31; d++)
                DropdownMenuItem(value: d, child: Text('$d')),
            ],
            onChanged: (v) => setState(() => _dayOfMonth = v!),
          ),
          if (_dayOfMonth > 28)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Kısa aylarda ayın son gününe kırpılır.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ),
        ];
      case RecurringFrequency.yearly:
        return [
          _dropdown<int>(
            label: 'Ay',
            value: _monthOfYear,
            items: [
              for (var m = 1; m <= 12; m++)
                DropdownMenuItem(value: m, child: Text(monthName(m))),
            ],
            onChanged: (v) => setState(() => _monthOfYear = v!),
          ),
          const SizedBox(height: 12),
          _dropdown<int>(
            label: 'Gün',
            value: _dayOfMonth,
            items: [
              for (var d = 1; d <= 31; d++)
                DropdownMenuItem(value: d, child: Text('$d')),
            ],
            onChanged: (v) => setState(() => _dayOfMonth = v!),
          ),
        ];
    }
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: context.scheme.onSurfaceVariant,
          ),
        ),
      );
}

/// Yatay kaydırılan kategori seçici (form içi).
class _CategoryStrip extends ConsumerWidget {
  const _CategoryStrip({
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
      loading: () => const SizedBox(height: 92),
      error: (e, _) => SizedBox(height: 92, child: Center(child: Text('$e'))),
      data: (list) => SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final cat = list[i];
            final color = Color(cat.colorValue);
            final selected = cat.id == selectedId;
            return GestureDetector(
              onTap: () => onSelected(cat.id),
              child: SizedBox(
                width: 68,
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: selected ? color : color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
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
