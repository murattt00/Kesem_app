import 'package:flutter/material.dart';

import '../domain/enums.dart';

/// İlk kurulumda veritabanına eklenen varsayılan kategori tanımı.
///
/// Not: İkonlar [IconData.codePoint] olarak saklanır ve çalışma zamanında
/// `IconData(codePoint, fontFamily: 'MaterialIcons')` ile yeniden kurulur.
/// Bu yüzden uygulama `flutter build ... --no-tree-shake-icons` ile derlenmeli
/// (aksi halde dinamik ikonlar boş görünür).
class DefaultCategory {
  const DefaultCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.colorValue,
  });

  final String id;
  final String name;
  final TransactionType type;
  final IconData icon;
  final int colorValue; // ARGB (0xAARRGGBB)

  int get iconCodePoint => icon.codePoint;
}

/// Ürün özetindeki varsayılan gider kategorileri.
final List<DefaultCategory> defaultExpenseCategories = [
  DefaultCategory(id: 'market', name: 'Market', type: TransactionType.expense, icon: Icons.shopping_cart, colorValue: 0xFF66BB6A),
  DefaultCategory(id: 'yeme_icme', name: 'Yeme-İçme', type: TransactionType.expense, icon: Icons.restaurant, colorValue: 0xFFEF5350),
  DefaultCategory(id: 'kira', name: 'Kira', type: TransactionType.expense, icon: Icons.home, colorValue: 0xFF8D6E63),
  DefaultCategory(id: 'faturalar', name: 'Faturalar', type: TransactionType.expense, icon: Icons.receipt_long, colorValue: 0xFFFFA726),
  DefaultCategory(id: 'ulasim', name: 'Ulaşım', type: TransactionType.expense, icon: Icons.directions_bus, colorValue: 0xFF42A5F5),
  DefaultCategory(id: 'saglik', name: 'Sağlık', type: TransactionType.expense, icon: Icons.local_hospital, colorValue: 0xFFEC407A),
  DefaultCategory(id: 'abonelikler', name: 'Abonelikler', type: TransactionType.expense, icon: Icons.subscriptions, colorValue: 0xFFAB47BC),
  DefaultCategory(id: 'giyim', name: 'Giyim', type: TransactionType.expense, icon: Icons.checkroom, colorValue: 0xFF26C6DA),
  DefaultCategory(id: 'kisisel_bakim', name: 'Kişisel Bakım', type: TransactionType.expense, icon: Icons.content_cut, colorValue: 0xFFFF7043),
  DefaultCategory(id: 'eglence', name: 'Eğlence', type: TransactionType.expense, icon: Icons.movie, colorValue: 0xFF7E57C2),
  DefaultCategory(id: 'egitim', name: 'Eğitim', type: TransactionType.expense, icon: Icons.school, colorValue: 0xFF5C6BC0),
  DefaultCategory(id: 'ev_esya', name: 'Ev & Ev Eşyası', type: TransactionType.expense, icon: Icons.chair, colorValue: 0xFF78909C),
  DefaultCategory(id: 'spor', name: 'Spor/Fitness', type: TransactionType.expense, icon: Icons.fitness_center, colorValue: 0xFF29B6F6),
  DefaultCategory(id: 'evcil_hayvan', name: 'Evcil Hayvan', type: TransactionType.expense, icon: Icons.pets, colorValue: 0xFFA1887F),
  DefaultCategory(id: 'cocuk', name: 'Çocuk', type: TransactionType.expense, icon: Icons.child_care, colorValue: 0xFFFFCA28),
  DefaultCategory(id: 'hediye', name: 'Hediye', type: TransactionType.expense, icon: Icons.card_giftcard, colorValue: 0xFFE91E63),
  DefaultCategory(id: 'seyahat', name: 'Seyahat/Tatil', type: TransactionType.expense, icon: Icons.flight, colorValue: 0xFF26A69A),
  DefaultCategory(id: 'sigorta', name: 'Sigorta', type: TransactionType.expense, icon: Icons.shield, colorValue: 0xFF546E7A),
  DefaultCategory(id: 'borc_kredi', name: 'Borç/Kredi Ödemesi', type: TransactionType.expense, icon: Icons.account_balance, colorValue: 0xFFD32F2F),
  DefaultCategory(id: 'vergi', name: 'Vergi/Resmi Ödemeler', type: TransactionType.expense, icon: Icons.gavel, colorValue: 0xFF6D4C41),
  DefaultCategory(id: 'diger_gider', name: 'Diğer', type: TransactionType.expense, icon: Icons.category, colorValue: 0xFF9E9E9E),
];

/// Ürün özetindeki varsayılan gelir kategorileri.
final List<DefaultCategory> defaultIncomeCategories = [
  DefaultCategory(id: 'maas', name: 'Maaş', type: TransactionType.income, icon: Icons.payments, colorValue: 0xFF66BB6A),
  DefaultCategory(id: 'ek_is', name: 'Ek İş/Freelance', type: TransactionType.income, icon: Icons.work, colorValue: 0xFF42A5F5),
  DefaultCategory(id: 'yatirim', name: 'Yatırım Geliri', type: TransactionType.income, icon: Icons.trending_up, colorValue: 0xFF26A69A),
  DefaultCategory(id: 'prim', name: 'Prim/İkramiye', type: TransactionType.income, icon: Icons.emoji_events, colorValue: 0xFFFFA726),
  DefaultCategory(id: 'iade', name: 'İade/Geri Ödeme', type: TransactionType.income, icon: Icons.replay, colorValue: 0xFF8D6E63),
  DefaultCategory(id: 'gelir_hediye', name: 'Hediye/Para Yardımı', type: TransactionType.income, icon: Icons.volunteer_activism, colorValue: 0xFFEC407A),
  DefaultCategory(id: 'gelir_diger', name: 'Diğer', type: TransactionType.income, icon: Icons.category, colorValue: 0xFF9E9E9E),
];

/// Tüm varsayılan kategoriler (önce giderler, sonra gelirler).
final List<DefaultCategory> allDefaultCategories = [
  ...defaultExpenseCategories,
  ...defaultIncomeCategories,
];
