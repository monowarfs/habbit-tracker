import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

/// Ramadan mode configuration: auto-detect toggle plus a manual override
/// shown only while auto-detect is off (`docs/superpowers/specs/
/// 02-delightful/01-ramadan-mode-design.md`).
class RamadanSettingsScreen extends ConsumerWidget {
  /// Creates the Ramadan mode settings screen.
  const RamadanSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider).value;
    if (settings == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.ramadanModeSettingsTitle)),
      );
    }
    final repo = ref.read(settingsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ramadanModeSettingsTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.ramadanModeSettingsSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.ramadanModeAutoDetectToggle),
            value: settings.ramadanAutoDetectEnabled,
            onChanged: (enabled) async {
              await repo.updateRamadanAutoDetectEnabled(enabled: enabled);
              // Turning auto-detect back on clears any pinned manual
              // override — the two controls never fight each other.
              if (enabled) {
                await repo.updateRamadanModeManualOverride(null);
              }
            },
          ),
          if (!settings.ramadanAutoDetectEnabled)
            SwitchListTile(
              title: Text(l10n.ramadanModeManualToggle),
              value: settings.ramadanModeManualOverride ?? false,
              onChanged: repo.updateRamadanModeManualOverride,
            ),
        ],
      ),
    );
  }
}
