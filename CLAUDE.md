# CLAUDE.md — Harcama Takip App

Kişisel gelir-gider takip uygulaması. **Tamamen offline**, veri telefonda kalır.
Kullanıcı harcama/gelirlerini hızlıca girer, kategori grafikleriyle görür, ay sonu
"kaç kaldı / kaç kaçtı" cevabını alır. Tekrarlayan sabit kalemler (kira, maaş,
abonelik) bir kez tanımlanır, her ay otomatik düşer.

## Teknoloji
- **Flutter** 3.44.8 (stable) — SDK: `C:\src\flutter` (PATH'te)
- **Drift** (SQLite ORM) + `drift_flutter` — yerel veritabanı, kod üretimli
- **flutter_riverpod** 3 — durum yönetimi
- **fl_chart** — donut + bar grafikler
- **intl** — TL ve tarih biçimlendirme (tr_TR)
- Para modeli: ücretsiz + banner reklam (AdMob), premium: reklamsız + bütçe uyarısı + export

## Komutlar
```bash
flutter test                     # tüm testler (motor + repository)
flutter analyze                  # statik analiz (temiz olmalı)
dart run build_runner build      # Drift kod üretimi (şema değişince ŞART)
dart run build_runner watch      # geliştirirken sürekli üretim
flutter run -d chrome            # web'de hızlı önizleme (en kolay)
flutter run -d windows           # Windows masaüstünde (VS C++ bileşeni gerekir)
flutter run                      # bağlı cihaz/emülatörde
```
> **Derleme uyarısı:** İkonlar `codePoint` olarak saklanıp dinamik `IconData` ile
> çizildiği için release derlemede **`--no-tree-shake-icons`** şart:
> `flutter build apk --no-tree-shake-icons`. Yoksa kategori ikonları boş görünür.

## Mimari / klasör yapısı
```
lib/
  domain/enums.dart            # TransactionType, TransactionSource (saf Dart)
  recurring/recurring_engine.dart   # Tekrarlayan TARİH mantığı (saf Dart, testli)
  data/
    database.dart              # Drift tablolar + AppDatabase + seed
    database.g.dart            # ÜRETİLEN — elle düzenleme
    default_categories.dart    # 21 gider + 7 gelir varsayılan kategori (ikon+renk)
    recurring_service.dart     # materializeDue: şablon → gerçek işlem
    repositories.dart          # Category/Transaction/Recurring CRUD + ay özeti
  main.dart                    # (henüz varsayılan sayaç — UI Faz 3'te gelecek)
test/
  recurring/recurring_engine_test.dart   # 23 test
  data/recurring_service_test.dart       # 9 entegrasyon testi
```

**Katman kuralı:** `recurring_engine.dart` ve `enums.dart` hiçbir dış pakete
bağlı DEĞİL (bu yüzden çok hızlı test edilir). DB/servis onları kullanır, UI da
repository'leri kullanır.

## Kritik tasarım kararları (baştan konuldu)
1. **Para = `int` (kuruş)**, asla float. `amountMinor`. Gösterimde 100'e böl.
2. **Kategori ayrı tablo** (slug değil): id, name, type, ikon (codePoint), renk
   (ARGB int), sortOrder, isArchived, isDefault. Silme yok → **arşivleme** (geçmiş
   işlemler bağlı kalsın).
3. **Tekrarlayan üretimi idempotent**: her şablonda `lastGeneratedDate` var.
   Motor `dueOccurrences` bu tarihten SONRASINI üretir → iki kez çalışsa da
   tekrar üretmez, **kullanıcının sildiğini geri getirmez**, uygulama aylarca
   açılmasa bile kaçan ayları toparlar.
4. **Zamanlama alanları**: monthly→`dayOfMonth` (ay sonu kırpması: 31 → Şubat 28/29),
   weekly→`weekday` (1=Pzt..7=Paz), yearly→`monthOfYear`+`dayOfMonth`.

## Veri modeli (Drift tabloları)
- **Categories** (PK: text id/slug)
- **RecurringTemplates** (PK: autoInc int) — `lastGeneratedDate` idempotentliğin anahtarı
- **Transactions** (PK: autoInc int) — `source` (manual/recurring), `recurringId` FK
- Foreign key'ler açık (`PRAGMA foreign_keys = ON`, beforeOpen'da).

## Tekrarlayan akışı (özet)
Uygulama açılışında `RecurringService.materializeDue()` çağrılmalı: aktif her
şablon için motordan vadesi gelmiş tarihleri alır, işlem olarak yazar,
`lastGeneratedDate`'i ilerletir. Tutar değişirse (kira zammı) sadece şablon
güncellenir; geçmiş işlemlere dokunulmaz, bundan sonrası yeni tutardan işler.

## Durum ve yol haritası
- ✅ Faz 2 — Tekrarlayan motoru (23 test)
- ✅ Faz 1 — Drift şeması + varsayılan kategoriler
- ✅ Faz 1b — Repository + servis (9 entegrasyon testi) — **toplam 33/33 yeşil**
- ⬜ Faz 3 — Ana ekran + işlem ekleme UI (Riverpod bağlama)
- ⬜ Faz 4 — Grafikler (donut + aylık trend) + karşılaştırma
- ⬜ Faz 5 — Tekrarlayanlar ekranı
- ⬜ Faz 6 — Ayarlar + JSON/CSV export/import (v1 yedekleme sigortası)
- ⬜ Faz 7 — AdMob, ikon/splash, gizlilik politikası, Play Store

## Bilinen kurulum notları
- **Android cmdline-tools eksik** + SDK lisansları kabul edilmedi. Telefona/APK
  derlemeden önce: Android Studio → SDK Manager → SDK Tools → "Android SDK
  Command-line Tools (latest)" → Apply, sonra `flutter doctor --android-licenses`.
- Visual Studio C++ bileşeni eksik → yalnızca **Windows masaüstü** derlemesi için
  gerekli; mobil için önemsiz.
- Java 24 kurulu; Gradle JDK 17 isterse Android Studio'nun JDK'sına yönlendir.
