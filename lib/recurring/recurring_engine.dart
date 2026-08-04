/// Tekrarlayan işlem motoru — saf Dart, hiçbir dış bağımlılığı yoktur.
///
/// Amaç: Bir tekrarlayan şablonun (kira, maaş, abonelik...) hangi tarihlerde
/// işlem üretmesi gerektiğini hesaplamak. Kritik davranışlar:
///   * Kaçan ayları toparlama (uygulama 3 ay açılmasa bile hepsini üretir).
///   * Idempotentlik: `lastGenerated`'dan SONRAKİ tarihleri üretir; iki kez
///     çalışsa bile aynı işlemi tekrar üretmez.
///   * Ay sonu kırpması: "her ayın 31'i" → Şubat'ta 28/29, Nisan'da 30.
///   * Bitiş tarihi (endDate) ve pasif (active) şablonlara saygı.
///
/// Motor bilerek yalnızca TARİH mantığıyla ilgilenir; tutar/kategori/tip gibi
/// alanları çağıran katman ekler. Böylece test etmesi çok kolay.
library;

/// İşlemin ne sıklıkta tekrarlandığı.
enum RecurringFrequency { weekly, monthly, yearly }

/// Bir tekrarlayan şablonun yalnızca ZAMANLAMA bilgisi.
///
/// Alanların hangisinin dolu olması gerektiği [frequency]'e bağlıdır:
///   * weekly  → [weekday] (1=Pazartesi ... 7=Pazar) zorunlu.
///   * monthly → [dayOfMonth] (1..31) zorunlu.
///   * yearly  → [monthOfYear] (1..12) ve [dayOfMonth] (1..31) zorunlu.
class RecurringSchedule {
  const RecurringSchedule({
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.active = true,
    this.dayOfMonth,
    this.weekday,
    this.monthOfYear,
  });

  final RecurringFrequency frequency;

  /// İlk üretimin başlayabileceği en erken tarih (dahil).
  final DateTime startDate;

  /// Şablonun bittiği son tarih (dahil). null → süresiz.
  final DateTime? endDate;

  /// false ise hiç üretim yapılmaz.
  final bool active;

  /// Aylık ve yıllık için ayın günü (1..31). 31 gibi taşan değerler o ayın
  /// son gününe kırpılır.
  final int? dayOfMonth;

  /// Haftalık için haftanın günü. [DateTime.weekday] ile aynı: 1=Pzt ... 7=Paz.
  final int? weekday;

  /// Yıllık için yılın ayı (1..12).
  final int? monthOfYear;
}

/// Yalnızca tarih kısmını (yerel gün) döndürür, saat/dakikayı sıfırlar.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Verilen yıl/ayın kaç gün çektiği (bir sonraki ayın "0"ıncı günü = bu ayın
/// son günü). Şubat ve artık yıllar dahil doğru sonuç verir.
int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// (year, month) ayındaki aylık tekrarın gerçek tarihi — [dayOfMonth] o ayın
/// gün sayısına kırpılarak.
DateTime _monthlyDate(int year, int month, int dayOfMonth) {
  final day = dayOfMonth.clamp(1, _daysInMonth(year, month));
  return DateTime(year, month, day);
}

/// (year) yılındaki yıllık tekrarın gerçek tarihi — gün kırpması ile.
DateTime _yearlyDate(int year, int monthOfYear, int dayOfMonth) {
  final day = dayOfMonth.clamp(1, _daysInMonth(year, monthOfYear));
  return DateTime(year, monthOfYear, day);
}

/// [startDate]'ten itibaren (dahil) ilk tekrar tarihini bulur.
DateTime _firstOccurrence(RecurringSchedule s) {
  final start = _dateOnly(s.startDate);
  switch (s.frequency) {
    case RecurringFrequency.weekly:
      final weekday = s.weekday!;
      final diff = (weekday - start.weekday + 7) % 7; // 0..6 gün ileri
      return DateTime(start.year, start.month, start.day + diff);
    case RecurringFrequency.monthly:
      final dom = s.dayOfMonth!;
      var occ = _monthlyDate(start.year, start.month, dom);
      if (occ.isBefore(start)) {
        // Bu ayın günü zaten geçti → gelecek ay.
        occ = _monthlyDate(start.year, start.month + 1, dom);
      }
      return occ;
    case RecurringFrequency.yearly:
      final moy = s.monthOfYear!;
      final dom = s.dayOfMonth!;
      var occ = _yearlyDate(start.year, moy, dom);
      if (occ.isBefore(start)) {
        occ = _yearlyDate(start.year + 1, moy, dom);
      }
      return occ;
  }
}

/// Verilen tekrar tarihinden bir SONRAKİ tekrar tarihi. Kırpma her zaman
/// orijinal [dayOfMonth]'tan yeniden hesaplanır (kırpılmış günden değil).
DateTime _nextOccurrence(RecurringSchedule s, DateTime occ) {
  switch (s.frequency) {
    case RecurringFrequency.weekly:
      // Duration yerine takvim aritmetiği → yaz saati geçişlerinde kaymaz.
      return DateTime(occ.year, occ.month, occ.day + 7);
    case RecurringFrequency.monthly:
      return _monthlyDate(occ.year, occ.month + 1, s.dayOfMonth!);
    case RecurringFrequency.yearly:
      return _yearlyDate(occ.year + 1, s.monthOfYear!, s.dayOfMonth!);
  }
}

/// [s] için zorunlu alanların dolu olduğunu doğrular; değilse [ArgumentError].
void _validate(RecurringSchedule s) {
  switch (s.frequency) {
    case RecurringFrequency.weekly:
      if (s.weekday == null || s.weekday! < 1 || s.weekday! > 7) {
        throw ArgumentError('weekly için weekday 1..7 olmalı: ${s.weekday}');
      }
    case RecurringFrequency.monthly:
      if (s.dayOfMonth == null || s.dayOfMonth! < 1 || s.dayOfMonth! > 31) {
        throw ArgumentError('monthly için dayOfMonth 1..31 olmalı: ${s.dayOfMonth}');
      }
    case RecurringFrequency.yearly:
      if (s.monthOfYear == null || s.monthOfYear! < 1 || s.monthOfYear! > 12) {
        throw ArgumentError('yearly için monthOfYear 1..12 olmalı: ${s.monthOfYear}');
      }
      if (s.dayOfMonth == null || s.dayOfMonth! < 1 || s.dayOfMonth! > 31) {
        throw ArgumentError('yearly için dayOfMonth 1..31 olmalı: ${s.dayOfMonth}');
      }
  }
}

/// Sonsuz döngüye karşı güvenlik sınırı (tek şablon için makul üst sınır).
const int _maxIterations = 20000;

/// [s] şablonu için üretilmesi gereken işlem tarihlerini döndürür.
///
/// Kural: `lastGenerated`'dan KESİN SONRA (o tarih hariç) ve [asOf]'a KADAR
/// (dahil) olan tüm tekrar tarihleri. `lastGenerated` null ise [startDate]'ten
/// itibaren tüm geçmiş (kaçan) tarihler üretilir.
///
/// Dönen liste tarih sırasına göre artan; saat bileşeni sıfırlanmıştır.
List<DateTime> dueOccurrences(
  RecurringSchedule s, {
  required DateTime asOf,
  DateTime? lastGenerated,
}) {
  if (!s.active) return const [];
  _validate(s);

  final asOfDate = _dateOnly(asOf);
  // Üst sınır: asOf ile endDate'in küçüğü.
  var upper = asOfDate;
  if (s.endDate != null) {
    final end = _dateOnly(s.endDate!);
    if (end.isBefore(upper)) upper = end;
  }

  final lower = lastGenerated == null ? null : _dateOnly(lastGenerated);

  final result = <DateTime>[];
  var occ = _firstOccurrence(s);
  var guard = 0;
  while (!occ.isAfter(upper)) {
    final afterLower = lower == null || occ.isAfter(lower);
    if (afterLower) result.add(occ);
    occ = _nextOccurrence(s, occ);
    if (++guard > _maxIterations) break;
  }
  return result;
}

/// [after] tarihinden KESİN SONRAKİ ilk tekrar tarihi (yaklaşan tekrarları
/// "önümüzdeki hafta 15.000 TL kira" gibi önceden göstermek için).
///
/// Pasif şablon veya endDate aşıldıysa null döner.
DateTime? nextOccurrence(RecurringSchedule s, {required DateTime after}) {
  if (!s.active) return null;
  _validate(s);

  final afterDate = _dateOnly(after);
  final end = s.endDate == null ? null : _dateOnly(s.endDate!);

  var occ = _firstOccurrence(s);
  var guard = 0;
  while (!occ.isAfter(afterDate)) {
    occ = _nextOccurrence(s, occ);
    if (++guard > _maxIterations) return null;
  }
  if (end != null && occ.isAfter(end)) return null;
  return occ;
}
