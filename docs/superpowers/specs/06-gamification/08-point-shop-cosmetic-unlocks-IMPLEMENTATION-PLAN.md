# Implementation Plan: Point-Shop for Cosmetic Unlocks

**Spec:** 08-point-shop-cosmetic-unlocks-design.md
**Complexity:** M | **Estimated effort:** 2 days
**Dependencies:** Spec 02 (XP/Level System) — hard dependency for currency, existing theme system

---

## Overview

A catalog-and-unlock shop where users spend XP on cosmetic items (themes, icon variants). Spendable XP is deducted from the `xp_balance.total_xp`, reducing the displayed level. Items are purely cosmetic — no functional advantage.

---

## Implementation Tasks

### Task 1: Shop Catalog Definition

**Files to create:**
- `lib/core/gamification/shop/shop_catalog.dart`

```dart
enum ShopItemType { palette, icon, theme }

class ShopItem {
  const ShopItem({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.type,
    required this.costXp,
    required this.assetPath,
  });

  final String id;
  final String nameKey;       // ARB key for display name
  final String descriptionKey; // ARB key for description
  final ShopItemType type;
  final int costXp;
  final String assetPath;     // path to theme/icon asset
}

/// The v1 catalog — curated set of cosmetic items.
const shopCatalog = [
  ShopItem(
    id: 'ocean_palette',
    nameKey: 'shopItemOceanPalette',
    descriptionKey: 'shopItemOceanPaletteDesc',
    type: ShopItemType.palette,
    costXp: 500,
    assetPath: 'assets/themes/ocean.json',
  ),
  ShopItem(
    id: 'forest_palette',
    nameKey: 'shopItemForestPalette',
    descriptionKey: 'shopItemForestPaletteDesc',
    type: ShopItemType.palette,
    costXp: 500,
    assetPath: 'assets/themes/forest.json',
  ),
  ShopItem(
    id: 'sunset_palette',
    nameKey: 'shopItemSunsetPalette',
    descriptionKey: 'shopItemSunsetPaletteDesc',
    type: ShopItemType.palette,
    costXp: 750,
    assetPath: 'assets/themes/sunset.json',
  ),
  ShopItem(
    id: 'minimal_icon',
    nameKey: 'shopItemMinimalIcon',
    descriptionKey: 'shopItemMinimalIconDesc',
    type: ShopItemType.icon,
    costXp: 300,
    assetPath: 'assets/icons/minimal.json',
  ),
];
```

---

### Task 2: Shop Unlock Drift Table

**Files to create/modify:**
- `lib/core/database/tables/shop_unlocks_table.dart` (create)
- `lib/core/database/app_database.dart` (modify)

**Drift table:**
```dart
@DataClassName('ShopUnlockRow')
class ShopUnlocksTable extends Table {
  @override
  String get tableName => 'shop_unlocks';

  TextColumn get id => text()();
  TextColumn get itemId => text()();
  TextColumn get itemType => text()(); // 'palette' | 'icon' | 'theme'
  IntColumn get unlockedAt => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {itemId},
  ];
}
```

**Migration:** `if (from < 21)` (or next available). Bump `schemaVersion`.

---

### Task 3: Shop Repository

**Files to create:**
- `lib/core/gamification/shop/shop_repository.dart`

```dart
class ShopRepository {
  ShopRepository(this._db);
  final AppDatabase _db;

  /// Returns all unlocked item IDs.
  Future<Set<String>> unlockedItemIds();

  /// Stream of unlocked items for reactive UI.
  Stream<Set<String>> watchUnlockedItems();

  /// Purchases an item: deducts XP from balance and records unlock.
  /// Throws if insufficient XP or item already owned.
  Future<void> purchaseItem({
    required ShopItem item,
    required DateTime now,
  });

  /// Returns the current XP balance.
  Future<int> currentBalance();
}
```

**Integration:** `purchaseItem()` calls `XpRepository.awardXp()` with a negative amount (or a separate `deductXp()` method) to reduce `total_xp`.

---

### Task 4: XP Deduction Method

**Files to modify:**
- `lib/core/gamification/xp_repository.dart`

**Add method:**
```dart
/// Deducts XP from the balance (for shop purchases).
/// Throws if balance < amount.
Future<void> deductXp({
  required int amount,
  required DateTime now,
  required String reason, // e.g. 'shop_purchase_ocean_palette'
});
```

**Integration:** Atomic deduction — updates `xp_balance.total_xp` and inserts ledger row with negative `xp_amount`.

---

### Task 5: Shop Catalog Provider

**Files to create:**
- `lib/core/gamification/shop/shop_providers.dart`

```dart
@riverpod
Stream<Set<String>> unlockedShopItems(Ref ref) {
  return shopRepository.watchUnlockedItems();
}

@riverpod
int currentXpBalance(Ref ref) {
  return ref.watch(xpRepositoryProvider).valueOrNull ?? 0;
}
```

---

### Task 6: Shop Screen

**Files to create:**
- `lib/features/shop/presentation/screens/shop_screen.dart`
- `lib/features/shop/presentation/widgets/shop_item_card.dart`

**Shop screen:**
```dart
class ShopScreen extends ConsumerWidget {
  /// Full-screen shop catalog with current XP balance displayed.
  /// Each item shows: name, description, cost, owned/buy button state.
}
```

**Item card:**
```dart
class ShopItemCard extends ConsumerWidget {
  /// Shows item name, cost, and Buy/Owned button.
  /// Buy button disabled when XP < cost.
  /// Shows "Already owned" when unlocked.
}
```

**Router integration:** Add `/shop` route to `app_router.dart` (under Settings tab or as a standalone route).

---

### Task 7: Purchase Flow

**Files to modify:**
- `lib/features/shop/presentation/widgets/shop_item_card.dart`

**Logic:**
```dart
Future<void> _purchase(ShopItem item) async {
  final balance = ref.read(currentXpBalanceProvider);
  if (balance < item.costXp) {
    showInsufficientXpDialog(context, current: balance, needed: item.costXp);
    return;
  }
  // Show confirmation dialog
  final confirmed = await showPurchaseConfirmation(context, item);
  if (!confirmed) return;

  await shopRepository.purchaseItem(item: item, now: clock.now());
  // UI auto-updates via StreamProvider
}
```

---

### Task 8: Settings Integration for Unlocked Themes

**Files to modify:**
- `lib/features/settings/presentation/screens/settings_screen.dart`

**Changes:**
- Theme selector shows unlocked cosmetic palettes from the shop alongside the default themes.
- Icon selector shows unlocked icon variants.

---

### Task 9: Localization

**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**ARB keys:**
```
"shopTitle": "Point Shop",
"shopBuyButton": "Buy for {cost} XP",
"shopOwnedLabel": "Owned",
"shopInsufficientXp": "Not enough XP ({current}/{needed})",
"shopConfirmPurchase": "Buy {item} for {cost} XP?",
"shopConfirmButton": "Buy",
"shopCancelButton": "Cancel",
"shopItemOceanPalette": "Ocean Palette",
"shopItemOceanPaletteDesc": "Cool blue and teal tones",
"shopItemForestPalette": "Forest Palette",
"shopItemForestPaletteDesc": "Natural green accents",
"shopItemSunsetPalette": "Sunset Palette",
"shopItemSunsetPaletteDesc": "Warm orange and gold tones",
"shopItemMinimalIcon": "Minimal Icons",
"shopItemMinimalIconDesc": "Clean, simplified icon set"
```

---

## Performance Considerations

- **Caching:** Unlocked items set is small — cache in Riverpod `StreamProvider`. XP balance is a singleton row query.
- **Lazy loading:** Shop catalog is static (defined in code). Items load instantly.
- **Memory:** No images loaded in the catalog — only when the user previews/selects a theme.

---

## Testing

**Files to create:**
- `test/core/gamification/shop/shop_repository_test.dart`
- `test/core/gamification/shop/shop_catalog_test.dart`
- `test/features/shop/presentation/screens/shop_screen_test.dart`

**Coverage:**
| Test | Covers |
|---|---|
| `shop_repository_test.dart` | Purchase deduction, duplicate prevention, insufficient XP, balance update |
| `shop_catalog_test.dart` | All items have valid IDs, costs > 0, unique item IDs |
| `shop_screen_test.dart` | Items render, owned state shows, buy button disabled when insufficient XP |

---

## Edge Cases

- **Insufficient XP:** Show "Not enough XP" with current balance and cost. Buy button disabled.
- **Reinstall data loss:** Unlocks are device-local. After reinstall, user must re-purchase.
- **Duplicate purchase:** `item_id` unique constraint prevents duplicates. Shows "Already owned."
- **XP goes negative:** Not possible — purchase only allowed when `totalXp >= cost`.
- **Level display after spending:** Level derived from `totalXp` at read time, so spending reduces displayed level immediately.
