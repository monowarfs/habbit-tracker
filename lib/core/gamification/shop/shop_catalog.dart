/// A shop item's cosmetic category.
enum ShopItemType {
  /// A theme color palette.
  palette,

  /// An app icon variant.
  icon,

  /// A full theme bundle (palette + icon).
  theme,
}

/// A purchasable cosmetic item — spends XP, no functional advantage.
class ShopItem {
  /// Creates a shop item definition.
  const ShopItem({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.type,
    required this.costXp,
    required this.assetPath,
  });

  /// Stable identifier — also the `shop_unlocks.itemId` value.
  final String id;

  /// l10n key for the item's display name.
  final String nameKey;

  /// l10n key for the item's description.
  final String descriptionKey;

  /// Which cosmetic category this item belongs to.
  final ShopItemType type;

  /// XP cost to purchase.
  final int costXp;

  /// Path to the theme/icon asset this item applies.
  final String assetPath;
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
