import 'package:flutter/services.dart';

/// Para girişini güvenli tutan formatter.
///
/// Sadece rakam ve **tek** bir virgül (en çok 2 ondalık) yazılabilir; boşluk,
/// nokta, harf, ikinci virgül veya aşırı uzun sayı **imkânsız**. Her tuş
/// vuruşunda girdiyi temizler, yani bozuk değer hiç oluşamaz.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({this.maxIntegerDigits = 12});

  final int maxIntegerDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Rakam ve virgül dışındaki her şeyi at.
    var t = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');

    final commaIndex = t.indexOf(',');
    if (commaIndex != -1) {
      var intPart = t.substring(0, commaIndex);
      // İlk virgülden sonrasındaki tüm virgülleri sil, en çok 2 ondalık.
      var decPart = t.substring(commaIndex + 1).replaceAll(',', '');
      if (decPart.length > 2) decPart = decPart.substring(0, 2);
      if (intPart.length > maxIntegerDigits) {
        intPart = intPart.substring(0, maxIntegerDigits);
      }
      t = '$intPart,$decPart';
    } else if (t.length > maxIntegerDigits) {
      t = t.substring(0, maxIntegerDigits);
    }

    if (t == newValue.text) return newValue;
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}

/// Doğrulanmış para metnini kuruşa çevirir. Boş/geçersiz → 0.
/// Sonuç 0..1 milyar TL aralığına kırpılır (taşma güvenliği).
int parseMoneyToMinor(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  final v = double.tryParse(trimmed.replaceAll(',', '.')) ?? 0;
  if (v.isNaN || v.isInfinite || v <= 0) return 0;
  final minor = (v * 100).round();
  const cap = 100000000000; // 1 milyar TL
  return minor > cap ? cap : minor;
}

/// Para alanı için hazır formatter listesi.
const List<TextInputFormatter> moneyInputFormatters = [MoneyInputFormatter()];
