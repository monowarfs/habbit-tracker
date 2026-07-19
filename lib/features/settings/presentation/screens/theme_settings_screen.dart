import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/presentation/providers/theme_controller.dart';

/// Theme mode picker, extracted from the old flat Settings home screen.
class ThemeSettingsScreen extends ConsumerWidget {
  /// Creates the theme settings screen.
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTheme)),
      body: Padding(
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
    );
  }
}
