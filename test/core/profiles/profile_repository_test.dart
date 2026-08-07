import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/profiles/profile_repository.dart';

void main() {
  late AppDatabase db;
  late ProfileRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProfileRepository(db);
  });

  tearDown(() => db.close());

  test(
    'listProfiles seeds and returns the system profile on first read',
    () async {
      final profiles = await repo.listProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.single.id, 'system');
    },
  );

  test('getActiveProfile falls back to system when unset', () async {
    final active = await repo.getActiveProfile();
    expect(active.id, 'system');
  });

  test('createProfile adds a profile and enforces the max limit', () async {
    for (var i = 0; i < ProfileRepository.maxProfiles - 1; i++) {
      await repo.createProfile('Kid $i', 'blue');
    }
    expect(await repo.listProfiles(), hasLength(ProfileRepository.maxProfiles));

    expect(
      () => repo.createProfile('One too many', 'red'),
      throwsA(isA<StateError>()),
    );
  });

  test('deleteProfile refuses to delete the last remaining profile', () async {
    expect(
      () => repo.deleteProfile('system'),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'deleteProfile soft-deletes scoped rows and falls back the active pointer',
    () async {
      final kid = await repo.createProfile('Kid', 'blue');
      await repo.setActiveProfile(kid.id);

      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await db
          .into(db.waterLogsTable)
          .insert(
            WaterLogsTableCompanion.insert(
              id: 'log1',
              amountMl: 250,
              loggedAt: now,
              source: 'quick',
              createdAt: now,
              updatedAt: now,
              profileId: Value(kid.id),
            ),
          );
      await db
          .into(db.waterSettingsTable)
          .insert(
            WaterSettingsTableCompanion.insert(
              id: 'singleton',
              quickAddAmountsMl: '[250]',
              createdAt: now,
              updatedAt: now,
              profileId: Value(kid.id),
            ),
          );

      await repo.deleteProfile(kid.id);

      final log = await (db.select(
        db.waterLogsTable,
      )..where((t) => t.id.equals('log1'))).getSingle();
      expect(log.deletedAt, isNot(null));

      final settingsRows = await (db.select(
        db.waterSettingsTable,
      )..where((t) => t.profileId.equals(kid.id))).get();
      expect(settingsRows, isEmpty);

      final active = await repo.getActiveProfile();
      expect(active.id, 'system');

      final profiles = await repo.listProfiles();
      expect(profiles.map((p) => p.id), isNot(contains(kid.id)));
    },
  );
}
