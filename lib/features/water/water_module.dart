import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/pauses/pause_service.dart';
import 'package:habit_tracker/core/pauses/presentation/create_pause_screen.dart';
import 'package:habit_tracker/core/recaps/year_summary.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/hijri_date.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/widget_summary_data.dart';
import 'package:habit_tracker/features/prayer/data/location_resolver.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_prayer_times.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/water/data/weather_cache_refresher.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/domain/entities/water_goal.dart';
import 'package:habit_tracker/features/water/domain/entities/water_settings.dart';
import 'package:habit_tracker/features/water/domain/repositories/water_repository.dart';
import 'package:habit_tracker/features/water/domain/usecases/calculate_water_streak.dart';
import 'package:habit_tracker/features/water/domain/usecases/resolve_goal_for_date.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_controller.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';
import 'package:habit_tracker/features/water/presentation/screens/archived_goals_screen.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_add_entry_screen.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_home_screen.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_settings_screen.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_stats_screen.dart';
import 'package:habit_tracker/features/water/presentation/water_amount_formatter.dart';
import 'package:habit_tracker/features/water/presentation/weather_nudge_copy.dart';
import 'package:habit_tracker/features/water/presentation/widgets/water_progress_ring.dart';

/// The Water module's [HabitModule] registration
/// (`technical/architecture.md`).
class WaterModule implements HabitModule {
  /// Creates the module backed by [_repository]. [_settingsRepository] and
  /// [_prayerRepository] are optional, additive dependencies powering
  /// Ramadan-mode fasting-aware reminder windows
  /// (`docs/superpowers/specs/02-delightful/01-ramadan-mode-design.md`) —
  /// omitted (as every pre-existing call site/test still does), Water
  /// behaves exactly as before and Ramadan mode never activates.
  const WaterModule(
    this._repository, {
    this._settingsRepository,
    this._prayerRepository,
    this._pauseService,
  });

  final WaterRepository _repository;
  final SettingsRepository? _settingsRepository;
  final PrayerRepository? _prayerRepository;
  final PauseService? _pauseService;

  /// `HabitModule` contract methods take no `Ref`
  /// (`core/modules/habit_module.dart`'s doc comment), so they can't read
  /// `activeProfileProvider` — they run from background isolates,
  /// WorkManager, and the notification engine, none of which have a
  /// widget tree. Family/multi-profile's Task 8/9 give the notification
  /// planner and widget refresher their own profile-aware entry points;
  /// everything else here (export/import/wipe/dashboard aggregation)
  /// still operates on the system profile only until a later pass thread
  /// a profile id through the `HabitModule` contract itself.
  static const _fixedProfileId = 'system';

  @override
  String get id => 'water';

  @override
  ModuleMetadata get metadata => ModuleMetadata(
    displayName: 'Water',
    icon: Icons.water_drop,
    accentColor: ModuleThemeAccents.defaults.water,
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
        GoRoute(
          path: 'archived',
          builder: (context, state) => const ArchivedGoalsScreen(),
        ),
        GoRoute(
          path: 'pause',
          builder: (context, state) => const CreatePauseScreen(
            moduleId: 'water',
          ),
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
        leading: Icon(
          Icons.water_drop,
          color: ModuleThemeAccents.defaults.water,
        ),
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
    final settings = await _repository
        .watchSettings(profileId: _fixedProfileId)
        .first;
    if (!settings.reminderEnabled) return [];

    final appSettings = _settingsRepository == null
        ? null
        : await _settingsRepository.watchSettings().first;

    final now = clock.now();
    final fetchedAt = settings.lastWeatherFetchedAt;
    final weatherClause =
        settings.weatherNudgeEnabled &&
            fetchedAt != null &&
            now.difference(fetchedAt) < weatherCacheStalenessCeiling
        ? weatherNudgeClause(settings.lastWeatherTemperatureCelsius!)
        : null;
    final body = weatherClause == null
        ? 'Keep your water goal on track.'
        : 'Keep your water goal on track. $weatherClause';
    final notifications = <PendingNotification>[];
    final today = localDayKey(now);
    for (var dayOffset = 0; dayOffset <= _lookaheadDays; dayOffset++) {
      final day = today.addDays(dayOffset);
      final ramadanActive =
          appSettings != null &&
          _prayerRepository != null &&
          resolveRamadanModeActive(
            manualOverride: appSettings.ramadanModeManualOverride,
            autoDetectEnabled: appSettings.ramadanAutoDetectEnabled,
            today: day,
          );
      final windows = ramadanActive
          ? await _fastingAwareWindows(day, settings)
          : [_weekdayWindow(day, settings)];
      for (final window in windows) {
        final localMidnight = DateTime(
          day.year,
          day.month,
          day.day,
        ).toUtc();
        var slot = localMidnight.toLocal().add(
          Duration(hours: window.start.hour, minutes: window.start.minute),
        );
        final windowEnd = localMidnight.toLocal().add(
          Duration(hours: window.end.hour, minutes: window.end.minute),
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
                body: body,
                sourceType: 'water_reminder',
                deepLinkRoute: '/water',
                quietHoursSuppressible: true,
              ),
            );
          }
          slot = slot.add(Duration(minutes: settings.reminderIntervalMinutes));
        }
      }
    }
    return notifications;
  }

  ({LocalTime start, LocalTime end}) _weekdayWindow(
    LocalDate day,
    WaterSettings settings,
  ) {
    final weekday = day.toDateTimeUtc().weekday;
    final override = settings.reminderWindowOverrides[weekday];
    return (
      start: override?.start ?? settings.reminderWindowStart,
      end: override?.end ?? settings.reminderWindowEnd,
    );
  }

  /// The non-fasting sub-windows within [day]: before that day's Fajr
  /// (the tail of the previous night's eating hours) and after that
  /// day's Maghrib (that night's Iftar onward), each clipped to the
  /// user's own configured window (`01-ramadan-mode-design.md`'s Design
  /// §3: "clips the window to whichever is narrower ... so a user who
  /// only wants morning reminders anyway isn't suddenly nudged at 9pm
  /// right after Iftar"). Falls back to the single plain weekday window,
  /// unclipped, if location resolution fails — Ramadan mode degrades to
  /// "no behavior change" rather than throwing.
  Future<List<({LocalTime start, LocalTime end})>> _fastingAwareWindows(
    LocalDate day,
    WaterSettings settings,
  ) async {
    final userWindow = _weekdayWindow(day, settings);
    final prayerSettings = await _prayerRepository!.getSettings(
      profileId: _fixedProfileId,
    );
    final locationResult = await resolveLocation(prayerSettings);
    if (locationResult case Failure()) return [userWindow];
    final location = (locationResult as Success<ResolvedLocation>).value;
    final times = calculatePrayerTimes(
      date: day,
      latitude: location.latitude,
      longitude: location.longitude,
      ianaTimezone: location.ianaTimezone,
      method: prayerSettings.calculationMethod,
      asrMethod: prayerSettings.asrMethod,
    );
    final fajrLocal = _asLocalTime(times.fajr);
    final maghribLocal = _asLocalTime(times.maghrib);
    final windows = <({LocalTime start, LocalTime end})>[];
    final morning = _clip(
      (start: const LocalTime(0, 0), end: fajrLocal),
      userWindow,
    );
    if (morning != null) windows.add(morning);
    final evening = _clip(
      (start: maghribLocal, end: const LocalTime(23, 59)),
      userWindow,
    );
    if (evening != null) windows.add(evening);
    return windows;
  }

  LocalTime _asLocalTime(DateTime utcInstant) {
    final local = utcInstant.toLocal();
    return LocalTime(local.hour, local.minute);
  }

  /// Intersects [candidate] with [userWindow], or `null` if the
  /// intersection is empty (e.g. the user's own configured window sits
  /// entirely inside daylight/fasting hours — correctly zero reminders
  /// that day, not a bug).
  ({LocalTime start, LocalTime end})? _clip(
    ({LocalTime start, LocalTime end}) candidate,
    ({LocalTime start, LocalTime end}) userWindow,
  ) {
    final start = candidate.start.compareTo(userWindow.start) >= 0
        ? candidate.start
        : userWindow.start;
    final end = candidate.end.compareTo(userWindow.end) <= 0
        ? candidate.end
        : userWindow.end;
    if (start.compareTo(end) >= 0) return null;
    return (start: start, end: end);
  }

  @override
  Future<void> onNotificationAction(
    String sourceId,
    NotificationActionType action,
  ) async {
    // Snooze/Skip never mutate Water data (`strategies/notifications.md`'s
    // "streak effect: none" note) — only Done logs an entry.
    if (action != NotificationActionType.done) return;
    final settings = await _repository
        .watchSettings(profileId: _fixedProfileId)
        .first;
    final amountMl = settings.quickAddAmountsMl.isEmpty
        ? 250
        : settings.quickAddAmountsMl.first;
    await _repository.addEntry(
      amountMl: amountMl,
      loggedAt: clock.now(),
      source: WaterEntrySource.quick,
      profileId: _fixedProfileId,
    );
  }

  @override
  Future<void> onQuickAction() async {
    final settings = await _repository
        .watchSettings(profileId: _fixedProfileId)
        .first;
    final amountMl = settings.quickAddAmountsMl.isEmpty
        ? 250
        : settings.quickAddAmountsMl.first;
    await _repository.addEntry(
      amountMl: amountMl,
      loggedAt: clock.now(),
      source: WaterEntrySource.quick,
      profileId: _fixedProfileId,
    );
  }

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async {
    final entries = await _repository
        .watchEntriesInRange(
          range.start,
          range.end,
          profileId: _fixedProfileId,
        )
        .first;
    final goals = await _repository.allGoals(profileId: _fixedProfileId);
    final totalsByDay = <LocalDate, int>{};
    for (final entry in entries) {
      final day = localDayKey(entry.loggedAt);
      totalsByDay[day] = (totalsByDay[day] ?? 0) + entry.amountMl;
    }
    const resolveGoal = ResolveGoalForDateUseCase();
    final result = <LocalDate, ModuleDayStatus>{};
    // Check if the user ever had goals (active or archived). If they
    // archived all goals, the module is paused. If they never set any,
    // the module is simply inactive (none).
    final hasAnyGoals = await _repository.hasAnyGoals(
      profileId: _fixedProfileId,
    );
    final isArchived = hasAnyGoals && goals.isEmpty;
    // Fetch pause-aware days for this module.
    final pauseSvc = _pauseService;
    final pausedDays = pauseSvc != null
        ? await pauseSvc.pausedDaysInRange(
            moduleId: 'water',
            range: range,
            profileId: _fixedProfileId,
          )
        : <LocalDate>{};
    var day = range.start;
    while (day.compareTo(range.end) <= 0) {
      if (isArchived || pausedDays.contains(day)) {
        result[day] = const ModuleDayStatus(
          kind: ModuleDayStatusKind.paused,
          value: 0,
        );
      } else {
        final total = totalsByDay[day] ?? 0;
        final goal = resolveGoal.execute(goals, day);
        final kind = total == 0
            ? ModuleDayStatusKind.none
            : (goal.goalMl > 0 && total >= goal.goalMl)
            ? ModuleDayStatusKind.complete
            : ModuleDayStatusKind.partial;
        result[day] = ModuleDayStatus(kind: kind, value: total);
      }
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
        final entries = await _repository.allEntries(
          profileId: _fixedProfileId,
        );
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
      rarity: BadgeRarity.rare,
    ),
    AchievementDefinition(
      key: 'water_streak_100',
      moduleId: id,
      titleKey: 'achievementWaterStreak100Title',
      descriptionKey: 'achievementWaterStreak100Description',
      target: 100,
      currentProgress: _currentWaterStreak,
      rarity: BadgeRarity.legendary,
    ),
    AchievementDefinition(
      key: 'water_perfect_week',
      moduleId: id,
      titleKey: 'achievementWaterPerfectWeekTitle',
      descriptionKey: 'achievementWaterPerfectWeekDescription',
      target: 1,
      currentProgress: _perfectWaterWeek,
      rarity: BadgeRarity.rare,
    ),
  ];

  Future<int> _currentWaterStreak() async {
    final goals = await _repository.allGoals(profileId: _fixedProfileId);
    if (goals.isEmpty) return 0;
    final today = localDayKey(clock.now());
    final earliest = goals
        .map((g) => localDayKey(g.effectiveFrom))
        .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    final entries = await _repository
        .watchEntriesInRange(earliest, today, profileId: _fixedProfileId)
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
    final goals = await _repository.allGoals(profileId: _fixedProfileId);
    final entries = await _repository.allEntries(profileId: _fixedProfileId);
    final settings = await _repository
        .watchSettings(profileId: _fixedProfileId)
        .first;
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
        profileId: _fixedProfileId,
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
        profileId: _fixedProfileId,
      );
    }
    final settingsJson = data.payload['settings'] as Map<String, dynamic>?;
    if (settingsJson != null) {
      await _repository.updateQuickAddAmounts(
        (settingsJson['quickAddAmountsMl'] as List<dynamic>).cast<int>(),
        profileId: _fixedProfileId,
      );
      final overridesJson =
          settingsJson['reminderWindowOverrides'] as Map<String, dynamic>? ??
          const {};
      await _repository.updateReminderSettings(
        enabled: settingsJson['reminderEnabled'] as bool,
        intervalMinutes: settingsJson['reminderIntervalMinutes'] as int,
        windowStart: LocalTime.parse(
          settingsJson['reminderWindowStart'] as String,
        ),
        windowEnd: LocalTime.parse(
          settingsJson['reminderWindowEnd'] as String,
        ),
        windowOverrides: {
          for (final entry in overridesJson.entries)
            int.parse(entry.key): (
              start: LocalTime.parse(
                (entry.value as Map)['start'] as String,
              ),
              end: LocalTime.parse(
                (entry.value as Map)['end'] as String,
              ),
            ),
        },
        profileId: _fixedProfileId,
      );
    }
  }

  @override
  Future<void> wipeData() => _repository.wipeAll(profileId: _fixedProfileId);

  @override
  Future<WidgetSummaryData?> widgetSummary() async {
    final settings = await _repository
        .watchSettings(profileId: _fixedProfileId)
        .first;
    final goals = await _repository.allGoals(profileId: _fixedProfileId);
    if (goals.isEmpty) return null;
    final today = localDayKey(clock.now());
    final goal = const ResolveGoalForDateUseCase().execute(goals, today);
    final entries = await _repository
        .watchEntriesInRange(today, today, profileId: _fixedProfileId)
        .first;
    final totalMl = entries.fold(0, (sum, e) => sum + e.amountMl);
    final amountMl = settings.quickAddAmountsMl.isEmpty
        ? 250
        : settings.quickAddAmountsMl.first;
    final remaining = goal.goalMl - totalMl;
    return WidgetSummaryData(
      moduleId: id,
      headline: '$totalMl / ${goal.goalMl} ml',
      progressFraction: goal.goalMl > 0
          ? (totalMl / goal.goalMl).clamp(0.0, 1.0)
          : null,
      primaryActionLabel: remaining > 0 ? '+$amountMl ml' : null,
      primaryActionSourceId: remaining > 0 ? 'water_quick_add' : null,
      deepLinkRoute: '/water',
      pendingCount: remaining > 0 ? 1 : 0,
    );
  }

  Map<String, Object?> _settingsToJson(WaterSettings settings) => {
    'quickAddAmountsMl': settings.quickAddAmountsMl,
    'reminderEnabled': settings.reminderEnabled,
    'reminderIntervalMinutes': settings.reminderIntervalMinutes,
    'reminderWindowStart': settings.reminderWindowStart.format(),
    'reminderWindowEnd': settings.reminderWindowEnd.format(),
    'reminderWindowOverrides': {
      for (final entry in settings.reminderWindowOverrides.entries)
        '${entry.key}': {
          'start': entry.value.start.format(),
          'end': entry.value.end.format(),
        },
    },
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

  @override
  Future<ModuleYearStats?> yearAggregation(DateRange yearRange) async {
    final entries = await _repository
        .watchEntriesInRange(
          yearRange.start,
          yearRange.end,
          profileId: _fixedProfileId,
        )
        .first;
    if (entries.isEmpty) return null;

    final goals = await _repository.allGoals(profileId: _fixedProfileId);
    const resolveGoal = ResolveGoalForDateUseCase();

    final totalsByDay = <LocalDate, int>{};
    for (final entry in entries) {
      final day = localDayKey(entry.loggedAt);
      totalsByDay[day] = (totalsByDay[day] ?? 0) + entry.amountMl;
    }

    var totalMl = 0;
    var daysGoalMet = 0;
    var bestDayValue = 0;
    final activeDays = <LocalDate>{};

    var day = yearRange.start;
    while (day.compareTo(yearRange.end) <= 0) {
      final total = totalsByDay[day] ?? 0;
      if (total > 0) {
        activeDays.add(day);
        totalMl += total;
        if (total > bestDayValue) bestDayValue = total;
        final goal = resolveGoal.execute(goals, day);
        if (goal.goalMl > 0 && total >= goal.goalMl) daysGoalMet++;
      }
      day = day.addDays(1);
    }

    // Count days in range by iterating.
    var daysInRange = 0;
    var countDay = yearRange.start;
    while (countDay.compareTo(yearRange.end) <= 0) {
      daysInRange++;
      countDay = countDay.addDays(1);
    }
    final averageDailyMl = daysInRange > 0 ? totalMl / daysInRange : 0.0;

    // Compute longest consecutive streak.
    var longest = 0;
    var running = 0;
    day = yearRange.start;
    while (day.compareTo(yearRange.end) <= 0) {
      final total = totalsByDay[day] ?? 0;
      final goal = resolveGoal.execute(goals, day);
      if (goal.goalMl > 0 && total >= goal.goalMl) {
        running++;
        if (running > longest) longest = running;
      } else {
        running = 0;
      }
      day = day.addDays(1);
    }

    // Compute months active.
    final monthsActive = <int>{};
    for (final d in activeDays) {
      monthsActive.add(d.month);
    }

    return moduleYearStatsFromColor(
      moduleId: id,
      displayName: metadata.displayName,
      accentColor: metadata.accentColor,
      totalMl: totalMl,
      averageDailyMl: averageDailyMl,
      daysGoalMet: daysGoalMet,
      longestConsecutiveStreak: longest,
      longestStreakAll: longest,
      bestDayValue: bestDayValue,
      monthsActive: monthsActive.length,
      monthsTotal: 12,
    );
  }
}
