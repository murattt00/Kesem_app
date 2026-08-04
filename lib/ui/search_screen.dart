import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/enums.dart';
import '../providers.dart';
import '../util/format.dart';
import '../util/icons.dart';
import '../util/money_input.dart';
import 'add_transaction_screen.dart';
import 'theme/app_theme.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  TransactionType? _type;
  String? _categoryId;
  DateTime? _from;
  DateTime? _to;

  List<Transaction> _results = const [];
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  int? _parseKurus(String text) {
    if (text.trim().isEmpty) return null;
    final k = parseMoneyToMinor(text);
    return k > 0 ? k : null;
  }

  Future<void> _run() async {
    final text = _queryCtrl.text.trim();
    final cats = ref.read(allCategoriesProvider).value ?? const [];
    final lowered = text.toLowerCase();
    final textCategoryIds = text.isEmpty
        ? <String>[]
        : cats
            .where((c) => c.name.toLowerCase().contains(lowered))
            .map((c) => c.id)
            .toList();

    // Ters girilen aralıkları sessizce normalle (başlangıç > bitiş olsa bile çalışır).
    var from = _from;
    var to = _to;
    if (from != null && to != null && from.isAfter(to)) {
      final tmp = from;
      from = to;
      to = tmp;
    }
    var minM = _parseKurus(_minCtrl.text);
    var maxM = _parseKurus(_maxCtrl.text);
    if (minM != null && maxM != null && minM > maxM) {
      final tmp = minM;
      minM = maxM;
      maxM = tmp;
    }

    final results = await ref.read(transactionRepoProvider).search(
          text: text.isEmpty ? null : text,
          type: _type,
          categoryId: _categoryId,
          from: from,
          toExclusive:
              to == null ? null : DateTime(to.year, to.month, to.day + 1),
          minMinor: minM,
          maxMinor: maxM,
          textCategoryIds: textCategoryIds,
        );
    if (mounted) {
      setState(() {
        _results = results;
        _searched = true;
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        final d = DateTime(picked.year, picked.month, picked.day);
        if (isStart) {
          _from = d;
        } else {
          _to = d;
        }
      });
      _run();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(allCategoriesProvider).value ?? const [];
    final catMap = ref.watch(categoryMapProvider);
    final total = _results.fold<int>(0, (a, t) => a + t.amountMinor);

    return Scaffold(
      appBar: AppBar(title: const Text('Ara')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _queryCtrl,
              autofocus: true,
              onChanged: (_) => _run(),
              decoration: InputDecoration(
                hintText: 'Not veya kategori ara',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _queryCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _queryCtrl.clear();
                          _run();
                        },
                      ),
              ),
            ),
          ),
          _FilterBar(
            type: _type,
            categoryId: _categoryId,
            from: _from,
            to: _to,
            minCtrl: _minCtrl,
            maxCtrl: _maxCtrl,
            categories: cats,
            onType: (v) {
              setState(() => _type = v);
              _run();
            },
            onCategory: (v) {
              setState(() => _categoryId = v);
              _run();
            },
            onPickDate: _pickDate,
            onClearDates: () {
              setState(() {
                _from = null;
                _to = null;
              });
              _run();
            },
            onAmountChanged: _run,
          ),
          const Divider(height: 1),
          if (_searched)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('${_results.length} sonuç',
                      style: TextStyle(color: context.scheme.onSurfaceVariant)),
                  const Spacer(),
                  if (_results.isNotEmpty)
                    Text('Toplam ${formatMoney(total)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _searched ? 'Sonuç yok' : '',
                      style: TextStyle(color: context.scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, i) {
                      final t = _results[i];
                      final cat = catMap[t.categoryId];
                      final color =
                          cat != null ? Color(cat.colorValue) : Colors.grey;
                      final c = context.appColors;
                      final isIncome = t.type == TransactionType.income;
                      final sub = [
                        formatFullDate(t.date),
                        if (t.note != null && t.note!.isNotEmpty) t.note!,
                      ].join(' · ');
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(
                            cat != null
                                ? iconFromCodePoint(cat.iconCodePoint)
                                : Icons.category,
                            color: color,
                            size: 20,
                          ),
                        ),
                        title: Text(cat?.name ?? t.categoryId),
                        subtitle: Text(sub),
                        trailing: Text(
                          formatSignedMoney(t.amountMinor, isIncome: isIncome),
                          style: TextStyle(
                            color: isIncome ? c.income : c.expense,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddTransactionScreen(transaction: t),
                            ),
                          );
                          _run(); // düzenleme sonrası yenile
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Katlanır filtre alanı.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.type,
    required this.categoryId,
    required this.from,
    required this.to,
    required this.minCtrl,
    required this.maxCtrl,
    required this.categories,
    required this.onType,
    required this.onCategory,
    required this.onPickDate,
    required this.onClearDates,
    required this.onAmountChanged,
  });

  final TransactionType? type;
  final String? categoryId;
  final DateTime? from;
  final DateTime? to;
  final TextEditingController minCtrl;
  final TextEditingController maxCtrl;
  final List<Category> categories;
  final ValueChanged<TransactionType?> onType;
  final ValueChanged<String?> onCategory;
  final void Function(bool isStart) onPickDate;
  final VoidCallback onClearDates;
  final VoidCallback onAmountChanged;

  @override
  Widget build(BuildContext context) {
    final dateLabel = (from == null && to == null)
        ? 'Tarih aralığı'
        : '${from == null ? '…' : formatDayShort(from!)} - ${to == null ? '…' : formatDayShort(to!)}';

    return ExpansionTile(
      title: const Text('Filtreler'),
      leading: const Icon(Icons.tune),
      shape: const Border(),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tümü'),
              selected: type == null,
              onSelected: (_) => onType(null),
            ),
            ChoiceChip(
              label: const Text('Gider'),
              selected: type == TransactionType.expense,
              onSelected: (_) => onType(TransactionType.expense),
            ),
            ChoiceChip(
              label: const Text('Gelir'),
              selected: type == TransactionType.income,
              onSelected: (_) => onType(TransactionType.income),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: categoryId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Kategori'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tümü')),
            for (final c in categories)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: onCategory,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onPickDate(true),
                icon: const Icon(Icons.event, size: 18),
                label: Text(dateLabel, overflow: TextOverflow.ellipsis),
              ),
            ),
            IconButton(
              tooltip: 'Bitiş',
              icon: const Icon(Icons.event_available),
              onPressed: () => onPickDate(false),
            ),
            if (from != null || to != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClearDates,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: minCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: moneyInputFormatters,
                onChanged: (_) => onAmountChanged(),
                decoration: const InputDecoration(
                  labelText: 'Min',
                  prefixText: '₺ ',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: maxCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: moneyInputFormatters,
                onChanged: (_) => onAmountChanged(),
                decoration: const InputDecoration(
                  labelText: 'Max',
                  prefixText: '₺ ',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
