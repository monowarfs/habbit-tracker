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
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_log.dart';
import 'package:habit_tracker/features/blood_pressure/domain/repositories/bp_repository.dart';
import 'package:habit_tracker/features/blood_pressure/domain/usecases/bp_day_status.dart';
import 'package:habit_tracker/features/blood_pressure/domain/usecases/log_bp_use_case.dart';
import 'package:habit_tracker/features/blood_pressure/presentation/providers/bp_providers.dart';

/// The Blood Pressure module's [HabitModule] registration
/// (`docs/superpowers/specs/04-premium/04-additional-habit-modules-pack
/// -design.md`) — premium-gated, no permanent bottom-nav tab, same shape
/// as `SleepModule` (see that file's doc comment for the reasoning this
/// mirrors: no goal concept, so streaks reuse the shared
/// `core/reports/day_status_streaks.dart` helpers via `bp_day_status.dart`
/// instead of a bespoke calculator).
class BloodPressureModule implements HabitModule {
  /// Creates the module backed by [_repository].
  const BloodPressureModule(this._repository);

  final BpRepository _repository;

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
  String get id => 'blood_pressure';

  @override
  ModuleMetadata get metadata => const ModuleMetadata(
    displayName: 'Blood Pressure',
    icon: Icons.monitor_heart_outlined,
    accentColor: Color(0xFFE53935),
  );

  // ponytail: no permanent bottom-nav branch — same reasoning as Sleep's
  // routes getter. Screens are hand-wired as nested routes under the
  // Settings branch in app_router.dart instead.
  @override
  List<RouteBase> get routes => const [];

  @override
  Widget dashboardSummary(WidgetRef ref) {
    final lastLog = ref.watch(lastBpLogProvider).value;
    return Builder(
      builder: (context) => Card(
        child: ListTile(
          leading: Icon(metadata.icon, color: metadata.accentColor),
          title: Text(metadata.displayName),
          subtitle: Text(
            lastLog == null
                ? AppLocalizations.of(context)!.bpHomeEmpty
                : '${lastLog.systolic}/${lastLog.diastolic} mmHg',
          ),
          onTap: () => context.push('/settings/blood-pressure'),
        ),
      ),
    );
  }

  @override
  Widget? settingsEntry(WidgetRef ref) => null;

  // ponytail: no reminder notifications — same scope drop as Sleep (the
  // background/isolate notification paths aren't premium-aware yet).
  @override
  Future<List<PendingNotification>> pendingNotifications() async => [];

  @override
  Future<void> onNotificationAction(
    String sourceId,
    NotificationActionType action,
  ) async {}

  // No "quick" action: a reading needs two numbers, unlike Water's
  // single-tap quick-add.
  @override
  Future<void> onQuickAction() async {}

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async {
    final logs = await _repository
        .watchLogsInRange(
          range.start,
          range.end,
          profileId: _fixedProfileId,
        )
        .first;
    return calculateBpDayStatus(logs: logs, range: range);
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
    // see SleepModule's identical fix for why (avoids 3-4x redundant
    // full-history scans per AchievementEngine.evaluate() call).
    final streak = _currentBpStreak();
    return [
      AchievementDefinition(
        key: 'bp_first_log',
        moduleId: id,
        titleKey: 'achievementBpFirstLogTitle',
        descriptionKey: 'achievementBpFirstLogDescription',
        target: 1,
        currentProgress: () async {
          final logs = await _repository.allLogs(profileId: _fixedProfileId);
          return logs.isEmpty ? 0 : 1;
        },
      ),
      AchievementDefinition(
        key: 'bp_streak_7',
        moduleId: id,
        titleKey: 'achievementBpStreak7Title',
        descriptionKey: 'achievementBpStreak7Description',
        target: 7,
        currentProgress: () => streak,
      ),
      AchievementDefinition(
        key: 'bp_streak_30',
        moduleId: id,
        titleKey: 'achievementBpStreak30Title',
        descriptionKey: 'achievementBpStreak30Description',
        target: 30,
        currentProgress: () => streak,
        rarity: BadgeRarity.rare,
      ),
      AchievementDefinition(
        key: 'bp_streak_100',
        moduleId: id,
        titleKey: 'achievementBpStreak100Title',
        descriptionKey: 'achievementBpStreak100Description',
        target: 100,
        currentProgress: () => streak,
        rarity: BadgeRarity.legendary,
      ),
    ];
  }

  Future<int> _currentBpStreak() {
    return currentBpStreak(
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
    final logReading = LogBpUseCase(_repository);
    for (final json in logs) {
      await logReading.execute(
        systolic: json['systolic'] as int,
        diastolic: json['diastolic'] as int,
        profileId: _fixedProfileId,
        loggedAt: DateTime.parse(json['loggedAt'] as String),
        pulse: json['pulse'] as int?,
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
      headline: '${last.systolic}/${last.diastolic} mmHg',
      deepLinkRoute: '/settings/blood-pressure',
    );
  }

  // ponytail: no year-over-year stats — same reasoning as Sleep
  // (ModuleYearStats' field set is Water/Medicine/Prayer-specific).
  @override
  Future<ModuleYearStats?> yearAggregation(DateRange yearRange) async => null;

  Map<String, Object?> _logToJson(BpLog log) => {
    'id': log.id,
    'systolic': log.systolic,
    'diastolic': log.diastolic,
    'loggedAt': log.loggedAt.toIso8601String(),
    'pulse': log.pulse,
    'notes': log.notes,
  };
}
