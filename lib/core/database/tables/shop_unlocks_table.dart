import 'package:drift/drift.dart';

/// Shop purchase records — one row per unlocked cosmetic item.
@DataClassName('ShopUnlockRow')
class ShopUnlocksTable extends Table {
  @override
  String get tableName => 'shop_unlocks';

  /// Row id.
  TextColumn get id => text()();

  /// The `ShopItem.id` that was purchased.
  TextColumn get itemId => text()();

  /// `'palette'` | `'icon'` | `'theme'` — mirrors `ShopItemType`.
  TextColumn get itemType => text()();

  /// UTC epoch millis when this item was purchased.
  IntColumn get unlockedAt => integer()();

  /// UTC epoch millis when this row was created.
  IntColumn get createdAt => integer()();

  /// Multi-profile scoping (`core/profiles/`); defaults to `'system'` for
  /// rows that pre-date profile support.
  TextColumn get profileId =>
      text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {itemId, profileId},
  ];
}
