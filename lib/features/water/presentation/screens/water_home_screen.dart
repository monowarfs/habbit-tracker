import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/widgets/undo_snackbar.dart';
import 'package:habit_tracker/features/achievements/presentation/achievement_localization.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_controller.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';
import 'package:habit_tracker/features/water/presentation/widgets/quick_add_button.dart';
import 'package:habit_tracker/features/water/presentation/widgets/water_log_tile.dart';
import 'package:habit_tracker/features/water/presentation/widgets/water_progress_ring.dart';

/// The Water module's home screen: today's progress, quick-add, and
/// today's log list (FR-W-03/06/09).
class WaterHomeScreen extends ConsumerStatefulWidget {
  /// Creates the water home screen.
  const WaterHomeScreen({super.key});

  @override
  ConsumerState<WaterHomeScreen> createState() => _WaterHomeScreenState();
}

class _WaterHomeScreenState extends ConsumerState<WaterHomeScreen> {
  /// Ids of entries the user just tapped delete on but hasn't yet been
  /// committed (the undo snackbar is still showing) — filtered out of
  /// the rendered list immediately (optimistic hide, zero DB write yet).
  final Set<String> _pendingDeleteIds = {};

  void _deleteWithUndo(AppLocalizations l10n, String entryId) {
    setState(() => _pendingDeleteIds.add(entryId));
    // Captured synchronously (not re-read inside the deferred callbacks
    // below, which can fire after this State is disposed).
    final notifier = ref.read(waterControllerProvider.notifier);
    unawaited(
      showUndoSnackbar(
        context,
        message: l10n.waterEntryDeletedSnackbar,
        undoLabel: l10n.commonUndo,
        onCommit: () async {
          final succeeded = await notifier.deleteEntry(entryId);
          // Write failed: unhide the entry rather than leaving it looking
          // deleted when it's still in the DB.
          if (!succeeded && mounted) {
            setState(() => _pendingDeleteIds.remove(entryId));
          }
        },
        onUndo: () {
          if (mounted) setState(() => _pendingDeleteIds.remove(entryId));
        },
      ),
    );
  }

  List<WaterEntry> _visibleEntries(List<WaterEntry> entries) =>
      _pendingDeleteIds.isEmpty
      ? entries
      : entries.where((e) => !_pendingDeleteIds.contains(e.id)).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progress = ref.watch(todaysWaterProgressProvider);
    final settings = ref.watch(waterSettingsProvider).value;
    final unit =
        ref.watch(appSettingsProvider).value?.waterUnit ?? WaterUnit.ml;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navWater),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: l10n.waterHomeStatsButton,
            onPressed: () => context.push('/water/stats'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.waterHomeSettingsButton,
            onPressed: () => context.push('/water/settings'),
          ),
        ],
      ),
      body: progress == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: WaterProgressRing(
                    totalMl: progress.totalMl,
                    goalMl: progress.goalMl,
                    unit: unit,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.waterHomeQuickAddLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final amount
                        in settings?.quickAddAmountsMl ?? const [250, 500, 750])
                      QuickAddButton(
                        amountMl: amount,
                        unit: unit,
                        onTap: () =>
                            _logQuickAddAndCelebrate(context, ref, amount),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/water/add'),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.waterHomeCustomAddButton),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.waterHomeTodaysLogLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_visibleEntries(progress.entries).isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(l10n.waterHomeEmptyLogs),
                  )
                else
                  for (final entry in _visibleEntries(
                    progress.entries,
                  ).reversed)
                    WaterLogTile(
                      entry: entry,
                      unit: unit,
                      onDelete: () => _deleteWithUndo(l10n, entry.id),
                      onTap: () =>
                          context.push('/water/entry/${entry.id}/edit'),
                    ),
              ],
            ),
    );
  }
}

/// Logs a quick-add entry, then shows a subtle (non-modal) snackbar if
/// doing so newly unlocked an achievement (FR-C-13's "no intrusive
/// popups" requirement).
Future<void> _logQuickAddAndCelebrate(
  BuildContext context,
  WidgetRef ref,
  int amountMl,
) async {
  final repository = ref.read(achievementRepositoryProvider);
  final before = await repository.watchByModule('water').first;
  final unlockedBefore = before
      .where((r) => r.unlockedAt != null)
      .map((r) => r.key)
      .toSet();

  await ref.read(waterControllerProvider.notifier).logQuickAdd(amountMl);

  final after = await repository.watchByModule('water').first;
  final newlyUnlocked = after.where(
    (r) => r.unlockedAt != null && !unlockedBefore.contains(r.key),
  );
  if (newlyUnlocked.isEmpty || !context.mounted) return;
  final module = ref
      .read(habitModulesProvider)
      .firstWhere((m) => m.id == 'water');
  final definition = module.achievementDefinitions.firstWhere(
    (d) => d.key == newlyUnlocked.first.key,
  );
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        l10n.achievementUnlockedSnackbar(
          localizedAchievementTitle(l10n, definition.titleKey),
        ),
      ),
    ),
  );
}
