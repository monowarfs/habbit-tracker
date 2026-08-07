import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/providers/module_day_status_provider.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/heatmap_color_scheme.dart';
import 'package:habit_tracker/core/widgets/heatmap_grid.dart';

/// Cross-module "Year at a Glance" screen (`docs/superpowers/specs/
/// 08-analytics/01-adherence-heatmap-IMPLEMENTATION-PLAN.md`, Task 5):
/// one GitHub-style [HeatmapGrid] per visible module for the selected
/// year, plus a shared legend. Reuses `moduleDayStatusProvider` — already
/// shared by every per-habit heatmap calendar screen (Water/Medicine/
/// Prayer's own stats/history screens) — instead of a second,
/// near-identical provider (the plan's Task 4).
class HeatmapScreen extends ConsumerStatefulWidget {
  /// Creates the heatmap screen.
  const HeatmapScreen({super.key});

  @override
  ConsumerState<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends ConsumerState<HeatmapScreen> {
  late int _year = clock.now().year;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modules = ref.watch(visibleHabitModulesProvider);
    final today = LocalDate.fromDateTime(clock.now());
    final range = DateRange(
      start: LocalDate(_year, 1, 1),
      end: LocalDate(_year, 12, 31),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.heatmapTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _year--),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$_year',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _year >= today.year
                ? null
                : () => setState(() => _year++),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final module in modules) ...[
            Row(
              children: [
                Icon(module.metadata.icon, color: module.metadata.accentColor),
                const SizedBox(width: 8),
                Text(
                  module.metadata.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final dayStatus = ref
                    .watch(moduleDayStatusProvider(module.id, range))
                    .value;
                if (dayStatus == null) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return HeatmapGrid(
                  dayStatus: dayStatus,
                  year: _year,
                  today: today,
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          const Divider(),
          const SizedBox(height: 8),
          _Legend(l10n: l10n),
        ],
      ),
    );
  }
}

/// Swatch legend below the grids — reuses [HeatmapColorScheme] itself so
/// the legend can never drift out of sync with the grid's actual colors.
class _Legend extends StatelessWidget {
  const _Legend({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final entries = <(ModuleDayStatusKind, String)>[
      (ModuleDayStatusKind.complete, l10n.calendarStatusDoneLabel),
      (ModuleDayStatusKind.partial, l10n.calendarStatusPartialLabel),
      (ModuleDayStatusKind.missed, l10n.calendarStatusMissedLabel),
      (ModuleDayStatusKind.paused, l10n.calendarStatusSkippedLabel),
      (ModuleDayStatusKind.none, l10n.heatmapTooltipNone),
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final (kind, label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: HeatmapColorScheme.colorForStatus(context, kind),
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: HeatmapColorScheme.iconForStatus(kind) == null
                    ? null
                    : Icon(
                        HeatmapColorScheme.iconForStatus(kind),
                        size: 8,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
              ),
              const SizedBox(width: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}
