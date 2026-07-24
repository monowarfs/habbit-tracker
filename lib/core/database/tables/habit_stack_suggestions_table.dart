import 'package:drift/drift.dart';

/// One tracked source-module -> Water correlation candidate
/// (`docs/superpowers/specs/02-delightful/
/// 04-habit-stacking-suggestions-design.md`). At most two rows exist in
/// v1 (`id` `'medicine_water'`/`'prayer_water'`) — a small, independently
/// queryable, multi-row table, following `achievements_table.dart`'s and
/// `notification_ledger_table.dart`'s precedent rather than a JSON blob
/// crammed into `app_settings` (which is a true singleton).
@DataClassName('HabitStackSuggestionRow')
class HabitStackSuggestionsTable extends Table {
  @override
  String get tableName => 'habit_stack_suggestions';

  /// Deterministic: `'{sourceModuleId}_{targetModuleId}'`, e.g.
  /// `'medicine_water'`.
  TextColumn get id => text()();

  /// `'medicine'` | `'prayer'` in v1.
  TextColumn get sourceModuleId => text()();

  /// Always `'water'` in v1 — Medicine/Prayer have no movable-reminder
  /// concept to retime.
  TextColumn get targetModuleId => text()();

  /// `'pending'` | `'accepted'` | `'dismissed'`.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Days (of the trailing window) a same-day Water log followed the
  /// source action within the gap cap.
  IntColumn get qualifyingDays => integer()();

  /// Median source-action -> water-log gap, in minutes.
  IntColumn get medianGapMinutes => integer()();

  /// `"HH:mm"` — median source-action wall-clock time, the anchor an
  /// accepted suggestion nudges Water's reminder window to.
  TextColumn get typicalSourceTime => text()();

  /// Human-readable label for the source action, e.g. `'Fajr'` for the
  /// prayer pair — `null` for the medicine pair (Medicine has only one
  /// kind of dose-completion event, nothing to name). **Added beyond the
  /// design doc's original column list** to fill the `{prayer}`
  /// placeholder in `habitStackSuggestionPrayerToWater` — the doc's
  /// `{prayer}` UI copy assumes a nameable source action, but its own
  /// table schema had nowhere to store one.
  TextColumn get sourceLabel => text().nullable()();

  /// UTC epoch millis of the last time this pair was evaluated —
  /// backs the 24h cheap-early-exit re-evaluation guard.
  IntColumn get lastEvaluatedAt => integer()();

  /// UTC epoch millis the user last accepted/dismissed this suggestion;
  /// null while `pending`.
  IntColumn get respondedAt => integer().nullable()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
