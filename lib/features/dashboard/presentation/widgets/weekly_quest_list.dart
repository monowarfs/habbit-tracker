import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/level_up_celebration.dart';
import 'package:habit_tracker/core/gamification/quests/quest_completion_celebration.dart';
import 'package:habit_tracker/core/gamification/quests/quest_providers.dart';
import 'package:habit_tracker/core/gamification/xp_providers.dart';
import 'package:habit_tracker/core/gamification/xp_values.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';

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
    // Drops a stale row for a module `QuestEngine` no longer generates
    // for (e.g. `buildHabitModules(enabledModules: ...)` excluding it) —
    // `watchCurrentWeek` has no module-list awareness of its own, so a
    // disabled module's already-created row would otherwise stay stuck
    // on the dashboard forever (PR #77 review finding). Boss rows are
    // excluded too — `BossChallengeCard` renders those, so a boss quest
    // never appears in both cards at once.
    final activeModuleIds = ref
        .watch(habitModulesProvider)
        .map((m) => m.id)
        .toSet();
    final quests = (ref.watch(currentWeekQuestsProvider).value ?? const [])
        .where((q) => q.isBoss == 0 && activeModuleIds.contains(q.moduleId))
        .toList();
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

/// Quests whose progress is a percentage (0-100), not a day count —
/// [_QuestTile] formats these with
/// [AppLocalizations.weeklyQuestProgressPercent] instead of the day-count
/// string, since "67/90 days" reads as nonsense for a quest with no
/// 90-day target (PR #77 review finding).
const _percentQuestKeys = {'medicine_90_percent'};

class _QuestTile extends ConsumerStatefulWidget {
  const _QuestTile({required this.quest});

  final WeeklyQuestRow quest;

  @override
  ConsumerState<_QuestTile> createState() => _QuestTileState();
}

class _QuestTileState extends ConsumerState<_QuestTile> {
  bool _claiming = false;

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
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
                _percentQuestKeys.contains(quest.questKey)
                    ? l10n.weeklyQuestProgressPercent(quest.progressCurrent)
                    : l10n.weeklyQuestProgress(
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
            onPressed: _claiming ? null : _claim,
            child: Text(l10n.weeklyQuestClaimButton),
          ),
      ],
    );
  }

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final now = clock.now();
    await ref
        .read(questRepositoryProvider)
        .claimReward(widget.quest.questKey, widget.quest.weekKey, now: now);
    final leveledUpTo = await _awardXp(now);
    if (!mounted) return;
    // Deliberately not resetting `_claiming` back to false here: the
    // claim celebration overlay doesn't block input (`streak_celebration
    // _overlay.dart`'s own doc comment), and the stream-driven
    // `isClaimed` rebuild that hides this button entirely lags a beat
    // behind this write completing — re-enabling in between reopens the
    // exact double-tap window this guard exists to close (PR #77
    // second-review finding). `claimReward` is a no-op past this point
    // either way, so there's nothing a second tap could still do.
    final l10n = AppLocalizations.of(context)!;
    await showQuestCompletionCelebration(
      context,
      title: l10n.weeklyQuestClaimed(XpValues.weeklyQuestComplete),
    );
    if (leveledUpTo != null && mounted) {
      await showLevelUpCelebration(context, newLevel: leveledUpTo);
    }
  }

  /// Awards the weekly-quest-complete XP once per (questKey, weekKey) —
  /// `hasAwarded` guards against a stale/duplicate claim re-triggering
  /// this (defense in depth alongside the `_claiming` reentrancy guard).
  /// Returns the new level if this award crossed a level threshold.
  Future<int?> _awardXp(DateTime now) async {
    final xpRepository = ref.read(xpRepositoryProvider);
    final sourceId = '${widget.quest.questKey}_${widget.quest.weekKey}';
    final alreadyAwarded = await xpRepository.hasAwarded(
      moduleId: widget.quest.moduleId,
      eventType: 'weekly_quest_complete',
      sourceId: sourceId,
    );
    if (alreadyAwarded) return null;
    final result = await xpRepository.awardXp(
      moduleId: widget.quest.moduleId,
      eventType: 'weekly_quest_complete',
      amount: XpValues.weeklyQuestComplete,
      now: now,
      sourceId: sourceId,
    );
    return result.leveledUpTo;
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
