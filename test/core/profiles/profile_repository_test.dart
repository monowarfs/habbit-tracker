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

  test(
    "deleting the 'system' profile while another remains doesn't "
    'resurrect a phantom one, and getActiveProfile falls back to the '
    'remaining live profile instead of the soft-deleted row',
    () async {
      final kid = await repo.createProfile('Kid', 'blue');

      await repo.deleteProfile('system');

      // listProfiles() (and its own _ensureSystemProfile() call) must
      // not bring 'system' back just because it's the one that got
      // deleted — a live profile (kid) still exists.
      final profiles = await repo.listProfiles();
      expect(profiles.map((p) => p.id), isNot(contains('system')));
      expect(profiles.map((p) => p.id), [kid.id]);

      // No app_settings row exists in this test's fresh in-memory db, so
      // activeId defaults to the literal 'system' id, which is now
      // deleted — getActiveProfile must fall back to the remaining live
      // profile (kid), not resolve/resurrect the deleted 'system' row.
      final active = await repo.getActiveProfile();
      expect(active.id, kid.id);

      final systemRow = await (db.select(
        db.profilesTable,
      )..where((t) => t.id.equals('system'))).getSingle();
      expect(systemRow.deletedAt, isNot(null));
    },
  );

  test(
    'setLeaderboardOptedOut defaults to false and can be toggled',
    () async {
      final profile = (await repo.listProfiles()).single;
      expect(profile.leaderboardOptedOut, isFalse);

      await repo.setLeaderboardOptedOut(profile.id, optedOut: true);
      expect(
        (await repo.listProfiles()).single.leaderboardOptedOut,
        isTrue,
      );

      await repo.setLeaderboardOptedOut(profile.id, optedOut: false);
      expect(
        (await repo.listProfiles()).single.leaderboardOptedOut,
        isFalse,
      );
    },
  );
}
