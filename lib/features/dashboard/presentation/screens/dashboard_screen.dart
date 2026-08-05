import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/router/app_router.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/greeting.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/global_month_calendar.dart';
import 'package:habit_tracker/core/widgets/responsive_breakpoints.dart';
import 'package:habit_tracker/features/dashboard/presentation/search/app_search_delegate.dart';
import 'package:habit_tracker/features/dashboard/presentation/widgets/avatar_display.dart';
import 'package:habit_tracker/features/dashboard/presentation/widgets/boss_challenge_card.dart';
import 'package:habit_tracker/features/dashboard/presentation/widgets/habit_stack_suggestion_card.dart';
import 'package:habit_tracker/features/dashboard/presentation/widgets/module_suggestion_card.dart';
import 'package:habit_tracker/features/dashboard/presentation/widgets/virtual_companion.dart';
import 'package:habit_tracker/features/dashboard/presentation/widgets/weekly_quest_list.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

/// The dashboard tab. Shows an empty state until a module is enabled;
/// otherwise every enabled module's summary card, a day-completion
/// indicator, an upcoming-items strip, and a quick-actions row (FR-C-11).
class DashboardScreen extends ConsumerWidget {
  /// Creates the dashboard screen.
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Premium-gated modules (e.g. Sleep) are excluded here so they don't
    // advertise themselves on the dashboard before purchase — see
    // visibleHabitModulesProvider's doc comment.
    final modules = ref.watch(visibleHabitModulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navDashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: modules.isEmpty
                ? null
                : () => showSearch(
                    context: context,
                    delegate: AppSearchDelegate(modules),
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push('/achievements'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push('/reports'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_view_month),
            onPressed: modules.isEmpty
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) =>
                        _GlobalCalendarSheet(modules: modules),
                  ),
          ),
        ],
      ),
      body: modules.isEmpty
          ? Center(child: Text(l10n.emptyDashboardMessage))
          : MaxContentWidth(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const ModuleSuggestionCard(),
                  Row(
                    children: [
                      const Expanded(child: _DashboardGreeting()),
                      const SizedBox(width: 12),
                      Semantics(
                        button: true,
                        child: GestureDetector(
                          onTap: () => context.push(AppRoutes.settingsAvatar),
                          child: const AvatarDisplay(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _DayCompletionIndicator(modules: modules),
                  const SizedBox(height: 16),
                  const VirtualCompanion(),
                  const SizedBox(height: 16),
                  const WeeklyQuestList(),
                  const SizedBox(height: 16),
                  const BossChallengeCard(),
                  const SizedBox(height: 16),
                  _UpcomingStrip(modules: modules),
                  const SizedBox(height: 16),
                  const HabitStackSuggestionCard(),
                  const SizedBox(height: 16),
                  _QuickActionsRow(modules: modules),
                  const SizedBox(height: 16),
                  for (final module in modules) module.dashboardSummary(ref),
                ],
              ),
            ),
    );
  }
}

class _DashboardGreeting extends ConsumerWidget {
  const _DashboardGreeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final name = ref.watch(appSettingsProvider).value?.displayName;
    final period = greetingPeriodFor(clock.now());
    final text = switch ((period, name)) {
      (GreetingPeriod.morning, final String n?) =>
        l10n.dashboardGreetingMorningNamed(n),
      (GreetingPeriod.morning, null) => l10n.dashboardGreetingMorning,
      (GreetingPeriod.afternoon, final String n?) =>
        l10n.dashboardGreetingAfternoonNamed(n),
      (GreetingPeriod.afternoon, null) => l10n.dashboardGreetingAfternoon,
      (GreetingPeriod.evening, final String n?) =>
        l10n.dashboardGreetingEveningNamed(n),
      (GreetingPeriod.evening, null) => l10n.dashboardGreetingEvening,
      (GreetingPeriod.night, final String n?) =>
        l10n.dashboardGreetingNightNamed(n),
      (GreetingPeriod.night, null) => l10n.dashboardGreetingNight,
    };
    return Text(text, style: Theme.of(context).textTheme.headlineSmall);
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

class _GlobalCalendarSheet extends StatefulWidget {
  const _GlobalCalendarSheet({required this.modules});
  final List<HabitModule> modules;

  @override
  State<_GlobalCalendarSheet> createState() => _GlobalCalendarSheetState();
}

class _GlobalCalendarSheetState extends State<_GlobalCalendarSheet> {
  final LocalDate _month = localDayKey(DateTime.now());
  Map<String, Map<LocalDate, ModuleDayStatus>>? _statuses;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final start = LocalDate(_month.year, _month.month, 1);
    final end = LocalDate(_month.year, _month.month + 1, 1).addDays(-1);
    final entries = await Future.wait(
      widget.modules.map(
        (m) async => MapEntry(
          m.id,
          await m.dayStatus(DateRange(start: start, end: end)),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _statuses = Map.fromEntries(entries));
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _statuses;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: statuses == null
            ? const Center(child: CircularProgressIndicator())
            : GlobalMonthCalendar(
                month: _month,
                statusesByModule: statuses,
                onDayTap: (day) => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(day.toIso()),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final module in widget.modules)
                          Text(
                            '${module.metadata.displayName}: '
                            '${statuses[module.id]?[day]?.kind.name ?? 'none'}',
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
