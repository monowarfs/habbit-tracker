import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/day_status_streaks.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_stock_event.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/dose_status.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_controller.dart';
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
      // Defensive re-check (FR-M-10): archiving cascade-deletes future
      // upcoming doses at archive time, but this guards the same
      // invariant directly at the notification-emission boundary too.
      if (medicine.archivedAt != null) continue;
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
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async {
    final doses = await _repository.dosesInRange(range.start, range.end);
    final now = clock.now();
    final byDay = <LocalDate, List<MedicineDose>>{};
    for (final dose in doses) {
      final day = localDayKey(dose.scheduledFor);
      (byDay[day] ??= []).add(dose);
    }
    final result = <LocalDate, ModuleDayStatus>{};
    var day = range.start;
    while (day.compareTo(range.end) <= 0) {
      final dayDoses = byDay[day] ?? const [];
      if (dayDoses.isEmpty) {
        result[day] = const ModuleDayStatus(
          kind: ModuleDayStatusKind.none,
          value: 0,
        );
        day = day.addDays(1);
        continue;
      }
      final statuses = dayDoses
          .map(
            (d) => effectiveDoseStatus(
              storedStatus: d.storedStatus,
              scheduledFor: d.scheduledFor,
              now: now,
              graceWindowMinutes: d.graceWindowMinutes,
            ),
          )
          .toList();
      final unresolved = statuses.any(
        (s) => s == MedicineDoseStatus.upcoming || s == MedicineDoseStatus.due,
      );
      final doneCount = statuses
          .where((s) => s == MedicineDoseStatus.done)
          .length;
      final kind = unresolved
          ? ModuleDayStatusKind.none
          : doneCount == statuses.length
          ? ModuleDayStatusKind.complete
          : doneCount == 0
          ? ModuleDayStatusKind.missed
          : ModuleDayStatusKind.partial;
      result[day] = ModuleDayStatus(kind: kind, value: doneCount);
      day = day.addDays(1);
    }
    return result;
  }

  @override
  Widget? nextUpcoming(WidgetRef ref) {
    final views = ref.watch(todaysDoseViewsProvider);
    if (views == null) return null;
    MedicineDoseView? next;
    for (final view in views) {
      if (view.effectiveStatus == MedicineDoseStatus.due ||
          view.effectiveStatus == MedicineDoseStatus.upcoming) {
        next = view;
        break;
      }
    }
    if (next == null) return null;
    return Builder(
      builder: (context) => Chip(
        avatar: const Icon(Icons.medication, size: 16),
        label: Text(next!.medicine.name),
      ),
    );
  }

  @override
  List<Widget> quickActions(WidgetRef ref) {
    final views = ref.watch(todaysDoseViewsProvider);
    if (views == null) return const [];
    final due = views.where((v) => v.effectiveStatus == MedicineDoseStatus.due);
    if (due.isEmpty) return const [];
    final doseId = due.first.dose.id;
    return [
      Consumer(
        builder: (context, innerRef, _) => ActionChip(
          avatar: const Icon(Icons.check, size: 16),
          label: Text(AppLocalizations.of(context)!.medicineMarkDoneAction),
          onPressed: () => innerRef
              .read(medicineControllerProvider.notifier)
              .markDoseDone(doseId),
        ),
      ),
    ];
  }

  @override
  Future<List<SearchResult>> search(String query) async {
    final medicines = await _repository.allMedicines();
    final lowerQuery = query.toLowerCase();
    return [
      for (final medicine in medicines)
        if (medicine.name.toLowerCase().contains(lowerQuery) ||
            (medicine.dosageNote?.toLowerCase().contains(lowerQuery) ?? false))
          SearchResult(
            title: medicine.name,
            subtitle: medicine.dosageNote ?? '',
            deepLinkRoute: '/medicine/${medicine.id}',
          ),
    ];
  }

  @override
  List<AchievementDefinition> get achievementDefinitions => [
    AchievementDefinition(
      key: 'medicine_first_dose',
      moduleId: id,
      titleKey: 'achievementMedicineFirstDoseTitle',
      descriptionKey: 'achievementMedicineFirstDoseDescription',
      target: 1,
      currentProgress: () async {
        final today = localDayKey(clock.now());
        final doses = await _repository.dosesInRange(
          const LocalDate(2000, 1, 1),
          today,
        );
        return doses.any((d) => d.storedStatus == MedicineDoseStatus.done)
            ? 1
            : 0;
      },
    ),
    AchievementDefinition(
      key: 'medicine_adherence_streak_7',
      moduleId: id,
      titleKey: 'achievementMedicineAdherenceStreak7Title',
      descriptionKey: 'achievementMedicineAdherenceStreak7Description',
      target: 7,
      currentProgress: _currentAdherenceStreak,
    ),
    AchievementDefinition(
      key: 'medicine_adherence_streak_30',
      moduleId: id,
      titleKey: 'achievementMedicineAdherenceStreak30Title',
      descriptionKey: 'achievementMedicineAdherenceStreak30Description',
      target: 30,
      currentProgress: _currentAdherenceStreak,
    ),
  ];

  Future<int> _currentAdherenceStreak() async {
    final today = localDayKey(clock.now());
    final status = await dayStatus(
      DateRange(start: today.addDays(-30), end: today),
    );
    return currentStreak(status, today);
  }

  @override
  Future<ModuleExport> exportData() async {
    final medicines = await _repository.allMedicines();
    final schedules = await _repository.allSchedules();
    final doses = await _repository.allDoses();
    final stockEvents = await _repository.allStockEvents();
    return ModuleExport({
      'medicines': medicines.map(_medicineToJson).toList(),
      'schedules': schedules.map(_scheduleToJson).toList(),
      'doses': doses.map(_doseToJson).toList(),
      'stockEvents': stockEvents.map(_stockEventToJson).toList(),
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

    final scheduleIdMap = <String, String>{};
    final schedules = (data.payload['schedules'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (final json in schedules) {
      final newMedicineId = medicineIdMap[json['medicineId'] as String];
      if (newMedicineId == null) continue;
      final result = await _repository.createSchedule(
        medicineId: newMedicineId,
        rule: _ruleFromJson(json),
        startDate: LocalDate.parse(json['startDate'] as String),
        endDate: json['endDate'] == null
            ? null
            : LocalDate.parse(json['endDate'] as String),
        graceWindowMinutes: json['graceWindowMinutes'] as int,
      );
      if (result case Success(:final value)) {
        scheduleIdMap[json['id'] as String] = value.id;
      }
    }

    final doseIdMap = <String, String>{};
    final doses = (data.payload['doses'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (final json in doses) {
      final newMedicineId = medicineIdMap[json['medicineId'] as String];
      final newScheduleId = scheduleIdMap[json['scheduleId'] as String];
      if (newMedicineId == null || newScheduleId == null) continue;
      final newId = await _repository.restoreDose(
        MedicineDose(
          id: '',
          medicineId: newMedicineId,
          scheduleId: newScheduleId,
          scheduledFor: DateTime.parse(json['scheduledFor'] as String),
          storedStatus: MedicineDoseStatus.values.byName(
            json['status'] as String,
          ),
          graceWindowMinutes: json['graceWindowMinutes'] as int,
          statusChangedAt: json['statusChangedAt'] == null
              ? null
              : DateTime.parse(json['statusChangedAt'] as String),
          stockDeltaApplied: json['stockDeltaApplied'] as int,
          notes: json['notes'] as String?,
        ),
      );
      doseIdMap[json['id'] as String] = newId;
    }

    final stockEvents = (data.payload['stockEvents'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (final json in stockEvents) {
      final newMedicineId = medicineIdMap[json['medicineId'] as String];
      if (newMedicineId == null) continue;
      final oldDoseId = json['doseId'] as String?;
      await _repository.restoreStockEvent(
        MedicineStockEvent(
          id: '',
          medicineId: newMedicineId,
          doseId: oldDoseId == null ? null : doseIdMap[oldDoseId],
          delta: json['delta'] as int,
          reason: MedicineStockEventReasonDb.fromDb(json['reason'] as String),
          occurredAt: DateTime.parse(json['occurredAt'] as String),
        ),
      );
    }

    await _repository.materializeDoses(clock.now());
  }

  @override
  Future<void> wipeData() => _repository.wipeAll();

  Map<String, Object?> _medicineToJson(Medicine medicine) => {
    'id': medicine.id,
    'name': medicine.name,
    'dosageNote': medicine.dosageNote,
    'stockEnabled': medicine.stockEnabled,
    'stockCount': medicine.stockCount,
    'stockThreshold': medicine.stockThreshold,
    'stopWhenStockDepleted': medicine.stopWhenStockDepleted,
    'consumptionPerDose': medicine.consumptionPerDose,
    'sortOrder': medicine.sortOrder,
  };

  Map<String, Object?> _scheduleToJson(MedicineSchedule schedule) => {
    'id': schedule.id,
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

  Map<String, Object?> _doseToJson(MedicineDose dose) => {
    'id': dose.id,
    'medicineId': dose.medicineId,
    'scheduleId': dose.scheduleId,
    'scheduledFor': dose.scheduledFor.toIso8601String(),
    'status': dose.storedStatus.name,
    'statusChangedAt': dose.statusChangedAt?.toIso8601String(),
    'stockDeltaApplied': dose.stockDeltaApplied,
    'graceWindowMinutes': dose.graceWindowMinutes,
    'notes': dose.notes,
  };

  Map<String, Object?> _stockEventToJson(MedicineStockEvent event) => {
    'medicineId': event.medicineId,
    'doseId': event.doseId,
    'delta': event.delta,
    'reason': event.reason.toDb(),
    'occurredAt': event.occurredAt.toIso8601String(),
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
