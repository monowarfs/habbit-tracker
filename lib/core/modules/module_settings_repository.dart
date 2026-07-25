import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';

/// CRUD for the `module_settings` table — enable/disable per module.
class ModuleSettingsRepository {
  /// Creates a repository backed by the given database.
  const ModuleSettingsRepository(this._db);

  final AppDatabase _db;

  /// Whether [moduleId] is enabled. Defaults to `true` for Water,
  /// `false` for others if no row exists.
  Future<bool> isEnabled(String moduleId) async {
    final row =
        await (_db.select(_db.moduleSettingsTable)
              ..where((t) => t.moduleId.equals(moduleId))
              ..limit(1))
            .getSingleOrNull();
    return row?.enabled ?? (moduleId == 'water');
  }

  /// Stream of enabled state for [moduleId].
  Stream<bool> watchEnabled(String moduleId) {
    return (_db.select(_db.moduleSettingsTable)
          ..where((t) => t.moduleId.equals(moduleId))
          ..limit(1))
        .watchSingleOrNull()
        .map(
          (row) => row?.enabled ?? (moduleId == 'water'),
        );
  }

  /// Enables or disables [moduleId].
  Future<void> setEnabled(String moduleId, {required bool enabled}) async {
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    final existing =
        await (_db.select(_db.moduleSettingsTable)
              ..where((t) => t.moduleId.equals(moduleId))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      await (_db.update(
        _db.moduleSettingsTable,
      )..where((t) => t.moduleId.equals(moduleId))).write(
        ModuleSettingsTableCompanion(
          enabled: Value(enabled),
          updatedAt: Value(now),
        ),
      );
    } else {
      await _db
          .into(_db.moduleSettingsTable)
          .insert(
            ModuleSettingsTableCompanion.insert(
              moduleId: moduleId,
              enabled: Value(enabled),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  /// All enabled module ids.
  Future<Set<String>> enabledModuleIds() async {
    final rows = await (_db.select(
      _db.moduleSettingsTable,
    )..where((t) => t.enabled.equals(true))).get();
    return rows.map((r) => r.moduleId).toSet();
  }

  /// Marks a module's suggestion as dismissed.
  Future<void> dismissSuggestion(String moduleId) async {
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(
      _db.moduleSettingsTable,
    )..where((t) => t.moduleId.equals(moduleId))).write(
      ModuleSettingsTableCompanion(
        suggestionDismissed: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  /// Whether a module's suggestion has been dismissed.
  Future<bool> isSuggestionDismissed(String moduleId) async {
    final row =
        await (_db.select(_db.moduleSettingsTable)
              ..where((t) => t.moduleId.equals(moduleId))
              ..limit(1))
            .getSingleOrNull();
    return row?.suggestionDismissed ?? false;
  }
}
