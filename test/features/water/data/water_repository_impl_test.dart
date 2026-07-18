import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';

void main() {
  late AppDatabase db;
  late WaterRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WaterRepositoryImpl(db);
  });

  tearDown(() => db.close());

  test('seeds a 2000ml default goal on first read (FR-W-01)', () async {
    final goal = await repo.watchCurrentGoal().first;
    expect(goal.goalMl, 2000);
  });

  test('seeds default 250/500/750 quick-add presets on first read '
      '(FR-W-03)', () async {
    final settings = await repo.watchSettings().first;
    expect(settings.quickAddAmountsMl, [250, 500, 750]);
    expect(settings.reminderEnabled, isFalse);
  });

  test('addEntry persists and watchEntriesForDay reflects it '
      'reactively', () async {
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 8)), () async {
      final result = await repo.addEntry(
        amountMl: 250,
        loggedAt: DateTime.utc(2026, 6, 1, 8),
        source: WaterEntrySource.quick,
      );
      expect(result, isA<Success<WaterEntry>>());
    });

    final entries = await repo
        .watchEntriesForDay(const LocalDate(2026, 6, 1))
        .first;
    expect(entries, hasLength(1));
    expect(entries.single.amountMl, 250);
    expect(entries.single.source, WaterEntrySource.quick);
  });

  test('deleteEntry soft-deletes: it stops appearing in day queries', () async {
    final added = await repo.addEntry(
      amountMl: 300,
      loggedAt: DateTime.utc(2026, 6, 1, 9),
      source: WaterEntrySource.custom,
    );
    final entry = (added as Success<WaterEntry>).value;

    var entries = await repo
        .watchEntriesForDay(const LocalDate(2026, 6, 1))
        .first;
    expect(entries, hasLength(1));

    final deleteResult = await repo.deleteEntry(entry.id);
    expect(deleteResult, isA<Success<void>>());

    entries = await repo.watchEntriesForDay(const LocalDate(2026, 6, 1)).first;
    expect(entries, isEmpty);
  });

  test('deleteEntry on an unknown id fails with NotFoundException', () async {
    final result = await repo.deleteEntry('does-not-exist');
    expect(result, isA<Failure<void>>());
  });

  test('setGoal is append-only: allGoals grows, watchCurrentGoal reflects '
      'the latest', () async {
    await withClock(Clock.fixed(DateTime.utc(2026, 6)), () async {
      // Trigger the default-goal seed first, matching a real screen that
      // always watches the current goal before the user edits it.
      await repo.watchCurrentGoal().first;
    });

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 2)), () async {
      await repo.setGoal(2500, effectiveFrom: clock.now());
    });

    final all = await repo.allGoals();
    expect(all, hasLength(2)); // seeded default + the new one
    expect((await repo.watchCurrentGoal().first).goalMl, 2500);
  });

  test('updateQuickAddAmounts round-trips through watchSettings', () async {
    final result = await repo.updateQuickAddAmounts([200, 400, 600]);
    expect(result, isA<Success<void>>());

    final settings = await repo.watchSettings().first;
    expect(settings.quickAddAmountsMl, [200, 400, 600]);
  });
}
