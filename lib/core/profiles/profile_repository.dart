import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/profiles/profile.dart';
import 'package:habit_tracker/core/utils/uuid.dart';

const _systemProfileId = 'system';
const _appSettingsSingletonId = 'singleton';

/// CRUD for the `profiles` table (family/multi-profile,
/// `docs/superpowers/specs/04-premium/03-family-multi-profile-design.md`)
/// — local-only, single-device profile switching. Every table scoped by
/// `profile_id` (Task 2's migration) funnels its reads/writes through
/// whichever profile [getActiveProfile]/[setActiveProfile] currently
/// point at.
class ProfileRepository {
  /// Creates a repository backed by [_db].
  ProfileRepository(this._db);

  final AppDatabase _db;

  /// Max profiles per device (design doc's review checklist).
  static const maxProfiles = 5;

  /// Guarantees at least one *live* profile exists — checks for any
  /// non-deleted row, not specifically `'system'`, so deliberately
  /// deleting the `'system'` profile while another profile remains
  /// doesn't resurrect a phantom "Me" profile on the next read. Only
  /// actually seeds `'system'` on a truly fresh install (createAll, not
  /// a migration — the Task 2 migration seeds this row itself for
  /// upgrading users) or the never-reachable-in-practice case of zero
  /// live profiles ([deleteProfile] itself refuses to drop the last one).
  Future<void> _ensureSystemProfile() async {
    final anyLive =
        await (_db.select(_db.profilesTable)
              ..where((t) => t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    if (anyLive != null) return;
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await _db
        .into(_db.profilesTable)
        .insertOnConflictUpdate(
          ProfilesTableCompanion.insert(
            id: _systemProfileId,
            displayName: 'Me',
            avatarColor: 'teal',
            createdAt: now,
            deletedAt: const Value(null),
          ),
        );
  }

  /// All non-deleted profiles, oldest first.
  Future<List<Profile>> listProfiles() async {
    await _ensureSystemProfile();
    final rows =
        await (_db.select(_db.profilesTable)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
            .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  /// Creates a new profile. Throws [StateError] past [maxProfiles].
  Future<Profile> createProfile(String name, String color) async {
    final existing = await listProfiles();
    if (existing.length >= maxProfiles) {
      throw StateError('Maximum of $maxProfiles profiles reached');
    }
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    final row = ProfileRow(
      id: generateId(),
      displayName: name,
      avatarColor: color,
      createdAt: now,
    );
    await _db.into(_db.profilesTable).insert(row);
    return row.toDomain();
  }

  /// Updates [id]'s display name and/or avatar color.
  Future<void> updateProfile(String id, {String? name, String? color}) {
    return (_db.update(
      _db.profilesTable,
    )..where((t) => t.id.equals(id))).write(
      ProfilesTableCompanion(
        displayName: name != null ? Value(name) : const Value.absent(),
        avatarColor: color != null ? Value(color) : const Value.absent(),
      ),
    );
  }

  /// Soft-deletes profile [id] and every row scoped to it — hard-deletes
  /// on the tables that have no soft-delete column of their own (settings
  /// singletons, ledgers with no undo path). Throws [StateError] deleting
  /// the last remaining profile. If [id] was the active profile, the
  /// active pointer falls back to the oldest remaining one.
  Future<void> deleteProfile(String id) async {
    final remaining = await listProfiles();
    if (remaining.length <= 1) {
      throw StateError('Cannot delete the last remaining profile');
    }

    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction(() async {
      // Soft-delete: tables with their own deletedAt column.
      await (_db.update(
        _db.notificationLedgerTable,
      )..where((t) => t.profileId.equals(id))).write(
        NotificationLedgerTableCompanion(deletedAt: Value(now)),
      );
      await (_db.update(
        _db.achievementsTable,
      )..where((t) => t.profileId.equals(id))).write(
        AchievementsTableCompanion(deletedAt: Value(now)),
      );
      await (_db.update(
        _db.waterGoalsTable,
      )..where((t) => t.profileId.equals(id))).write(
        WaterGoalsTableCompanion(deletedAt: Value(now)),
      );
      await (_db.update(
        _db.waterLogsTable,
      )..where((t) => t.profileId.equals(id))).write(
        WaterLogsTableCompanion(deletedAt: Value(now)),
      );
      await (_db.update(
        _db.medicinesTable,
      )..where((t) => t.profileId.equals(id))).write(
        MedicinesTableCompanion(deletedAt: Value(now)),
      );
      await (_db.update(
        _db.medicineSchedulesTable,
      )..where((t) => t.profileId.equals(id))).write(
        MedicineSchedulesTableCompanion(deletedAt: Value(now)),
      );
      await (_db.update(
        _db.medicineDosesTable,
      )..where((t) => t.profileId.equals(id))).write(
        MedicineDosesTableCompanion(deletedAt: Value(now)),
      );
      await (_db.update(
        _db.medicineStockEventsTable,
      )..where((t) => t.profileId.equals(id))).write(
        MedicineStockEventsTableCompanion(deletedAt: Value(now)),
      );
      await (_db.update(
        _db.prayerRecordsTable,
      )..where((t) => t.profileId.equals(id))).write(
        PrayerRecordsTableCompanion(deletedAt: Value(now)),
      );
      await (_db.update(
        _db.sleepLogsTable,
      )..where((t) => t.profileId.equals(id))).write(
        SleepLogsTableCompanion(deletedAt: Value(now)),
      );
      await (_db.update(
        _db.bpLogsTable,
      )..where((t) => t.profileId.equals(id))).write(
        BpLogsTableCompanion(deletedAt: Value(now)),
      );
      await (_db.update(
        _db.moodLogsTable,
      )..where((t) => t.profileId.equals(id))).write(
        MoodLogsTableCompanion(deletedAt: Value(now)),
      );
      await (_db.update(
        _db.exerciseLogsTable,
      )..where((t) => t.profileId.equals(id))).write(
        ExerciseLogsTableCompanion(deletedAt: Value(now)),
      );

      // Hard-delete: tables with no soft-delete column.
      await (_db.delete(
        _db.habitStackSuggestionsTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.recapsTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.pauseRangesTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.recalibrationMarkersTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.moduleSettingsTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.cosmeticUnlocksTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.avatarEquippedTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.xpLedgerTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.xpBalanceTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.shopUnlocksTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.personalRecordsTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.weeklyQuestsTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.waterSettingsTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.prayerSettingsTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.prayerQadhaCountersTable,
      )..where((t) => t.profileId.equals(id))).go();

      await (_db.update(
        _db.profilesTable,
      )..where((t) => t.id.equals(id))).write(
        ProfilesTableCompanion(deletedAt: Value(now)),
      );

      final settings =
          await (_db.select(_db.appSettingsTable)..where(
                (t) => t.id.equals(_appSettingsSingletonId),
              ))
              .getSingleOrNull();
      if (settings?.activeProfileId == id) {
        final fallback = remaining.firstWhere((p) => p.id != id);
        await (_db.update(_db.appSettingsTable)..where(
              (t) => t.id.equals(_appSettingsSingletonId),
            ))
            .write(
              AppSettingsTableCompanion(
                activeProfileId: Value(fallback.id),
              ),
            );
      }
    });
  }

  /// The currently active profile, falling back to the oldest live
  /// profile if the active pointer is unset or stale (pointing at a
  /// deleted or nonexistent profile).
  Future<Profile> getActiveProfile() async {
    await _ensureSystemProfile();
    final settings = await (_db.select(
      _db.appSettingsTable,
    )..where((t) => t.id.equals(_appSettingsSingletonId))).getSingleOrNull();
    final activeId = settings?.activeProfileId ?? _systemProfileId;
    final row =
        await (_db.select(_db.profilesTable)..where(
              (t) => t.id.equals(activeId) & t.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (row != null) return row.toDomain();
    // _ensureSystemProfile() above guarantees at least one live profile
    // exists by this point — fall back to the oldest one, not
    // specifically 'system' (which may itself be the deleted profile
    // that made activeId stale in the first place).
    final fallback =
        await (_db.select(_db.profilesTable)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
              ..limit(1))
            .getSingle();
    return fallback.toDomain();
  }

  /// Approximate data volume for [id] — counts rows across each module's
  /// main per-entry table (Water logs, Medicine doses, Prayer records).
  /// Not an exhaustive byte-accurate total (that would mean summing all
  /// 28 profile-scoped tables for a number nobody reads that precisely);
  /// good enough for the manage-profiles screen's "N items" label.
  Future<int> dataItemCount(String id) async {
    final waterLogs =
        await (_db.selectOnly(_db.waterLogsTable)
              ..addColumns([_db.waterLogsTable.id.count()])
              ..where(
                _db.waterLogsTable.profileId.equals(id) &
                    _db.waterLogsTable.deletedAt.isNull(),
              ))
            .getSingle();
    final medicineDoses =
        await (_db.selectOnly(_db.medicineDosesTable)
              ..addColumns([_db.medicineDosesTable.id.count()])
              ..where(
                _db.medicineDosesTable.profileId.equals(id) &
                    _db.medicineDosesTable.deletedAt.isNull(),
              ))
            .getSingle();
    final prayerRecords =
        await (_db.selectOnly(_db.prayerRecordsTable)
              ..addColumns([_db.prayerRecordsTable.id.count()])
              ..where(
                _db.prayerRecordsTable.profileId.equals(id) &
                    _db.prayerRecordsTable.deletedAt.isNull(),
              ))
            .getSingle();
    final waterCount = waterLogs.read(_db.waterLogsTable.id.count())!;
    final medicineCount = medicineDoses.read(
      _db.medicineDosesTable.id.count(),
    )!;
    final prayerCount = prayerRecords.read(
      _db.prayerRecordsTable.id.count(),
    )!;
    return waterCount + medicineCount + prayerCount;
  }

  /// Switches the active profile to [id]. No-ops if the `app_settings`
  /// singleton row doesn't exist yet — safe in practice since app boot
  /// always seeds it (`SettingsRepositoryImpl._ensureSeeded`) before any
  /// profile-switching UI is reachable.
  Future<void> setActiveProfile(String id) {
    return (_db.update(_db.appSettingsTable)..where(
          (t) => t.id.equals(_appSettingsSingletonId),
        ))
        .write(AppSettingsTableCompanion(activeProfileId: Value(id)));
  }
}
