import 'package:drift/drift.dart';

/// Single-row running XP total (id `'singleton'`) — denormalized off
/// `xp_ledger` so reading the current level never needs to sum the
/// whole ledger.
@DataClassName('XpBalanceRow')
class XpBalanceTable extends Table {
  @override
  String get tableName => 'xp_balance';

  /// Always `'singleton'`.
  TextColumn get id => text()();

  /// Running total across every ledger row ever inserted.
  IntColumn get totalXp => integer()();

  /// UTC epoch millis when this row was created.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis when this row was last updated.
  IntColumn get updatedAt => integer()();

  /// Multi-profile scoping (`core/profiles/`); defaults to `'system'` for
  /// rows that pre-date profile support. Part of the primary key since
  /// [id] is always `'singleton'` — each profile needs its own row.
  TextColumn get profileId =>
      text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {id, profileId};
}
