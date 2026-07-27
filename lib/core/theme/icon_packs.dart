/// Defines an app icon pack.
class IconPack {
  final String id;
  final String displayNameKey;
  final String? androidAlias;
  final String? iosIconName;
  final bool isPremium;

  const IconPack({
    required this.id,
    required this.displayNameKey,
    this.androidAlias,
    this.iosIconName,
    this.isPremium = false,
  });
}

/// The set of available app icons.
const iconPacks = [
  IconPack(
    id: 'default',
    displayNameKey: 'iconPackDefault',
    isPremium: false,
  ),
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
];
