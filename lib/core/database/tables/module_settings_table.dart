import 'package:drift/drift.dart';

/// Per-module enable/disable settings — tracks which modules are active.
@DataClassName('ModuleSettingsRow')
class ModuleSettingsTable extends Table {
  @override
  String get tableName => 'module_settings';

  /// Module id: `'water'`, `'medicine'`, `'prayer'`.
  TextColumn get moduleId => text()();

  /// Whether this module is enabled.
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();

  /// Whether the user dismissed the suggestion card for this module.
  BoolColumn get suggestionDismissed =>
      boolean().withDefault(const Constant(false))();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Multi-profile scoping (`core/profiles/`); defaults to `'system'` for
  /// rows that pre-date profile support. Part of the primary key since
  /// [moduleId] alone is no longer unique once each profile has its own
  /// per-module enable/disable state.
  TextColumn get profileId =>
      text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {moduleId, profileId};
}
