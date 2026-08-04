import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/backup_service.dart';
import 'data/database.dart';
import 'data/notification_service.dart';
import 'data/recurring_service.dart';
import 'data/repositories.dart';
import 'domain/enums.dart';

/// Tek veritabanı örneği (uygulama boyunca yaşar).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final transactionRepoProvider = Provider<TransactionRepository>(
    (ref) => TransactionRepository(ref.watch(databaseProvider)));
final categoryRepoProvider = Provider<CategoryRepository>(
    (ref) => CategoryRepository(ref.watch(databaseProvider)));
final recurringRepoProvider = Provider<RecurringRepository>(
    (ref) => RecurringRepository(ref.watch(databaseProvider)));
final recurringServiceProvider = Provider<RecurringService>(
    (ref) => RecurringService(ref.watch(databaseProvider)));
final quickTemplateRepoProvider = Provider<QuickTemplateRepository>(
    (ref) => QuickTemplateRepository(ref.watch(databaseProvider)));
final backupServiceProvider = Provider<BackupService>(
    (ref) => BackupService(ref.watch(databaseProvider)));
final settingsRepoProvider = Provider<SettingsRepository>(
    (ref) => SettingsRepository(ref.watch(databaseProvider)));

/// Kullanıcının seçtiği tema modu (canlı; kaydedilir).
final themeModeProvider = StreamProvider<ThemeMode>((ref) {
  return ref.watch(settingsRepoProvider).watchValue('themeMode').map((v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  });
});
final notificationServiceProvider = Provider<NotificationService>(
    (ref) => NotificationService(ref.watch(databaseProvider)));

/// Uygulama açılışında vadesi gelmiş tekrarlayanları üretir, sonra bildirimleri
/// yeniden planlar (web'de atlanır). Dönen: üretilen işlem sayısı.
final appInitProvider = FutureProvider<int>((ref) async {
  final produced = await ref.read(recurringServiceProvider).materializeDue();
  if (!kIsWeb) {
    try {
      final notif = ref.read(notificationServiceProvider);
      await notif.init();
      await notif.requestPermission();
      await notif.rescheduleAll();
    } catch (_) {
      // Bildirim kurulumu başarısız olsa da uygulama açılmaya devam etsin.
    }
  }
  return produced;
});

/// Ana ekranda seçili ay (ayın 1'i olarak normalize).
class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  void next() => state = DateTime(state.year, state.month + 1, 1);
  void previous() => state = DateTime(state.year, state.month - 1, 1);
}

final selectedMonthProvider =
    NotifierProvider<SelectedMonth, DateTime>(SelectedMonth.new);

/// Seçili ayın işlemleri (canlı).
final monthTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(transactionRepoProvider).watchForMonth(month);
});

/// Seçili ayın özeti — işlemlerden türetilir, işlem değişince otomatik güncellenir.
final monthSummaryProvider = Provider.autoDispose<MonthSummary>((ref) {
  final txns = ref.watch(monthTransactionsProvider).value ?? const [];
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
});

/// Tüm kategoriler (id → kategori haritası, liste ekranında ikon/renk için).
final allCategoriesProvider = StreamProvider<List<Category>>(
    (ref) => ref.watch(categoryRepoProvider).watchAll());

final categoryMapProvider = Provider<Map<String, Category>>((ref) {
  final list = ref.watch(allCategoriesProvider).value ?? const [];
  return {for (final c in list) c.id: c};
});

/// Belirli tipteki (gelir/gider) seçilebilir kategoriler.
final categoriesByTypeProvider =
    StreamProvider.family<List<Category>, TransactionType>(
        (ref, type) => ref.watch(categoryRepoProvider).watchByType(type));

/// Her kategorinin kaç kez kullanıldığı (id → işlem sayısı) — sıralama için.
final categoryUsageProvider = StreamProvider<Map<String, int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.transactions).watch().map((txns) {
    final counts = <String, int>{};
    for (final t in txns) {
      counts[t.categoryId] = (counts[t.categoryId] ?? 0) + 1;
    }
    return counts;
  });
});

/// Kategoriler; en çok kullanılan en üstte (hızlı giriş için), sonra sıraya göre.
final orderedCategoriesByTypeProvider =
    Provider.family<AsyncValue<List<Category>>, TransactionType>((ref, type) {
  final catsAsync = ref.watch(categoriesByTypeProvider(type));
  final usage = ref.watch(categoryUsageProvider).value ?? const <String, int>{};
  return catsAsync.whenData((cats) {
    final sorted = [...cats]..sort((a, b) {
        final ua = usage[a.id] ?? 0;
        final ub = usage[b.id] ?? 0;
        if (ua != ub) return ub.compareTo(ua); // çok kullanılan önce
        return a.sortOrder.compareTo(b.sortOrder);
      });
    return sorted;
  });
});

/// Tüm tekrarlayan şablonlar (canlı) — Tekrarlayanlar ekranı için.
final recurringTemplatesProvider = StreamProvider<List<RecurringTemplate>>(
    (ref) => ref.watch(recurringRepoProvider).watchAll());

/// Hızlı işlem şablonları (canlı) — ana ekran çipleri için.
final quickTemplatesProvider = StreamProvider<List<QuickTemplate>>(
    (ref) => ref.watch(quickTemplateRepoProvider).watchAll());

/// Bir kategorinin seçili aydaki bütçe durumu.
class CategoryBudget {
  const CategoryBudget({
    required this.category,
    required this.budgetMinor,
    required this.spentMinor,
  });

  final Category category;
  final int budgetMinor;
  final int spentMinor;

  double get ratio => budgetMinor == 0 ? 0 : spentMinor / budgetMinor;
  bool get over => spentMinor > budgetMinor;
  int get remainingMinor => budgetMinor - spentMinor;
}

/// Bütçesi tanımlı gider kategorilerinin, seçili aydaki durumu (en dolu üstte).
final categoryBudgetsProvider =
    Provider.autoDispose<List<CategoryBudget>>((ref) {
  final cats = ref.watch(allCategoriesProvider).value ?? const [];
  final txns = ref.watch(monthTransactionsProvider).value ?? const [];

  final spent = <String, int>{};
  for (final t in txns) {
    if (t.type == TransactionType.expense) {
      spent[t.categoryId] = (spent[t.categoryId] ?? 0) + t.amountMinor;
    }
  }

  final result = <CategoryBudget>[];
  for (final c in cats) {
    final b = c.budgetMinor;
    if (c.type == TransactionType.expense &&
        !c.isArchived &&
        b != null &&
        b > 0) {
      result.add(CategoryBudget(
        category: c,
        budgetMinor: b,
        spentMinor: spent[c.id] ?? 0,
      ));
    }
  }
  result.sort((a, b) => b.ratio.compareTo(a.ratio));
  return result;
});

/// Donut grafik için: seçili ayın bir kategorideki gider toplamı ve payı.
class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.category,
    required this.totalMinor,
    required this.fraction,
  });

  final String categoryId;
  final Category? category;
  final int totalMinor;
  final double fraction; // 0..1
}

/// Seçili ayın giderlerini kategoriye göre toplar, büyükten küçüğe sıralar.
final expenseByCategoryProvider =
    Provider.autoDispose<List<CategorySlice>>((ref) {
  final txns = ref.watch(monthTransactionsProvider).value ?? const [];
  final catMap = ref.watch(categoryMapProvider);

  final totals = <String, int>{};
  for (final t in txns) {
    if (t.type == TransactionType.expense) {
      totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amountMinor;
    }
  }
  final grand = totals.values.fold<int>(0, (a, b) => a + b);

  final slices = totals.entries
      .map((e) => CategorySlice(
            categoryId: e.key,
            category: catMap[e.key],
            totalMinor: e.value,
            fraction: grand == 0 ? 0 : e.value / grand,
          ))
      .toList()
    ..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
  return slices;
});

/// Aylık trend grafiğinde tek bir ayın noktası.
class MonthPoint {
  const MonthPoint({
    required this.month,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final DateTime month;
  final int incomeMinor;
  final int expenseMinor;
}

/// Seçili ay dahil son 6 ayın gelir/gider trendi (canlı).
final trendProvider = StreamProvider.autoDispose<List<MonthPoint>>((ref) {
  final selected = ref.watch(selectedMonthProvider);
  final start = DateTime(selected.year, selected.month - 5, 1);
  final end = DateTime(selected.year, selected.month + 1, 1);

  return ref.watch(transactionRepoProvider).watchRange(start, end).map((txns) {
    // 6 aylık boş iskeleti oluştur.
    final months = List.generate(
      6,
      (i) => DateTime(selected.year, selected.month - 5 + i, 1),
    );
    final income = {for (final m in months) _key(m): 0};
    final expense = {for (final m in months) _key(m): 0};

    for (final t in txns) {
      final k = _key(DateTime(t.date.year, t.date.month, 1));
      if (t.type == TransactionType.income) {
        income[k] = (income[k] ?? 0) + t.amountMinor;
      } else {
        expense[k] = (expense[k] ?? 0) + t.amountMinor;
      }
    }

    return months
        .map((m) => MonthPoint(
              month: m,
              incomeMinor: income[_key(m)] ?? 0,
              expenseMinor: expense[_key(m)] ?? 0,
            ))
        .toList();
  });
});

String _key(DateTime m) => '${m.year}-${m.month}';

/// Tek bir kategorinin bir aydaki toplamı (kategori detay trendi için).
class CategoryMonthTotal {
  const CategoryMonthTotal({required this.month, required this.totalMinor});
  final DateTime month;
  final int totalMinor;
}

/// Verilen kategorinin, seçili ay dahil son 6 aylık toplam trendi (canlı).
final categoryTrendProvider =
    StreamProvider.autoDispose.family<List<CategoryMonthTotal>, String>(
        (ref, categoryId) {
  final selected = ref.watch(selectedMonthProvider);
  final start = DateTime(selected.year, selected.month - 5, 1);
  final end = DateTime(selected.year, selected.month + 1, 1);

  return ref.watch(transactionRepoProvider).watchRange(start, end).map((txns) {
    final months = List.generate(
      6,
      (i) => DateTime(selected.year, selected.month - 5 + i, 1),
    );
    final totals = {for (final m in months) _key(m): 0};
    for (final t in txns) {
      if (t.categoryId != categoryId) continue;
      final k = _key(DateTime(t.date.year, t.date.month, 1));
      totals[k] = (totals[k] ?? 0) + t.amountMinor;
    }
    return months
        .map((m) =>
            CategoryMonthTotal(month: m, totalMinor: totals[_key(m)] ?? 0))
        .toList();
  });
});

/// Seçili ayda verilen kategoriye ait işlemler (detay ekranının listesi).
final categoryMonthTransactionsProvider =
    Provider.autoDispose.family<List<Transaction>, String>((ref, categoryId) {
  final txns = ref.watch(monthTransactionsProvider).value ?? const [];
  return txns.where((t) => t.categoryId == categoryId).toList();
});
