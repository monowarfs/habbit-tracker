import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/cosmetics/cosmetic_repository.dart';
import 'package:habit_tracker/core/cosmetics/cosmetic_unlock_engine.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Screen showing cosmetic unlock options.
class UnlocksScreen extends ConsumerWidget {
  /// Creates the unlocks screen.
  const UnlocksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);
    final repo = CosmeticRepository(db);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.unlocksTitle)),
      body: FutureBuilder<Set<String>>(
        future: repo.unlockedKeys(),
        builder: (context, snapshot) {
          final unlocked = snapshot.data ?? {};

          if (unlocked.isEmpty &&
              snapshot.connectionState == ConnectionState.done) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.unlocksEmptyState,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: availableCosmetics.length,
            itemBuilder: (context, index) {
              final cosmetic = availableCosmetics[index];
              final isUnlocked = unlocked.contains(cosmetic.key);

              return Card(
                child: ListTile(
                  leading: Icon(
                    isUnlocked ? Icons.check_circle : Icons.lock_outline,
                    color: isUnlocked
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  title: Text(
                    _cosmeticTitle(l10n, cosmetic.key),
                    style: TextStyle(
                      color: isUnlocked
                          ? null
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  subtitle: Text(
                    isUnlocked
                        ? _cosmeticDescription(l10n, cosmetic.key)
                        : l10n.unlocksLockedDescription,
                  ),
                  trailing: isUnlocked
                      ? FilledButton.tonal(
                          onPressed: () {
                            // TODO(nick): Apply accent color to theme
                          },
                          child: Text(l10n.unlockApply),
                        )
                      : Text(
                          l10n.unlocksLockedLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _cosmeticTitle(AppLocalizations l10n, String key) => switch (key) {
    'theme_accent_midnight' => l10n.unlockThemeAccentMidnight,
    _ => key,
  };

  String _cosmeticDescription(AppLocalizations l10n, String key) =>
      switch (key) {
        'theme_accent_midnight' => l10n.unlockThemeAccentMidnightDescription,
        _ => '',
      };
}
