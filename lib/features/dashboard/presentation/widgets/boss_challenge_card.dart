import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/level_up_celebration.dart';
import 'package:habit_tracker/core/gamification/quests/quest_completion_celebration.dart';
import 'package:habit_tracker/core/gamification/quests/quest_providers.dart';
import 'package:habit_tracker/core/gamification/quests/week_utils.dart';
import 'package:habit_tracker/core/gamification/xp_providers.dart';
import 'package:habit_tracker/core/gamification/xp_values.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/utils/local_day.dart';

String? _bossQuestDescription(AppLocalizations l10n, String questKey) =>
    switch (questKey) {
      'boss_water_6_of_7' => l10n.bossQuestWater6of7,
      'boss_medicine_perfect_week' => l10n.bossQuestMedicinePerfect,
      'boss_prayer_5of5_5days' => l10n.bossQuestPrayer5of5,
      _ => null,
    };

/// Dashboard card for the current week's boss challenge — a single
/// harder-than-usual weekly quest for whichever module `boss_rotation
/// .dart` spotlights this week, distinct in presentation from the
/// regular `WeeklyQuestList` tiles (dark card, bold module accent, "BOSS"
/// badge, countdown). Renders nothing if the week has no boss row yet, or
/// if its spotlighted module isn't currently registered (mirrors
/// `WeeklyQuestList`'s same defensive check).
class BossChallengeCard extends ConsumerWidget {
  /// Creates the boss challenge card.
  const BossChallengeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(currentWeekQuestsProvider).value ?? const [];
    WeeklyQuestRow? bossQuest;
    for (final quest in quests) {
      if (quest.isBoss == 1) {
        bossQuest = quest;
        break;
      }
    }
    if (bossQuest == null) return const SizedBox.shrink();

    HabitModule? module;
    for (final m in ref.watch(habitModulesProvider)) {
      if (m.id == bossQuest.moduleId) {
        module = m;
        break;
      }
    }
    if (module == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final questDescription = _bossQuestDescription(l10n, bossQuest.questKey);
    if (questDescription == null) return const SizedBox.shrink();

    final accent = module.metadata.accentColor;
    final isComplete = bossQuest.completedAt != null;
    final isClaimed = bossQuest.rewardClaimed == 1;
    final progress = bossQuest.progressTarget == 0
        ? 0.0
        : (bossQuest.progressCurrent / bossQuest.progressTarget)
              .clamp(0, 1)
              .toDouble();
    final daysRemaining = _daysRemainingInWeek(clock.now());

    return Card(
      color: Color.alphaBlend(Colors.black.withValues(alpha: 0.55), accent),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'BOSS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.bossChallengeTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.bossChallengeModuleWeek(module.metadata.displayName),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              questDescription,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.weeklyQuestProgress(
                bossQuest.progressCurrent,
                bossQuest.progressTarget,
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.bossChallengeCountdown(daysRemaining),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                if (isClaimed)
                  const Icon(Icons.emoji_events, color: Colors.amber)
                else if (isComplete)
                  _ClaimButton(quest: bossQuest),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _daysRemainingInWeek(DateTime now) {
    final today = localDayKey(now);
    final weekEnd = mondayOfWeek(today).addDays(6);
    return weekEnd.toDateTimeUtc().difference(today.toDateTimeUtc()).inDays;
  }
}

class _ClaimButton extends ConsumerStatefulWidget {
  const _ClaimButton({required this.quest});

  final WeeklyQuestRow quest;

  @override
  ConsumerState<_ClaimButton> createState() => _ClaimButtonState();
}

class _ClaimButtonState extends ConsumerState<_ClaimButton> {
  bool _claiming = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      onPressed: _claiming ? null : _claim,
      child: Text(l10n.weeklyQuestClaimButton),
    );
  }

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final now = clock.now();
    final profileId = (await ref.read(activeProfileProvider.future)).id;
    await ref
        .read(questRepositoryProvider)
        .claimReward(
          widget.quest.questKey,
          widget.quest.weekKey,
          now: now,
          profileId: profileId,
        );
    final leveledUpTo = await _awardXp(now, profileId);
    if (!mounted) return;
    // Deliberately not resetting `_claiming` — same reasoning as
    // `WeeklyQuestList._QuestTileState._claim` (PR #77 second-review
    // finding): the button disappears once `isClaimed` flips, so
    // there's nothing left for a second tap to do.
    final l10n = AppLocalizations.of(context)!;
    await showQuestCompletionCelebration(
      context,
      title: l10n.bossChallengeCleared(XpValues.bossCleared),
    );
    if (leveledUpTo != null && mounted) {
      await showLevelUpCelebration(context, newLevel: leveledUpTo);
    }
  }

  /// Awards the boss-cleared XP once per (questKey, weekKey) —
  /// `hasAwarded` guards against a stale/duplicate claim re-triggering
  /// this (defense in depth alongside the `_claiming` reentrancy guard).
  /// Returns the new level if this award crossed a level threshold.
  Future<int?> _awardXp(DateTime now, String profileId) async {
    final xpRepository = ref.read(xpRepositoryProvider);
    final sourceId = '${widget.quest.questKey}_${widget.quest.weekKey}';
    final alreadyAwarded = await xpRepository.hasAwarded(
      moduleId: widget.quest.moduleId,
      eventType: 'boss_cleared',
      sourceId: sourceId,
      profileId: profileId,
    );
    if (alreadyAwarded) return null;
    final result = await xpRepository.awardXp(
      moduleId: widget.quest.moduleId,
      eventType: 'boss_cleared',
      amount: XpValues.bossCleared,
      now: now,
      sourceId: sourceId,
      profileId: profileId,
    );
    return result.leveledUpTo;
  }
}
