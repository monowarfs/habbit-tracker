import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/notifications/notification_permission_explainer_screen.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/water/domain/water_goal_presets.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_controller.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';

/// The Water module's own settings: daily goal, quick-add presets, and
/// reminder preferences (FR-W-01/03/10).
class WaterSettingsScreen extends ConsumerWidget {
  /// Creates the water settings screen.
  const WaterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final goal = ref.watch(currentWaterGoalProvider).value;
    final settings = ref.watch(waterSettingsProvider).value;
    final controller = ref.read(waterControllerProvider.notifier);

    if (goal == null || settings == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.waterSettingsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.waterSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final preset in waterGoalPresets)
                ChoiceChip(
                  label: Text(_presetLabel(l10n, preset)),
                  selected: goal.goalMl == preset.goalMl,
                  onSelected: (selected) {
                    if (selected) {
                      unawaited(controller.updateGoal(preset.goalMl));
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          _GoalField(
            key: ValueKey(goal.goalMl),
            label: l10n.waterSettingsGoalLabel,
            initialValue: goal.goalMl,
            onChanged: controller.updateGoal,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.waterSettingsQuickAddLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Row(
            children: [
              for (var i = 0; i < settings.quickAddAmountsMl.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _GoalField(
                      label: '',
                      initialValue: settings.quickAddAmountsMl[i],
                      onChanged: (value) {
                        final updated = [...settings.quickAddAmountsMl];
                        updated[i] = value;
                        unawaited(controller.updateQuickAddAmounts(updated));
                      },
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 32),
          Text(
            l10n.waterSettingsReminderSectionLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.waterSettingsReminderEnableToggle),
            value: settings.reminderEnabled,
            onChanged: (enabled) async {
              // FR-C-02/`strategies/notifications.md`: ask for the OS
              // notification permission (with a friendly explainer first)
              // the moment the user opts into reminders, not before.
              if (enabled) {
                final granted = await showNotificationPermissionExplainer(
                  context,
                );
                if (!granted) return;
              }
              unawaited(
                controller.updateReminderSettings(
                  enabled: enabled,
                  intervalMinutes: settings.reminderIntervalMinutes,
                  windowStart: settings.reminderWindowStart,
                  windowEnd: settings.reminderWindowEnd,
                ),
              );
            },
          ),
          if (settings.reminderEnabled) ...[
            _GoalField(
              label: l10n.waterSettingsReminderIntervalLabel,
              initialValue: settings.reminderIntervalMinutes,
              onChanged: (value) => controller.updateReminderSettings(
                enabled: settings.reminderEnabled,
                intervalMinutes: value,
                windowStart: settings.reminderWindowStart,
                windowEnd: settings.reminderWindowEnd,
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.waterSettingsReminderWindowLabel),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    time: settings.reminderWindowStart,
                    onChanged: (value) => controller.updateReminderSettings(
                      enabled: settings.reminderEnabled,
                      intervalMinutes: settings.reminderIntervalMinutes,
                      windowStart: value,
                      windowEnd: settings.reminderWindowEnd,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeField(
                    time: settings.reminderWindowEnd,
                    onChanged: (value) => controller.updateReminderSettings(
                      enabled: settings.reminderEnabled,
                      intervalMinutes: settings.reminderIntervalMinutes,
                      windowStart: settings.reminderWindowStart,
                      windowEnd: value,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _presetLabel(AppLocalizations l10n, WaterGoalPreset preset) =>
    switch (preset.labelKey) {
      'waterPresetLight' => l10n.waterPresetLight,
      'waterPresetStandard' => l10n.waterPresetStandard,
      'waterPresetActive' => l10n.waterPresetActive,
      _ => preset.labelKey,
    };

class _GoalField extends StatefulWidget {
  const _GoalField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int initialValue;
  final ValueChanged<int> onChanged;

  @override
  State<_GoalField> createState() => _GoalFieldState();
}

class _GoalFieldState extends State<_GoalField> {
  late final _controller = TextEditingController(
    text: '${widget.initialValue}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: widget.label),
      onSubmitted: (text) {
        final value = int.tryParse(text);
        if (value != null && value > 0) widget.onChanged(value);
      },
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.time, required this.onChanged});

  final LocalTime time;
  final ValueChanged<LocalTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
        );
        if (picked != null) onChanged(LocalTime(picked.hour, picked.minute));
      },
      child: Text(time.format()),
    );
  }
}
