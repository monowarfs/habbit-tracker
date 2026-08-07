import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/analytics/personal_record_providers.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/widgets/streak_celebration_overlay.dart';

/// "Personal Record" section (Task 5,
/// `docs/superpowers/specs/08-analytics/
/// 02-personal-record-tracking-IMPLEMENTATION-PLAN.md`): a module's
/// persisted longest-streak record, distinct from the current/active
/// streak already shown elsewhere on the screen — with a "New Record!"
/// badge and celebration overlay the moment [currentStreak] surpasses it.
class PersonalRecordSection extends ConsumerWidget {
  /// Creates a personal-record section for [moduleId].
  const PersonalRecordSection({
    required this.moduleId,
    required this.currentStreak,
    required this.accentColor,
    this.icon = Icons.emoji_events,
    super.key,
  });

  /// The owning module's id (`'water'` / `'medicine'` / `'prayer'`).
  final String moduleId;

  /// The module's current streak, checked against the persisted record.
  final int currentStreak;

  /// The module's accent color.
  final Color accentColor;

  /// Icon shown in the card and the celebration overlay.
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = personalRecordStatusProvider(
      moduleId: moduleId,
      currentValue: currentStreak,
    );
    final status = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next.value?.isNewRecord ?? false) {
        unawaited(
          showStreakCelebration(
            context,
            title: l10n.personalRecordNewRecord,
            accentColor: accentColor,
            icon: icon,
          ),
        );
      }
    });

    final data = status.value;
    if (data == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.personalRecordTitle,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(l10n.personalRecordLongestStreak(data.value)),
                  if (data.isNewRecord && data.previousValue != null)
                    Text(
                      l10n.personalRecordPrevious(data.previousValue!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (data.isNewRecord)
              Flexible(
                child: Chip(
                  label: Text(l10n.personalRecordNewRecord),
                  backgroundColor: accentColor.withValues(alpha: 0.15),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
