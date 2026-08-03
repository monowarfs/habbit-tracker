import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/mood/data/repositories/mood_repository_impl.dart';
import 'package:habit_tracker/features/mood/mood_module.dart';

void main() {
  late AppDatabase db;
  late MoodRepositoryImpl repository;
  late MoodModule module;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = MoodRepositoryImpl(db);
    module = MoodModule(repository);
  });

  tearDown(() async {
    await db.close();
  });

  test('dayStatus is complete only for days with a logged check-in', () async {
    await repository.addLog(
      moodValue: 4,
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
      'mood_first_log',
      'mood_streak_7',
      'mood_streak_30',
      'mood_streak_100',
    ]);
  });

  test('exportData/importData round-trips check-ins', () async {
    await repository.addLog(
      moodValue: 5,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
      notes: 'Great day',
    );
    final export = await module.exportData();

    await repository.wipeAll();
    expect(await repository.allLogs(), isEmpty);

    await module.importData(export);
    final logs = await repository.allLogs();
    expect(logs, hasLength(1));
    expect(logs.first.notes, 'Great day');
  });

  test('importData rejects a malformed check-in', () async {
    final malformedExport = ModuleExport({
      'logs': [
        {
          'id': 'bad',
          'moodValue': 9,
          'loggedAt': DateTime.utc(2026, 6, 15, 8).toIso8601String(),
          'notes': null,
        },
      ],
    });

    await module.importData(malformedExport);

    expect(await repository.allLogs(), isEmpty);
  });
}
