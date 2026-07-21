import 'package:drift/drift.dart';

/// A materialized prayer record (D-13) — one per prayer per local day,
/// rolling 30-day window.
@DataClassName('PrayerRecordRow')
@TableIndex(name: 'idx_prayer_records_scheduled_for', columns: {#scheduledFor})
class PrayerRecordsTable extends Table {
  @override
  String get tableName => 'prayer_records';

  /// Row id.
  TextColumn get id => text()();

  /// Local calendar date `"YYYY-MM-DD"` — materialized bucket key.
  TextColumn get prayerDate => text()();

  /// `'fajr'` | `'dhuhr'` | `'asr'` | `'maghrib'` | `'isha'` — Jumu'ah is
  /// a Friday display label over `'dhuhr'`, never its own stored value.
  TextColumn get prayerName => text()();

  /// UTC epoch millis, computed from `prayer_settings` + resolved
  /// location at generation time.
  IntColumn get scheduledFor => integer()();

  /// `'upcoming'` | `'prayed'` | `'missed'` only — `due` is derived at
  /// read time, never stored.
  TextColumn get status => text()();

  /// UTC epoch millis of the last explicit status change; null while
  /// still `upcoming`.
  IntColumn get statusChangedAt => integer().nullable()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker; null = not deleted.
  IntColumn get deletedAt => integer().nullable()();

  /// Optional free-text annotation on this specific prayer record.
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {prayerDate, prayerName},
  ];
}
