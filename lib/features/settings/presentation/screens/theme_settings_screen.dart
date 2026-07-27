import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
import 'package:habit_tracker/core/theme/icon_pack_provider.dart';
import 'package:habit_tracker/core/theme/icon_packs.dart';
import 'package:habit_tracker/core/theme/palette_packs.dart';
import 'package:habit_tracker/core/theme/palette_provider.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/settings/presentation/providers/theme_controller.dart';
import 'package:go_router/go_router.dart';

/// Theme mode picker, extracted from the old flat Settings home screen.
class ThemeSettingsScreen extends ConsumerWidget {
  /// Creates the theme settings screen.
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeControllerProvider);
    final settings = ref.watch(appSettingsProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTheme)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.themeModeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.themeModeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeModeDark),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) => ref
                  .read(themeControllerProvider.notifier)
                  .updateThemeMode(selection.first),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsAppearance),
          const SizedBox(height: 8),
          _PaletteSelector(),
          const Divider(),
          _SectionHeader(l10n.settingsAppIcon),
          const SizedBox(height: 8),
          _IconPackSelector(),
          const Divider(),
          SwitchListTile(
            title: Text(l10n.settingsSeasonalAccentsToggle),
            subtitle: Text(l10n.settingsSeasonalAccentsDescription),
            value: settings?.seasonalAccentsEnabled ?? true,
            onChanged: (value) => ref
                .read(settingsRepositoryProvider)
                .updateSeasonalAccentsEnabled(enabled: value),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      title,
      style:
          Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
    ),
  );
}

class _PaletteSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePalette = ref.watch(activePaletteProvider);
    final isPremium = ref.watch(isPremiumUserProvider);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: palettePacks.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final palette = palettePacks[index];
              final isSelected = palette.id == activePalette.id;
              final locked = palette.isPremium && !isPremium;

              return Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (locked) {
                        context.push('/settings/purchase');
                      } else {
                        ref.read(activePaletteProvider.notifier).setPalette(palette.id);
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: palette.seedColor,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 4,
                              )
                            : null,
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: palette.seedColor.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: locked
                          ? const Icon(Icons.lock_outline, color: Colors.white)
                          : isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _localizedPaletteName(l10n, palette.id),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _localizedPaletteName(AppLocalizations l10n, String id) =>
      switch (id) {
        'teal' => l10n.palettePackTeal,
        'ocean' => l10n.palettePackOcean,
        'sunset' => l10n.palettePackSunset,
        'lavender' => l10n.palettePackLavender,
        'midnight' => l10n.palettePackMidnight,
        _ => id,
      };
}

class _IconPackSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIconPack = ref.watch(activeIconPackProvider);
    final isPremium = ref.watch(isPremiumUserProvider);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: iconPacks.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final pack = iconPacks[index];
              final isSelected = pack.id == activeIconPack.id;
              final locked = pack.isPremium && !isPremium;

              return Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (locked) {
                        context.push('/settings/purchase');
                      } else {
                        ref.read(activeIconPackProvider.notifier).setIconPack(pack.id);
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 4,
                              )
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.apps,
                            size: 40,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          if (locked)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Icon(
                                Icons.lock,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          if (isSelected)
                            const Positioned(
                              right: 4,
                              bottom: 4,
                              child: Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.green,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _localizedIconPackName(l10n, pack.id),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _localizedIconPackName(AppLocalizations l10n, String id) =>
      switch (id) {
        'default' => l10n.iconPackDefault,
        'ocean' => l10n.iconPackOcean,
        'sunset' => l10n.iconPackSunset,
        _ => id,
      };
}
