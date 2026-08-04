# Kesem

Kişisel gelir–gider takip uygulaması. **Tamamen çevrimdışı** — verilerin telefonunda
kalır, hesap yok, üyelik yok. Harcamalarını saniyeler içinde gir, kategori
grafikleriyle nereye ne kadar gittiğini gör, ay sonunda "kaç kaldı, kaç kaçtı"
cevabını al.

## Özellikler
- ⚡ Hızlı giriş — büyük tuş takımı + tek dokunuşla hazır şablonlar
- 🔁 Tekrarlayan işlemler — kira, maaş, abonelik bir kez tanımla, her ay otomatik düşsün
- 📊 Grafikler — kategori donutu + aylık gelir/gider trendi + geçen aya kıyas
- 🎯 Bütçe uyarısı — kategoriye aylık limit koy, aşınca uyarılan
- 🔔 Yerel bildirimler — yaklaşan kira, ay sonu özeti
- 🔍 Arama & filtre — kategoriye, tarihe, tutara göre
- 💾 Yedekleme — JSON/CSV dışa/içe aktarma
- 🌙 Koyu tema + tam Türkçe, Türk Lirası

## Teknoloji
Flutter · Drift (SQLite) · flutter_riverpod 3 · fl_chart · intl (tr_TR)

Para modeli `int` (kuruş), asla float. Kategoriler silinmez, **arşivlenir**.
Tekrarlayan üretimi **idempotent** (`lastGeneratedDate` ile) — uygulama aylarca
açılmasa bile kaçan ayları toparlar, kullanıcının sildiğini geri getirmez.

## Geliştirme
```bash
flutter pub get
dart run build_runner build   # Drift kod üretimi (şema değişince şart)
flutter test                  # motor + repository testleri
flutter analyze               # statik analiz
flutter run -d chrome         # web'de hızlı önizleme
```

> Release derlemede ikonlar dinamik `IconData` ile çizildiği için
> `--no-tree-shake-icons` şart:
> `flutter build apk --release --no-tree-shake-icons`

Mimari ve tasarım kararlarının ayrıntısı için [CLAUDE.md](CLAUDE.md).

## Lisans
Tüm hakları saklıdır. © 2026 UregenStudios
