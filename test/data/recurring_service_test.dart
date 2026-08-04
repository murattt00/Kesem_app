import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip_app/data/database.dart';
import 'package:harcama_takip_app/data/recurring_service.dart';
import 'package:harcama_takip_app/data/repositories.dart';
import 'package:harcama_takip_app/domain/enums.dart';
import 'package:harcama_takip_app/recurring/recurring_engine.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  late AppDatabase db;
  late RecurringService service;
  late TransactionRepository txns;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = RecurringService(db);
    txns = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Test için standart bir "Kira" tekrarlayanı ekler (aylık, her ayın 1'i).
  Future<int> insertKira({DateTime? start}) {
    return db.into(db.recurringTemplates).insert(
          RecurringTemplatesCompanion.insert(
            type: TransactionType.expense,
            amountMinor: 1500000, // 15.000,00 TL
            categoryId: 'kira',
            frequency: RecurringFrequency.monthly,
            startDate: start ?? d(2026, 1, 1),
            dayOfMonth: const Value(1),
          ),
        );
  }

  test('varsayılan kategoriler ilk açılışta seed edilir', () async {
    final expense = await CategoryRepository(db).getByType(TransactionType.expense);
    final income = await CategoryRepository(db).getByType(TransactionType.income);
    expect(expense.length, 21);
    expect(income.length, 7);
    expect(expense.map((c) => c.id), contains('kira'));
  });

  test('vadesi gelmiş tekrarlar işleme dönüşür ve alanlar doğru', () async {
    final id = await insertKira();
    final produced = await service.materializeDue(asOf: d(2026, 3, 15));
    expect(produced, 3); // Oca 1, Şub 1, Mar 1

    final all = await db.select(db.transactions).get();
    expect(all.length, 3);
    for (final t in all) {
      expect(t.source, TransactionSource.recurring);
      expect(t.recurringId, id);
      expect(t.amountMinor, 1500000);
      expect(t.categoryId, 'kira');
      expect(t.type, TransactionType.expense);
    }
    expect(all.map((t) => t.date).toSet(),
        {d(2026, 1, 1), d(2026, 2, 1), d(2026, 3, 1)});
  });

  test('ikinci kez çalıştırma yeni işlem üretmez (idempotent)', () async {
    await insertKira();
    await service.materializeDue(asOf: d(2026, 3, 15));
    final again = await service.materializeDue(asOf: d(2026, 3, 15));
    expect(again, 0);
    expect((await db.select(db.transactions).get()).length, 3);
  });

  test('zaman ilerleyince sadece yeni ay üretilir', () async {
    await insertKira();
    await service.materializeDue(asOf: d(2026, 3, 15));
    final more = await service.materializeDue(asOf: d(2026, 4, 15));
    expect(more, 1); // Nis 1
    expect((await db.select(db.transactions).get()).length, 4);
  });

  test('lastGeneratedDate son üretilen tarihe ilerler', () async {
    final id = await insertKira();
    await service.materializeDue(asOf: d(2026, 3, 15));
    final tpl = await (db.select(db.recurringTemplates)
          ..where((r) => r.id.equals(id)))
        .getSingle();
    expect(tpl.lastGeneratedDate, d(2026, 3, 1));
  });

  test('üretilen bir işlemi silmek onu geri getirmez', () async {
    await insertKira();
    await service.materializeDue(asOf: d(2026, 3, 15));
    final first = (await db.select(db.transactions).get()).first;
    await txns.delete(first.id);
    expect((await db.select(db.transactions).get()).length, 2);

    // Tekrar çalıştır → silineni geri getirmemeli.
    final again = await service.materializeDue(asOf: d(2026, 3, 15));
    expect(again, 0);
    expect((await db.select(db.transactions).get()).length, 2);
  });

  test('pasif şablon işleme dönüşmez', () async {
    await db.into(db.recurringTemplates).insert(
          RecurringTemplatesCompanion.insert(
            type: TransactionType.expense,
            amountMinor: 5000,
            categoryId: 'abonelikler',
            frequency: RecurringFrequency.monthly,
            startDate: d(2026, 1, 1),
            dayOfMonth: const Value(1),
            active: const Value(false),
          ),
        );
    final produced = await service.materializeDue(asOf: d(2026, 6, 1));
    expect(produced, 0);
  });

  test('ay özeti gelir/gider/kalan doğru hesaplar', () async {
    // Mart ayına: 1 maaş geliri + 1 market gideri
    await txns.add(
      type: TransactionType.income,
      amountMinor: 5000000,
      categoryId: 'maas',
      date: d(2026, 3, 5),
    );
    await txns.add(
      type: TransactionType.expense,
      amountMinor: 120000,
      categoryId: 'market',
      date: d(2026, 3, 10),
    );
    // Nisan işlemi karışmamalı
    await txns.add(
      type: TransactionType.expense,
      amountMinor: 999999,
      categoryId: 'market',
      date: d(2026, 4, 1),
    );

    final s = await txns.monthSummary(d(2026, 3, 1));
    expect(s.incomeMinor, 5000000);
    expect(s.expenseMinor, 120000);
    expect(s.netMinor, 4880000);
  });

  test('yaklaşan tekrarlar önizlemesi', () async {
    await insertKira(); // her ayın 1'i
    final list = await RecurringRepository(db).upcoming(
      now: d(2026, 7, 26),
      horizon: d(2026, 8, 15),
    );
    expect(list.length, 1);
    expect(list.first.date, d(2026, 8, 1));
    expect(list.first.template.categoryId, 'kira');
  });
}
