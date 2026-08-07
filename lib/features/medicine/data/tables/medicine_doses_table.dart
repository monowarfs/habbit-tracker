import 'package:drift/drift.dart';

/// A materialized dose instance (D-13).
///
/// `grace_window_minutes` is denormalized from the generating schedule at
/// materialization time — an implementation refinement over
/// `technical/database-design.md`'s original column list, avoiding a join
/// back to `medicine_schedules` on the hottest read path (today's dose
/// list, adherence calc).
@DataClassName('MedicineDoseRow')
@TableIndex(name: 'idx_medicine_doses_scheduled_for', columns: {#scheduledFor})
@TableIndex(
  name: 'idx_medicine_doses_medicine_scheduled',
  columns: {#medicineId, #scheduledFor},
)
class MedicineDosesTable extends Table {
  @override
  String get tableName => 'medicine_doses';

  /// Row id.
  TextColumn get id => text()();

  /// Denormalized alongside `scheduleId` so a dose survives being queried
  /// even if its generating schedule is later edited/replaced.
  TextColumn get medicineId => text()();

  /// The schedule that generated this instance.
  TextColumn get scheduleId => text()();

  /// UTC epoch millis this dose is scheduled for.
  IntColumn get scheduledFor => integer()();

  /// `'upcoming'` | `'done'` | `'skipped'` only — `due`/`missed` are
  /// derived at read time (FR-M-06), never stored.
  TextColumn get status => text()();

  /// UTC epoch millis of the last explicit status change; null while
  /// still `upcoming`.
  IntColumn get statusChangedAt => integer().nullable()();

  /// How much stock this specific dose has deducted, so an undo reverses
  /// the exact right amount.
  IntColumn get stockDeltaApplied => integer().withDefault(const Constant(0))();

  /// Grace window (minutes) captured from the generating schedule.
  IntColumn get graceWindowMinutes => integer()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker; null = not deleted.
  IntColumn get deletedAt => integer().nullable()();

  /// Optional free-text annotation on this specific dose instance.
  TextColumn get notes => text().nullable()();

  /// Multi-profile scoping (`core/profiles/`); defaults to `'system'` for
  /// rows that pre-date profile support.
  TextColumn get profileId => text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {id};
}
