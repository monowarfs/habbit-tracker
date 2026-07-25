import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/achievements/presentation/achievement_localization.dart';
import 'package:habit_tracker/features/achievements/presentation/providers/achievement_providers.dart';

/// The badge gallery — every module's achievements, locked (progress bar)
/// or unlocked (unlock date) (FR-C-13).
class AchievementGalleryScreen extends ConsumerWidget {
  /// Creates the achievement gallery screen.
  const AchievementGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final viewsAsync = ref.watch(achievementViewsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.achievementsTitle)),
      body: viewsAsync.when(
        data: (views) {
          // Sort: unlocked achievements first, then by progress percentage
          // (closest to unlocking first).
          final sorted = List<AchievementView>.from(views)..sort((a, b) {
            final aUnlocked = a.unlockedAt != null;
            final bUnlocked = b.unlockedAt != null;
            if (aUnlocked && !bUnlocked) return -1;
            if (!aUnlocked && bUnlocked) return 1;
            if (aUnlocked && bUnlocked) return 0;
            // Both locked — sort by progress percentage (descending).
            final aPercent = a.definition.target > 0
                ? a.progressCurrent / a.definition.target
                : 0.0;
            final bPercent = b.definition.target > 0
                ? b.progressCurrent / b.definition.target
                : 0.0;
            return bPercent.compareTo(aPercent);
          });
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final view = sorted[index];
              final unlocked = view.unlockedAt != null;
              return Card(
                color: unlocked
                    ? null
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        unlocked
                            ? Icons.emoji_events
                            : Icons.emoji_events_outlined,
                        size: 40,
                        color: unlocked
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizedAchievementTitle(
                          l10n,
                          view.definition.titleKey,
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        localizedAchievementDescription(
                          l10n,
                          view.definition.descriptionKey,
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (!unlocked)
                        LinearProgressIndicator(
                          value:
                              view.progressCurrent / view.definition.target,
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        error: (error, stack) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
