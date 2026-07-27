import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';
import 'package:habit_tracker/core/theme/icon_packs.dart';

/// Service for switching the app's launcher icon at runtime.
///
/// Requires platform-specific configuration in AndroidManifest.xml
/// (activity-alias) and Info.plist (CFBundleAlternateIcons).
class IconSwitcher {
  /// Sets the alternate app icon.
  static Future<void> setIcon(IconPack pack) async {
    try {
      if (!await FlutterDynamicIcon.canIconChange) return;

      if (pack.id == 'default') {
        await FlutterDynamicIcon.setAlternateIconName(null);
      } else {
        await FlutterDynamicIcon.setAlternateIconName(
          Platform.isAndroid ? pack.androidAlias : pack.iosIconName,
        );
      }
    } on PlatformException catch (e) {
      // Silently fail if platform doesn't support or config is missing.
      // ignore: avoid_print
      print('Failed to change app icon: $e');
    }
  }
}
