import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/domain/entities/water_goal.dart';
import 'package:habit_tracker/features/water/domain/entities/water_settings.dart';
import 'package:habit_tracker/features/water/domain/repositories/water_repository.dart';
import 'package:habit_tracker/features/water/domain/usecases/calculate_water_streak.dart';
import 'package:habit_tracker/features/water/domain/usecases/resolve_goal_for_date.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_controller.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_add_entry_screen.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_home_screen.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_settings_screen.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_stats_screen.dart';
import 'package:habit_tracker/features/water/presentation/water_amount_formatter.dart';
import 'package:habit_tracker/features/water/presentation/widgets/water_progress_ring.dart';

/// The Water module's [HabitModule] registration
/// (`technical/architecture.md`).
class WaterModule implements HabitModule {
  /// Creates the module backed by [_repository].
  const WaterModule(this._repository);

  final WaterRepository _repository;

  @override
  String get id => 'water';

  @override
  ModuleMetadata get metadata => const ModuleMetadata(
    displayName: 'Water',
    icon: Icons.water_drop,
    accentColor: ModuleAccents.water,
  );

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/water',
      builder: (context, state) => const WaterHomeScreen(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => const WaterAddEntryScreen(),
        ),
        GoRoute(
          path: 'entry/:id/edit',
          builder: (context, state) => WaterAddEntryScreen(
            editEntryId: state.pathParameters['id'],
          ),
        ),
        GoRoute(
          path: 'stats',
          builder: (context, state) => const WaterStatsScreen(),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const WaterSettingsScreen(),
        ),
      ],
    ),
  ];

  @override
  Widget dashboardSummary(WidgetRef ref) {
    final progress = ref.watch(todaysWaterProgressProvider);
    final unit =
        ref.watch(appSettingsProvider).value?.waterUnit ?? WaterUnit.ml;
    if (progress == null) return const SizedBox.shrink();
    return Builder(
      builder: (context) => Card(
        child: ListTile(
          leading: WaterProgressRing(
            totalMl: progress.totalMl,
            goalMl: progress.goalMl,
            unit: unit,
            size: 40,
            // The subtitle below already shows totals; the ring's own
            // center label doesn't fit at this tile scale (pre-existing
            // overflow, only exposed once the dashboard actually
            // rendered this tile — see `docs/superpowers/plans/
            // 2026-07-19-dashboard-reports-achievements.md`, Task 13).
            showLabel: false,
          ),
          title: Text(metadata.displayName),
          subtitle: Text(
            '${formatWaterNumber(context, progress.totalMl, unit)} / '
            '${formatWaterAmount(context, progress.goalMl, unit)}',
          ),
          onTap: () => context.go('/water'),
        ),
      ),
    );
  }

  @override
  Widget? settingsEntry(WidgetRef ref) {
    return Builder(
      builder: (context) => ListTile(
        leading: const Icon(Icons.water_drop, color: ModuleAccents.water),
        title: Text(metadata.displayName),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/water/settings'),
      ),
    );
  }

  /// How many days ahead to compute reminder slots — matches
  /// `core/notifications`'s own materialization window
  /// (`strategies/notifications.md`'s "Window 2"), so nothing here needs to
  /// track that constant separately; it just needs to cover it.
  static const _lookaheadDays = 3;

  @override
  Future<List<PendingNotification>> pendingNotifications() async {
    final settings = await _repository.watchSettings().first;
    if (!settings.reminderEnabled) return [];

    final now = clock.now();
    final notifications = <PendingNotification>[];
    for (var dayOffset = 0; dayOffset <= _lookaheadDays; dayOffset++) {
      final day = localDayKey(now).addDays(dayOffset);
      var slot = day.toDateTimeUtc().toLocal().add(
        Duration(
          hours: settings.reminderWindowStart.hour,
          minutes: settings.reminderWindowStart.minute,
        ),
      );
      final windowEnd = day.toDateTimeUtc().toLocal().add(
        Duration(
          hours: settings.reminderWindowEnd.hour,
          minutes: settings.reminderWindowEnd.minute,
        ),
      );
      while (slot.isBefore(windowEnd) || slot.isAtSameMomentAs(windowEnd)) {
        if (slot.isAfter(now)) {
          notifications.add(
            PendingNotification(
              id:
                  'water_reminder_'
                  '${day.year}${day.month.toString().padLeft(2, '0')}'
                  '${day.day.toString().padLeft(2, '0')}_'
                  '${slot.hour}_${slot.minute}',
              scheduledAt: slot,
              title: 'Time to drink water',
              body: 'Keep your water goal on track.',
              sourceType: 'water_reminder',
              deepLinkRoute: '/water',
            ),
          );
        }
        slot = slot.add(Duration(minutes: settings.reminderIntervalMinutes));
      }
    }
    return notifications;
  }

  @override
  Future<void> onNotificationAction(
    String sourceId,
    NotificationActionType action,
  ) async {
    // Snooze/Skip never mutate Water data (`strategies/notifications.md`'s
    // "streak effect: none" note) — only Done logs an entry.
    if (action != NotificationActionType.done) return;
    final settings = await _repository.watchSettings().first;
    final amountMl = settings.quickAddAmountsMl.isEmpty
        ? 250
        : settings.quickAddAmountsMl.first;
    await _repository.addEntry(
      amountMl: amountMl,
      loggedAt: clock.now(),
      source: WaterEntrySource.quick,
    );
  }

  @override
  Future<void> onQuickAction() async {
    final settings = await _repository.watchSettings().first;
    final amountMl = settings.quickAddAmountsMl.isEmpty
        ? 250
        : settings.quickAddAmountsMl.first;
    await _repository.addEntry(
      amountMl: amountMl,
      loggedAt: clock.now(),
      source: WaterEntrySource.quick,
    );
  }

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async {
    final entries = await _repository
        .watchEntriesInRange(range.start, range.end)
        .first;
    final goals = await _repository.allGoals();
    final totalsByDay = <LocalDate, int>{};
    for (final entry in entries) {
      final day = localDayKey(entry.loggedAt);
      totalsByDay[day] = (totalsByDay[day] ?? 0) + entry.amountMl;
    }
    const resolveGoal = ResolveGoalForDateUseCase();
    final result = <LocalDate, ModuleDayStatus>{};
    var day = range.start;
    while (day.compareTo(range.end) <= 0) {
      final total = totalsByDay[day] ?? 0;
      final goal = resolveGoal.execute(goals, day);
      final kind = total == 0
          ? ModuleDayStatusKind.none
          : (goal.goalMl > 0 && total >= goal.goalMl)
          ? ModuleDayStatusKind.complete
          : ModuleDayStatusKind.partial;
      result[day] = ModuleDayStatus(kind: kind, value: total);
      day = day.addDays(1);
    }
    return result;
  }

  @override
  Widget? nextUpcoming(WidgetRef ref) {
    final progress = ref.watch(todaysWaterProgressProvider);
    if (progress == null) return null;
    final remainingMl = progress.goalMl - progress.totalMl;
    if (remainingMl <= 0) return null;
    final unit =
        ref.watch(appSettingsProvider).value?.waterUnit ?? WaterUnit.ml;
    return Builder(
      builder: (context) => Chip(
        avatar: const Icon(Icons.water_drop, size: 16),
        label: Text(formatWaterAmount(context, remainingMl, unit)),
      ),
    );
  }

  @override
  List<Widget> quickActions(WidgetRef ref) {
    final settings = ref.watch(waterSettingsProvider).value;
    if (settings == null || settings.quickAddAmountsMl.isEmpty) return const [];
    final unit =
        ref.watch(appSettingsProvider).value?.waterUnit ?? WaterUnit.ml;
    final amountMl = settings.quickAddAmountsMl.first;
    return [
      Consumer(
        builder: (context, innerRef, _) => ActionChip(
          avatar: const Icon(Icons.add, size: 16),
          label: Text(formatWaterAmount(context, amountMl, unit)),
          onPressed: () => innerRef
              .read(waterControllerProvider.notifier)
              .logQuickAdd(amountMl),
        ),
      ),
    ];
  }

  @override
  Future<List<SearchResult>> search(String query) async => const [];

  @override
  List<AchievementDefinition> get achievementDefinitions => [
    AchievementDefinition(
      key: 'water_first_log',
      moduleId: id,
      titleKey: 'achievementWaterFirstLogTitle',
      descriptionKey: 'achievementWaterFirstLogDescription',
      target: 1,
      currentProgress: () async {
        final entries = await _repository.allEntries();
        return entries.isEmpty ? 0 : 1;
      },
    ),
    AchievementDefinition(
      key: 'water_streak_7',
      moduleId: id,
      titleKey: 'achievementWaterStreak7Title',
      descriptionKey: 'achievementWaterStreak7Description',
      target: 7,
      currentProgress: _currentWaterStreak,
    ),
    AchievementDefinition(
      key: 'water_streak_30',
      moduleId: id,
      titleKey: 'achievementWaterStreak30Title',
      descriptionKey: 'achievementWaterStreak30Description',
      target: 30,
      currentProgress: _currentWaterStreak,
    ),
    AchievementDefinition(
      key: 'water_streak_100',
      moduleId: id,
      titleKey: 'achievementWaterStreak100Title',
      descriptionKey: 'achievementWaterStreak100Description',
      target: 100,
      currentProgress: _currentWaterStreak,
    ),
    AchievementDefinition(
      key: 'water_perfect_week',
      moduleId: id,
      titleKey: 'achievementWaterPerfectWeekTitle',
      descriptionKey: 'achievementWaterPerfectWeekDescription',
      target: 1,
      currentProgress: _perfectWaterWeek,
    ),
  ];

  Future<int> _currentWaterStreak() async {
    final goals = await _repository.allGoals();
    if (goals.isEmpty) return 0;
    final today = localDayKey(clock.now());
    final earliest = goals
        .map((g) => localDayKey(g.effectiveFrom))
        .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    final entries = await _repository
        .watchEntriesInRange(earliest, today)
        .first;
    final totals = <LocalDate, int>{};
    for (final entry in entries) {
      final day = localDayKey(entry.loggedAt);
      totals[day] = (totals[day] ?? 0) + entry.amountMl;
    }
    final result = const CalculateWaterStreakUseCase().execute(
      dailyTotalsMl: totals,
      goals: goals,
      earliestDay: earliest,
      today: today,
    );
    return result.current;
  }

  Future<int> _perfectWaterWeek() async {
    final today = localDayKey(clock.now());
    final status = await dayStatus(
      DateRange(start: today.addDays(-6), end: today),
    );
    final allComplete = status.values.every(
      (s) => s.kind == ModuleDayStatusKind.complete,
    );
    return allComplete ? 1 : 0;
  }

  @override
  Future<ModuleExport> exportData() async {
    final goals = await _repository.allGoals();
    final entries = await _repository.allEntries();
    final settings = await _repository.watchSettings().first;
    return ModuleExport({
      'goals': goals.map(_goalToJson).toList(),
      'logs': entries.map(_entryToJson).toList(),
      'settings': _settingsToJson(settings),
    });
  }

  @override
  Future<void> importData(ModuleExport data) async {
    final goals = (data.payload['goals'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (final json in goals) {
      await _repository.setGoal(
        json['goalMl'] as int,
        effectiveFrom: DateTime.parse(json['effectiveFrom'] as String),
      );
    }
    final logs = (data.payload['logs'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (final json in logs) {
      await _repository.addEntry(
        amountMl: json['amountMl'] as int,
        loggedAt: DateTime.parse(json['loggedAt'] as String),
        source: json['source'] == 'quick'
            ? WaterEntrySource.quick
            : WaterEntrySource.custom,
        notes: json['notes'] as String?,
      );
    }
    final settingsJson = data.payload['settings'] as Map<String, dynamic>?;
    if (settingsJson != null) {
      await _repository.updateQuickAddAmounts(
        (settingsJson['quickAddAmountsMl'] as List<dynamic>).cast<int>(),
      );
      await _repository.updateReminderSettings(
        enabled: settingsJson['reminderEnabled'] as bool,
        intervalMinutes: settingsJson['reminderIntervalMinutes'] as int,
        windowStart: LocalTime.parse(
          settingsJson['reminderWindowStart'] as String,
        ),
        windowEnd: LocalTime.parse(
          settingsJson['reminderWindowEnd'] as String,
        ),
      );
    }
  }

  @override
  Future<void> wipeData() => _repository.wipeAll();

  Map<String, Object?> _settingsToJson(WaterSettings settings) => {
    'quickAddAmountsMl': settings.quickAddAmountsMl,
    'reminderEnabled': settings.reminderEnabled,
    'reminderIntervalMinutes': settings.reminderIntervalMinutes,
    'reminderWindowStart': settings.reminderWindowStart.format(),
    'reminderWindowEnd': settings.reminderWindowEnd.format(),
  };

  Map<String, Object?> _goalToJson(WaterGoal goal) => {
    'id': goal.id,
    'goalMl': goal.goalMl,
    'effectiveFrom': goal.effectiveFrom.toIso8601String(),
  };

  Map<String, Object?> _entryToJson(WaterEntry entry) => {
    'id': entry.id,
    'amountMl': entry.amountMl,
    'loggedAt': entry.loggedAt.toIso8601String(),
    'source': entry.source == WaterEntrySource.quick ? 'quick' : 'custom',
    'notes': entry.notes,
  };
}
