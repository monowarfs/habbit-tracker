import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_day.dart';

/// The dashboard tab. Shows an empty state until a module is enabled;
/// otherwise every enabled module's summary card, a day-completion
/// indicator, an upcoming-items strip, and a quick-actions row (FR-C-11).
class DashboardScreen extends ConsumerWidget {
  /// Creates the dashboard screen.
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final modules = ref.watch(habitModulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navDashboard),
        actions: [
          // ponytail: search wiring lands in a later task
          // (`app_search_delegate.dart`); disabled until then.
          const IconButton(icon: Icon(Icons.search), onPressed: null),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push('/achievements'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push('/reports'),
          ),
        ],
      ),
      body: modules.isEmpty
          ? Center(child: Text(l10n.emptyDashboardMessage))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _DayCompletionIndicator(modules: modules),
                const SizedBox(height: 16),
                _UpcomingStrip(modules: modules),
                const SizedBox(height: 16),
                _QuickActionsRow(modules: modules),
                const SizedBox(height: 16),
                for (final module in modules) module.dashboardSummary(ref),
              ],
            ),
    );
  }
}

class _DayCompletionIndicator extends StatelessWidget {
  const _DayCompletionIndicator({required this.modules});
  final List<HabitModule> modules;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: Future.wait(
        modules.map((m) async {
          final today = localDayKey(DateTime.now());
          final status = await m.dayStatus(
            DateRange(start: today, end: today),
          );
          return status[today]?.kind == ModuleDayStatusKind.complete ? 1 : 0;
        }),
      ),
      builder: (context, snapshot) {
        final completed = snapshot.data?.fold<int>(0, (a, b) => a + b) ?? 0;
        return LinearProgressIndicator(
          value: modules.isEmpty ? 0 : completed / modules.length,
          minHeight: 8,
        );
      },
    );
  }
}

class _UpcomingStrip extends StatelessWidget {
  const _UpcomingStrip({required this.modules});
  final List<HabitModule> modules;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final chips = [
          for (final module in modules) ?module.nextUpcoming(ref),
        ];
        if (chips.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => chips[index],
          ),
        );
      },
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.modules});
  final List<HabitModule> modules;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final actions = [
          for (final module in modules) ...module.quickActions(ref),
        ];
        if (actions.isEmpty) return const SizedBox.shrink();
        return Wrap(spacing: 8, runSpacing: 8, children: actions);
      },
    );
  }
}
