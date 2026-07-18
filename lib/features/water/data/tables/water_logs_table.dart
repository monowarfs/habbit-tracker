import 'package:drift/drift.dart';

/// A water-intake log row (`technical/database-design.md`).
///
/// **Correction from Run 07 implementation:** `database-design.md`'s
/// original `water_logs` schema had no `source` column; this run adds one
/// to distinguish quick-add (FR-W-03) from custom-amount entries, per this
/// run's own explicit scope.
@DataClassName('WaterLogRow')
@TableIndex(name: 'idx_water_logs_logged_at', columns: {#loggedAt})
class WaterLogsTable extends Table {
  @override
  String get tableName => 'water_logs';

  /// Row id.
  TextColumn get id => text()();

  /// Canonical unit is always ml regardless of display unit (D-01).
  IntColumn get amountMl => integer()();

  /// UTC epoch millis this entry represents (may be backdated, FR-W-05).
  IntColumn get loggedAt => integer()();

  /// `'quick'` | `'custom'`.
  TextColumn get source => text()();

  /// UTC epoch millis. Differs from [loggedAt] exactly when an entry was
  /// backdated.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker; null = not deleted.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
