import 'package:drift/drift.dart';

/// One of a medicine's (possibly several, D-02) schedules
/// (`technical/database-design.md`).
@DataClassName('MedicineScheduleRow')
class MedicineSchedulesTable extends Table {
  @override
  String get tableName => 'medicine_schedules';

  /// Row id.
  TextColumn get id => text()();

  /// Owning medicine.
  TextColumn get medicineId => text()();

  /// `'fixed_daily'` | `'every_n_days'` | `'weekday_set'` | `'prn'`.
  TextColumn get frequencyType => text()();

  /// Used only when `frequencyType = 'every_n_days'` (D-03).
  IntColumn get intervalDays => integer().nullable()();

  /// Bitmask Mon=1..Sun=64, used only for `'weekday_set'`.
  IntColumn get weekdaysMask => integer().nullable()();

  /// JSON array of local `"HH:mm"` strings.
  TextColumn get timesOfDay => text()();

  /// Local calendar date `"YYYY-MM-DD"`, anchor for `every_n_days` (D-03).
  TextColumn get startDate => text()();

  /// Local calendar date, null = open-ended.
  TextColumn get endDate => text().nullable()();

  /// Default 30, editable 0-180 (D-05).
  IntColumn get graceWindowMinutes =>
      integer().withDefault(const Constant(30))();

  /// UTC epoch millis — the D-02 collision-priority tiebreaker.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker; null = not deleted.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
