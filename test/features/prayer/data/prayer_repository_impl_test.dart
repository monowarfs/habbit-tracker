import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';

const _profileId = 'system';

void main() {
  setUpAll(ensureTimeZonesInitialized);

  late AppDatabase db;
  late PrayerRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PrayerRepositoryImpl(
      db,
      defaultCalculationMethod: () => CalculationMethod.karachi,
      defaultAsrMethod: () => AsrMethod.hanafi,
    );
  });

  tearDown(() => db.close());

  test('watchSettings seeds a singleton row on first read', () async {
    final settings = await repo.watchSettings(profileId: _profileId).first;
    expect(settings.id, 'singleton');
    expect(settings.calculationMethod, CalculationMethod.karachi);
    expect(settings.asrMethod, AsrMethod.hanafi);
    expect(settings.locationMode, LocationMode.auto);
  });

  test('watchQadhaCounters seeds exactly 5 rows, one per PrayerName', () async {
    final counters = await repo.watchQadhaCounters(profileId: _profileId).first;
    expect(counters, hasLength(5));
    expect(
      counters.map((c) => c.prayerName).toSet(),
      PrayerName.values.toSet(),
    );
    expect(counters.every((c) => c.count == 0), isTrue);
  });

  test('updateSettings changes only the given fields', () async {
    await repo.watchSettings(profileId: _profileId).first; // ensure seeded
    final result = await repo.updateSettings(
      profileId: _profileId,
      observesJumuah: true,
    );
    expect(result, isA<Success<void>>());
    final settings = await repo.watchSettings(profileId: _profileId).first;
    expect(settings.observesJumuah, isTrue);
    expect(settings.calculationMethod, CalculationMethod.karachi); // unchanged
  });

  test(
    'markQadhaMakeup decrements the named counter by 1, clamped at 0',
    () async {
      await repo
          .watchQadhaCounters(profileId: _profileId)
          .first; // ensure seeded
      await repo.setQadhaBalance(PrayerName.fajr, 3, profileId: _profileId);

      final result = await repo.markQadhaMakeup(
        PrayerName.fajr,
        profileId: _profileId,
      );
      expect(result, isA<Success<void>>());
      final counters = await repo
          .watchQadhaCounters(profileId: _profileId)
          .first;
      expect(
        counters.firstWhere((c) => c.prayerName == PrayerName.fajr).count,
        2,
      );
    },
  );

  test('setQadhaBalance clamps a negative input at 0', () async {
    await repo.watchQadhaCounters(profileId: _profileId).first;
    await repo.setQadhaBalance(PrayerName.dhuhr, -5, profileId: _profileId);
    final counters = await repo.watchQadhaCounters(profileId: _profileId).first;
    expect(
      counters.firstWhere((c) => c.prayerName == PrayerName.dhuhr).count,
      0,
    );
  });

  test(
    'materializeRecords fills the window with 5 records/day and is '
    'idempotent on a second call',
    () async {
      const location = (
        latitude: 23.8103,
        longitude: 90.4125,
        ianaTimezone: 'Asia/Dhaka',
      );
      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 1)), () async {
        await repo.materializeRecords(
          clock.now(),
          location,
          profileId: _profileId,
        );
      });
      final firstPass = await repo.recordsInRange(
        const LocalDate(2026, 6, 1),
        const LocalDate(2026, 6, 30),
        profileId: _profileId,
      );
      expect(firstPass, hasLength(30 * 5));

      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 1)), () async {
        await repo.materializeRecords(
          clock.now(),
          location,
          profileId: _profileId,
        );
      });
      final secondPass = await repo.recordsInRange(
        const LocalDate(2026, 6, 1),
        const LocalDate(2026, 6, 30),
        profileId: _profileId,
      );
      expect(secondPass, hasLength(30 * 5)); // unchanged, not duplicated
    },
  );

  test(
    'materializeRecords regenerates a day whose upcoming records were '
    'soft-deleted by a settings change (regression: insertOrIgnore silently '
    'no-ops against the still-occupied (prayerDate, prayerName) unique '
    'slot, permanently leaving the day empty)',
    () async {
      const location = (
        latitude: 23.8103,
        longitude: 90.4125,
        ianaTimezone: 'Asia/Dhaka',
      );
      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 1)), () async {
        await repo.materializeRecords(
          clock.now(),
          location,
          profileId: _profileId,
        );
        // Any calculation-method change soft-deletes every future
        // `upcoming` record so the next pass recalculates them.
        await repo.updateSettings(
          profileId: _profileId,
          calculationMethod: CalculationMethod.mwl,
        );
        await repo.materializeRecords(
          clock.now(),
          location,
          profileId: _profileId,
        );
      });

      final day = await repo
          .watchRecordsForDay(
            const LocalDate(2026, 6, 15),
            profileId: _profileId,
          )
          .first;
      expect(day, hasLength(5));
      expect(day.every((r) => r.storedStatus == PrayerStatus.upcoming), isTrue);
    },
  );

  test("watchRecordsForDay reflects a single day's 5 records", () async {
    const location = (
      latitude: 23.8103,
      longitude: 90.4125,
      ianaTimezone: 'Asia/Dhaka',
    );
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 1)), () async {
      await repo.materializeRecords(
        clock.now(),
        location,
        profileId: _profileId,
      );
    });
    final records = await repo
        .watchRecordsForDay(const LocalDate(2026, 6, 1), profileId: _profileId)
        .first;
    expect(records, hasLength(5));
  });

  test(
    'sweepMissedPrayers persists missed for a record past its cutoff and '
    'bumps its Qadha counter exactly once',
    () async {
      const location = (latitude: 0.0, longitude: 0.0, ianaTimezone: 'Etc/UTC');
      await withClock(Clock.fixed(DateTime.utc(2026, 6)), () async {
        await repo.materializeRecords(
          clock.now(),
          location,
          profileId: _profileId,
        );
      });
      await repo
          .watchQadhaCounters(profileId: _profileId)
          .first; // ensure seeded

      // Just past Isha's rollover cutoff on 2026-06-02 (default 00:00),
      // so all 5 records for June 1st sweep to missed, but June 2nd's
      // records are not yet past their cutoffs.
      final farFuture = DateTime.utc(2026, 6, 2, 0, 1);
      await repo.sweepMissedPrayers(farFuture, location, profileId: _profileId);

      final records = await repo.recordsInRange(
        const LocalDate(2026, 6, 1),
        const LocalDate(2026, 6, 1),
        profileId: _profileId,
      );
      expect(
        records.every((r) => r.storedStatus == PrayerStatus.missed),
        isTrue,
      );

      final counters = await repo
          .watchQadhaCounters(profileId: _profileId)
          .first;
      expect(counters.every((c) => c.count == 1), isTrue);

      // Idempotent: sweeping again doesn't double-bump.
      await repo.sweepMissedPrayers(farFuture, location, profileId: _profileId);
      final countersAfterSecondSweep = await repo
          .watchQadhaCounters(profileId: _profileId)
          .first;
      expect(countersAfterSecondSweep.every((c) => c.count == 1), isTrue);
    },
  );

  test('markPrayed marks a record prayed', () async {
    const location = (latitude: 0.0, longitude: 0.0, ianaTimezone: 'Etc/UTC');
    await withClock(Clock.fixed(DateTime.utc(2026, 6)), () async {
      await repo.materializeRecords(
        clock.now(),
        location,
        profileId: _profileId,
      );
    });
    final records = await repo.recordsInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
      profileId: _profileId,
    );
    final recordId = records.first.id;

    final result = await repo.markPrayed(recordId, profileId: _profileId);
    expect(result, isA<Success<void>>());
    final updated = await repo.recordsInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
      profileId: _profileId,
    );
    expect(
      updated.firstWhere((r) => r.id == recordId).storedStatus,
      PrayerStatus.prayed,
    );
  });

  test(
    'markPrayed(forceOnTime: true) backdates statusChangedAt to '
    'scheduledFor',
    () async {
      const location = (latitude: 0.0, longitude: 0.0, ianaTimezone: 'Etc/UTC');
      await withClock(Clock.fixed(DateTime.utc(2026, 6)), () async {
        await repo.materializeRecords(
          clock.now(),
          location,
          profileId: _profileId,
        );
      });
      final records = await repo.recordsInRange(
        const LocalDate(2026, 6, 1),
        const LocalDate(2026, 6, 1),
        profileId: _profileId,
      );
      final record = records.first;

      await withClock(
        Clock.fixed(record.scheduledFor.add(const Duration(hours: 2))),
        () => repo.markPrayed(
          record.id,
          forceOnTime: true,
          profileId: _profileId,
        ),
      );

      final updated = await repo.recordsInRange(
        const LocalDate(2026, 6, 1),
        const LocalDate(2026, 6, 1),
        profileId: _profileId,
      );
      expect(
        updated.firstWhere((r) => r.id == record.id).statusChangedAt,
        record.scheduledFor,
      );
    },
  );

  test(
    'unmarkPrayed reverts a prayed record to upcoming (toggle off)',
    () async {
      const location = (latitude: 0.0, longitude: 0.0, ianaTimezone: 'Etc/UTC');
      await withClock(Clock.fixed(DateTime.utc(2026, 6)), () async {
        await repo.materializeRecords(
          clock.now(),
          location,
          profileId: _profileId,
        );
      });
      final records = await repo.recordsInRange(
        const LocalDate(2026, 6, 1),
        const LocalDate(2026, 6, 1),
        profileId: _profileId,
      );
      final recordId = records.first.id;
      await repo.markPrayed(recordId, profileId: _profileId);

      final result = await repo.unmarkPrayed(recordId, profileId: _profileId);
      expect(result, isA<Success<void>>());
      final updated = await repo.recordsInRange(
        const LocalDate(2026, 6, 1),
        const LocalDate(2026, 6, 1),
        profileId: _profileId,
      );
      expect(
        updated.firstWhere((r) => r.id == recordId).storedStatus,
        PrayerStatus.upcoming,
      );
    },
  );

  test('markPrayed fails validation on an already-missed record', () async {
    const location = (latitude: 0.0, longitude: 0.0, ianaTimezone: 'Etc/UTC');
    await withClock(Clock.fixed(DateTime.utc(2026, 6)), () async {
      await repo.materializeRecords(
        clock.now(),
        location,
        profileId: _profileId,
      );
    });
    await repo.watchQadhaCounters(profileId: _profileId).first;
    await repo.sweepMissedPrayers(
      DateTime.utc(2026, 6, 2, 0, 1),
      location,
      profileId: _profileId,
    );
    final records = await repo.recordsInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
      profileId: _profileId,
    );
    final missedId = records.first.id;

    final result = await repo.markPrayed(missedId, profileId: _profileId);
    expect(result, isA<Failure<void>>());
  });

  test('markMissedBySkip marks missed and bumps the Qadha counter', () async {
    const location = (latitude: 0.0, longitude: 0.0, ianaTimezone: 'Etc/UTC');
    await withClock(Clock.fixed(DateTime.utc(2026, 6)), () async {
      await repo.materializeRecords(
        clock.now(),
        location,
        profileId: _profileId,
      );
    });
    await repo.watchQadhaCounters(profileId: _profileId).first;
    final records = await repo.recordsInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
      profileId: _profileId,
    );
    final fajr = records.firstWhere((r) => r.prayerName == PrayerName.fajr);

    final result = await repo.markMissedBySkip(
      fajr.id,
      profileId: _profileId,
    );
    expect(result, isA<Success<void>>());
    final counters = await repo.watchQadhaCounters(profileId: _profileId).first;
    expect(
      counters.firstWhere((c) => c.prayerName == PrayerName.fajr).count,
      1,
    );
  });

  test('allRecords returns every non-deleted record', () async {
    const location = (latitude: 0.0, longitude: 0.0, ianaTimezone: 'Etc/UTC');
    await withClock(Clock.fixed(DateTime.utc(2026, 6)), () async {
      await repo.materializeRecords(
        clock.now(),
        location,
        profileId: _profileId,
      );
    });
    final all = await repo.allRecords(profileId: _profileId);
    expect(all, hasLength(30 * 5));
  });

  test('updatePrayerNotes annotates a record even when missed (the most '
      'useful case)', () async {
    const location = (latitude: 0.0, longitude: 0.0, ianaTimezone: 'Etc/UTC');
    await withClock(Clock.fixed(DateTime.utc(2026, 6)), () async {
      await repo.materializeRecords(
        clock.now(),
        location,
        profileId: _profileId,
      );
    });
    await repo.watchQadhaCounters(profileId: _profileId).first;
    await repo.sweepMissedPrayers(
      DateTime.utc(2026, 6, 2, 0, 1),
      location,
      profileId: _profileId,
    );
    final records = await repo.recordsInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
      profileId: _profileId,
    );
    final missed = records.firstWhere(
      (r) => r.storedStatus == PrayerStatus.missed,
    );

    final result = await repo.updatePrayerNotes(
      missed.id,
      'was in a meeting',
      profileId: _profileId,
    );
    expect(result, isA<Success<void>>());

    final updated = await repo.recordsInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
      profileId: _profileId,
    );
    final updatedRecord = updated.firstWhere((r) => r.id == missed.id);
    expect(updatedRecord.notes, 'was in a meeting');
    expect(updatedRecord.storedStatus, PrayerStatus.missed); // unchanged
  });

  test(
    'updatePrayerNotes on an unknown id fails with NotFoundException',
    () async {
      final result = await repo.updatePrayerNotes(
        'missing',
        'x',
        profileId: _profileId,
      );
      expect(result, isA<Failure<void>>());
    },
  );

  test('restoreRecord persists notes (import round-trip)', () async {
    final newId = await _insertRestoredRecord(repo, notes: 'restored note');
    final records = await repo.recordsInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
      profileId: _profileId,
    );
    expect(records.firstWhere((r) => r.id == newId).notes, 'restored note');
  });
}

Future<String> _insertRestoredRecord(
  PrayerRepositoryImpl repo, {
  required String? notes,
}) async {
  await repo.restoreRecord(
    PrayerRecord(
      id: '',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.fajr,
      scheduledFor: DateTime.utc(2026, 6, 1, 5),
      storedStatus: PrayerStatus.upcoming,
      notes: notes,
    ),
    profileId: _profileId,
  );
  final records = await repo.recordsInRange(
    const LocalDate(2026, 6, 1),
    const LocalDate(2026, 6, 1),
    profileId: _profileId,
  );
  return records.first.id;
}
