import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
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
    registerFallbackValue(DateTime.utc(2026, 6));
    registerFallbackValue(
      (latitude: 0.0, longitude: 0.0, ianaTimezone: 'Etc/UTC'),
    );
    registerFallbackValue(
      PrayerRecord(
        id: 'fallback',
        prayerDate: const LocalDate(2026, 1, 1),
        prayerName: PrayerName.fajr,
        scheduledFor: DateTime.utc(2026),
        storedStatus: PrayerStatus.upcoming,
      ),
    );
    registerFallbackValue(PrayerName.fajr);
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

  test('onQuickAction marks the earliest due prayer prayed', () async {
    final now = DateTime.utc(2026, 6, 1, 9);
    final fajr = PrayerRecord(
      id: 'r-fajr',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.fajr,
      scheduledFor: DateTime.utc(2026, 6, 1, 5),
      storedStatus: PrayerStatus.upcoming,
    );
    final dhuhr = PrayerRecord(
      id: 'r-dhuhr',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.dhuhr,
      scheduledFor: DateTime.utc(2026, 6, 1, 8),
      storedStatus: PrayerStatus.upcoming,
    );
    final asr = PrayerRecord(
      id: 'r-asr',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.asr,
      scheduledFor: DateTime.utc(2026, 6, 1, 12),
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
    ).thenAnswer((_) async => [asr, dhuhr, fajr]);
    when(
      () => repo.markPrayed(any()),
    ).thenAnswer((_) async => const Result.success(null));

    await withClock(Clock.fixed(now), () async {
      await module.onQuickAction();
    });

    // fajr (5am) is past its cutoff (dhuhr's 8am start) -> missed, not due.
    // dhuhr (8am) is past its own start but before asr's 12pm cutoff -> due.
    // asr (12pm) hasn't started yet -> upcoming.
    verify(() => repo.markPrayed('r-dhuhr')).called(1);
  });

  test('onQuickAction no-ops when nothing is due', () async {
    when(() => repo.watchSettings()).thenAnswer(
      (_) => Stream.value(settings),
    );
    when(
      () => repo.sweepMissedPrayers(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => repo.materializeRecords(any(), any()),
    ).thenAnswer((_) async {});
    when(() => repo.recordsInRange(any(), any())).thenAnswer((_) async => []);

    await module.onQuickAction();

    verifyNever(() => repo.markPrayed(any()));
  });

  test(
    'dayStatus: 5 prayed records is complete, mix is partial, none is missed',
    () async {
      const day = LocalDate(2026, 6, 1);
      List<PrayerRecord> recordsWith(PrayerStatus Function(int) statusFor) => [
        for (var i = 0; i < 5; i++)
          PrayerRecord(
            id: 'r$i',
            prayerDate: day,
            prayerName: PrayerName.values[i],
            scheduledFor: DateTime.utc(2026, 6, 1, 5 + i),
            storedStatus: statusFor(i),
          ),
      ];
      const range = DateRange(start: day, end: day);

      when(
        () => repo.recordsInRange(any(), any()),
      ).thenAnswer((_) async => recordsWith((_) => PrayerStatus.prayed));
      expect(
        (await module.dayStatus(range))[day]!.kind,
        ModuleDayStatusKind.complete,
      );

      when(
        () => repo.recordsInRange(any(), any()),
      ).thenAnswer((_) async => recordsWith((_) => PrayerStatus.missed));
      expect(
        (await module.dayStatus(range))[day]!.kind,
        ModuleDayStatusKind.missed,
      );

      when(() => repo.recordsInRange(any(), any())).thenAnswer(
        (_) async => recordsWith(
          (i) => i == 0 ? PrayerStatus.prayed : PrayerStatus.missed,
        ),
      );
      expect(
        (await module.dayStatus(range))[day]!.kind,
        ModuleDayStatusKind.partial,
      );
    },
  );

  test('search always returns empty (Prayer has no named user data)', () async {
    expect(await module.search('fajr'), isEmpty);
  });

  test('exportData includes qadhaCounters', () async {
    when(() => repo.watchSettings()).thenAnswer((_) => Stream.value(settings));
    when(() => repo.allRecords()).thenAnswer((_) async => const []);
    when(() => repo.allQadhaCounters()).thenAnswer(
      (_) async => [
        PrayerQadhaCounter(
          id: 'q1',
          prayerName: PrayerName.fajr,
          count: 3,
          updatedAt: DateTime.utc(2026, 6),
        ),
      ],
    );

    final export = await module.exportData();
    final counters = export.payload['qadhaCounters']! as List<dynamic>;
    final fajr = counters.cast<Map<String, Object?>>().firstWhere(
      (c) => c['prayerName'] == 'fajr',
    );
    expect(fajr['count'], 3);
  });

  test('importData restores records and Qadha balances', () async {
    when(
      () => repo.updateSettings(
        calculationMethod: any(named: 'calculationMethod'),
        asrMethod: any(named: 'asrMethod'),
        observesJumuah: any(named: 'observesJumuah'),
        locationMode: any(named: 'locationMode'),
        manualLatitude: any(named: 'manualLatitude'),
        manualLongitude: any(named: 'manualLongitude'),
        manualTimezone: any(named: 'manualTimezone'),
      ),
    ).thenAnswer((_) async => const Result.success(null));
    when(() => repo.restoreRecord(any())).thenAnswer((_) async {});
    when(
      () => repo.setQadhaBalance(any(), any()),
    ).thenAnswer((_) async => const Result.success(null));

    await module.importData(
      const ModuleExport({
        'settings': null,
        'records': [
          {
            'prayerDate': '2026-06-01',
            'prayerName': 'fajr',
            'scheduledFor': '2026-06-01T05:00:00.000Z',
            'status': 'prayed',
            'statusChangedAt': null,
          },
        ],
        'qadhaCounters': [
          {'prayerName': 'dhuhr', 'count': 2},
        ],
      }),
    );

    final capturedRecords = verify(
      () => repo.restoreRecord(captureAny()),
    ).captured;
    expect(capturedRecords, hasLength(1));
    expect(
      (capturedRecords.single as PrayerRecord).storedStatus,
      PrayerStatus.prayed,
    );
    verify(() => repo.setQadhaBalance(PrayerName.dhuhr, 2)).called(1);
  });

  test('wipeData delegates to the repository', () async {
    when(() => repo.wipeAll()).thenAnswer((_) async {});
    await module.wipeData();
    verify(() => repo.wipeAll()).called(1);
  });
}
