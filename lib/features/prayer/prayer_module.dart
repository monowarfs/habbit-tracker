import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/pauses/pause_service.dart';
import 'package:habit_tracker/core/recaps/year_summary.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/countdown_format.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/hijri_date.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/widget_summary_data.dart';
import 'package:habit_tracker/features/prayer/data/location_resolver.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_prayer_streak.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/effective_prayer_status.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/jumuah_label.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_controller.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:habit_tracker/features/prayer/presentation/ramadan_prayer_framing.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_history_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_home_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_qadha_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_settings_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_stats_screen.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

/// The Prayer module's [HabitModule] registration
/// (`technical/architecture.md`). Mirrors `MedicineModule`'s shape almost
/// exactly.
class PrayerModule implements HabitModule {
  /// Creates the module backed by [_repository]. [_settingsRepository] is
  /// an optional, additive dependency used only to relabel Fajr/Maghrib
  /// as Sehri/Iftar during Ramadan (`docs/superpowers/specs/
  /// 02-delightful/01-ramadan-mode-design.md`) — omitted (as every
  /// pre-existing call site/test still does), that relabeling never
  /// happens and everything else is unchanged.
  const PrayerModule(
    this._repository, {
    this._settingsRepository,
    this._pauseService,
  });

  final PrayerRepository _repository;
  final SettingsRepository? _settingsRepository;
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
  String get id => 'prayer';

  @override
  ModuleMetadata get metadata => ModuleMetadata(
    displayName: 'Prayer',
    icon: Icons.mosque,
    accentColor: ModuleThemeAccents.defaults.prayer,
  );

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/prayer',
      builder: (context, state) => const PrayerHomeScreen(),
      routes: [
        GoRoute(
          path: 'history',
          builder: (context, state) => const PrayerHistoryScreen(),
        ),
        GoRoute(
          path: 'qadha',
          builder: (context, state) => const PrayerQadhaScreen(),
        ),
        GoRoute(
          path: 'stats',
          builder: (context, state) => const PrayerStatsScreen(),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const PrayerSettingsScreen(),
        ),
        GoRoute(
          path: 'record/:id',
          builder: (context, state) => PrayerHomeScreen(
            highlightRecordId: state.pathParameters['id'],
          ),
        ),
      ],
    ),
  ];

  @override
  Widget dashboardSummary(WidgetRef ref) {
    final views = ref.watch(todaysPrayerViewsProvider);
    if (views == null || views.isEmpty) return const SizedBox.shrink();
    final next = views.firstWhere(
      (v) =>
          v.effectiveStatus == PrayerStatus.upcoming ||
          v.effectiveStatus == PrayerStatus.due,
      orElse: () => views.last,
    );
    final allPrayed = views.every(
      (v) => v.effectiveStatus == PrayerStatus.prayed,
    );
    return Builder(
      builder: (context) => Card(
        child: ListTile(
          leading: Icon(
            Icons.mosque,
            color: ModuleThemeAccents.defaults.prayer,
          ),
          title: Text(metadata.displayName),
          subtitle: Text(
            allPrayed
                ? 'All prayers done for today'
                : '${next.record.prayerName.name} next',
          ),
          onTap: () => context.go('/prayer'),
        ),
      ),
    );
  }

  @override
  Widget? settingsEntry(WidgetRef ref) {
    return Builder(
      builder: (context) => ListTile(
        leading: Icon(Icons.mosque, color: ModuleThemeAccents.defaults.prayer),
        title: Text(metadata.displayName),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/prayer/settings'),
      ),
    );
  }

  static const _lookaheadDays = 3;

  @override
  Future<List<PendingNotification>> pendingNotifications() async {
    final now = clock.now();
    final settings = await _repository
        .watchSettings(
          profileId: _fixedProfileId,
        )
        .first;
    final locationResult = await resolveLocation(settings);
    if (locationResult case Failure()) {
      return const [];
    }
    final location = (locationResult as Success<ResolvedLocation>).value;

    await _repository.sweepMissedPrayers(
      now,
      location,
      profileId: _fixedProfileId,
    );
    await _repository.materializeRecords(
      now,
      location,
      profileId: _fixedProfileId,
    );

    if (!settings.notificationsEnabled) return const [];

    final windowEnd = localDayKey(now).addDays(_lookaheadDays);
    final records = await _repository.recordsInRange(
      localDayKey(now),
      windowEnd,
      profileId: _fixedProfileId,
    );
    final appSettings = _settingsRepository == null
        ? null
        : await _settingsRepository.watchSettings().first;
    final notifications = <PendingNotification>[];
    for (final record in records) {
      if (record.storedStatus != PrayerStatus.upcoming) continue;
      if (!record.scheduledFor.isAfter(now)) continue;
      final isJumuah = isJumuahDisplay(
        prayerName: record.prayerName,
        date: record.prayerDate,
        observesJumuah: settings.observesJumuah,
      );
      final ramadanActive =
          !isJumuah &&
          appSettings != null &&
          resolveRamadanModeActive(
            manualOverride: appSettings.ramadanModeManualOverride,
            autoDetectEnabled: appSettings.ramadanAutoDetectEnabled,
            today: record.prayerDate,
          );
      final framing = ramadanActive
          ? ramadanFramingFor(record.prayerName)
          : null;
      final label = isJumuah
          ? "Jumu'ah"
          : switch (framing) {
              RamadanPrayerFraming.sehri => 'Sehri ends',
              RamadanPrayerFraming.iftar => 'Iftar',
              null => _titleCase(record.prayerName.name),
            };
      final body = switch (framing) {
        RamadanPrayerFraming.sehri =>
          'Sehri ends now — finish eating and drinking',
        RamadanPrayerFraming.iftar => 'Time to break your fast',
        null => "It's time for $label prayer",
      };
      notifications.add(
        PendingNotification(
          id: record.id,
          scheduledAt: record.scheduledFor,
          title: label,
          body: body,
          sourceType: 'prayer_record',
          deepLinkRoute: '/prayer/record/${record.id}',
          quietHoursSuppressible: false,
        ),
      );
      if (settings.preReminderEnabled) {
        final reminderAt = record.scheduledFor.subtract(
          Duration(minutes: settings.preReminderOffsetMinutes),
        );
        if (reminderAt.isAfter(now)) {
          notifications.add(
            PendingNotification(
              id: 'prayer_prereminder_${record.id}',
              scheduledAt: reminderAt,
              title: label,
              body: '$label prayer is coming up soon',
              sourceType: 'prayer_record',
              deepLinkRoute: '/prayer/record/${record.id}',
              quietHoursSuppressible: false,
            ),
          );
        }
      }
    }
    return notifications;
  }

  String _titleCase(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  @override
  Future<void> onNotificationAction(
    String sourceId,
    NotificationActionType action,
  ) async {
    final recordId = sourceId.startsWith('prayer_prereminder_')
        ? sourceId.substring('prayer_prereminder_'.length)
        : sourceId;
    switch (action) {
      case NotificationActionType.done:
        // The notification fired at the scheduled time, so a Done tap
        // is always on time regardless of how late the user acts on it
        // (08-analytics/10-prayer-on-time-vs-late).
        await _repository.markPrayed(
          recordId,
          forceOnTime: true,
          profileId: _fixedProfileId,
        );
      case NotificationActionType.skip:
        await _repository.markMissedBySkip(
          recordId,
          profileId: _fixedProfileId,
        );
      case NotificationActionType.snooze:
        break;
    }
  }

  @override
  Future<void> onQuickAction() async {
    final settings = await _repository
        .watchSettings(
          profileId: _fixedProfileId,
        )
        .first;
    final locationResult = await resolveLocation(settings);
    if (locationResult case Failure()) return;
    final location = (locationResult as Success<ResolvedLocation>).value;

    final now = clock.now();
    await _repository.sweepMissedPrayers(
      now,
      location,
      profileId: _fixedProfileId,
    );
    await _repository.materializeRecords(
      now,
      location,
      profileId: _fixedProfileId,
    );
    final today = localDayKey(now);
    final records = await _repository.recordsInRange(
      today,
      today,
      profileId: _fixedProfileId,
    );
    records.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    for (final record in records) {
      final cutoff = cutoffForPrayer(
        record: record,
        sameDayRecordsSorted: records,
        ishaDayRolloverTime: settings.ishaDayRolloverTime,
        ianaTimezone: location.ianaTimezone,
      );
      final status = effectivePrayerStatus(
        storedStatus: record.storedStatus,
        scheduledFor: record.scheduledFor,
        cutoff: cutoff,
        now: now,
      );
      if (status == PrayerStatus.due) {
        await _repository.markPrayed(record.id, profileId: _fixedProfileId);
        return;
      }
    }
  }

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async {
    final records = await _repository.recordsInRange(
      range.start,
      range.end,
      profileId: _fixedProfileId,
    );
    final byDay = <LocalDate, List<PrayerRecord>>{};
    for (final record in records) {
      (byDay[record.prayerDate] ??= []).add(record);
    }
    final pauseSvc = _pauseService;
    final pausedDays = pauseSvc != null
        ? await pauseSvc.pausedDaysInRange(
            moduleId: 'prayer',
            range: range,
            profileId: _fixedProfileId,
          )
        : <LocalDate>{};
    final result = <LocalDate, ModuleDayStatus>{};
    var day = range.start;
    while (day.compareTo(range.end) <= 0) {
      if (pausedDays.contains(day)) {
        result[day] = const ModuleDayStatus(
          kind: ModuleDayStatusKind.paused,
          value: 0,
        );
        day = day.addDays(1);
        continue;
      }
      final dayRecords = byDay[day] ?? const [];
      if (dayRecords.length < 5 ||
          dayRecords.any((r) => r.storedStatus == PrayerStatus.upcoming)) {
        result[day] = const ModuleDayStatus(
          kind: ModuleDayStatusKind.none,
          value: 0,
        );
        day = day.addDays(1);
        continue;
      }
      final prayedCount = dayRecords
          .where((r) => r.storedStatus == PrayerStatus.prayed)
          .length;
      final kind = prayedCount == dayRecords.length
          ? ModuleDayStatusKind.complete
          : prayedCount == 0
          ? ModuleDayStatusKind.missed
          : ModuleDayStatusKind.partial;
      result[day] = ModuleDayStatus(kind: kind, value: prayedCount);
      day = day.addDays(1);
    }
    return result;
  }

  @override
  Widget? nextUpcoming(WidgetRef ref) {
    final views = ref.watch(todaysPrayerViewsProvider);
    if (views == null) return null;
    PrayerRecordView? next;
    for (final view in views) {
      if (view.effectiveStatus == PrayerStatus.due ||
          view.effectiveStatus == PrayerStatus.upcoming) {
        next = view;
        break;
      }
    }
    if (next == null) return null;
    final appSettings = ref.watch(appSettingsProvider).value;
    final ramadanActive =
        !next.showAsJumuah &&
        appSettings != null &&
        resolveRamadanModeActive(
          manualOverride: appSettings.ramadanModeManualOverride,
          autoDetectEnabled: appSettings.ramadanAutoDetectEnabled,
          today: next.record.prayerDate,
        );
    final framing = ramadanActive
        ? ramadanFramingFor(next.record.prayerName)
        : null;
    final remaining = next.record.scheduledFor.difference(clock.now());
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final label = switch (framing) {
          null =>
            next!.showAsJumuah
                ? "Jumu'ah"
                : _titleCase(next.record.prayerName.name),
          RamadanPrayerFraming.sehri =>
            remaining.isNegative
                ? l10n.sehriEndsLabel
                : l10n.sehriEndsCountdown(formatCountdown(remaining)),
          RamadanPrayerFraming.iftar =>
            remaining.isNegative
                ? l10n.iftarLabel
                : l10n.iftarCountdown(formatCountdown(remaining)),
        };
        return Chip(
          avatar: const Icon(Icons.mosque, size: 16),
          label: Text(label),
        );
      },
    );
  }

  @override
  List<Widget> quickActions(WidgetRef ref) {
    final views = ref.watch(todaysPrayerViewsProvider);
    if (views == null) return const [];
    final due = views.where((v) => v.effectiveStatus == PrayerStatus.due);
    if (due.isEmpty) return const [];
    final recordId = due.first.record.id;
    return [
      Consumer(
        builder: (context, innerRef, _) => ActionChip(
          avatar: const Icon(Icons.check, size: 16),
          label: Text(AppLocalizations.of(context)!.prayerMarkPrayedAction),
          onPressed: () => innerRef
              .read(prayerControllerProvider.notifier)
              .togglePrayed(recordId, currentlyPrayed: false),
        ),
      ),
    ];
  }

  @override
  Future<List<SearchResult>> search(String query) async => const [];

  @override
  List<AchievementDefinition> get achievementDefinitions => [
    AchievementDefinition(
      key: 'prayer_first_log',
      moduleId: id,
      titleKey: 'achievementPrayerFirstLogTitle',
      descriptionKey: 'achievementPrayerFirstLogDescription',
      target: 1,
      currentProgress: () async {
        final today = localDayKey(clock.now());
        final records = await _repository.recordsInRange(
          const LocalDate(2000, 1, 1),
          today,
          profileId: _fixedProfileId,
        );
        return records.any((r) => r.storedStatus == PrayerStatus.prayed)
            ? 1
            : 0;
      },
    ),
    AchievementDefinition(
      key: 'prayer_streak_7',
      moduleId: id,
      titleKey: 'achievementPrayerStreak7Title',
      descriptionKey: 'achievementPrayerStreak7Description',
      target: 7,
      currentProgress: _currentPrayerStreak,
    ),
    AchievementDefinition(
      key: 'prayer_streak_30',
      moduleId: id,
      titleKey: 'achievementPrayerStreak30Title',
      descriptionKey: 'achievementPrayerStreak30Description',
      target: 30,
      currentProgress: _currentPrayerStreak,
      rarity: BadgeRarity.rare,
    ),
    AchievementDefinition(
      key: 'prayer_streak_100',
      moduleId: id,
      titleKey: 'achievementPrayerStreak100Title',
      descriptionKey: 'achievementPrayerStreak100Description',
      target: 100,
      currentProgress: _currentPrayerStreak,
      rarity: BadgeRarity.legendary,
    ),
    AchievementDefinition(
      key: 'prayer_perfect_week',
      moduleId: id,
      titleKey: 'achievementPrayerPerfectWeekTitle',
      descriptionKey: 'achievementPrayerPerfectWeekDescription',
      target: 1,
      currentProgress: _perfectPrayerWeek,
      rarity: BadgeRarity.rare,
    ),
  ];

  Future<int> _currentPrayerStreak() async {
    final today = localDayKey(clock.now());
    final records = await _repository.recordsInRange(
      today.addDays(-100),
      today,
      profileId: _fixedProfileId,
    );
    final byDay = <LocalDate, List<PrayerRecord>>{};
    for (final record in records) {
      (byDay[record.prayerDate] ??= []).add(record);
    }
    final result = const CalculatePrayerStreakUseCase().execute(
      recordsByDay: byDay,
      earliestDay: today.addDays(-100),
      today: today,
    );
    return result.current;
  }

  Future<int> _perfectPrayerWeek() async {
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
    final settings = await _repository
        .watchSettings(
          profileId: _fixedProfileId,
        )
        .first;
    final records = await _repository.allRecords(profileId: _fixedProfileId);
    final qadhaCounters = await _repository.allQadhaCounters(
      profileId: _fixedProfileId,
    );
    return ModuleExport({
      'settings': _settingsToJson(settings),
      'records': records.map(_recordToJson).toList(),
      'qadhaCounters': qadhaCounters.map(_qadhaToJson).toList(),
    });
  }

  @override
  Future<void> importData(ModuleExport data) async {
    final settingsJson = data.payload['settings'] as Map<String, dynamic>?;
    if (settingsJson != null) {
      await _repository.updateSettings(
        profileId: _fixedProfileId,
        calculationMethod: CalculationMethodDb.fromDb(
          settingsJson['calculationMethod'] as String,
        ),
        asrMethod: AsrMethodDb.fromDb(
          settingsJson['asrMethod'] as String,
        ),
        observesJumuah: settingsJson['observesJumuah'] as bool,
        locationMode: LocationModeDb.fromDb(
          settingsJson['locationMode'] as String,
        ),
        manualLatitude: (settingsJson['manualLatitude'] as num?)?.toDouble(),
        manualLongitude: (settingsJson['manualLongitude'] as num?)?.toDouble(),
        manualTimezone: settingsJson['manualTimezone'] as String?,
      );
    }

    final records = (data.payload['records'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (final json in records) {
      await _repository.restoreRecord(
        PrayerRecord(
          id: '',
          prayerDate: LocalDate.parse(json['prayerDate'] as String),
          prayerName: PrayerNameDb.fromDb(json['prayerName'] as String),
          scheduledFor: DateTime.parse(json['scheduledFor'] as String),
          storedStatus: PrayerStatusDb.fromDb(json['status'] as String),
          statusChangedAt: json['statusChangedAt'] == null
              ? null
              : DateTime.parse(json['statusChangedAt'] as String),
          notes: json['notes'] as String?,
        ),
        profileId: _fixedProfileId,
      );
    }

    final qadhaCounters =
        (data.payload['qadhaCounters'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    for (final json in qadhaCounters) {
      await _repository.setQadhaBalance(
        PrayerNameDb.fromDb(json['prayerName'] as String),
        json['count'] as int,
        profileId: _fixedProfileId,
      );
    }
  }

  @override
  Future<void> wipeData() => _repository.wipeAll(profileId: _fixedProfileId);

  @override
  Future<WidgetSummaryData?> widgetSummary() async {
    final settings = await _repository
        .watchSettings(
          profileId: _fixedProfileId,
        )
        .first;
    final locationResult = await resolveLocation(settings);
    if (locationResult case Failure()) return null;
    final location = (locationResult as Success<ResolvedLocation>).value;
    final now = clock.now();
    await _repository.sweepMissedPrayers(
      now,
      location,
      profileId: _fixedProfileId,
    );
    await _repository.materializeRecords(
      now,
      location,
      profileId: _fixedProfileId,
    );
    final today = localDayKey(now);
    // First try today's records only.
    var records = await _repository.recordsInRange(
      today,
      today,
      profileId: _fixedProfileId,
    );
    records.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    var pendingCount = 0;
    PrayerRecord? firstPending;
    for (final record in records) {
      final cutoff = cutoffForPrayer(
        record: record,
        sameDayRecordsSorted: records,
        ishaDayRolloverTime: settings.ishaDayRolloverTime,
        ianaTimezone: location.ianaTimezone,
      );
      final status = effectivePrayerStatus(
        storedStatus: record.storedStatus,
        scheduledFor: record.scheduledFor,
        cutoff: cutoff,
        now: now,
      );
      if (status == PrayerStatus.due || status == PrayerStatus.upcoming) {
        pendingCount++;
        firstPending ??= record;
      }
    }
    // Midnight rollover: if no pending today, widen to tomorrow.
    if (firstPending == null) {
      final tomorrow = today.addDays(1);
      records =
          await _repository.recordsInRange(
              today,
              tomorrow,
              profileId: _fixedProfileId,
            )
            ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
      for (final record in records) {
        final cutoff = cutoffForPrayer(
          record: record,
          sameDayRecordsSorted: records,
          ishaDayRolloverTime: settings.ishaDayRolloverTime,
          ianaTimezone: location.ianaTimezone,
        );
        final status = effectivePrayerStatus(
          storedStatus: record.storedStatus,
          scheduledFor: record.scheduledFor,
          cutoff: cutoff,
          now: now,
        );
        if (status == PrayerStatus.due || status == PrayerStatus.upcoming) {
          pendingCount++;
          firstPending ??= record;
        }
      }
    }
    if (firstPending == null) return null;
    final label = _titleCase(firstPending.prayerName.name);
    final timeStr =
        '${firstPending.scheduledFor.hour.toString().padLeft(2, '0')}:'
        '${firstPending.scheduledFor.minute.toString().padLeft(2, '0')}';
    return WidgetSummaryData(
      moduleId: id,
      headline: '$label · $timeStr',
      deepLinkRoute: '/prayer',
      pendingCount: pendingCount,
      countdownTargetAt: firstPending.scheduledFor,
    );
  }

  Map<String, Object?> _settingsToJson(PrayerSettings settings) => {
    'calculationMethod': settings.calculationMethod.toDb(),
    'asrMethod': settings.asrMethod.toDb(),
    'observesJumuah': settings.observesJumuah,
    'locationMode': settings.locationMode.toDb(),
    'manualLatitude': settings.manualLatitude,
    'manualLongitude': settings.manualLongitude,
    'manualTimezone': settings.manualTimezone,
  };

  Map<String, Object?> _recordToJson(PrayerRecord record) => {
    'prayerDate': record.prayerDate.toIso(),
    'prayerName': record.prayerName.toDb(),
    'scheduledFor': record.scheduledFor.toIso8601String(),
    'status': record.storedStatus.toDb(),
    'statusChangedAt': record.statusChangedAt?.toIso8601String(),
    'notes': record.notes,
  };

  Map<String, Object?> _qadhaToJson(PrayerQadhaCounter counter) => {
    'prayerName': counter.prayerName.toDb(),
    'count': counter.count,
  };

  @override
  Future<ModuleYearStats?> yearAggregation(DateRange yearRange) async {
    final records = await _repository.recordsInRange(
      yearRange.start,
      yearRange.end,
      profileId: _fixedProfileId,
    );
    if (records.isEmpty) return null;

    var totalPrayers = 0;
    var prayersCompleted = 0;
    var onTimeCount = 0;
    final monthsActive = <int>{};
    final recordsByDay = <LocalDate, List<PrayerRecord>>{};

    for (final record in records) {
      final day = record.prayerDate;
      recordsByDay.putIfAbsent(day, () => []).add(record);
      monthsActive.add(day.month);

      if (record.storedStatus == PrayerStatus.upcoming) continue;
      totalPrayers++;
      if (record.storedStatus == PrayerStatus.prayed) {
        prayersCompleted++;
        final changedAt = record.statusChangedAt;
        if (changedAt != null && !changedAt.isAfter(record.scheduledFor)) {
          onTimeCount++;
        }
      }
    }

    final onTimePercent = prayersCompleted > 0
        ? onTimeCount / prayersCompleted * 100
        : 0.0;

    // Use the streak calculator for longest streak.
    final streakResult = const CalculatePrayerStreakUseCase().execute(
      recordsByDay: recordsByDay,
      earliestDay: yearRange.start,
      today: yearRange.end,
    );

    return moduleYearStatsFromColor(
      moduleId: id,
      displayName: metadata.displayName,
      accentColor: metadata.accentColor,
      totalPrayers: totalPrayers,
      prayersCompleted: prayersCompleted,
      onTimePercent: onTimePercent,
      longestStreak: streakResult.longest,
      longestStreakAll: streakResult.longest,
      bestDayValue: prayersCompleted,
      monthsActive: monthsActive.length,
      monthsTotal: 12,
    );
  }
}
