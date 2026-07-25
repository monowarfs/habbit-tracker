import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

/// Quiet-hours configuration screen — a toggle plus two time pickers
/// for the start/end of the suppression window.
class QuietHoursScreen extends ConsumerWidget {
  /// Creates the quiet hours screen.
  const QuietHoursScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider).value;
    if (settings == null) {
      return Scaffold(appBar: AppBar(title: Text(l10n.quietHoursTitle)));
    }
    final repo = ref.read(settingsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.quietHoursTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.quietHoursDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.quietHoursEnableToggle),
            value: settings.quietHoursEnabled,
            onChanged: (value) => repo.updateQuietHours(
              enabled: value,
              start: settings.quietHoursStart,
              end: settings.quietHoursEnd,
            ),
          ),
          ListTile(
            title: Text(l10n.quietHoursStartLabel),
            trailing: Text(settings.quietHoursStart.format()),
            onTap: () => _pickTime(
              context,
              ref,
              initial: settings.quietHoursStart,
              isStart: true,
            ),
          ),
          ListTile(
            title: Text(l10n.quietHoursEndLabel),
            trailing: Text(settings.quietHoursEnd.format()),
            onTap: () => _pickTime(
              context,
              ref,
              initial: settings.quietHoursEnd,
              isStart: false,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref, {
    required LocalTime initial,
    required bool isStart,
  }) async {
    final settings = ref.read(appSettingsProvider).value;
    if (settings == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (picked == null || !context.mounted) return;
    final newTime = LocalTime(picked.hour, picked.minute);
    await ref
        .read(settingsRepositoryProvider)
        .updateQuietHours(
          enabled: settings.quietHoursEnabled,
          start: isStart ? newTime : settings.quietHoursStart,
          end: isStart ? settings.quietHoursEnd : newTime,
        );
  }
}
