import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/stacking/habit_stack_suggestion_repository.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';

/// Dashboard card surfacing a pending habit-stacking suggestion — a
/// `Card`, not a snackbar (needs to stay visible with two actions,
/// `docs/superpowers/specs/02-delightful/
/// 04-habit-stacking-suggestions-design.md`'s "UI surface"). Renders
/// nothing when there's no pending suggestion.
class HabitStackSuggestionCard extends ConsumerWidget {
  /// Creates the suggestion card.
  const HabitStackSuggestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestion = ref.watch(pendingHabitStackSuggestionProvider).value;
    if (suggestion == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final message = suggestion.sourceModuleId == 'medicine'
        ? l10n.habitStackSuggestionMedicineToWater
        : l10n.habitStackSuggestionPrayerToWater(
            suggestion.sourceLabel ?? suggestion.sourceModuleId,
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _dismiss(ref, suggestion.id),
                  child: Text(l10n.habitStackSuggestionDismiss),
                ),
                FilledButton(
                  onPressed: () => _accept(ref, suggestion),
                  child: Text(l10n.habitStackSuggestionAccept),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dismiss(WidgetRef ref, String id) async {
    final profile = await ref.read(activeProfileProvider.future);
    await ref
        .read(habitStackSuggestionRepositoryProvider)
        .dismiss(id, now: clock.now(), profileId: profile.id);
  }

  Future<void> _accept(
    WidgetRef ref,
    HabitStackSuggestionRow suggestion,
  ) async {
    final now = clock.now();
    final profile = await ref.read(activeProfileProvider.future);
    await ref
        .read(habitStackSuggestionRepositoryProvider)
        .accept(suggestion.id, now: now, profileId: profile.id);

    // Applies the nudge to every weekday, not just the weekdays that
    // happened to contribute a qualifying day: `habit_stack_suggestions`
    // stores one aggregate `typicalSourceTime`, not a per-weekday
    // breakdown, so "whichever weekdays contributed" (the design doc's
    // UI-surface note) reduces to "every weekday" given this table's
    // actual columns (this plan's Global Constraints).
    final waterRepository = ref.read(waterRepositoryProvider);
    final currentSettings = await waterRepository
        .watchSettings(profileId: profile.id)
        .first;
    final typicalTime = LocalTime.parse(suggestion.typicalSourceTime);
    final overrides = {
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: (
          start: typicalTime,
          end:
              currentSettings.reminderWindowOverrides[weekday]?.end ??
              currentSettings.reminderWindowEnd,
        ),
    };
    await waterRepository.updateReminderSettings(
      enabled: currentSettings.reminderEnabled,
      intervalMinutes: currentSettings.reminderIntervalMinutes,
      windowStart: currentSettings.reminderWindowStart,
      windowEnd: currentSettings.reminderWindowEnd,
      windowOverrides: overrides,
      profileId: profile.id,
    );
  }
}
