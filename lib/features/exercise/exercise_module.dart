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
import 'package:habit_tracker/features/exercise/domain/entities/exercise_log.dart';
import 'package:habit_tracker/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:habit_tracker/features/exercise/domain/usecases/log_exercise_use_case.dart';
import 'package:habit_tracker/features/exercise/presentation/providers/exercise_providers.dart';

/// The Exercise module's [HabitModule] registration
/// (`docs/superpowers/specs/04-premium/04-additional-habit-modules-pack
/// -design.md`) — premium-gated, no permanent bottom-nav tab, same shape
/// as Sleep/Blood Pressure. Day status/streak use the shared generic
/// `core/reports/logged_day_status.dart` helper (Exercise is its 2nd
/// consumer alongside Mood — "day complete = a workout was logged", no
/// goal concept).
class ExerciseModule implements HabitModule {
  /// Creates the module backed by [_repository].
  const ExerciseModule(this._repository);

  final ExerciseRepository _repository;

  @override
  String get id => 'exercise';

  @override
  ModuleMetadata get metadata => const ModuleMetadata(
    displayName: 'Exercise',
    icon: Icons.fitness_center_outlined,
    accentColor: Color(0xFF43A047),
  );

  // ponytail: no permanent bottom-nav branch — same reasoning as Sleep's
  // routes getter. Screens are hand-wired as nested routes under the
  // Settings branch in app_router.dart instead.
  @override
  List<RouteBase> get routes => const [];

  @override
  Widget dashboardSummary(WidgetRef ref) {
    final lastLog = ref.watch(lastExerciseLogProvider).value;
    return Builder(
      builder: (context) => Card(
        child: ListTile(
          leading: Icon(metadata.icon, color: metadata.accentColor),
          title: Text(metadata.displayName),
          subtitle: Text(
            lastLog == null
                ? AppLocalizations.of(context)!.exerciseHomeEmpty
                : '${lastLog.exerciseType} — ${lastLog.durationMinutes} min',
          ),
          onTap: () => context.push('/settings/exercise'),
        ),
      ),
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

  // No "quick" action: a workout needs a type and duration, unlike
  // Water's single-tap quick-add.
  @override
  Future<void> onQuickAction() async {}

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async {
    final logs = await _repository
        .watchLogsInRange(range.start, range.end)
        .first;
    return calculateLoggedDayStatus<ExerciseLog>(
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
    // same fix as Sleep/BP (avoids 3-4x redundant full-history scans per
    // AchievementEngine.evaluate() call).
    final streak = _currentExerciseStreak();
    return [
      AchievementDefinition(
        key: 'exercise_first_log',
        moduleId: id,
        titleKey: 'achievementExerciseFirstLogTitle',
        descriptionKey: 'achievementExerciseFirstLogDescription',
        target: 1,
        currentProgress: () async {
          final logs = await _repository.allLogs();
          return logs.isEmpty ? 0 : 1;
        },
      ),
      AchievementDefinition(
        key: 'exercise_streak_7',
        moduleId: id,
        titleKey: 'achievementExerciseStreak7Title',
        descriptionKey: 'achievementExerciseStreak7Description',
        target: 7,
        currentProgress: () => streak,
      ),
      AchievementDefinition(
        key: 'exercise_streak_30',
        moduleId: id,
        titleKey: 'achievementExerciseStreak30Title',
        descriptionKey: 'achievementExerciseStreak30Description',
        target: 30,
        currentProgress: () => streak,
        rarity: BadgeRarity.rare,
      ),
      AchievementDefinition(
        key: 'exercise_streak_100',
        moduleId: id,
        titleKey: 'achievementExerciseStreak100Title',
        descriptionKey: 'achievementExerciseStreak100Description',
        target: 100,
        currentProgress: () => streak,
        rarity: BadgeRarity.legendary,
      ),
    ];
  }

  Future<int> _currentExerciseStreak() {
    return currentLoggedStreak<ExerciseLog>(
      allLogs: _repository.allLogs,
      dateOf: (log) => log.loggedAt,
      today: localDayKey(clock.now()),
    );
  }

  @override
  Future<ModuleExport> exportData() async {
    final logs = await _repository.allLogs();
    return ModuleExport({'logs': logs.map(_logToJson).toList()});
  }

  @override
  Future<void> importData(ModuleExport data) async {
    final logs = (data.payload['logs'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final logExercise = LogExerciseUseCase(_repository);
    for (final json in logs) {
      await logExercise.execute(
        exerciseType: json['exerciseType'] as String,
        durationMinutes: json['durationMinutes'] as int,
        loggedAt: DateTime.parse(json['loggedAt'] as String),
        calories: json['calories'] as int?,
        notes: json['notes'] as String?,
      );
    }
  }

  @override
  Future<void> wipeData() => _repository.wipeAll();

  @override
  Future<WidgetSummaryData?> widgetSummary() async {
    final logs = await _repository.allLogs();
    if (logs.isEmpty) return null;
    final last = logs.last;
    return WidgetSummaryData(
      moduleId: id,
      headline: '${last.durationMinutes} min',
      deepLinkRoute: '/settings/exercise',
    );
  }

  // ponytail: no year-over-year stats — same reasoning as Sleep/BP
  // (ModuleYearStats' field set is Water/Medicine/Prayer-specific).
  @override
  Future<ModuleYearStats?> yearAggregation(DateRange yearRange) async => null;

  Map<String, Object?> _logToJson(ExerciseLog log) => {
    'id': log.id,
    'exerciseType': log.exerciseType,
    'durationMinutes': log.durationMinutes,
    'loggedAt': log.loggedAt.toIso8601String(),
    'calories': log.calories,
    'notes': log.notes,
  };
}
