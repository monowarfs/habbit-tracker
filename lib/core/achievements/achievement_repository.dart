import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/utils/uuid.dart';

/// Drift-backed CRUD over the `achievements` table
/// (`core/achievements/achievement_engine.dart`'s only data dependency).
class AchievementRepository {
  /// Creates a repository backed by [_db].
  AchievementRepository(this._db);

  final AppDatabase _db;

  /// Looks up a single achievement row by its stable [key], or `null` if
  /// it has never been evaluated.
  Future<AchievementRow?> byKey(String key) {
    return (_db.select(
      _db.achievementsTable,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
  }

  /// Every achievement row for [moduleId], live-updating.
  Stream<List<AchievementRow>> watchByModule(String moduleId) {
    return (_db.select(
      _db.achievementsTable,
    )..where((t) => t.moduleId.equals(moduleId))).watch();
  }

  /// Every achievement row across every module, live-updating — the
  /// badge gallery's source.
  Stream<List<AchievementRow>> watchAll() =>
      _db.select(_db.achievementsTable).watch();

  /// Creates or updates [key]'s progress row. Once `unlockedAt` is set it
  /// is never cleared or overwritten by a later, lower [current] — an
  /// achievement stays unlocked.
  Future<void> upsertProgress({
    required String moduleId,
    required String key,
    required int current,
    required int target,
    required DateTime now,
  }) async {
    final nowMillis = now.millisecondsSinceEpoch;
    final existing = await byKey(key);
    if (existing == null) {
      await _db
          .into(_db.achievementsTable)
          .insert(
            AchievementsTableCompanion.insert(
              id: generateId(),
              moduleId: moduleId,
              key: key,
              progressCurrent: current,
              progressTarget: target,
              unlockedAt: Value(current >= target ? nowMillis : null),
              createdAt: nowMillis,
              updatedAt: nowMillis,
            ),
          );
      return;
    }
    final justUnlocked = existing.unlockedAt == null && current >= target;
    await (_db.update(
      _db.achievementsTable,
    )..where((t) => t.id.equals(existing.id))).write(
      AchievementsTableCompanion(
        progressCurrent: Value(current),
        progressTarget: Value(target),
        unlockedAt: Value(justUnlocked ? nowMillis : existing.unlockedAt),
        updatedAt: Value(nowMillis),
      ),
    );
  }

  /// Restores an achievement row exactly as given (import's replace
  /// step) — bypasses [upsertProgress]'s unlock-timestamp-preservation
  /// logic, since a restore should reproduce recorded history exactly,
  /// not recompute it.
  Future<void> restoreRow({
    required String moduleId,
    required String key,
    required int progressCurrent,
    required int progressTarget,
    DateTime? unlockedAt,
  }) async {
    final now = clock.now().millisecondsSinceEpoch;
    await _db
        .into(_db.achievementsTable)
        .insert(
          AchievementsTableCompanion.insert(
            id: generateId(),
            moduleId: moduleId,
            key: key,
            progressCurrent: progressCurrent,
            progressTarget: progressTarget,
            unlockedAt: Value(unlockedAt?.millisecondsSinceEpoch),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}
