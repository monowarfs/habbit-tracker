import 'package:drift/drift.dart';

/// Append-only stock ledger (`technical/database-design.md`) —
/// `medicines.stock_count` is a cached/derived value, this table is the
/// source of truth for "why did stock change."
@DataClassName('MedicineStockEventRow')
class MedicineStockEventsTable extends Table {
  @override
  String get tableName => 'medicine_stock_events';

  /// Row id.
  TextColumn get id => text()();

  /// Owning medicine.
  TextColumn get medicineId => text()();

  /// Null for manual refills/adjustments not tied to a dose.
  TextColumn get doseId => text().nullable()();

  /// Negative = consumption, positive = refill/adjustment.
  IntColumn get delta => integer()();

  /// `'dose_taken'` | `'manual_refill'` | `'manual_adjustment'` |
  /// `'dose_undone'`.
  TextColumn get reason => text()();

  /// UTC epoch millis.
  IntColumn get occurredAt => integer()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker; null = not deleted.
  IntColumn get deletedAt => integer().nullable()();

  /// Multi-profile scoping (`core/profiles/`); defaults to `'system'` for
  /// rows that pre-date profile support.
  TextColumn get profileId =>
      text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {id};
}
