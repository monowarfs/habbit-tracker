import 'package:drift/drift.dart';

/// Schema-only groundwork (`database-design.md`) — no achievement UI/logic
/// ships in v1.0; this table exists so a future gamification feature has a
/// home without a schema migration.
@DataClassName('AchievementRow')
class AchievementsTable extends Table {
  @override
  String get tableName => 'achievements';

  /// Row id.
  TextColumn get id => text()();

  /// Which module this achievement belongs to.
  TextColumn get moduleId => text()();

  /// E.g. `'water_7_day_streak'`.
  TextColumn get key => text()();

  /// Current progress toward [progressTarget].
  IntColumn get progressCurrent => integer()();

  /// Progress needed to unlock.
  IntColumn get progressTarget => integer()();

  /// UTC epoch millis; null = not yet unlocked.
  IntColumn get unlockedAt => integer().nullable()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker; null = not deleted.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
