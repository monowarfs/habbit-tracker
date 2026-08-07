import 'package:drift/drift.dart';

/// Per-module recalibration prompt tracking — when the prompt was last
/// shown, when the goal was last edited, and how many times the user
/// dismissed consecutively (for fatigue backoff).
@DataClassName('RecalibrationMarkerRow')
class RecalibrationMarkersTable extends Table {
  @override
  String get tableName => 'recalibration_markers';

  /// Module this marker applies to: `'water'`, `'medicine'`.
  TextColumn get moduleId => text()();

  /// UTC epoch millis when the recalibration prompt was last shown.
  IntColumn get lastShownAt => integer()();

  /// UTC epoch millis when the goal/schedule was last edited.
  IntColumn get lastGoalEditedAt => integer()();

  /// How many times the user dismissed consecutively (resets on confirm/edit).
  IntColumn get consecutiveDismissals =>
      integer().withDefault(const Constant(0))();

  /// Multi-profile scoping (`core/profiles/`); defaults to `'system'` for
  /// rows that pre-date profile support. Part of the primary key since
  /// [moduleId] alone is no longer unique once each profile has its own
  /// recalibration marker.
  TextColumn get profileId =>
      text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {moduleId, profileId};
}
