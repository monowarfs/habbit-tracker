import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';

void main() {
  late AppDatabase db;
  late PrayerRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PrayerRepositoryImpl(db);
  });

  tearDown(() => db.close());

  test('restoreRecord inserts a record with a fresh id', () async {
    await repo.restoreRecord(
      PrayerRecord(
        id: 'old-id',
        prayerDate: const LocalDate(2026, 6, 1),
        prayerName: PrayerName.fajr,
        scheduledFor: DateTime.utc(2026, 6, 1, 5),
        storedStatus: PrayerStatus.prayed,
      ),
    );
    final records = await repo.allRecords();
    expect(records, hasLength(1));
    expect(records.first.id, isNot('old-id'));
    expect(records.first.storedStatus, PrayerStatus.prayed);
  });

  test('allQadhaCounters returns the seeded 5 rows', () async {
    await repo.watchSettings().first;
    final counters = await repo.allQadhaCounters();
    expect(counters, hasLength(5));
  });

  test('wipeAll deletes settings, records, and Qadha counters', () async {
    await repo.watchSettings().first;
    await repo.restoreRecord(
      PrayerRecord(
        id: 'x',
        prayerDate: const LocalDate(2026, 6, 1),
        prayerName: PrayerName.fajr,
        scheduledFor: DateTime.utc(2026, 6, 1, 5),
        storedStatus: PrayerStatus.upcoming,
      ),
    );

    await repo.wipeAll();

    expect(await repo.allRecords(), isEmpty);
    expect(await repo.allQadhaCounters(), isEmpty);
    final settingsRows = await db.select(db.prayerSettingsTable).get();
    expect(settingsRows, isEmpty);
  });
}
