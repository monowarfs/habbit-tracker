/// Defines an app icon pack.
class IconPack {
  /// Creates an icon pack definition.
  const IconPack({
    required this.id,
    required this.displayNameKey,
    this.androidAlias,
    this.iosIconName,
    this.isPremium = false,
  });

  /// Stable identifier stored in settings.
  final String id;

  /// l10n key for the pack's display name.
  final String displayNameKey;

  /// Android activity-alias name, if this pack changes the launcher icon.
  final String? androidAlias;

  /// iOS alternate icon name, if this pack changes the launcher icon.
  final String? iosIconName;

  /// Whether selecting this pack requires premium.
  final bool isPremium;
}

/// The set of available app icons.
const iconPacks = [
  IconPack(id: 'default', displayNameKey: 'iconPackDefault'),
  IconPack(
    id: 'ocean',
    displayNameKey: 'iconPackOcean',
    androidAlias: '.OceanIcon',
    iosIconName: 'OceanIcon',
    isPremium: true,
  ),
  IconPack(
    id: 'sunset',
    displayNameKey: 'iconPackSunset',
    androidAlias: '.SunsetIcon',
    iosIconName: 'SunsetIcon',
    isPremium: true,
  ),
  // Point-shop icon — gated by `unlockedShopItemsProvider`, not
  // `isPremium`. No native activity-alias yet since `IconSwitcher.setIcon`
  // is already a no-op for every pack (see its own doc comment).
  IconPack(id: 'minimal_icon', displayNameKey: 'shopItemMinimalIcon'),
];
