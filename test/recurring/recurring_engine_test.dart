import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip_app/recurring/recurring_engine.dart';

/// Testleri okumayı kolaylaştıran kısa tarih yardımcısı.
DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  group('dueOccurrences — aylık', () {
    test('ilk kez çalıştırma geçmişteki tüm ayları toparlar', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 1,
        startDate: d(2026, 1, 1),
      );
      final result = dueOccurrences(s, asOf: d(2026, 3, 15));
      expect(result, [d(2026, 1, 1), d(2026, 2, 1), d(2026, 3, 1)]);
    });

    test('lastGenerated sonrası SADECE yeni ayları üretir (idempotent)', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 1,
        startDate: d(2026, 1, 1),
      );
      final result = dueOccurrences(
        s,
        asOf: d(2026, 3, 15),
        lastGenerated: d(2026, 2, 1),
      );
      expect(result, [d(2026, 3, 1)]);
    });

    test('lastGenerated tam bir tekrar tarihine eşitse onu tekrar üretmez', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 10,
        startDate: d(2026, 1, 1),
      );
      final result = dueOccurrences(
        s,
        asOf: d(2026, 3, 10),
        lastGenerated: d(2026, 3, 10),
      );
      expect(result, isEmpty);
    });

    test("ayın 31'i → Şubat/Nisan ay sonuna kırpılır", () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 31,
        startDate: d(2026, 1, 1),
      );
      final result = dueOccurrences(s, asOf: d(2026, 4, 30));
      expect(result, [
        d(2026, 1, 31),
        d(2026, 2, 28), // 2026 artık yıl değil
        d(2026, 3, 31),
        d(2026, 4, 30),
      ]);
    });

    test('artık yılda Şubat 29 doğru hesaplanır', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 31,
        startDate: d(2028, 1, 1),
      );
      final result = dueOccurrences(s, asOf: d(2028, 3, 31));
      // 31'i olan şablon: Şubat 29'a (artık yıl), Mart 31'e çözülür.
      expect(result, [d(2028, 1, 31), d(2028, 2, 29), d(2028, 3, 31)]);
    });

    test('başlangıç ay ortasında, o ayın günü geçmişse ilk üretim gelecek ay', () {
      // Ayın 1'i, ama başlangıç 15 Ocak → Ocak 1 üretilmez.
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 1,
        startDate: d(2026, 1, 15),
      );
      final result = dueOccurrences(s, asOf: d(2026, 3, 5));
      expect(result, [d(2026, 2, 1), d(2026, 3, 1)]);
    });

    test('başlangıç günü tam tekrar gününe denk gelirse o ay da üretilir', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 15,
        startDate: d(2026, 1, 15),
      );
      final result = dueOccurrences(s, asOf: d(2026, 2, 1));
      expect(result, [d(2026, 1, 15)]);
    });

    test('kırpma her ay orijinal günden hesaplanır (28e sabitlenmez)', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 30,
        startDate: d(2026, 1, 1),
      );
      final result = dueOccurrences(s, asOf: d(2026, 3, 31));
      // Şubat 28'e kırpılır ama Mart yine 30 olmalı.
      expect(result, [d(2026, 1, 30), d(2026, 2, 28), d(2026, 3, 30)]);
    });
  });

  group('dueOccurrences — haftalık', () {
    test('başlangıçtan sonraki ilk hedef günden itibaren üretir', () {
      // 1 Temmuz 2026 = Çarşamba. Hedef Pazartesi (1).
      final s = RecurringSchedule(
        frequency: RecurringFrequency.weekly,
        weekday: DateTime.monday,
        startDate: d(2026, 7, 1),
      );
      final result = dueOccurrences(s, asOf: d(2026, 7, 20));
      expect(result, [d(2026, 7, 6), d(2026, 7, 13), d(2026, 7, 20)]);
    });

    test('başlangıç tam hedef güne denk gelirse o günü de içerir', () {
      // 6 Temmuz 2026 = Pazartesi.
      final s = RecurringSchedule(
        frequency: RecurringFrequency.weekly,
        weekday: DateTime.monday,
        startDate: d(2026, 7, 6),
      );
      final result = dueOccurrences(s, asOf: d(2026, 7, 13));
      expect(result, [d(2026, 7, 6), d(2026, 7, 13)]);
    });

    test('lastGenerated ile haftalık idempotentlik', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.weekly,
        weekday: DateTime.monday,
        startDate: d(2026, 7, 1),
      );
      final result = dueOccurrences(
        s,
        asOf: d(2026, 7, 20),
        lastGenerated: d(2026, 7, 6),
      );
      expect(result, [d(2026, 7, 13), d(2026, 7, 20)]);
    });
  });

  group('dueOccurrences — yıllık', () {
    test('her yıl aynı ay/gün üretilir', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.yearly,
        monthOfYear: 3,
        dayOfMonth: 15,
        startDate: d(2026, 1, 1),
      );
      final result = dueOccurrences(s, asOf: d(2029, 6, 1));
      expect(result, [d(2026, 3, 15), d(2027, 3, 15), d(2028, 3, 15), d(2029, 3, 15)]);
    });

    test('29 Şubat yıllık → artık olmayan yıllarda 28e kırpılır', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.yearly,
        monthOfYear: 2,
        dayOfMonth: 29,
        startDate: d(2025, 1, 1),
      );
      final result = dueOccurrences(s, asOf: d(2028, 12, 31));
      expect(result, [
        d(2025, 2, 28),
        d(2026, 2, 28),
        d(2027, 2, 28),
        d(2028, 2, 29), // 2028 artık yıl
      ]);
    });
  });

  group('bitiş tarihi (endDate) ve pasiflik', () {
    test('endDate dahil edilir, sonrası üretilmez', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 1,
        startDate: d(2026, 1, 1),
        endDate: d(2026, 3, 1),
      );
      final result = dueOccurrences(s, asOf: d(2026, 12, 31));
      expect(result, [d(2026, 1, 1), d(2026, 2, 1), d(2026, 3, 1)]);
    });

    test('endDate bir tekrar gününden önceyse o tekrar üretilmez', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 1,
        startDate: d(2026, 1, 1),
        endDate: d(2026, 2, 15),
      );
      final result = dueOccurrences(s, asOf: d(2026, 12, 31));
      expect(result, [d(2026, 1, 1), d(2026, 2, 1)]);
    });

    test('pasif şablon hiçbir şey üretmez', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 1,
        startDate: d(2026, 1, 1),
        active: false,
      );
      expect(dueOccurrences(s, asOf: d(2026, 12, 31)), isEmpty);
    });

    test("başlangıç asOf'tan sonraysa hiçbir şey üretilmez", () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 1,
        startDate: d(2027, 1, 1),
      );
      expect(dueOccurrences(s, asOf: d(2026, 12, 31)), isEmpty);
    });
  });

  group('uzun aralık toparlama', () {
    test('uygulama 6 ay açılmasa bile tüm kaçan ayları üretir', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 5,
        startDate: d(2026, 1, 5),
      );
      final result = dueOccurrences(
        s,
        asOf: d(2026, 7, 26),
        lastGenerated: d(2026, 1, 5),
      );
      expect(result, [
        d(2026, 2, 5),
        d(2026, 3, 5),
        d(2026, 4, 5),
        d(2026, 5, 5),
        d(2026, 6, 5),
        d(2026, 7, 5),
      ]);
    });
  });

  group('nextOccurrence — yaklaşan önizleme', () {
    test('verilen tarihten sonraki ilk tekrarı döndürür', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 1,
        startDate: d(2026, 1, 1),
      );
      expect(nextOccurrence(s, after: d(2026, 7, 26)), d(2026, 8, 1));
    });

    test('endDate aşıldıysa null döner', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 1,
        startDate: d(2026, 1, 1),
        endDate: d(2026, 7, 1),
      );
      expect(nextOccurrence(s, after: d(2026, 7, 26)), isNull);
    });

    test('pasif şablonda null döner', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 1,
        startDate: d(2026, 1, 1),
        active: false,
      );
      expect(nextOccurrence(s, after: d(2026, 7, 26)), isNull);
    });
  });

  group('doğrulama', () {
    test('haftalıkta weekday eksikse hata', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.weekly,
        startDate: d(2026, 1, 1),
      );
      expect(() => dueOccurrences(s, asOf: d(2026, 2, 1)), throwsArgumentError);
    });

    test('aylıkta dayOfMonth eksikse hata', () {
      final s = RecurringSchedule(
        frequency: RecurringFrequency.monthly,
        startDate: d(2026, 1, 1),
      );
      expect(() => dueOccurrences(s, asOf: d(2026, 2, 1)), throwsArgumentError);
    });
  });
}
