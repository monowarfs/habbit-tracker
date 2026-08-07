import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';

const _profileId = 'system';

void main() {
  late AppDatabase db;
  late WaterRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WaterRepositoryImpl(db);
  });

  tearDown(() => db.close());

  test('seeds a 2000ml default goal on first read (FR-W-01)', () async {
    final goal = await repo.watchCurrentGoal(profileId: _profileId).first;
    expect(goal?.goalMl, 2000);
  });

  test('seeds default 250/500/750 quick-add presets on first read '
      '(FR-W-03)', () async {
    final settings = await repo.watchSettings(profileId: _profileId).first;
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
        profileId: _profileId,
      );
      expect(result, isA<Success<WaterEntry>>());
    });

    final entries = await repo
        .watchEntriesForDay(const LocalDate(2026, 6, 1), profileId: _profileId)
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
      profileId: _profileId,
    );
    final entry = (added as Success<WaterEntry>).value;

    var entries = await repo
        .watchEntriesForDay(const LocalDate(2026, 6, 1), profileId: _profileId)
        .first;
    expect(entries, hasLength(1));

    final deleteResult = await repo.deleteEntry(
      entry.id,
      profileId: _profileId,
    );
    expect(deleteResult, isA<Success<void>>());

    entries = await repo
        .watchEntriesForDay(const LocalDate(2026, 6, 1), profileId: _profileId)
        .first;
    expect(entries, isEmpty);
  });

  test('deleteEntry on an unknown id fails with NotFoundException', () async {
    final result = await repo.deleteEntry(
      'does-not-exist',
      profileId: _profileId,
    );
    expect(result, isA<Failure<void>>());
  });

  test('setGoal is append-only: allGoals grows, watchCurrentGoal reflects '
      'the latest', () async {
    await withClock(Clock.fixed(DateTime.utc(2026, 6)), () async {
      // Trigger the default-goal seed first, matching a real screen that
      // always watches the current goal before the user edits it.
      await repo.watchCurrentGoal(profileId: _profileId).first;
    });

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 2)), () async {
      await repo.setGoal(
        2500,
        effectiveFrom: clock.now(),
        profileId: _profileId,
      );
    });

    final all = await repo.allGoals(profileId: _profileId);
    expect(all, hasLength(2)); // seeded default + the new one
    expect(
      (await repo.watchCurrentGoal(profileId: _profileId).first)?.goalMl,
      2500,
    );
  });

  test('updateQuickAddAmounts round-trips through watchSettings', () async {
    final result = await repo.updateQuickAddAmounts(
      [200, 400, 600],
      profileId: _profileId,
    );
    expect(result, isA<Success<void>>());

    final settings = await repo.watchSettings(profileId: _profileId).first;
    expect(settings.quickAddAmountsMl, [200, 400, 600]);
  });

  test('addEntry persists notes, and updateEntry can change them without '
      'touching amount/loggedAt', () async {
    final added = await repo.addEntry(
      amountMl: 250,
      loggedAt: DateTime.utc(2026, 6, 1, 8),
      source: WaterEntrySource.custom,
      notes: 'felt great',
      profileId: _profileId,
    );
    final entry = (added as Success<WaterEntry>).value;
    expect(entry.notes, 'felt great');
    expect(
      (await repo.entryById(entry.id, profileId: _profileId))!.notes,
      'felt great',
    );

    await repo.updateEntry(
      entry.id,
      notes: 'updated note',
      profileId: _profileId,
    );
    final updated = await repo.entryById(entry.id, profileId: _profileId);
    expect(updated!.notes, 'updated note');
    expect(updated.amountMl, 250); // untouched

    await repo.updateEntry(entry.id, amountMl: 300, profileId: _profileId);
    final afterAmountOnlyUpdate = await repo.entryById(
      entry.id,
      profileId: _profileId,
    );
    expect(
      afterAmountOnlyUpdate!.notes,
      'updated note',
    ); // not clobbered by an update that omits notes
  });

  test('updateEntry(notes: null) explicitly clears a previously-set note '
      '(distinct from omitting the notes argument entirely)', () async {
    final added = await repo.addEntry(
      amountMl: 250,
      loggedAt: DateTime.utc(2026, 6, 1, 8),
      source: WaterEntrySource.custom,
      notes: 'will be cleared',
      profileId: _profileId,
    );
    final entry = (added as Success<WaterEntry>).value;

    await repo.updateEntry(entry.id, notes: null, profileId: _profileId);

    expect(
      (await repo.entryById(entry.id, profileId: _profileId))!.notes,
      isNull,
    );
  });
}
