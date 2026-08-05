import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/gamification/level_curve.dart';
import 'package:habit_tracker/core/gamification/xp_providers.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Compact cross-module level/XP progress card for the dashboard: current
/// level, and a progress bar toward the next. Level is derived from
/// [totalXpProvider] at read time (never persisted, per the plan's
/// "XP after level-up display" edge case — no stale-state issue).
class XpLevelDisplay extends ConsumerWidget {
  /// Creates the level/XP display card.
  const XpLevelDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalXp = ref.watch(totalXpProvider).value ?? 0;
    final level = LevelCurve.levelForXp(totalXp);
    final xpInLevel = LevelCurve.xpInCurrentLevel(totalXp);
    final xpToNext = LevelCurve.xpToNextLevel(totalXp);
    final levelSpan = xpInLevel + xpToNext;
    final progress = levelSpan == 0 ? 0.0 : xpInLevel / levelSpan;

    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.xpLevelDashboardLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  l10n.levelDisplay(level),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.xpProgress(xpInLevel, levelSpan),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
