import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip_app/util/format.dart';

void main() {
  group('formatMoney', () {
    test('kuruşu TL biçimine çevirir', () {
      expect(formatMoney(150000), contains('1.500,00'));
      expect(formatMoney(150000), contains('₺'));
      expect(formatMoney(99), contains('0,99'));
    });

    test('işaretli tutar gelir/gider işaretini ekler', () {
      expect(formatSignedMoney(150000, isIncome: true), startsWith('+'));
      expect(formatSignedMoney(150000, isIncome: false), startsWith('-'));
    });
  });
}
