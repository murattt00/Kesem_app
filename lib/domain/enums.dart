/// Uygulamanın çekirdek alan (domain) enum'ları. Saf Dart, dış bağımlılığı yok.
library;

/// Bir işlemin veya kategorinin gelir mi gider mi olduğu.
enum TransactionType { expense, income }

/// Bir işlemin nasıl oluşturulduğu.
///   * manual    → kullanıcı elle girdi.
///   * recurring → tekrarlayan şablondan otomatik üretildi.
enum TransactionSource { manual, recurring }
