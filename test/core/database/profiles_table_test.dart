import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test(
    'two profiles can each have their own singleton-style settings row',
    () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db
          .into(db.profilesTable)
          .insert(
            ProfilesTableCompanion.insert(
              id: 'system',
              displayName: 'Me',
              avatarColor: 'teal',
              createdAt: now,
            ),
          );
      await db
          .into(db.profilesTable)
          .insert(
            ProfilesTableCompanion.insert(
              id: 'kid',
              displayName: 'Kid',
              avatarColor: 'blue',
              createdAt: now,
            ),
          );

      await db
          .into(db.waterSettingsTable)
          .insert(
            WaterSettingsTableCompanion.insert(
              id: 'singleton',
              quickAddAmountsMl: '[250,500,750]',
              createdAt: now,
              updatedAt: now,
              profileId: const Value('system'),
            ),
          );
      await db
          .into(db.waterSettingsTable)
          .insert(
            WaterSettingsTableCompanion.insert(
              id: 'singleton',
              quickAddAmountsMl: '[100,200,300]',
              createdAt: now,
              updatedAt: now,
              profileId: const Value('kid'),
            ),
          );

      final rows = await db.select(db.waterSettingsTable).get();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.profileId), containsAll(['system', 'kid']));
    },
  );

  test(
    'module_settings composite PK allows same moduleId across profiles',
    () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db
          .into(db.moduleSettingsTable)
          .insert(
            ModuleSettingsTableCompanion.insert(
              moduleId: 'water',
              createdAt: now,
              updatedAt: now,
              profileId: const Value('system'),
            ),
          );
      await db
          .into(db.moduleSettingsTable)
          .insert(
            ModuleSettingsTableCompanion.insert(
              moduleId: 'water',
              createdAt: now,
              updatedAt: now,
              profileId: const Value('kid'),
            ),
          );

      final rows = await db.select(db.moduleSettingsTable).get();
      expect(rows, hasLength(2));
    },
  );
}
