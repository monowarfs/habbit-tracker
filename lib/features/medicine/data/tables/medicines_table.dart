import 'package:drift/drift.dart';

/// A medicine record (`technical/database-design.md`).
///
/// `low_stock_notified_at` is an addition beyond that doc's original
/// column list — it makes FR-M-04's "one notification per threshold
/// crossing" possible without a background scan: set the instant stock
/// crosses at/below `stock_threshold`, cleared on the next refill that
/// brings it back above threshold.
@DataClassName('MedicineRow')
class MedicinesTable extends Table {
  @override
  String get tableName => 'medicines';

  /// Row id.
  TextColumn get id => text()();

  /// Medicine name.
  TextColumn get name => text()();

  /// Free-text dosage note, e.g. `"500mg"`.
  TextColumn get dosageNote => text().nullable()();

  /// Whether stock tracking is enabled for this medicine.
  BoolColumn get stockEnabled => boolean()();

  /// Current stock count, if tracking is enabled.
  IntColumn get stockCount => integer().nullable()();

  /// Low-stock trigger point.
  IntColumn get stockThreshold => integer().nullable()();

  /// D-04: default false — zero stock alone never ends the schedule.
  BoolColumn get stopWhenStockDepleted =>
      boolean().withDefault(const Constant(false))();

  /// Units consumed per dose marked done.
  IntColumn get consumptionPerDose =>
      integer().withDefault(const Constant(1))();

  /// UTC epoch millis of the last low-stock crossing not yet cleared by a
  /// refill; null if not currently in a "just crossed" state.
  IntColumn get lowStockNotifiedAt => integer().nullable()();

  /// FR-M-10 soft-archive; null = active.
  IntColumn get archivedAt => integer().nullable()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker; null = not deleted.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
