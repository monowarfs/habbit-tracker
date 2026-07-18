import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_detail_screen.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_form_screen.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_home_screen.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_list_screen.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_stats_screen.dart';

/// The Medicine module's [HabitModule] registration
/// (`technical/architecture.md`). Mirrors `WaterModule`'s shape exactly.
class MedicineModule implements HabitModule {
  /// Creates the module backed by [_repository].
  const MedicineModule(this._repository);

  final MedicineRepository _repository;

  @override
  String get id => 'medicine';

  @override
  ModuleMetadata get metadata => const ModuleMetadata(
    displayName: 'Medicine',
    icon: Icons.medication,
    accentColor: ModuleAccents.medicine,
  );

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/medicine',
      builder: (context, state) => const MedicineHomeScreen(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => const MedicineFormScreen(),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) => MedicineDetailScreen(
            medicineId: state.pathParameters['id']!,
          ),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) => MedicineFormScreen(
                editMedicineId: state.pathParameters['id'],
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'dose/:id',
          builder: (context, state) => MedicineHomeScreen(
            highlightDoseId: state.pathParameters['id'],
          ),
        ),
        GoRoute(
          path: 'stats',
          builder: (context, state) => const MedicineStatsScreen(),
        ),
        GoRoute(
          path: 'list',
          builder: (context, state) => const MedicineListScreen(),
        ),
      ],
    ),
  ];

  @override
  Widget dashboardSummary(WidgetRef ref) {
    final views = ref.watch(todaysDoseViewsProvider);
    if (views == null) return const SizedBox.shrink();
    final dueOrUpcoming = views
        .where(
          (v) =>
              v.effectiveStatus == MedicineDoseStatus.due ||
              v.effectiveStatus == MedicineDoseStatus.upcoming,
        )
        .toList();
    return Builder(
      builder: (context) => Card(
        child: ListTile(
          leading: const Icon(Icons.medication, color: ModuleAccents.medicine),
          title: Text(metadata.displayName),
          subtitle: Text(
            dueOrUpcoming.isEmpty
                ? 'All doses done for today'
                : '${dueOrUpcoming.first.medicine.name} next',
          ),
          onTap: () => context.go('/medicine'),
        ),
      ),
    );
  }

  @override
  Widget? settingsEntry(WidgetRef ref) => null; // no medicine_settings table

  /// Matches `core/notifications`' own materialization window
  /// (`strategies/notifications.md`'s "Window 2") — same constant/
  /// reasoning as `WaterModule._lookaheadDays`.
  static const _lookaheadDays = 3;

  /// D-13's "topped up on app foreground and via a daily background
  /// refresh" is exactly what `core/notifications`' existing triggers
  /// (`main.dart` resume, the WorkManager top-up) already do — both call
  /// this method, so materializing here needs no new call site anywhere
  /// else in the app.
  @override
  Future<List<PendingNotification>> pendingNotifications() async {
    final now = clock.now();
    await _repository.materializeDoses(now);

    final windowEnd = localDayKey(now).addDays(_lookaheadDays);
    final doses = await _repository.dosesInRange(
      localDayKey(now),
      windowEnd,
    );
    final notifications = <PendingNotification>[];
    for (final dose in doses) {
      if (dose.storedStatus != MedicineDoseStatus.upcoming) continue;
      if (!dose.scheduledFor.isAfter(now)) continue;
      final medicine = await _repository.medicineById(dose.medicineId);
      if (medicine == null) continue;
      notifications.add(
        PendingNotification(
          // Bare dose id, not module/type-prefixed. `notification_ledger.id`
          // is one shared primary-key namespace across every module's
          // notifications (`core/notifications/notification_planner.dart`'s
          // dedup/cap logic compares `pending.id` with no module scoping),
          // so this relies on dose ids being random UUIDs (de facto globally
          // unique) rather than on any module-scoping guarantee — low-stock
          // ids below keep an explicit `medicine_lowstock_` prefix instead.
          id: dose.id,
          scheduledAt: dose.scheduledFor,
          title: medicine.name,
          body: medicine.dosageNote ?? 'Time for your dose',
          sourceType: 'medicine_dose',
          deepLinkRoute: '/medicine/dose/${dose.id}',
        ),
      );
    }

    final lowStockMedicines = await _repository.medicinesNeedingLowStockAlert();
    for (final medicine in lowStockMedicines) {
      final crossedAt = medicine.lowStockNotifiedAt;
      if (crossedAt == null) continue;
      notifications.add(
        PendingNotification(
          // Stable per-crossing: the timestamp only changes when a
          // refill clears and a later crossing re-sets it, so this
          // naturally dedupes against the ledger across repeated
          // planning passes for the same crossing.
          id:
              'medicine_lowstock_${medicine.id}_'
              '${crossedAt.millisecondsSinceEpoch}',
          scheduledAt: now.add(const Duration(minutes: 1)),
          title: '${medicine.name} is running low',
          body: 'Refill soon to keep your schedule on track.',
          sourceType: 'low_stock',
          deepLinkRoute: '/medicine/${medicine.id}',
        ),
      );
    }
    return notifications;
  }

  @override
  Future<void> onNotificationAction(
    String sourceId,
    NotificationActionType action,
  ) async {
    if (sourceId.startsWith('medicine_lowstock_')) {
      return; // low-stock notifications have no dose to act on
    }
    switch (action) {
      case NotificationActionType.done:
        await _repository.markDoseDone(sourceId, fromOtherSource: false);
      case NotificationActionType.skip:
        await _repository.markDoseSkipped(sourceId);
      case NotificationActionType.snooze:
        break; // streak-neutral, same precedent as Water; snooze-count
      // cap enforced by the existing ledger logic, not duplicated here.
    }
  }

  @override
  Future<ModuleExport> exportData() async {
    final medicines = await _repository.allMedicines();
    final schedules = await _repository.allSchedules();
    return ModuleExport({
      'medicines': medicines.map(_medicineToJson).toList(),
      'schedules': schedules.map(_scheduleToJson).toList(),
    });
  }

  @override
  Future<void> importData(ModuleExport data) async {
    final medicineIdMap = <String, String>{};
    final medicines = (data.payload['medicines'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (final json in medicines) {
      final result = await _repository.createMedicine(
        name: json['name'] as String,
        dosageNote: json['dosageNote'] as String?,
        stockEnabled: json['stockEnabled'] as bool,
        stockCount: json['stockCount'] as int?,
        stockThreshold: json['stockThreshold'] as int?,
        stopWhenStockDepleted: json['stopWhenStockDepleted'] as bool,
        consumptionPerDose: json['consumptionPerDose'] as int,
      );
      if (result case Success(:final value)) {
        medicineIdMap[json['id'] as String] = value.id;
      }
    }
    final schedules = (data.payload['schedules'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (final json in schedules) {
      final newMedicineId = medicineIdMap[json['medicineId'] as String];
      if (newMedicineId == null) continue;
      await _repository.createSchedule(
        medicineId: newMedicineId,
        rule: _ruleFromJson(json),
        startDate: LocalDate.parse(json['startDate'] as String),
        endDate: json['endDate'] == null
            ? null
            : LocalDate.parse(json['endDate'] as String),
        graceWindowMinutes: json['graceWindowMinutes'] as int,
      );
    }
    await _repository.materializeDoses(clock.now());
  }

  Map<String, Object?> _medicineToJson(Medicine medicine) => {
    'id': medicine.id,
    'name': medicine.name,
    'dosageNote': medicine.dosageNote,
    'stockEnabled': medicine.stockEnabled,
    'stockCount': medicine.stockCount,
    'stockThreshold': medicine.stockThreshold,
    'stopWhenStockDepleted': medicine.stopWhenStockDepleted,
    'consumptionPerDose': medicine.consumptionPerDose,
  };

  Map<String, Object?> _scheduleToJson(MedicineSchedule schedule) => {
    'medicineId': schedule.medicineId,
    'frequencyType': schedule.rule.toDbFrequencyType(),
    'intervalDays': schedule.rule.toDbIntervalDays(),
    'weekdaysMask': schedule.rule.toDbWeekdaysMask(),
    'timesOfDay': schedule.rule
        .toDbTimesOfDay()
        .map((t) => t.format())
        .toList(),
    'startDate': schedule.startDate.toIso(),
    'endDate': schedule.endDate?.toIso(),
    'graceWindowMinutes': schedule.graceWindowMinutes,
  };

  RepeatRule _ruleFromJson(Map<String, dynamic> json) {
    final times = (json['timesOfDay'] as List<dynamic>)
        .cast<String>()
        .map(LocalTime.parse)
        .toList();
    return switch (json['frequencyType'] as String) {
      'every_n_days' => RepeatRule.everyNDays(
        intervalDays: json['intervalDays'] as int,
        timesOfDay: times,
      ),
      'weekday_set' => RepeatRule.weekdaySet(
        weekdaysMask: json['weekdaysMask'] as int,
        timesOfDay: times,
      ),
      'prn' => const RepeatRule.prn(),
      _ => RepeatRule.fixedDaily(timesOfDay: times),
    };
  }
}
