import 'package:drift/drift.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/enums.dart';
import '../recurring/recurring_engine.dart';
import '../util/format.dart';
import 'database.dart';
import 'recurring_service.dart';

/// Yerel bildirimler: yaklaşan tekrarlayan hatırlatması + ay sonu özeti.
///
/// Web'de desteklenmez — çağıran taraf (appInit) web'de atlar.
class NotificationService {
  NotificationService(this.db);

  final AppDatabase db;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (_) {}
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );
    _ready = true;
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Hatırlatıcılar',
      channelDescription: 'Tekrarlayan ve ay sonu hatırlatmaları',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Uygulama açılışında çağrılır: eskiyi temizle, yenilerini planla.
  Future<void> rescheduleAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
    await _scheduleUpcomingRecurring();
    await _scheduleMonthEnd();
  }

  Future<void> _schedule(
    int id,
    String title,
    String body,
    DateTime when,
  ) async {
    if (!when.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _scheduleUpcomingRecurring() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final templates = await (db.select(db.recurringTemplates)
          ..where((t) => t.active.equals(true)))
        .get();
    final names = {
      for (final c in await db.select(db.categories).get()) c.id: c.name,
    };

    var id = 1000;
    for (final t in templates) {
      DateTime? next;
      try {
        next = nextOccurrence(RecurringService.scheduleOf(t), after: today);
      } catch (_) {
        continue;
      }
      if (next == null) continue;
      final when = DateTime(next.year, next.month, next.day - 1, 9); // 1 gün önce 09:00
      final name = names[t.categoryId] ?? 'Tekrarlayan';
      final tur = t.type == TransactionType.expense ? 'gider' : 'gelir';
      await _schedule(
        id++,
        'Yaklaşan: $name',
        'Yarın ${formatMoney(t.amountMinor)} $tur işlenecek',
        when,
      );
    }
  }

  Future<void> _scheduleMonthEnd() async {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final when = DateTime(lastDay.year, lastDay.month, lastDay.day, 20);

    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    final txns = await (db.select(db.transactions)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end)))
        .get();

    var income = 0;
    var expense = 0;
    for (final t in txns) {
      if (t.type == TransactionType.income) {
        income += t.amountMinor;
      } else {
        expense += t.amountMinor;
      }
    }
    final net = income - expense;
    final durum = net >= 0
        ? '${formatMoney(net)} kaldı'
        : '${formatMoney(-net)} açık verdin';

    await _schedule(
      2,
      'Ay Sonu Özeti',
      'Bu ay ${formatMoney(expense)} harcadın, $durum.',
      when,
    );
  }
}
