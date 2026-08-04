import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/enums.dart';
import '../recurring/recurring_engine.dart' show RecurringFrequency;
import 'default_categories.dart';

part 'database.g.dart';

/// Gider/gelir kategorileri. Kullanıcı ekleyip düzenleyebilir; bu yüzden ayrı
/// tablo (sadece string slug değil).
class Categories extends Table {
  /// Slug ('market') ya da özel kategoriler için üretilmiş kimlik.
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => textEnum<TransactionType>()();

  /// Material ikonunun kod noktası (bkz. [DefaultCategory]).
  IntColumn get iconCodePoint => integer()();

  /// Renk, ARGB tam sayısı olarak (0xAARRGGBB).
  IntColumn get colorValue => integer()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Silmek yerine arşivle: geçmiş işlemler kategoriye bağlı kalır.
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// İlk kurulumla gelen varsayılan kategori mi?
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// Aylık gider bütçesi (kuruş). null → bütçe yok. (Yalnızca gider kategorileri.)
  IntColumn get budgetMinor => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tekrarlayan işlem şablonları (kira, maaş, abonelik...).
///
/// Zamanlama alanları [frequency]'e göre doldurulur — mantık için
/// `recurring_engine.dart`'a bak. [lastGeneratedDate] idempotent üretimin
/// anahtarıdır: bu tarihten sonrası üretilir, öncesi tekrar üretilmez.
class RecurringTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<TransactionType>()();

  /// Tutar, en küçük para biriminde (kuruş) — asla ondalık/float değil.
  IntColumn get amountMinor => integer()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get note => text().nullable()();

  TextColumn get frequency => textEnum<RecurringFrequency>()();
  IntColumn get dayOfMonth => integer().nullable()(); // aylık & yıllık
  IntColumn get weekday => integer().nullable()(); // haftalık (1=Pzt..7=Paz)
  IntColumn get monthOfYear => integer().nullable()(); // yıllık (1..12)

  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// En son üretimin yapıldığı tarih (dahil). null → hiç üretilmedi.
  DateTimeColumn get lastGeneratedDate => dateTime().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Tekil gelir/gider işlemleri.
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<TransactionType>()();

  /// Tutar, en küçük para biriminde (kuruş).
  IntColumn get amountMinor => integer()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get note => text().nullable()();

  /// İşlemin tarihi (gün olarak; saat bileşeni önemsenmez).
  DateTimeColumn get date => dateTime()();

  TextColumn get source =>
      textEnum<TransactionSource>().withDefault(const Constant('manual'))();

  /// Tekrarlayandan üretildiyse şablonun kimliği.
  IntColumn get recurringId =>
      integer().nullable().references(RecurringTemplates, #id)();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Tek dokunuşla eklenen hızlı işlem şablonları ("Kahve 50₺").
class QuickTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Opsiyonel özel ad; yoksa "kategori + tutar" gösterilir.
  TextColumn get label => text().nullable()();
  TextColumn get type => textEnum<TransactionType>()();
  IntColumn get amountMinor => integer()();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Basit anahtar-değer uygulama ayarları (tema, ileride dil vb.).
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  Categories,
  RecurringTemplates,
  Transactions,
  QuickTemplates,
  AppSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'harcama_takip',
              // Web'de veritabanı için web/ içindeki wasm + worker kullanılır.
              // (Mobil/masaüstü bu ayarı yok sayar.)
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaultCategories();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: kategori bütçesi alanı eklendi.
            await m.addColumn(categories, categories.budgetMinor);
          }
          if (from < 3) {
            // v3: hızlı işlem şablonları tablosu eklendi.
            await m.createTable(quickTemplates);
          }
          if (from < 4) {
            // v4: uygulama ayarları (tema vb.) tablosu eklendi.
            await m.createTable(appSettings);
          }
        },
        beforeOpen: (details) async {
          // Foreign key kısıtlarını aç (SQLite'ta varsayılan kapalı).
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// İlk kurulumda varsayılan kategorileri ekler.
  Future<void> _seedDefaultCategories() async {
    await batch((b) {
      for (var i = 0; i < allDefaultCategories.length; i++) {
        final c = allDefaultCategories[i];
        b.insert(
          categories,
          CategoriesCompanion.insert(
            id: c.id,
            name: c.name,
            type: c.type,
            iconCodePoint: c.iconCodePoint,
            colorValue: c.colorValue,
            sortOrder: Value(i),
            isDefault: const Value(true),
          ),
        );
      }
    });
  }
}
