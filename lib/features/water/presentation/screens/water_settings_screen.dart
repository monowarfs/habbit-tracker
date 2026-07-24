import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/notifications/notification_permission_explainer_screen.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/water/data/weather_location_resolver.dart';
import 'package:habit_tracker/features/water/domain/water_goal_presets.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_controller.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';
import 'package:habit_tracker/features/water/presentation/weather_nudge_explainer.dart';

/// The Water module's own settings: daily goal, quick-add presets, and
/// reminder preferences (FR-W-01/03/10).
class WaterSettingsScreen extends ConsumerWidget {
  /// Creates the water settings screen. [resolveWeatherLocationOverride]
  /// overrides `resolveWeatherLocation` — test-only seam, since
  /// `geolocator`'s platform channel isn't available under `flutter test`.
  const WaterSettingsScreen({super.key, this.resolveWeatherLocationOverride});

  /// Test seam for `resolveWeatherLocation`.
  final Future<Result<WeatherLocation>> Function()?
  resolveWeatherLocationOverride;

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
                  windowOverrides: settings.reminderWindowOverrides,
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
                windowOverrides: settings.reminderWindowOverrides,
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
                      windowOverrides: settings.reminderWindowOverrides,
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
                      windowOverrides: settings.reminderWindowOverrides,
                    ),
                  ),
                ),
              ],
            ),
            _WeekdayOverridesSection(
              overrides: settings.reminderWindowOverrides,
              defaultStart: settings.reminderWindowStart,
              defaultEnd: settings.reminderWindowEnd,
              intervalMinutes: settings.reminderIntervalMinutes,
              onChanged: (overrides) => controller.updateReminderSettings(
                enabled: settings.reminderEnabled,
                intervalMinutes: settings.reminderIntervalMinutes,
                windowStart: settings.reminderWindowStart,
                windowEnd: settings.reminderWindowEnd,
                windowOverrides: overrides,
              ),
            ),
          ],
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.weatherNudgeSettingsTitle),
            subtitle: Text(l10n.weatherNudgeSettingsExplainerBody),
            value: settings.weatherNudgeEnabled,
            onChanged: (enabled) async {
              if (enabled) {
                final granted = await showWeatherNudgeExplainer(
                  context,
                  resolveLocation: resolveWeatherLocationOverride,
                );
                if (!granted) return;
              }
              unawaited(
                controller.updateWeatherNudgeEnabled(enabled: enabled),
              );
            },
          ),
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

class _WeekdayOverridesSection extends StatelessWidget {
  const _WeekdayOverridesSection({
    required this.overrides,
    required this.defaultStart,
    required this.defaultEnd,
    required this.intervalMinutes,
    required this.onChanged,
  });

  final Map<int, ({LocalTime start, LocalTime end})> overrides;
  final LocalTime defaultStart;
  final LocalTime defaultEnd;
  final int intervalMinutes;
  final ValueChanged<Map<int, ({LocalTime start, LocalTime end})>> onChanged;

  static const _weekdayKeys = [1, 2, 3, 4, 5, 6, 7];

  String _weekdayLabel(AppLocalizations l10n, int weekday) => switch (weekday) {
    1 => l10n.weekdayMonday,
    2 => l10n.weekdayTuesday,
    3 => l10n.weekdayWednesday,
    4 => l10n.weekdayThursday,
    5 => l10n.weekdayFriday,
    6 => l10n.weekdaySaturday,
    7 => l10n.weekdaySunday,
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(l10n.waterSettingsReminderOverridesTitle),
      children: [
        for (final weekday in _weekdayKeys) ...[
          _WeekdayOverrideRow(
            label: _weekdayLabel(l10n, weekday),
            override_: overrides[weekday],
            defaultStart: defaultStart,
            defaultEnd: defaultEnd,
            onChanged: (entry) {
              final updated = Map<int, ({LocalTime start, LocalTime end})>.of(
                overrides,
              );
              if (entry != null) {
                updated[weekday] = entry;
              } else {
                updated.remove(weekday);
              }
              onChanged(updated);
            },
          ),
        ],
      ],
    );
  }
}

class _WeekdayOverrideRow extends StatelessWidget {
  const _WeekdayOverrideRow({
    required this.label,
    required this.override_,
    required this.defaultStart,
    required this.defaultEnd,
    required this.onChanged,
  });

  final String label;
  final ({LocalTime start, LocalTime end})? override_;
  final LocalTime defaultStart;
  final LocalTime defaultEnd;
  final ValueChanged<({LocalTime start, LocalTime end})?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: override_ != null,
      onChanged: (enabled) {
        if (enabled) {
          onChanged((start: defaultStart, end: defaultEnd));
        } else {
          onChanged(null);
        }
      },
      subtitle: override_ != null
          ? Row(
              children: [
                Expanded(
                  child: _TimeField(
                    time: override_!.start,
                    onChanged: (value) =>
                        onChanged((start: value, end: override_!.end)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeField(
                    time: override_!.end,
                    onChanged: (value) =>
                        onChanged((start: override_!.start, end: value)),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
