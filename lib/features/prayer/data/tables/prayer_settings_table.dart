import 'package:drift/drift.dart';

/// The Prayer module's singleton settings row (`technical/database-
/// design.md`).
///
/// `notifications_enabled`/`pre_reminder_enabled`/
/// `pre_reminder_offset_minutes` are additions beyond that doc's original
/// column list (FR-P-08's reminder controls) — same "settings gained a
/// reminder column mid-run" precedent as `water_settings`.
@DataClassName('PrayerSettingsRow')
class PrayerSettingsTable extends Table {
  @override
  String get tableName => 'prayer_settings';

  /// Row id — always `'singleton'`.
  TextColumn get id => text()();

  /// D-06.
  TextColumn get calculationMethod => text()();

  /// `'standard'` | `'hanafi'` (D-06).
  TextColumn get asrMethod => text()();

  /// Default false (D-07).
  BoolColumn get observesJumuah =>
      boolean().withDefault(const Constant(false))();

  /// `'auto'` | `'manual'` (D-09).
  TextColumn get locationMode => text()();

  /// Used when `locationMode = 'manual'`.
  RealColumn get manualLatitude => real().nullable()();

  /// Used when `locationMode = 'manual'`.
  RealColumn get manualLongitude => real().nullable()();

  /// IANA tz id, e.g. `"Asia/Dhaka"`.
  TextColumn get manualTimezone => text().nullable()();

  /// Local `"HH:mm"`, default `"00:00"` (D-08 cutoff).
  TextColumn get ishaDayRolloverTime =>
      text().withDefault(const Constant('00:00'))();

  /// FR-P-08 — default true (unlike Water's reminders, which default off).
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();

  /// FR-P-08's optional pre-prayer reminder.
  BoolColumn get preReminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Minutes before `scheduledFor`.
  IntColumn get preReminderOffsetMinutes =>
      integer().withDefault(const Constant(10))();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
