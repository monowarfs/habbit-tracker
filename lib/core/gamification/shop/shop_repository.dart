import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/shop/shop_catalog.dart';
import 'package:habit_tracker/core/gamification/xp_repository.dart';
import 'package:habit_tracker/core/utils/uuid.dart';

/// CRUD over the `shop_unlocks` table + the XP spend that gates it.
///
/// Every method takes `profileId` (family/multi-profile,
/// `docs/superpowers/specs/04-premium/03-family-multi-profile-
/// IMPLEMENTATION-PLAN.md`) — `shop_unlocks`'s unique constraint is now
/// `{itemId, profileId}`.
class ShopRepository {
  /// Creates a repository backed by [_db].
  const ShopRepository(this._db);

  final AppDatabase _db;

  /// All unlocked item ids.
  Future<Set<String>> unlockedItemIds({required String profileId}) async {
    final rows = await (_db.select(
      _db.shopUnlocksTable,
    )..where((t) => t.profileId.equals(profileId))).get();
    return rows.map((r) => r.itemId).toSet();
  }

  /// Reactive stream of unlocked item ids, for reactive UI.
  Stream<Set<String>> watchUnlockedItems({required String profileId}) {
    return (_db.select(
      _db.shopUnlocksTable,
    )..where((t) => t.profileId.equals(profileId))).watch().map(
      (rows) => rows.map((r) => r.itemId).toSet(),
    );
  }

  /// Purchases [item]: deducts its cost from the XP balance and records
  /// the unlock, in one transaction.
  ///
  /// Throws a [StateError] if the item is already owned. XP-insufficiency
  /// is surfaced by [XpRepository.deductXp]'s own [StateError].
  Future<void> purchaseItem({
    required ShopItem item,
    required DateTime now,
    required String profileId,
  }) async {
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.shopUnlocksTable)
                ..where(
                  (t) =>
                      t.itemId.equals(item.id) & t.profileId.equals(profileId),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) {
        throw StateError('Item ${item.id} is already owned');
      }
      await XpRepository(_db).deductXp(
        amount: item.costXp,
        now: now,
        reason: 'shop_purchase_${item.id}',
        profileId: profileId,
      );
      final nowMillis = now.millisecondsSinceEpoch;
      await _db
          .into(_db.shopUnlocksTable)
          .insert(
            ShopUnlocksTableCompanion.insert(
              id: generateId(),
              itemId: item.id,
              itemType: item.type.name,
              unlockedAt: nowMillis,
              createdAt: nowMillis,
              profileId: Value(profileId),
            ),
          );
    });
  }

  /// The current XP balance.
  Future<int> currentBalance({required String profileId}) =>
      XpRepository(_db).totalXp(profileId: profileId);
}
