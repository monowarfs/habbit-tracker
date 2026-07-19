import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/features/achievements/presentation/providers/achievement_providers.dart';

/// The badge gallery — every module's achievements, locked (progress bar)
/// or unlocked (unlock date) (FR-C-13).
///
/// ponytail: title/description render `titleKey`/`descriptionKey`
/// directly for now — the localized-text switch lands in a later task
/// (`gen_l10n` additions) once the l10n keys themselves exist.
class AchievementGalleryScreen extends ConsumerWidget {
  /// Creates the achievement gallery screen.
  const AchievementGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewsAsync = ref.watch(achievementViewsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: viewsAsync.when(
        data: (views) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: views.length,
          itemBuilder: (context, index) {
            final view = views[index];
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
                      view.definition.titleKey,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      view.definition.descriptionKey,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (!unlocked)
                      LinearProgressIndicator(
                        value: view.progressCurrent / view.definition.target,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        error: (error, stack) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
