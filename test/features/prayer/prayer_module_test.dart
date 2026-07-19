import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/prayer_module.dart';
import 'package:mocktail/mocktail.dart';

class _MockPrayerRepository extends Mock implements PrayerRepository {}

void main() {
  late _MockPrayerRepository repo;
  late PrayerModule module;

  setUpAll(() {
    registerFallbackValue(const LocalDate(2026, 1, 1));
    registerFallbackValue(DateTime.utc(2026, 6, 1));
    registerFallbackValue(
      (latitude: 0.0, longitude: 0.0, ianaTimezone: 'Etc/UTC'),
    );
  });

  setUp(() {
    repo = _MockPrayerRepository();
    module = PrayerModule(repo);
  });

  const settings = PrayerSettings(
    id: 'singleton',
    calculationMethod: CalculationMethod.karachi,
    asrMethod: AsrMethod.hanafi,
    locationMode: LocationMode.manual,
    manualLatitude: 23.8103,
    manualLongitude: 90.4125,
    manualTimezone: 'Asia/Dhaka',
  );

  test(
    'pendingNotifications sweeps then materializes before querying, and '
    'maps upcoming records within 3 days to PendingNotification',
    () async {
      final now = DateTime.utc(2026, 6, 1, 7);
      final record = PrayerRecord(
        id: 'r1',
        prayerDate: const LocalDate(2026, 6, 1),
        prayerName: PrayerName.dhuhr,
        scheduledFor: DateTime.utc(2026, 6, 1, 8),
        storedStatus: PrayerStatus.upcoming,
      );

      when(() => repo.watchSettings()).thenAnswer(
        (_) => Stream.value(settings),
      );
      when(
        () => repo.sweepMissedPrayers(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => repo.materializeRecords(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => repo.recordsInRange(any(), any()),
      ).thenAnswer((_) async => [record]);

      await withClock(Clock.fixed(now), () async {
        final notifications = await module.pendingNotifications();
        expect(notifications, hasLength(1));
        expect(notifications.single.sourceType, 'prayer_record');
        expect(notifications.single.deepLinkRoute, '/prayer/record/r1');
      });

      verifyInOrder([
        () => repo.sweepMissedPrayers(any(), any()),
        () => repo.materializeRecords(any(), any()),
      ]);
    },
  );

  test(
    'pendingNotifications includes a pre-reminder when preReminderEnabled',
    () async {
      final now = DateTime.utc(2026, 6, 1, 7);
      final record = PrayerRecord(
        id: 'r1',
        prayerDate: const LocalDate(2026, 6, 1),
        prayerName: PrayerName.dhuhr,
        scheduledFor: DateTime.utc(2026, 6, 1, 8),
        storedStatus: PrayerStatus.upcoming,
      );
      final settingsWithReminder = settings.copyWith(
        preReminderEnabled: true,
        preReminderOffsetMinutes: 10,
      );

      when(
        () => repo.watchSettings(),
      ).thenAnswer((_) => Stream.value(settingsWithReminder));
      when(
        () => repo.sweepMissedPrayers(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => repo.materializeRecords(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => repo.recordsInRange(any(), any()),
      ).thenAnswer((_) async => [record]);

      await withClock(Clock.fixed(now), () async {
        final notifications = await module.pendingNotifications();
        expect(notifications, hasLength(2)); // on-time + pre-reminder
      });
    },
  );

  test('onNotificationAction(done) marks the record prayed', () async {
    when(
      () => repo.markPrayed(any()),
    ).thenAnswer((_) async => const Result.success(null));

    await module.onNotificationAction('r1', NotificationActionType.done);

    verify(() => repo.markPrayed('r1')).called(1);
  });

  test(
    'onNotificationAction(skip) marks the record missed '
    'via markMissedBySkip',
    () async {
      when(
        () => repo.markMissedBySkip(any()),
      ).thenAnswer((_) async => const Result.success(null));

      await module.onNotificationAction('r1', NotificationActionType.skip);

      verify(() => repo.markMissedBySkip('r1')).called(1);
    },
  );

  test('onNotificationAction(snooze) never mutates record data', () async {
    await module.onNotificationAction('r1', NotificationActionType.snooze);
    verifyNever(() => repo.markPrayed(any()));
    verifyNever(() => repo.markMissedBySkip(any()));
  });
}
