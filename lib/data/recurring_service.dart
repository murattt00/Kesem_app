import 'package:drift/drift.dart';

import '../domain/enums.dart';
import '../recurring/recurring_engine.dart';
import 'database.dart';

/// Tekrarlayan şablonları gerçek işlemlere dönüştüren servis.
///
/// Uygulama her açıldığında [materializeDue] çağrılır: son üretimden bu yana
/// vadesi gelmiş tüm tekrarları (kaçan aylar dahil) tek tek işlem olarak
/// yazar ve şablonun [lastGeneratedDate]'ini ilerletir. İki kez çalışsa da
/// aynı işlemi tekrar üretmez (idempotent — bkz. [dueOccurrences]).
class RecurringService {
  RecurringService(this.db);

  final AppDatabase db;

  /// Bir şablon satırını, motorun anlayacağı saf [RecurringSchedule]'a çevirir.
  static RecurringSchedule scheduleOf(RecurringTemplate t) => RecurringSchedule(
        frequency: t.frequency,
        startDate: t.startDate,
        endDate: t.endDate,
        active: t.active,
        dayOfMonth: t.dayOfMonth,
        weekday: t.weekday,
        monthOfYear: t.monthOfYear,
      );

  /// Vadesi gelmiş tüm tekrarlayanları işleme dönüştürür.
  /// [asOf] verilmezse "şimdi" kullanılır (testlerde sabit tarih vermek için).
  /// Dönen değer: üretilen toplam işlem sayısı.
  Future<int> materializeDue({DateTime? asOf}) async {
    final now = asOf ?? DateTime.now();

    final templates = await (db.select(db.recurringTemplates)
          ..where((t) => t.active.equals(true)))
        .get();

    var produced = 0;
    for (final t in templates) {
      List<DateTime> occurrences;
      try {
        occurrences = dueOccurrences(
          scheduleOf(t),
          asOf: now,
          lastGenerated: t.lastGeneratedDate,
        );
      } catch (_) {
        // Bozuk/eksik alanlı şablon uygulamayı kilitlememeli — atla.
        continue;
      }
      if (occurrences.isEmpty) continue;

      await db.transaction(() async {
        for (final date in occurrences) {
          await db.into(db.transactions).insert(
                TransactionsCompanion.insert(
                  type: t.type,
                  amountMinor: t.amountMinor,
                  categoryId: t.categoryId,
                  date: date,
                  note: Value(t.note),
                  source: const Value(TransactionSource.recurring),
                  recurringId: Value(t.id),
                ),
              );
        }
        // En son üretilen tarihe kadar işlendi olarak işaretle.
        await (db.update(db.recurringTemplates)
              ..where((r) => r.id.equals(t.id)))
            .write(
          RecurringTemplatesCompanion(lastGeneratedDate: Value(occurrences.last)),
        );
      });

      produced += occurrences.length;
    }
    return produced;
  }
}
