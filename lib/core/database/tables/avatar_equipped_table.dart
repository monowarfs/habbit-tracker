import 'package:drift/drift.dart';

/// Singleton row of currently-equipped avatar piece ids per slot.
@DataClassName('AvatarEquippedRow')
class AvatarEquippedTable extends Table {
  @override
  String get tableName => 'avatar_equipped';

  /// Always `'singleton'` — one row for the whole app.
  TextColumn get id => text()();

  /// Equipped `head` slot piece id, or null for none.
  TextColumn get headPieceId => text().nullable()();

  /// Equipped `body` slot piece id, or null for none.
  TextColumn get bodyPieceId => text().nullable()();

  /// Equipped `background` slot piece id, or null for none.
  TextColumn get backgroundPieceId => text().nullable()();

  /// Equipped `frame` slot piece id, or null for none.
  TextColumn get framePieceId => text().nullable()();

  /// UTC epoch millis when this row was first created.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis of the last equip change.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
