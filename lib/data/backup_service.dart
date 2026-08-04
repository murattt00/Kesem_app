import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/enums.dart';
import '../recurring/recurring_engine.dart';
import 'database.dart';

/// İçe aktarma sonucu özeti.
class BackupSummary {
  const BackupSummary({
    required this.categories,
    required this.recurring,
    required this.transactions,
  });

  final int categories;
  final int recurring;
  final int transactions;
}

/// Tüm veriyi JSON olarak dışa/içe aktaran yedekleme servisi.
///
/// JSON yedeğinde satırların id'leri korunur; içe aktarmada aynı id'lerle
/// yazılır → işlem↔kategori↔tekrarlayan foreign key bağları bozulmaz.
class BackupService {
  BackupService(this.db);

  final AppDatabase db;

  static const _appTag = 'harcama_takip';
  static const _formatVersion = 1;

  Future<String> exportJson() async {
    final cats = await db.select(db.categories).get();
    final recs = await db.select(db.recurringTemplates).get();
    final txns = await db.select(db.transactions).get();
    final quicks = await db.select(db.quickTemplates).get();

    final map = {
      'app': _appTag,
      'formatVersion': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': cats.map(_catToJson).toList(),
      'recurringTemplates': recs.map(_recToJson).toList(),
      'transactions': txns.map(_txnToJson).toList(),
      'quickTemplates': quicks.map(_quickToJson).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Yedekten geri yükler. Mevcut TÜM veriyi siler ve yedektekiyle değiştirir.
  Future<BackupSummary> importJson(String jsonStr) async {
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map || decoded['app'] != _appTag) {
      throw const FormatException('Bu dosya bir Kesem yedeği değil.');
    }
    final cats = (decoded['categories'] as List?) ?? const [];
    final recs = (decoded['recurringTemplates'] as List?) ?? const [];
    final txns = (decoded['transactions'] as List?) ?? const [];
    final quicks = (decoded['quickTemplates'] as List?) ?? const [];

    await db.transaction(() async {
      // FK sırası — silme: bağımlılar önce, categories en son
      await db.delete(db.transactions).go();
      await db.delete(db.recurringTemplates).go();
      await db.delete(db.quickTemplates).go();
      await db.delete(db.categories).go();
      // ekleme: önce categories, sonra bağımlılar
      for (final c in cats) {
        await db
            .into(db.categories)
            .insert(_catFromJson(c as Map<String, dynamic>));
      }
      for (final r in recs) {
        await db
            .into(db.recurringTemplates)
            .insert(_recFromJson(r as Map<String, dynamic>));
      }
      for (final q in quicks) {
        await db
            .into(db.quickTemplates)
            .insert(_quickFromJson(q as Map<String, dynamic>));
      }
      for (final t in txns) {
        await db
            .into(db.transactions)
            .insert(_txnFromJson(t as Map<String, dynamic>));
      }
    });

    return BackupSummary(
      categories: cats.length,
      recurring: recs.length,
      transactions: txns.length,
    );
  }

  /// İşlemleri Excel/Sheets uyumlu CSV olarak verir.
  Future<String> exportCsv() async {
    final txns = await (db.select(db.transactions)
          ..orderBy([(t) => OrderingTerm(expression: t.date)]))
        .get();
    final names = {
      for (final c in await db.select(db.categories).get()) c.id: c.name,
    };

    final buf = StringBuffer()..writeln('Tarih,Tip,Kategori,Tutar,Not');
    for (final t in txns) {
      final tip = t.type == TransactionType.income ? 'Gelir' : 'Gider';
      final tutar = (t.amountMinor / 100).toStringAsFixed(2);
      final kat = (names[t.categoryId] ?? t.categoryId).replaceAll('"', '""');
      final not = (t.note ?? '').replaceAll('"', '""');
      final tarih = t.date.toIso8601String().substring(0, 10);
      buf.writeln('$tarih,$tip,"$kat",$tutar,"$not"');
    }
    return buf.toString();
  }

  // --- JSON dönüşümleri ---

  static DateTime? _dateOrNull(Object? v) =>
      v == null ? null : DateTime.parse(v as String);

  Map<String, dynamic> _catToJson(Category c) => {
        'id': c.id,
        'name': c.name,
        'type': c.type.name,
        'iconCodePoint': c.iconCodePoint,
        'colorValue': c.colorValue,
        'sortOrder': c.sortOrder,
        'isArchived': c.isArchived,
        'isDefault': c.isDefault,
        'budgetMinor': c.budgetMinor,
      };

  CategoriesCompanion _catFromJson(Map<String, dynamic> m) => CategoriesCompanion(
        id: Value(m['id'] as String),
        name: Value(m['name'] as String),
        type: Value(TransactionType.values.byName(m['type'] as String)),
        iconCodePoint: Value(m['iconCodePoint'] as int),
        colorValue: Value(m['colorValue'] as int),
        sortOrder: Value(m['sortOrder'] as int? ?? 0),
        isArchived: Value(m['isArchived'] as bool? ?? false),
        isDefault: Value(m['isDefault'] as bool? ?? false),
        budgetMinor: Value(m['budgetMinor'] as int?),
      );

  Map<String, dynamic> _recToJson(RecurringTemplate r) => {
        'id': r.id,
        'type': r.type.name,
        'amountMinor': r.amountMinor,
        'categoryId': r.categoryId,
        'note': r.note,
        'frequency': r.frequency.name,
        'dayOfMonth': r.dayOfMonth,
        'weekday': r.weekday,
        'monthOfYear': r.monthOfYear,
        'startDate': r.startDate.toIso8601String(),
        'endDate': r.endDate?.toIso8601String(),
        'active': r.active,
        'lastGeneratedDate': r.lastGeneratedDate?.toIso8601String(),
        'createdAt': r.createdAt.toIso8601String(),
      };

  RecurringTemplatesCompanion _recFromJson(Map<String, dynamic> m) =>
      RecurringTemplatesCompanion(
        id: Value(m['id'] as int),
        type: Value(TransactionType.values.byName(m['type'] as String)),
        amountMinor: Value(m['amountMinor'] as int),
        categoryId: Value(m['categoryId'] as String),
        note: Value(m['note'] as String?),
        frequency:
            Value(RecurringFrequency.values.byName(m['frequency'] as String)),
        dayOfMonth: Value(m['dayOfMonth'] as int?),
        weekday: Value(m['weekday'] as int?),
        monthOfYear: Value(m['monthOfYear'] as int?),
        startDate: Value(DateTime.parse(m['startDate'] as String)),
        endDate: Value(_dateOrNull(m['endDate'])),
        active: Value(m['active'] as bool? ?? true),
        lastGeneratedDate: Value(_dateOrNull(m['lastGeneratedDate'])),
        createdAt: Value(DateTime.parse(m['createdAt'] as String)),
      );

  Map<String, dynamic> _txnToJson(Transaction t) => {
        'id': t.id,
        'type': t.type.name,
        'amountMinor': t.amountMinor,
        'categoryId': t.categoryId,
        'note': t.note,
        'date': t.date.toIso8601String(),
        'source': t.source.name,
        'recurringId': t.recurringId,
        'createdAt': t.createdAt.toIso8601String(),
      };

  TransactionsCompanion _txnFromJson(Map<String, dynamic> m) =>
      TransactionsCompanion(
        id: Value(m['id'] as int),
        type: Value(TransactionType.values.byName(m['type'] as String)),
        amountMinor: Value(m['amountMinor'] as int),
        categoryId: Value(m['categoryId'] as String),
        note: Value(m['note'] as String?),
        date: Value(DateTime.parse(m['date'] as String)),
        source: Value(TransactionSource.values.byName(m['source'] as String)),
        recurringId: Value(m['recurringId'] as int?),
        createdAt: Value(DateTime.parse(m['createdAt'] as String)),
      );

  Map<String, dynamic> _quickToJson(QuickTemplate q) => {
        'id': q.id,
        'label': q.label,
        'type': q.type.name,
        'amountMinor': q.amountMinor,
        'categoryId': q.categoryId,
        'sortOrder': q.sortOrder,
        'createdAt': q.createdAt.toIso8601String(),
      };

  QuickTemplatesCompanion _quickFromJson(Map<String, dynamic> m) =>
      QuickTemplatesCompanion(
        id: Value(m['id'] as int),
        label: Value(m['label'] as String?),
        type: Value(TransactionType.values.byName(m['type'] as String)),
        amountMinor: Value(m['amountMinor'] as int),
        categoryId: Value(m['categoryId'] as String),
        sortOrder: Value(m['sortOrder'] as int? ?? 0),
        createdAt: Value(DateTime.parse(m['createdAt'] as String)),
      );
}
