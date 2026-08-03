import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/blood_pressure/blood_pressure_module.dart';
import 'package:habit_tracker/features/blood_pressure/data/repositories/bp_repository_impl.dart';

void main() {
  late AppDatabase db;
  late BpRepositoryImpl repository;
  late BloodPressureModule module;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = BpRepositoryImpl(db);
    module = BloodPressureModule(repository);
  });

  tearDown(() async {
    await db.close();
  });

  test('dayStatus is complete only for days with a logged reading', () async {
    await repository.addLog(
      systolic: 118,
      diastolic: 76,
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
      'bp_first_log',
      'bp_streak_7',
      'bp_streak_30',
      'bp_streak_100',
    ]);
  });

  test('exportData/importData round-trips readings', () async {
    await repository.addLog(
      systolic: 150,
      diastolic: 95,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
      pulse: 72,
    );
    final export = await module.exportData();

    await repository.wipeAll();
    expect(await repository.allLogs(), isEmpty);

    await module.importData(export);
    final logs = await repository.allLogs();
    expect(logs, hasLength(1));
    expect(logs.first.pulse, 72);
  });

  test('importData rejects a malformed reading', () async {
    final malformedExport = ModuleExport({
      'logs': [
        {
          'id': 'bad',
          'systolic': 100,
          'diastolic': 110,
          'loggedAt': DateTime.utc(2026, 6, 15, 8).toIso8601String(),
          'pulse': null,
          'notes': null,
        },
      ],
    });

    await module.importData(malformedExport);

    expect(await repository.allLogs(), isEmpty);
  });
}
