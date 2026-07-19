import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';

void main() {
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
    final settings = await repo.watchSettings().first;
    expect(settings.id, 'singleton');
    expect(settings.calculationMethod, CalculationMethod.karachi);
    expect(settings.asrMethod, AsrMethod.hanafi);
    expect(settings.locationMode, LocationMode.auto);
  });

  test('watchQadhaCounters seeds exactly 5 rows, one per PrayerName', () async {
    final counters = await repo.watchQadhaCounters().first;
    expect(counters, hasLength(5));
    expect(
      counters.map((c) => c.prayerName).toSet(),
      PrayerName.values.toSet(),
    );
    expect(counters.every((c) => c.count == 0), isTrue);
  });

  test('updateSettings changes only the given fields', () async {
    await repo.watchSettings().first; // ensure seeded
    final result = await repo.updateSettings(observesJumuah: true);
    expect(result, isA<Success<void>>());
    final settings = await repo.watchSettings().first;
    expect(settings.observesJumuah, isTrue);
    expect(settings.calculationMethod, CalculationMethod.karachi); // unchanged
  });

  test('markQadhaMakeup decrements the named counter by 1, clamped at 0', () async {
    await repo.watchQadhaCounters().first; // ensure seeded
    await repo.setQadhaBalance(PrayerName.fajr, 3);

    final result = await repo.markQadhaMakeup(PrayerName.fajr);
    expect(result, isA<Success<void>>());
    final counters = await repo.watchQadhaCounters().first;
    expect(
      counters.firstWhere((c) => c.prayerName == PrayerName.fajr).count,
      2,
    );
  });

  test('setQadhaBalance clamps a negative input at 0', () async {
    await repo.watchQadhaCounters().first;
    await repo.setQadhaBalance(PrayerName.dhuhr, -5);
    final counters = await repo.watchQadhaCounters().first;
    expect(
      counters.firstWhere((c) => c.prayerName == PrayerName.dhuhr).count,
      0,
    );
  });
}
