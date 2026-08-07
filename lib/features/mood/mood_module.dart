import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/recaps/year_summary.dart';
import 'package:habit_tracker/core/reports/logged_day_status.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/widget_summary_data.dart';
import 'package:habit_tracker/features/mood/domain/entities/mood_log.dart';
import 'package:habit_tracker/features/mood/domain/repositories/mood_repository.dart';
import 'package:habit_tracker/features/mood/domain/usecases/log_mood_use_case.dart';
import 'package:habit_tracker/features/mood/presentation/mood_value_display.dart';
import 'package:habit_tracker/features/mood/presentation/providers/mood_providers.dart';

/// The Mood module's [HabitModule] registration
/// (`docs/superpowers/specs/04-premium/04-additional-habit-modules-pack
/// -design.md`) — premium-gated, no permanent bottom-nav tab, same
/// shape as `SleepModule`/`BloodPressureModule`. Uses the shared
/// `core/reports/logged_day_status.dart` generic helpers directly
/// (Mood was the module that triggered extracting them, since Sleep and
/// Blood Pressure each hand-rolled the same "no goal, day counts if a
/// log exists" pattern before this existed).
class MoodModule implements HabitModule {
  /// Creates the module backed by [_repository].
  const MoodModule(this._repository);

  final MoodRepository _repository;

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
  String get id => 'mood';

  @override
  ModuleMetadata get metadata => const ModuleMetadata(
    displayName: 'Mood',
    icon: Icons.sentiment_satisfied_outlined,
    accentColor: Color(0xFF8E24AA),
  );

  // ponytail: no permanent bottom-nav branch — same reasoning as Sleep/BP.
  @override
  List<RouteBase> get routes => const [];

  @override
  Widget dashboardSummary(WidgetRef ref) {
    final lastLog = ref.watch(lastMoodLogProvider).value;
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Card(
          child: ListTile(
            leading: Icon(
              lastLog == null
                  ? metadata.icon
                  : moodValueIcons[lastLog.moodValue],
              color: metadata.accentColor,
            ),
            title: Text(metadata.displayName),
            subtitle: Text(
              lastLog == null
                  ? l10n.moodHomeEmpty
                  : moodValueLabel(l10n, lastLog.moodValue),
            ),
            onTap: () => context.push('/settings/mood'),
          ),
        );
      },
    );
  }

  @override
  Widget? settingsEntry(WidgetRef ref) => null;

  // ponytail: no reminder notifications — same scope drop as Sleep/BP.
  @override
  Future<List<PendingNotification>> pendingNotifications() async => [];

  @override
  Future<void> onNotificationAction(
    String sourceId,
    NotificationActionType action,
  ) async {}

  // No single "quick" default: mood is inherently a 1-5 choice, so
  // there's no unambiguous value to log without the user picking one on
  // Mood's own home screen (its quick-log buttons, not a cross-module
  // dashboard chip).
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
    return calculateLoggedDayStatus(
      logs: logs,
      range: range,
      dateOf: (log) => log.loggedAt,
    );
  }

  @override
  Widget? nextUpcoming(WidgetRef ref) => null;

  @override
  List<Widget> quickActions(WidgetRef ref) => const [];

  @override
  Future<List<SearchResult>> search(String query) async => const [];

  @override
  List<AchievementDefinition> get achievementDefinitions {
    // Computed once per access and shared by all 3 streak definitions —
    // see SleepModule's/BloodPressureModule's identical fix.
    final streak = _currentMoodStreak();
    return [
      AchievementDefinition(
        key: 'mood_first_log',
        moduleId: id,
        titleKey: 'achievementMoodFirstLogTitle',
        descriptionKey: 'achievementMoodFirstLogDescription',
        target: 1,
        currentProgress: () async {
          final logs = await _repository.allLogs(profileId: _fixedProfileId);
          return logs.isEmpty ? 0 : 1;
        },
      ),
      AchievementDefinition(
        key: 'mood_streak_7',
        moduleId: id,
        titleKey: 'achievementMoodStreak7Title',
        descriptionKey: 'achievementMoodStreak7Description',
        target: 7,
        currentProgress: () => streak,
      ),
      AchievementDefinition(
        key: 'mood_streak_30',
        moduleId: id,
        titleKey: 'achievementMoodStreak30Title',
        descriptionKey: 'achievementMoodStreak30Description',
        target: 30,
        currentProgress: () => streak,
        rarity: BadgeRarity.rare,
      ),
      AchievementDefinition(
        key: 'mood_streak_100',
        moduleId: id,
        titleKey: 'achievementMoodStreak100Title',
        descriptionKey: 'achievementMoodStreak100Description',
        target: 100,
        currentProgress: () => streak,
        rarity: BadgeRarity.legendary,
      ),
    ];
  }

  Future<int> _currentMoodStreak() {
    return currentLoggedStreak<MoodLog>(
      allLogs: () => _repository.allLogs(profileId: _fixedProfileId),
      dateOf: (log) => log.loggedAt,
      today: localDayKey(clock.now()),
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
    final logMood = LogMoodUseCase(_repository);
    for (final json in logs) {
      await logMood.execute(
        moodValue: json['moodValue'] as int,
        loggedAt: DateTime.parse(json['loggedAt'] as String),
        profileId: _fixedProfileId,
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
    final last = logs.last;
    return WidgetSummaryData(
      moduleId: id,
      headline: '${last.moodValue}/5',
      deepLinkRoute: '/settings/mood',
    );
  }

  // ponytail: no year-over-year stats — same reasoning as Sleep/BP.
  @override
  Future<ModuleYearStats?> yearAggregation(DateRange yearRange) async => null;

  Map<String, Object?> _logToJson(MoodLog log) => {
    'id': log.id,
    'moodValue': log.moodValue,
    'loggedAt': log.loggedAt.toIso8601String(),
    'notes': log.notes,
  };
}
