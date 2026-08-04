import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/quests/quest_completion_celebration.dart';
import 'package:habit_tracker/core/gamification/quests/quest_providers.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Dashboard card showing the current week's quests, one progress bar per
/// quest, with a claim button once a quest is complete (Task 7). Renders
/// nothing while there are no quests yet — `WeeklyQuestResetHandler`
/// generates the first week's quests on app start, so this is only ever
/// empty for a brief instant.
class WeeklyQuestList extends ConsumerWidget {
  /// Creates the weekly quest list card.
  const WeeklyQuestList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(currentWeekQuestsProvider).value ?? const [];
    if (quests.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.weeklyQuestTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              l10n.weeklyQuestReset,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final quest in quests) ...[
              _QuestTile(quest: quest),
              if (quest != quests.last) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestTile extends ConsumerWidget {
  const _QuestTile({required this.quest});

  final WeeklyQuestRow quest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isComplete = quest.completedAt != null;
    final isClaimed = quest.rewardClaimed == 1;
    final progress = quest.progressTarget == 0
        ? 0.0
        : (quest.progressCurrent / quest.progressTarget).clamp(0, 1).toDouble();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_questTitle(l10n, quest.questKey)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: progress),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.weeklyQuestProgress(
                  quest.progressCurrent,
                  quest.progressTarget,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (isClaimed)
          const Icon(Icons.check_circle, color: Colors.green)
        else if (isComplete)
          TextButton(
            onPressed: () => _claim(context, ref),
            child: Text(l10n.weeklyQuestClaimButton),
          ),
      ],
    );
  }

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    await ref
        .read(questRepositoryProvider)
        .claimReward(quest.questKey, quest.weekKey, now: clock.now());
    if (!context.mounted) return;
    await showQuestCompletionCelebration(context);
  }

  String _questTitle(AppLocalizations l10n, String questKey) {
    return switch (questKey) {
      'water_goal_5_of_7' => l10n.questWater5of7,
      'water_no_skip_week' => l10n.questWaterNoSkip,
      'medicine_perfect_week' => l10n.questMedicinePerfect,
      'medicine_90_percent' => l10n.questMedicine90,
      'prayer_5_of_7' => l10n.questPrayer5of7,
      'prayer_no_skip_week' => l10n.questPrayerNoSkip,
      _ => questKey,
    };
  }
}
