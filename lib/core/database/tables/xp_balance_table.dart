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

  @override
  Set<Column> get primaryKey => {id};
}
