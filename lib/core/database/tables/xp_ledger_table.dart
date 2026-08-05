import 'package:drift/drift.dart';

/// Append-only XP award history — one row per award, source of truth for
/// `xp_balance`'s running total and the XP-history screen.
@DataClassName('XpLedgerRow')
class XpLedgerTable extends Table {
  @override
  String get tableName => 'xp_ledger';

  /// Row id.
  TextColumn get id => text()();

  /// Which module this award came from (`'water'`/`'medicine'`/`'prayer'`,
  /// or `'system'` for cross-module bonuses like a combo/quest/boss award).
  TextColumn get moduleId => text()();

  /// `'action'` | `'day_complete'` | `'streak_milestone'` | `'combo_bonus'`
  /// | `'weekly_quest_complete'` | `'boss_cleared'`.
  TextColumn get eventType => text()();

  /// XP granted by this award.
  IntColumn get xpAmount => integer()();

  /// The triggering record (dose id, prayer record id, achievement key,
  /// quest key, a day's `LocalDate.toIso()`, ...), or null. Together with
  /// [moduleId]/[eventType] this is what `XpRepository.hasAwarded` checks
  /// to keep idempotent event types (day-complete, quest/boss claims) from
  /// double-awarding.
  TextColumn get sourceId => text().nullable()();

  /// UTC epoch millis when this award was recorded.
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
