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
import 'package:habit_tracker/features/water/domain/repositories/water_repository.dart';
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
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async {
    final result = <LocalDate, ModuleDayStatus>{};
    var day = range.start;
    while (day.compareTo(range.end) <= 0) {
      result[day] = const ModuleDayStatus(kind: ModuleDayStatusKind.none, value: 0);
      day = day.addDays(1);
    }
    return result;
  }

  @override
  Widget? nextUpcoming(WidgetRef ref) => null;

  @override
  List<Widget> quickActions(WidgetRef ref) => const [];

  @override
  Future<List<SearchResult>> search(String query) async => const [];

  @override
  List<AchievementDefinition> get achievementDefinitions => const [];

  @override
  Future<ModuleExport> exportData() async {
    final goals = await _repository.allGoals();
    final entries = await _repository.allEntries();
    return ModuleExport({
      'goals': goals.map(_goalToJson).toList(),
      'logs': entries.map(_entryToJson).toList(),
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
      );
    }
  }

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
  };
}
