import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_controller.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';
import 'package:habit_tracker/features/water/presentation/widgets/quick_add_button.dart';
import 'package:habit_tracker/features/water/presentation/widgets/water_log_tile.dart';
import 'package:habit_tracker/features/water/presentation/widgets/water_progress_ring.dart';

/// The Water module's home screen: today's progress, quick-add, and
/// today's log list (FR-W-03/06/09).
class WaterHomeScreen extends ConsumerWidget {
  /// Creates the water home screen.
  const WaterHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final progress = ref.watch(todaysWaterProgressProvider);
    final settings = ref.watch(waterSettingsProvider).value;
    final unit =
        ref.watch(appSettingsProvider).value?.waterUnit ?? WaterUnit.ml;
    final controller = ref.read(waterControllerProvider.notifier);

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
                        onTap: () => controller.logQuickAdd(amount),
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
                if (progress.entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(l10n.waterHomeEmptyLogs),
                  )
                else
                  for (final entry in progress.entries.reversed)
                    WaterLogTile(
                      entry: entry,
                      unit: unit,
                      onDelete: () => controller.deleteEntry(entry.id),
                      onTap: () =>
                          context.push('/water/entry/${entry.id}/edit'),
                    ),
              ],
            ),
    );
  }
}
