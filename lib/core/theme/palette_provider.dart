import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/theme/palette_packs.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'palette_provider.g.dart';

/// Provider for the currently active theme palette.
@Riverpod(keepAlive: true)
class ActivePalette extends _$ActivePalette {
  @override
  PalettePack build() {
    final settings = ref.watch(appSettingsProvider).value;
    final paletteId = settings?.activePaletteId ?? 'teal';
    return palettePacks.firstWhere(
      (p) => p.id == paletteId,
      orElse: () => palettePacks.first,
    );
  }

  /// Updates the active palette in the database.
  Future<void> setPalette(String paletteId) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.updateActivePaletteId(paletteId);
    // The provider will rebuild automatically because it watches appSettingsProvider.
  }
}
