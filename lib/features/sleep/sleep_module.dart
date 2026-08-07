import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/recaps/year_summary.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/widget_summary_data.dart';
import 'package:habit_tracker/features/sleep/domain/entities/sleep_log.dart';
import 'package:habit_tracker/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:habit_tracker/features/sleep/domain/usecases/log_sleep_use_case.dart';
import 'package:habit_tracker/features/sleep/domain/usecases/sleep_day_status.dart';
import 'package:habit_tracker/features/sleep/presentation/providers/sleep_providers.dart';

/// The Sleep module's [HabitModule] registration
/// (`docs/superpowers/specs/04-premium/04-additional-habit-modules-pack
/// -design.md`) — premium-gated, no permanent bottom-nav tab (see
/// `lib/core/router/app_router.dart`'s settings-branch wiring).
///
/// Unlike Water, there's no goal concept: a night "counts" simply by
/// having a logged entry, so `dayStatus` only ever produces `complete`
/// or `none` (never `partial`) and streaks reuse the shared
/// `core/reports/day_status_streaks.dart` helpers directly instead of a
/// bespoke calculator.
class SleepModule implements HabitModule {
  /// Creates the module backed by [_repository].
  const SleepModule(this._repository);

  final SleepRepository _repository;

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
  String get id => 'sleep';

  @override
  ModuleMetadata get metadata => const ModuleMetadata(
    displayName: 'Sleep',
    icon: Icons.bedtime,
    accentColor: Color(0xFF5C6BC0),
  );

  // ponytail: no permanent bottom-nav branch for a premium-only module —
  // its screens are hand-wired as nested routes under the Settings
  // branch in app_router.dart instead (same shape as Avatar/Priority
  // Support). This getter stays empty so HabitModule's contract is still
  // satisfied without inventing a second route-registration mechanism.
  @override
  List<RouteBase> get routes => const [];

  @override
  Widget dashboardSummary(WidgetRef ref) {
    final lastNight = ref.watch(lastNightSleepLogProvider).value;
    return Builder(
      builder: (context) => Card(
        child: ListTile(
          leading: Icon(metadata.icon, color: metadata.accentColor),
          title: Text(metadata.displayName),
          subtitle: Text(
            lastNight == null
                ? AppLocalizations.of(context)!.sleepHomeEmpty
                : _formatDuration(lastNight.durationMinutes),
          ),
          onTap: () => context.push('/settings/sleep'),
        ),
      ),
    );
  }

  @override
  Widget? settingsEntry(WidgetRef ref) => null;

  // ponytail: no reminder notifications in this pass — a bedtime
  // reminder needs the background/isolate notification paths to be
  // premium-aware too (they build modules via buildHabitModules(db)
  // directly, bypassing the Riverpod entitlement check), which is a
  // separate, cross-cutting piece of work. Add when that's in place.
  @override
  Future<List<PendingNotification>> pendingNotifications() async => [];

  @override
  Future<void> onNotificationAction(
    String sourceId,
    NotificationActionType action,
  ) async {}

  @override
  Future<void> onQuickAction() async {}

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(
    DateRange range, {
    String? profileId,
  }) async {
    final logs = await _repository
        .watchLogsInRange(
          range.start,
          range.end,
          profileId: profileId ?? _fixedProfileId,
        )
        .first;
    return calculateSleepDayStatus(logs: logs, range: range);
  }

  @override
  Widget? nextUpcoming(WidgetRef ref) => null;

  @override
  List<Widget> quickActions(WidgetRef ref) => const [];

  @override
  Future<List<SearchResult>> search(String query) async => const [];

  @override
  List<AchievementDefinition> get achievementDefinitions {
    // Computed once per access (AchievementEngine.evaluate() reads this
    // getter exactly once per evaluation) and shared by all 3 streak
    // definitions below, instead of each independently re-running the
    // same unbounded allLogs() scan.
    final streak = _currentSleepStreak();
    return [
      AchievementDefinition(
        key: 'sleep_first_log',
        moduleId: id,
        titleKey: 'achievementSleepFirstLogTitle',
        descriptionKey: 'achievementSleepFirstLogDescription',
        target: 1,
        currentProgress: () async {
          final logs = await _repository.allLogs(profileId: _fixedProfileId);
          return logs.isEmpty ? 0 : 1;
        },
      ),
      AchievementDefinition(
        key: 'sleep_streak_7',
        moduleId: id,
        titleKey: 'achievementSleepStreak7Title',
        descriptionKey: 'achievementSleepStreak7Description',
        target: 7,
        currentProgress: () => streak,
      ),
      AchievementDefinition(
        key: 'sleep_streak_30',
        moduleId: id,
        titleKey: 'achievementSleepStreak30Title',
        descriptionKey: 'achievementSleepStreak30Description',
        target: 30,
        currentProgress: () => streak,
        rarity: BadgeRarity.rare,
      ),
      AchievementDefinition(
        key: 'sleep_streak_100',
        moduleId: id,
        titleKey: 'achievementSleepStreak100Title',
        descriptionKey: 'achievementSleepStreak100Description',
        target: 100,
        currentProgress: () => streak,
        rarity: BadgeRarity.legendary,
      ),
    ];
  }

  Future<int> _currentSleepStreak() {
    return currentSleepStreak(
      _repository,
      localDayKey(clock.now()),
      profileId: _fixedProfileId,
    );
  }

  @override
  Future<ModuleExport> exportData() async {
    final logs = await _repository.allLogs(profileId: _fixedProfileId);
    return ModuleExport({'logs': logs.map(_logToJson).toList()});
  }

  @override
  Future<void> importData(ModuleExport data) async {
    final logs = (data.payload['logs'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final logSleep = LogSleepUseCase(_repository);
    for (final json in logs) {
      await logSleep.execute(
        bedTime: DateTime.parse(json['bedTime'] as String),
        wakeTime: DateTime.parse(json['wakeTime'] as String),
        profileId: _fixedProfileId,
        quality: json['quality'] as int?,
        notes: json['notes'] as String?,
      );
    }
  }

  @override
  Future<void> wipeData() => _repository.wipeAll(profileId: _fixedProfileId);

  @override
  Future<WidgetSummaryData?> widgetSummary() async {
    final logs = await _repository.allLogs(profileId: _fixedProfileId);
    if (logs.isEmpty) return null;
    final lastNight = logs.last;
    return WidgetSummaryData(
      moduleId: id,
      headline: _formatDuration(lastNight.durationMinutes),
      deepLinkRoute: '/settings/sleep',
    );
  }

  // ponytail: no year-over-year stats yet — ModuleYearStats' field set
  // (totalMl/totalDoses/totalPrayers etc.) is Water/Medicine/Prayer-
  // specific with no generic "duration" slot; adding one means touching
  // the shared freezed union (core/recaps/year_summary.dart) and its
  // renderer for every existing module. Returning null here is the same
  // "nothing to show" branch Water itself uses for an empty range.
  @override
  Future<ModuleYearStats?> yearAggregation(DateRange yearRange) async => null;

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  Map<String, Object?> _logToJson(SleepLog log) => {
    'id': log.id,
    'bedTime': log.bedTime.toIso8601String(),
    'wakeTime': log.wakeTime.toIso8601String(),
    'quality': log.quality,
    'notes': log.notes,
  };
}
