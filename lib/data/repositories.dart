import 'package:drift/drift.dart';

import '../domain/enums.dart';
import '../recurring/recurring_engine.dart';
import 'database.dart';
import 'recurring_service.dart';

/// Bir ayın gelir/gider/kalan özeti (tümü kuruş cinsinden).
class MonthSummary {
  const MonthSummary({required this.incomeMinor, required this.expenseMinor});

  final int incomeMinor;
  final int expenseMinor;

  int get netMinor => incomeMinor - expenseMinor;

  /// Tasarruf oranı (%). Gelir yoksa 0.
  double get savingsRate =>
      incomeMinor == 0 ? 0 : (netMinor / incomeMinor) * 100;
}

/// Yaklaşan bir tekrarlayan işlem (önizleme kartı için).
class UpcomingRecurring {
  const UpcomingRecurring(this.template, this.date);

  final RecurringTemplate template;
  final DateTime date;
}

DateTime _monthStart(DateTime m) => DateTime(m.year, m.month, 1);
DateTime _nextMonthStart(DateTime m) => DateTime(m.year, m.month + 1, 1);

/// Kategori okuma/yazma.
class CategoryRepository {
  CategoryRepository(this.db);

  final AppDatabase db;

  /// Verilen tipteki (gelir/gider) arşivlenmemiş kategoriler, sıraya göre.
  Stream<List<Category>> watchByType(TransactionType type) {
    return (db.select(db.categories)
          ..where((c) => c.type.equalsValue(type) & c.isArchived.equals(false))
          ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
        .watch();
  }

  Future<List<Category>> getByType(TransactionType type) {
    return (db.select(db.categories)
          ..where((c) => c.type.equalsValue(type) & c.isArchived.equals(false))
          ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
        .get();
  }

  Future<Category?> findById(String id) {
    return (db.select(db.categories)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Tüm kategoriler (arşivlenmişler dahil) — liste ekranında geçmiş
  /// işlemlerin kategorisini bulmak için de gerekir.
  Stream<List<Category>> watchAll() {
    return (db.select(db.categories)
          ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
        .watch();
  }

  Future<void> addCustom({
    required String id,
    required String name,
    required TransactionType type,
    required int iconCodePoint,
    required int colorValue,
    int sortOrder = 1000,
  }) async {
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: id,
            name: name,
            type: type,
            iconCodePoint: iconCodePoint,
            colorValue: colorValue,
            sortOrder: Value(sortOrder),
          ),
        );
  }

  Future<void> updateCategory(
    String id, {
    String? name,
    int? iconCodePoint,
    int? colorValue,
  }) async {
    await (db.update(db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        iconCodePoint:
            iconCodePoint == null ? const Value.absent() : Value(iconCodePoint),
        colorValue:
            colorValue == null ? const Value.absent() : Value(colorValue),
      ),
    );
  }

  /// Kategori silmek yerine arşivlenir; geçmiş işlemler bağlı kalır.
  Future<void> setArchived(String id, bool archived) async {
    await (db.update(db.categories)..where((c) => c.id.equals(id)))
        .write(CategoriesCompanion(isArchived: Value(archived)));
  }

  /// Aylık gider bütçesi (kuruş). null → bütçeyi kaldırır.
  Future<void> setBudget(String id, int? budgetMinor) async {
    await (db.update(db.categories)..where((c) => c.id.equals(id)))
        .write(CategoriesCompanion(budgetMinor: Value(budgetMinor)));
  }
}

/// İşlem okuma/yazma + ay özeti.
class TransactionRepository {
  TransactionRepository(this.db);

  final AppDatabase db;

  /// Verilen aya ait işlemler; en yeni tarih (ve giriş) en üstte.
  Stream<List<Transaction>> watchForMonth(DateTime month) {
    return (db.select(db.transactions)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(_monthStart(month)) &
              t.date.isSmallerThanValue(_nextMonthStart(month)))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Belirli bir tarih aralığındaki işlemler (canlı) — trend grafiği için.
  Stream<List<Transaction>> watchRange(
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    return (db.select(db.transactions)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(startInclusive) &
              t.date.isSmallerThanValue(endExclusive)))
        .watch();
  }

  /// Verilen ayın gelir/gider toplamları.
  Future<MonthSummary> monthSummary(DateTime month) async {
    final txns = await (db.select(db.transactions)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(_monthStart(month)) &
              t.date.isSmallerThanValue(_nextMonthStart(month))))
        .get();

    var income = 0;
    var expense = 0;
    for (final t in txns) {
      if (t.type == TransactionType.income) {
        income += t.amountMinor;
      } else {
        expense += t.amountMinor;
      }
    }
    return MonthSummary(incomeMinor: income, expenseMinor: expense);
  }

  /// Esnek arama/filtre. [textCategoryIds]: metne göre eşleşen kategori
  /// id'leri (çağıran, kategori adlarını arayıp geçer). En yeni tarih üstte.
  Future<List<Transaction>> search({
    String? text,
    TransactionType? type,
    String? categoryId,
    DateTime? from,
    DateTime? toExclusive,
    int? minMinor,
    int? maxMinor,
    List<String> textCategoryIds = const [],
  }) {
    final t = db.transactions;
    final conds = <Expression<bool>>[];
    if (type != null) conds.add(t.type.equalsValue(type));
    if (categoryId != null) conds.add(t.categoryId.equals(categoryId));
    if (from != null) conds.add(t.date.isBiggerOrEqualValue(from));
    if (toExclusive != null) conds.add(t.date.isSmallerThanValue(toExclusive));
    if (minMinor != null) conds.add(t.amountMinor.isBiggerOrEqualValue(minMinor));
    if (maxMinor != null) conds.add(t.amountMinor.isSmallerOrEqualValue(maxMinor));
    if (text != null && text.isNotEmpty) {
      var textCond = t.note.like('%$text%');
      if (textCategoryIds.isNotEmpty) {
        textCond = textCond | t.categoryId.isIn(textCategoryIds);
      }
      conds.add(textCond);
    }

    final query = db.select(db.transactions);
    if (conds.isNotEmpty) {
      query.where((_) => conds.reduce((a, b) => a & b));
    }
    query.orderBy(
      [(tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.desc)],
    );
    return query.get();
  }

  Future<int> add({
    required TransactionType type,
    required int amountMinor,
    required String categoryId,
    required DateTime date,
    String? note,
  }) {
    return db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            type: type,
            amountMinor: amountMinor,
            categoryId: categoryId,
            date: date,
            note: Value(note),
          ),
        );
  }

  Future<void> edit(
    int id, {
    TransactionType? type,
    int? amountMinor,
    String? categoryId,
    DateTime? date,
    Value<String?> note = const Value.absent(),
  }) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        type: type == null ? const Value.absent() : Value(type),
        amountMinor:
            amountMinor == null ? const Value.absent() : Value(amountMinor),
        categoryId:
            categoryId == null ? const Value.absent() : Value(categoryId),
        date: date == null ? const Value.absent() : Value(date),
        note: note,
      ),
    );
  }

  Future<void> delete(int id) async {
    await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
  }
}

/// Tekrarlayan şablon okuma/yazma + yaklaşan önizleme.
class RecurringRepository {
  RecurringRepository(this.db);

  final AppDatabase db;

  Stream<List<RecurringTemplate>> watchAll() {
    return (db.select(db.recurringTemplates)
          ..orderBy([
            (r) =>
                OrderingTerm(expression: r.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<int> add(RecurringTemplatesCompanion entry) {
    return db.into(db.recurringTemplates).insert(entry);
  }

  /// Tutar/gün gibi alanlar güncellenir; geçmiş üretilmiş işlemlere DOKUNULMAZ
  /// (zam sonrası yalnızca bundan sonrası yeni tutardan işler).
  Future<void> update(int id, RecurringTemplatesCompanion changes) async {
    await (db.update(db.recurringTemplates)..where((r) => r.id.equals(id)))
        .write(changes);
  }

  Future<void> setActive(int id, bool active) async {
    await (db.update(db.recurringTemplates)..where((r) => r.id.equals(id)))
        .write(RecurringTemplatesCompanion(active: Value(active)));
  }

  Future<void> delete(int id) async {
    await (db.delete(db.recurringTemplates)..where((r) => r.id.equals(id)))
        .go();
  }

  /// [now] ile [horizon] arasında vadesi gelecek tekrarları, tarih sırasına
  /// göre döndürür ("önümüzdeki hafta 15.000 TL kira" kartı için).
  Future<List<UpcomingRecurring>> upcoming({
    required DateTime now,
    required DateTime horizon,
  }) async {
    final templates = await (db.select(db.recurringTemplates)
          ..where((t) => t.active.equals(true)))
        .get();

    final result = <UpcomingRecurring>[];
    for (final t in templates) {
      DateTime? next;
      try {
        next = nextOccurrence(RecurringService.scheduleOf(t), after: now);
      } catch (_) {
        continue;
      }
      if (next != null && !next.isAfter(horizon)) {
        result.add(UpcomingRecurring(t, next));
      }
    }
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }
}

/// Hızlı işlem şablonları (tek dokunuşla ekleme).
class QuickTemplateRepository {
  QuickTemplateRepository(this.db);

  final AppDatabase db;

  Stream<List<QuickTemplate>> watchAll() {
    return (db.select(db.quickTemplates)
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }

  Future<int> add({
    required TransactionType type,
    required int amountMinor,
    required String categoryId,
    String? label,
  }) {
    return db.into(db.quickTemplates).insert(
          QuickTemplatesCompanion.insert(
            type: type,
            amountMinor: amountMinor,
            categoryId: categoryId,
            label: Value(label),
          ),
        );
  }

  Future<void> delete(int id) async {
    await (db.delete(db.quickTemplates)..where((t) => t.id.equals(id))).go();
  }
}

/// Basit anahtar-değer uygulama ayarları (tema, ileride dil vb.).
class SettingsRepository {
  SettingsRepository(this.db);

  final AppDatabase db;

  Stream<String?> watchValue(String key) {
    return (db.select(db.appSettings)..where((s) => s.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  Future<void> setValue(String key, String value) async {
    await db.into(db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }
}
