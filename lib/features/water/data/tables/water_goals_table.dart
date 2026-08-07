import 'package:drift/drift.dart';

/// Append-only goal history (`technical/database-design.md`) — a goal
/// change inserts a new row rather than mutating the old one, so a past
/// day's applicable goal never silently changes (FR-W-04).
@DataClassName('WaterGoalRow')
@TableIndex(name: 'idx_water_goals_effective_from', columns: {#effectiveFrom})
class WaterGoalsTable extends Table {
  @override
  String get tableName => 'water_goals';

  /// Row id.
  TextColumn get id => text()();

  /// Canonical unit is always ml (D-01).
  IntColumn get goalMl => integer()();

  /// UTC epoch millis this goal took effect.
  IntColumn get effectiveFrom => integer()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker; null = not deleted.
  IntColumn get deletedAt => integer().nullable()();

  /// Archive marker; null = active. When set, the goal is hidden from
  /// active views and excluded from streak calculations.
  IntColumn get archivedAt => integer().nullable()();

  /// Multi-profile scoping (`core/profiles/`); defaults to `'system'` for
  /// rows that pre-date profile support.
  TextColumn get profileId => text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {id};
}
