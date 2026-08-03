import 'package:habit_tracker/core/theme/icon_packs.dart';

/// Service for switching the app's launcher icon at runtime.
///
/// Requires platform-specific configuration in AndroidManifest.xml
/// (activity-alias) and Info.plist (CFBundleAlternateIcons).
class IconSwitcher {
  /// Sets the alternate app icon.
  // ponytail: no-op — flutter_dynamic_icon still uses Flutter's v1 plugin
  // embedding (removed from the engine), blocking every Android build.
  // Unmaintained since 2022. Re-wire to a maintained replacement package
  // when the icon-pack feature needs runtime switching back.
  static Future<void> setIcon(IconPack pack) async {}
}
