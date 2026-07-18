import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/domain/entities/water_settings.dart';
import 'package:habit_tracker/features/water/domain/repositories/water_repository.dart';
import 'package:habit_tracker/features/water/water_module.dart';

class _FakeWaterRepository extends Fake implements WaterRepository {
  _FakeWaterRepository(this._settings);

  final WaterSettings _settings;
  int? capturedAmountMl;
  WaterEntrySource? capturedSource;

  @override
  Stream<WaterSettings> watchSettings() => Stream.value(_settings);

  @override
  Future<Result<WaterEntry>> addEntry({
    required int amountMl,
    required DateTime loggedAt,
    required WaterEntrySource source,
  }) async {
    capturedAmountMl = amountMl;
    capturedSource = source;
    return Result.success(
      WaterEntry(
        id: 'x',
        amountMl: amountMl,
        loggedAt: loggedAt,
        source: source,
      ),
    );
  }
}

WaterSettings _settings({required bool reminderEnabled}) => WaterSettings(
  quickAddAmountsMl: const [250, 500, 750],
  reminderEnabled: reminderEnabled,
  reminderIntervalMinutes: 120,
  reminderWindowStart: const LocalTime(8, 0),
  reminderWindowEnd: const LocalTime(10, 0),
);

void main() {
  test('pendingNotifications is empty when reminders are disabled', () async {
    final module = WaterModule(
      _FakeWaterRepository(_settings(reminderEnabled: false)),
    );
    expect(await module.pendingNotifications(), isEmpty);
  });

  test(
    'pendingNotifications projects slots across multiple upcoming days, all '
    'strictly after now, none more than 3 days out',
    () async {
      final module = WaterModule(
        _FakeWaterRepository(_settings(reminderEnabled: true)),
      );
      final now = DateTime(2026, 6, 1, 9);
      await withClock(Clock.fixed(now), () async {
        final notifications = await module.pendingNotifications();
        expect(notifications, isNotEmpty);
        final days = notifications
            .map((n) => localDayKey(n.scheduledAt))
            .toSet();
        // At least today's remaining slots plus at least one future day.
        expect(days.length, greaterThanOrEqualTo(2));
        for (final n in notifications) {
          expect(n.sourceType, 'water_reminder');
          expect(n.deepLinkRoute, '/water');
          expect(n.scheduledAt.isAfter(now), isTrue);
          expect(
            n.scheduledAt.isBefore(now.add(const Duration(days: 4))),
            isTrue,
          );
        }
      });
    },
  );

  test(
    'onNotificationAction(done) logs a quick entry of the first quick-add '
    'amount',
    () async {
      final repo = _FakeWaterRepository(_settings(reminderEnabled: true));
      final module = WaterModule(repo);

      await module.onNotificationAction('any_id', NotificationActionType.done);

      expect(repo.capturedAmountMl, 250);
      expect(repo.capturedSource, WaterEntrySource.quick);
    },
  );

  test('onNotificationAction(snooze/skip) never logs an entry', () async {
    final repo = _FakeWaterRepository(_settings(reminderEnabled: true));
    final module = WaterModule(repo);

    await module.onNotificationAction('any_id', NotificationActionType.snooze);
    await module.onNotificationAction('any_id', NotificationActionType.skip);

    expect(repo.capturedAmountMl, isNull);
  });
}
