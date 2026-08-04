import 'package:intl/intl.dart';

/// Kuruş (int) → "1.234,56 ₺" biçimi.
String formatMoney(int minor, {String symbol = '₺'}) {
  final f = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: symbol,
    decimalDigits: 2,
  );
  return f.format(minor / 100.0);
}

/// İşaretli tutar: gelir için "+", gider için "-".
String formatSignedMoney(int minor, {required bool isIncome}) {
  final sign = isIncome ? '+' : '-';
  return '$sign${formatMoney(minor)}';
}

/// "Temmuz 2026"
String formatMonthYear(DateTime m) => DateFormat('MMMM yyyy', 'tr_TR').format(m);

/// "26 Tem"
String formatDayShort(DateTime d) => DateFormat('d MMM', 'tr_TR').format(d);

/// "Tem" (trend ekseni için kısa ay)
String formatMonthAbbr(DateTime d) => DateFormat('MMM', 'tr_TR').format(d);

const _weekdayNames = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

const _monthNames = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

/// 1=Pazartesi .. 7=Pazar
String weekdayName(int weekday) => _weekdayNames[(weekday - 1).clamp(0, 6)];

/// 1=Ocak .. 12=Aralık
String monthName(int month) => _monthNames[(month - 1).clamp(0, 11)];

/// Kompakt TL: 1.500.000 kuruş → "15B", 1.250.000.000 → "12,5Mn". Grafik ekseni için.
String formatCompactMoney(int minor) {
  final v = minor / 100.0;
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(v >= 10000000 ? 0 : 1)}Mn';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}B';
  return v.toStringAsFixed(0);
}

/// "26 Temmuz 2026"
String formatFullDate(DateTime d) =>
    DateFormat('d MMMM yyyy', 'tr_TR').format(d);
