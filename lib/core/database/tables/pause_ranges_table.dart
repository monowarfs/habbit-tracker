import 'package:drift/drift.dart';

/// Date-range exclusion for a module — "travel", "illness", etc.
/// Paused days are excluded from streak calculations and dayStatus
/// returns `paused` for them.
@DataClassName('PauseRangeRow')
class PauseRangesTable extends Table {
  @override
  String get tableName => 'pause_ranges';

  /// Row id.
  TextColumn get id => text()();

  /// Module this pause applies to: `'water'`, `'medicine'`, `'prayer'`.
  TextColumn get moduleId => text()();

  /// Local calendar date `"YYYY-MM-DD"` (inclusive).
  TextColumn get startDate => text()();

  /// Local calendar date `"YYYY-MM-DD"` (inclusive).
  TextColumn get endDate => text()();

  /// UTC epoch millis when this pause was created.
  IntColumn get createdAt => integer()();

  /// Multi-profile scoping (`core/profiles/`); defaults to `'system'` for
  /// rows that pre-date profile support.
  TextColumn get profileId =>
      text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {id};
}
