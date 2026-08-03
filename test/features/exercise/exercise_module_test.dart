import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/exercise/data/repositories/exercise_repository_impl.dart';
import 'package:habit_tracker/features/exercise/exercise_module.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepositoryImpl repository;
  late ExerciseModule module;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = ExerciseRepositoryImpl(db);
    module = ExerciseModule(repository);
  });

  tearDown(() async {
    await db.close();
  });

  test('dayStatus is complete only for days with a logged workout', () async {
    await repository.addLog(
      exerciseType: 'Running',
      durationMinutes: 30,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
    );

    final status = await module.dayStatus(
      const DateRange(
        start: LocalDate(2026, 6, 14),
        end: LocalDate(2026, 6, 15),
      ),
    );

    expect(
      status[const LocalDate(2026, 6, 14)]!.kind,
      ModuleDayStatusKind.none,
    );
    expect(
      status[const LocalDate(2026, 6, 15)]!.kind,
      ModuleDayStatusKind.complete,
    );
  });

  test('achievementDefinitions use real streak keys', () {
    final keys = module.achievementDefinitions.map((a) => a.key).toList();
    expect(keys, [
      'exercise_first_log',
      'exercise_streak_7',
      'exercise_streak_30',
      'exercise_streak_100',
    ]);
  });

  test('exportData/importData round-trips workouts', () async {
    await repository.addLog(
      exerciseType: 'Cycling',
      durationMinutes: 45,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
      calories: 300,
    );
    final export = await module.exportData();

    await repository.wipeAll();
    expect(await repository.allLogs(), isEmpty);

    await module.importData(export);
    final logs = await repository.allLogs();
    expect(logs, hasLength(1));
    expect(logs.first.calories, 300);
  });

  test('importData rejects a malformed workout', () async {
    final malformedExport = ModuleExport({
      'logs': [
        {
          'id': 'bad',
          'exerciseType': 'Running',
          'durationMinutes': 0,
          'loggedAt': DateTime.utc(2026, 6, 15, 8).toIso8601String(),
          'calories': null,
          'notes': null,
        },
      ],
    });

    await module.importData(malformedExport);

    expect(await repository.allLogs(), isEmpty);
  });
}
