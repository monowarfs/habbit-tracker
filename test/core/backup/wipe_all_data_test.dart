import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/backup/wipe_all_data.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';

void main() {
  test('wipes every module and every common table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final modules = buildHabitModules(db);

    await db
        .into(db.waterLogsTable)
        .insert(
          WaterLogsTableCompanion.insert(
            id: 'e1',
            amountMl: 250,
            loggedAt: 0,
            source: 'quick',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.achievementsTable)
        .insert(
          AchievementsTableCompanion.insert(
            id: 'a1',
            moduleId: 'water',
            key: 'water_first_log',
            progressCurrent: 1,
            progressTarget: 1,
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    await wipeAllAppData(modules, db);

    expect(await db.select(db.waterLogsTable).get(), isEmpty);
    expect(await db.select(db.achievementsTable).get(), isEmpty);
  });
}
