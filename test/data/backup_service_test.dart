import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip_app/data/backup_service.dart';
import 'package:harcama_takip_app/data/database.dart';
import 'package:harcama_takip_app/data/repositories.dart';
import 'package:harcama_takip_app/domain/enums.dart';
import 'package:harcama_takip_app/recurring/recurring_engine.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  test('export → import: veri birebir korunur (id + FK bütün)', () async {
    final db1 = AppDatabase(NativeDatabase.memory());
    final txns = TransactionRepository(db1);
    final recs = RecurringRepository(db1);

    // Bir tekrarlayan + ona bağlı bir işlem + manuel bir işlem ekle.
    final recId = await recs.add(
      RecurringTemplatesCompanion.insert(
        type: TransactionType.expense,
        amountMinor: 1500000,
        categoryId: 'kira',
        frequency: RecurringFrequency.monthly,
        startDate: d(2026, 1, 1),
        dayOfMonth: const Value(1),
      ),
    );
    await db1.into(db1.transactions).insert(
          TransactionsCompanion.insert(
            type: TransactionType.expense,
            amountMinor: 1500000,
            categoryId: 'kira',
            date: d(2026, 7, 1),
            source: const Value(TransactionSource.recurring),
            recurringId: Value(recId),
          ),
        );
    await txns.add(
      type: TransactionType.expense,
      amountMinor: 12345,
      categoryId: 'market',
      date: d(2026, 7, 10),
      note: 'test',
    );

    final json = await BackupService(db1).exportJson();
    await db1.close();

    // Yepyeni bir veritabanına geri yükle.
    final db2 = AppDatabase(NativeDatabase.memory());
    final summary = await BackupService(db2).importJson(json);

    expect(summary.categories, 28); // 21 gider + 7 gelir
    expect(summary.recurring, 1);
    expect(summary.transactions, 2);

    final recs2 = await db2.select(db2.recurringTemplates).get();
    expect(recs2.single.id, recId, reason: 'tekrarlayan id korunmalı');

    final txns2 = await db2.select(db2.transactions).get();
    final recurringTxn =
        txns2.firstWhere((t) => t.source == TransactionSource.recurring);
    expect(recurringTxn.recurringId, recId, reason: 'FK bağı bozulmamalı');

    final amounts = txns2.map((t) => t.amountMinor).toList()..sort();
    expect(amounts, [12345, 1500000]);

    await db2.close();
  });

  test('geçersiz dosya reddedilir', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(
      () => BackupService(db).importJson('{"app":"baska_uygulama"}'),
      throwsA(isA<FormatException>()),
    );
    await db.close();
  });

  test('CSV başlık ve satırları üretir', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await TransactionRepository(db).add(
      type: TransactionType.expense,
      amountMinor: 12345,
      categoryId: 'market',
      date: d(2026, 7, 10),
      note: 'Migros',
    );
    final csv = await BackupService(db).exportCsv();
    expect(csv, contains('Tarih,Tip,Kategori,Tutar,Not'));
    expect(csv, contains('2026-07-10'));
    expect(csv, contains('123.45'));
    expect(csv, contains('Migros'));
    await db.close();
  });
}
