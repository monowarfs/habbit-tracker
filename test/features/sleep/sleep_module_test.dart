import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/sleep/data/repositories/sleep_repository_impl.dart';
import 'package:habit_tracker/features/sleep/sleep_module.dart';

void main() {
  late AppDatabase db;
  late SleepRepositoryImpl repository;
  late SleepModule module;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = SleepRepositoryImpl(db);
    module = SleepModule(repository);
  });

  tearDown(() async {
    await db.close();
  });

  test('dayStatus is complete only for days with a logged wake time', () async {
    await repository.addLog(
      bedTime: DateTime.utc(2026, 6, 14, 22),
      wakeTime: DateTime.utc(2026, 6, 15, 6),
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

  test('achievementDefinitions use real streak keys, not goal-based ones', () {
    final keys = module.achievementDefinitions.map((a) => a.key).toList();
    expect(keys, [
      'sleep_first_log',
      'sleep_streak_7',
      'sleep_streak_30',
      'sleep_streak_100',
    ]);
  });

  test('exportData/importData round-trips logs', () async {
    await repository.addLog(
      bedTime: DateTime.utc(2026, 6, 14, 22),
      wakeTime: DateTime.utc(2026, 6, 15, 6),
      quality: 4,
    );
    final export = await module.exportData();

    await repository.wipeAll();
    expect(await repository.allLogs(), isEmpty);

    await module.importData(export);
    final logs = await repository.allLogs();
    expect(logs, hasLength(1));
    expect(logs.first.quality, 4);
  });
}
