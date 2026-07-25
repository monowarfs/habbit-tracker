import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';

/// CRUD for the `recalibration_markers` table.
class RecalibrationRepository {
  /// Creates a repository backed by the given database.
  const RecalibrationRepository(this._db);

  final AppDatabase _db;

  /// Gets the marker for [moduleId], seeding defaults if absent.
  Future<RecalibrationMarkerRow> forModule(String moduleId) async {
    final row =
        await (_db.select(_db.recalibrationMarkersTable)
              ..where((t) => t.moduleId.equals(moduleId))
              ..limit(1))
            .getSingleOrNull();
    if (row != null) return row;

    // Seed with install date as the baseline.
    final settingsRow =
        await (_db.select(_db.appSettingsTable)
              ..where((t) => t.id.equals('singleton'))
              ..limit(1))
            .getSingleOrNull();
    final installAt =
        settingsRow?.installDate ?? clock.now().toUtc().millisecondsSinceEpoch;

    final seeded = RecalibrationMarkerRow(
      moduleId: moduleId,
      lastShownAt: installAt,
      lastGoalEditedAt: installAt,
      consecutiveDismissals: 0,
    );
    await _db.into(_db.recalibrationMarkersTable).insert(seeded);
    return seeded;
  }

  /// Records that the prompt was shown now.
  Future<void> markShown(String moduleId) async {
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(
      _db.recalibrationMarkersTable,
    )..where((t) => t.moduleId.equals(moduleId))).write(
      RecalibrationMarkersTableCompanion(
        lastShownAt: Value(now),
      ),
    );
  }

  /// Records that the user dismissed with "Still right" (resets to 90 days).
  Future<void> markConfirmed(String moduleId) async {
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(
      _db.recalibrationMarkersTable,
    )..where((t) => t.moduleId.equals(moduleId))).write(
      RecalibrationMarkersTableCompanion(
        lastGoalEditedAt: Value(now),
        consecutiveDismissals: const Value(0),
      ),
    );
  }

  /// Records that the user dismissed with "Remind later" (resets to 30 days).
  Future<void> markDeferred(String moduleId) async {
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    final current = await forModule(moduleId);
    await (_db.update(
      _db.recalibrationMarkersTable,
    )..where((t) => t.moduleId.equals(moduleId))).write(
      RecalibrationMarkersTableCompanion(
        lastShownAt: Value(now),
        consecutiveDismissals: Value(current.consecutiveDismissals + 1),
      ),
    );
  }

  /// Records that the goal was edited (resets timer to now = 90 days out).
  Future<void> markGoalEdited(String moduleId) async {
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(
      _db.recalibrationMarkersTable,
    )..where((t) => t.moduleId.equals(moduleId))).write(
      RecalibrationMarkersTableCompanion(
        lastGoalEditedAt: Value(now),
        consecutiveDismissals: const Value(0),
      ),
    );
  }
}
