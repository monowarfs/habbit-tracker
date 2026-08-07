import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/stacking/habit_stack_correlation_usecase.dart';
import 'package:habit_tracker/core/stacking/habit_stack_suggestion_repository.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

void main() {
  late AppDatabase db;
  late HabitStackSuggestionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HabitStackSuggestionRepository(db);
  });

  tearDown(() => db.close());

  const result = StackCorrelationResult(
    qualifyingDays: 6,
    totalDaysWithSource: 7,
    medianGapMinutes: 20,
    typicalSourceTime: LocalTime(8, 15),
  );

  test('upsertEvaluation creates a pending row when none exists', () async {
    await repo.upsertEvaluation(
      id: 'medicine_water',
      sourceModuleId: 'medicine',
      targetModuleId: 'water',
      result: result,
      now: DateTime.utc(2026, 7),
      profileId: 'system',
    );

    final row = await repo.byId('medicine_water', profileId: 'system');
    expect(row, isNotNull);
    expect(row!.status, 'pending');
    expect(row.qualifyingDays, 6);
    expect(row.typicalSourceTime, '08:15');
    expect(row.sourceLabel, isNull);
  });

  test(
    'accept locks the row so a later evaluation never overwrites it',
    () async {
      await repo.upsertEvaluation(
        id: 'medicine_water',
        sourceModuleId: 'medicine',
        targetModuleId: 'water',
        result: result,
        now: DateTime.utc(2026, 7),
        profileId: 'system',
      );
      await repo.accept(
        'medicine_water',
        now: DateTime.utc(2026, 7, 2),
        profileId: 'system',
      );

      await repo.upsertEvaluation(
        id: 'medicine_water',
        sourceModuleId: 'medicine',
        targetModuleId: 'water',
        result: const StackCorrelationResult(
          qualifyingDays: 7,
          totalDaysWithSource: 7,
          medianGapMinutes: 10,
          typicalSourceTime: LocalTime(9, 0),
        ),
        now: DateTime.utc(2026, 7, 10),
        profileId: 'system',
      );

      final row = await repo.byId('medicine_water', profileId: 'system');
      expect(row!.status, 'accepted');
      expect(row.qualifyingDays, 6); // unchanged
    },
  );

  test(
    'a dismissed row stays dismissed on re-evaluation within the 30-day '
    'cooldown, but its lastEvaluatedAt still bumps',
    () async {
      await repo.upsertEvaluation(
        id: 'prayer_water',
        sourceModuleId: 'prayer',
        targetModuleId: 'water',
        result: result,
        sourceLabel: 'Fajr',
        now: DateTime.utc(2026, 7),
        profileId: 'system',
      );
      await repo.dismiss(
        'prayer_water',
        now: DateTime.utc(2026, 7, 2),
        profileId: 'system',
      );

      await repo.upsertEvaluation(
        id: 'prayer_water',
        sourceModuleId: 'prayer',
        targetModuleId: 'water',
        result: result,
        sourceLabel: 'Fajr',
        now: DateTime.utc(2026, 7, 20), // 18 days after dismissal
        profileId: 'system',
      );

      final row = await repo.byId('prayer_water', profileId: 'system');
      expect(row!.status, 'dismissed');
      expect(
        row.lastEvaluatedAt,
        DateTime.utc(2026, 7, 20).millisecondsSinceEpoch,
      );
    },
  );

  test(
    'a dismissed row resurfaces to pending once the 30-day cooldown has '
    'passed',
    () async {
      await repo.upsertEvaluation(
        id: 'prayer_water',
        sourceModuleId: 'prayer',
        targetModuleId: 'water',
        result: result,
        sourceLabel: 'Fajr',
        now: DateTime.utc(2026, 7),
        profileId: 'system',
      );
      await repo.dismiss(
        'prayer_water',
        now: DateTime.utc(2026, 7, 2),
        profileId: 'system',
      );

      await repo.upsertEvaluation(
        id: 'prayer_water',
        sourceModuleId: 'prayer',
        targetModuleId: 'water',
        result: result,
        sourceLabel: 'Fajr',
        now: DateTime.utc(2026, 9, 5), // 65 days after dismissal
        profileId: 'system',
      );

      final row = await repo.byId('prayer_water', profileId: 'system');
      expect(row!.status, 'pending');
      expect(row.respondedAt, isNull);
    },
  );

  test('pendingSuggestion streams the one pending row', () async {
    await repo.upsertEvaluation(
      id: 'medicine_water',
      sourceModuleId: 'medicine',
      targetModuleId: 'water',
      result: result,
      now: DateTime.utc(2026, 7),
      profileId: 'system',
    );

    final pending = await repo.pendingSuggestion(profileId: 'system').first;
    expect(pending, isNotNull);
    expect(pending!.id, 'medicine_water');
  });

  test('byId returns null for an unknown id', () async {
    expect(await repo.byId('nope', profileId: 'system'), isNull);
  });
}
