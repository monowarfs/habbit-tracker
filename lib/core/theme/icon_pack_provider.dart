import 'package:habit_tracker/core/theme/icon_packs.dart';
import 'package:habit_tracker/core/theme/icon_switcher.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'icon_pack_provider.g.dart';

/// Provider for the currently active app icon.
@Riverpod(keepAlive: true)
class ActiveIconPack extends _$ActiveIconPack {
  @override
  IconPack build() {
    final settings = ref.watch(appSettingsProvider).value;
    final iconPackId = settings?.activeIconPackId ?? 'default';
    return iconPacks.firstWhere(
      (p) => p.id == iconPackId,
      orElse: () => iconPacks.first,
    );
  }

  /// Updates the active icon pack and attempts to switch the app icon.
  Future<void> setIconPack(String iconPackId) async {
    final pack = iconPacks.firstWhere((p) => p.id == iconPackId);
    await IconSwitcher.setIcon(pack);

    final repository = ref.read(settingsRepositoryProvider);
    await repository.updateActiveIconPackId(iconPackId);
  }
}
