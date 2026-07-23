import 'package:drift/drift.dart';

/// The Water module's own singleton settings row — same
/// always-upsert-the-one-row pattern as `app_settings`
/// (`technical/database-design.md`).
///
/// **Added during Run 07 implementation:** `database-design.md`'s original
/// "Water module" section had no table for FR-W-03's configurable
/// quick-add presets or FR-W-10's reminder preferences — this table fills
/// that gap.
@DataClassName('WaterSettingsRow')
class WaterSettingsTable extends Table {
  @override
  String get tableName => 'water_settings';

  /// Always `'singleton'`.
  TextColumn get id => text()();

  /// JSON array of ml amounts, e.g. `"[250,500,750]"` (FR-W-03).
  TextColumn get quickAddAmountsMl => text()();

  /// FR-W-10; off by default.
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Minutes between reminders while [reminderEnabled].
  IntColumn get reminderIntervalMinutes =>
      integer().withDefault(const Constant(120))();

  /// Local `"HH:mm"` — reminders never fire before this time.
  TextColumn get reminderWindowStart =>
      text().withDefault(const Constant('08:00'))();

  /// Local `"HH:mm"` — reminders never fire after this time.
  TextColumn get reminderWindowEnd =>
      text().withDefault(const Constant('22:00'))();

  /// JSON object mapping weekday (1=Mon..7=Sun, string keys) to
  /// `{"start": "HH:mm", "end": "HH:mm"}`. Absent days fall back to
  /// [reminderWindowStart]/[reminderWindowEnd].
  TextColumn get reminderWindowOverrides =>
      text().withDefault(const Constant('{}'))();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
