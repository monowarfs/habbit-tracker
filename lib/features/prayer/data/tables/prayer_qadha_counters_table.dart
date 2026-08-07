import 'package:drift/drift.dart';

/// One prayer's running Qadha balance (D-08) — exactly five rows, one per
/// prayer, seeded at first setup.
@DataClassName('PrayerQadhaCounterRow')
class PrayerQadhaCountersTable extends Table {
  @override
  String get tableName => 'prayer_qadha_counters';

  /// Row id.
  TextColumn get id => text()();

  /// `'fajr'` | `'dhuhr'` | `'asr'` | `'maghrib'` | `'isha'` — no
  /// `'jumuah'` row, it shares Dhuhr's bucket (D-07/FR-P-03).
  TextColumn get prayerName => text()();

  /// Default 0, floors at 0 (app-enforced).
  IntColumn get count => integer().withDefault(const Constant(0))();

  /// UTC epoch millis.
  IntColumn get updatedAt => integer()();

  /// Multi-profile scoping (`core/profiles/`); defaults to `'system'` for
  /// rows that pre-date profile support.
  TextColumn get profileId => text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {prayerName, profileId},
  ];
}
