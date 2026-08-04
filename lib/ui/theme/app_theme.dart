import 'package:flutter/material.dart';

/// Marka çekirdek rengi — indigo/mor. Gelir yeşili ve gider kırmızısından
/// kasıtlı olarak farklı: marka ≠ gelir/gider, göz karışmasın.
const Color kBrandSeed = Color(0xFF4F46E5);

/// Uygulama boyunca kullanılan semantik renkler (gelir/gider). Tema uzantısı
/// olarak taşınır ki açık/koyu modda otomatik doğru tonu versin.
/// Erişim: `Theme.of(context).extension<AppColors>()!` ya da `context.c`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.income,
    required this.expense,
    required this.incomeSurface,
    required this.expenseSurface,
    required this.positive,
    required this.negative,
  });

  final Color income; // gelir metni/vurgusu
  final Color expense; // gider metni/vurgusu
  final Color incomeSurface; // gelir için yumuşak arka plan
  final Color expenseSurface; // gider için yumuşak arka plan
  final Color positive; // "kalan" artı
  final Color negative; // "kalan" eksi

  static const light = AppColors(
    income: Color(0xFF15803D),
    expense: Color(0xFFDC2626),
    incomeSurface: Color(0xFFE7F6EC),
    expenseSurface: Color(0xFFFDECEC),
    positive: Color(0xFF15803D),
    negative: Color(0xFFDC2626),
  );

  static const dark = AppColors(
    income: Color(0xFF4ADE80),
    expense: Color(0xFFF87171),
    incomeSurface: Color(0xFF163A28),
    expenseSurface: Color(0xFF3A1D1D),
    positive: Color(0xFF4ADE80),
    negative: Color(0xFFF87171),
  );

  @override
  AppColors copyWith({
    Color? income,
    Color? expense,
    Color? incomeSurface,
    Color? expenseSurface,
    Color? positive,
    Color? negative,
  }) {
    return AppColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      incomeSurface: incomeSurface ?? this.incomeSurface,
      expenseSurface: expenseSurface ?? this.expenseSurface,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      incomeSurface: Color.lerp(incomeSurface, other.incomeSurface, t)!,
      expenseSurface: Color.lerp(expenseSurface, other.expenseSurface, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
    );
  }
}

/// Grafiklerde kategori dilimleri için, kategorinin kendi rengi yoksa
/// kullanılacak marka uyumlu paleti.
const List<Color> kChartPalette = [
  Color(0xFF4F46E5),
  Color(0xFF06B6D4),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
  Color(0xFF8B5CF6),
  Color(0xFF14B8A6),
  Color(0xFF64748B),
];

ThemeData _base(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrandSeed,
    brightness: brightness,
  );
  final colors = brightness == Brightness.light ? AppColors.light : AppColors.dark;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [colors],
    cardTheme: CardThemeData(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      scrolledUnderElevation: 0.5,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 68,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

ThemeData buildLightTheme() => _base(Brightness.light);
ThemeData buildDarkTheme() => _base(Brightness.dark);

/// Kısa erişim: `context.appColors.income`
extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
  ColorScheme get scheme => Theme.of(this).colorScheme;
}
