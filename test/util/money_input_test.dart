import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip_app/util/money_input.dart';

/// Formatter'ı verilen girdi üzerinde çalıştırıp sonucu döndürür.
String fmt(String input) {
  return const MoneyInputFormatter()
      .formatEditUpdate(
        const TextEditingValue(text: ''),
        TextEditingValue(
          text: input,
          selection: TextSelection.collapsed(offset: input.length),
        ),
      )
      .text;
}

void main() {
  group('parseMoneyToMinor', () {
    test('normal değerler kuruşa çevrilir', () {
      expect(parseMoneyToMinor('1,50'), 150);
      expect(parseMoneyToMinor('1500'), 150000);
      expect(parseMoneyToMinor('1500,50'), 150050);
    });

    test('boş/geçersiz → 0', () {
      expect(parseMoneyToMinor(''), 0);
      expect(parseMoneyToMinor('   '), 0);
      expect(parseMoneyToMinor('abc'), 0);
      expect(parseMoneyToMinor('1..2'), 0);
    });

    test('aşırı büyük değer üst sınıra kırpılır (taşma güvenliği)', () {
      expect(parseMoneyToMinor('999999999999'), 100000000000);
    });
  });

  group('MoneyInputFormatter — bozuk girdi imkânsız', () {
    test('nokta, boşluk, harf, fazla virgül temizlenir', () {
      expect(fmt('1.,23323'), '1,23'); // ekran görüntüsündeki hata
      expect(fmt('1 1'), '11');
      expect(fmt('abc12,999'), '12,99');
      expect(fmt('1,2,3'), '1,23');
      expect(fmt('12,5'), '12,5');
    });
  });
}
