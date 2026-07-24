import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_stock_event.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:habit_tracker/features/medicine/medicine_module.dart';
import 'package:mocktail/mocktail.dart';

class _MockMedicineRepository extends Mock implements MedicineRepository {}

void main() {
  late _MockMedicineRepository repo;
  late MedicineModule module;

  setUpAll(() {
    // mocktail requires a fallback instance for any non-primitive type used
    // with `any()` (here, `dosesInRange(LocalDate, LocalDate)`).
    registerFallbackValue(const LocalDate(2026, 1, 1));
    registerFallbackValue(const RepeatRule.prn());
    registerFallbackValue(
      MedicineDose(
        id: 'fallback',
        medicineId: 'fallback',
        scheduleId: 'fallback',
        scheduledFor: DateTime.utc(2026),
        storedStatus: MedicineDoseStatus.upcoming,
        graceWindowMinutes: 30,
      ),
    );
    registerFallbackValue(
      MedicineStockEvent(
        id: 'fallback',
        medicineId: 'fallback',
        delta: 0,
        reason: MedicineStockEventReason.doseTaken,
        occurredAt: DateTime.utc(2026),
      ),
    );
  });

  setUp(() {
    repo = _MockMedicineRepository();
    module = MedicineModule(repo);
  });

  test('pendingNotifications maps due doses within 3 days to '
      'PendingNotification with sourceType medicine_dose', () async {
    final now = DateTime.utc(2026, 6, 1, 7);
    final dose = MedicineDose(
      id: 'd1',
      medicineId: 'm1',
      scheduleId: 's1',
      scheduledFor: DateTime.utc(2026, 6, 1, 8),
      storedStatus: MedicineDoseStatus.upcoming,
      graceWindowMinutes: 30,
    );
    const medicine = Medicine(id: 'm1', name: 'X', stockEnabled: false);

    when(() => repo.materializeDoses(any())).thenAnswer((_) async {});
    when(
      () => repo.dosesInRange(any(), any()),
    ).thenAnswer((_) async => [dose]);
    when(() => repo.medicineById('m1')).thenAnswer((_) async => medicine);
    when(
      () => repo.medicinesNeedingLowStockAlert(),
    ).thenAnswer((_) async => []);

    await withClock(Clock.fixed(now), () async {
      final notifications = await module.pendingNotifications();
      expect(notifications, hasLength(1));
      expect(notifications.single.sourceType, 'medicine_dose');
      expect(notifications.single.deepLinkRoute, '/medicine/dose/d1');
    });
  });

  test('pendingNotifications excludes doses whose medicine is archived '
      '(FR-M-10 defensive re-check)', () async {
    final now = DateTime.utc(2026, 6, 1, 7);
    final dose = MedicineDose(
      id: 'd1',
      medicineId: 'm1',
      scheduleId: 's1',
      scheduledFor: DateTime.utc(2026, 6, 1, 8),
      storedStatus: MedicineDoseStatus.upcoming,
      graceWindowMinutes: 30,
    );
    final archivedMedicine = Medicine(
      id: 'm1',
      name: 'X',
      stockEnabled: false,
      archivedAt: DateTime.utc(2026, 5),
    );

    when(() => repo.materializeDoses(any())).thenAnswer((_) async {});
    when(
      () => repo.dosesInRange(any(), any()),
    ).thenAnswer((_) async => [dose]);
    when(
      () => repo.medicineById('m1'),
    ).thenAnswer((_) async => archivedMedicine);
    when(
      () => repo.medicinesNeedingLowStockAlert(),
    ).thenAnswer((_) async => []);

    await withClock(Clock.fixed(now), () async {
      final notifications = await module.pendingNotifications();
      expect(notifications, isEmpty);
    });
  });

  test('pendingNotifications includes a low_stock notification for '
      'medicines returned by medicinesNeedingLowStockAlert', () async {
    final now = DateTime.utc(2026, 6, 1, 7);
    final medicine = Medicine(
      id: 'm1',
      name: 'X',
      stockEnabled: true,
      stockCount: 0,
      stockThreshold: 5,
      lowStockNotifiedAt: now,
    );
    when(() => repo.materializeDoses(any())).thenAnswer((_) async {});
    when(() => repo.dosesInRange(any(), any())).thenAnswer((_) async => []);
    when(
      () => repo.medicinesNeedingLowStockAlert(),
    ).thenAnswer((_) async => [medicine]);

    await withClock(Clock.fixed(now), () async {
      final notifications = await module.pendingNotifications();
      expect(
        notifications.where((n) => n.sourceType == 'low_stock'),
        hasLength(1),
      );
    });
  });

  test(
    'onNotificationAction(done) marks the dose done — and, being a '
    'plain test() with no Flutter test binding registered, doubles as '
    'the regression guard that this background-isolate path never '
    'grows a dependency on ChimePlayer/audioplayers '
    '(docs/superpowers/specs/02-delightful/'
    '10-optional-sound-design-pass-design.md): a real AudioPlayer '
    'platform-channel call here would throw without one registered',
    () async {
      when(
        () => repo.markDoseDone(
          any(),
          fromOtherSource: any(named: 'fromOtherSource'),
        ),
      ).thenAnswer((_) async => const Result.success(null));

      await module.onNotificationAction('d1', NotificationActionType.done);

      verify(
        () => repo.markDoseDone('d1', fromOtherSource: false),
      ).called(1);
    },
  );

  test('onNotificationAction(skip) marks the dose skipped', () async {
    when(
      () => repo.markDoseSkipped(any()),
    ).thenAnswer((_) async => const Result.success(null));

    await module.onNotificationAction('d1', NotificationActionType.skip);

    verify(() => repo.markDoseSkipped('d1')).called(1);
  });

  test('onNotificationAction(snooze) never mutates dose data', () async {
    await module.onNotificationAction('d1', NotificationActionType.snooze);
    verifyNever(
      () => repo.markDoseDone(
        any(),
        fromOtherSource: any(named: 'fromOtherSource'),
      ),
    );
    verifyNever(() => repo.markDoseSkipped(any()));
  });

  test(
    'onQuickAction marks the earliest due dose done and ignores others',
    () async {
      final now = DateTime.utc(2026, 6, 1, 9);
      final dueDose = MedicineDose(
        id: 'd-due',
        medicineId: 'm1',
        scheduleId: 's1',
        scheduledFor: DateTime.utc(2026, 6, 1, 8, 45),
        storedStatus: MedicineDoseStatus.upcoming,
        graceWindowMinutes: 30,
      );
      final upcomingDose = MedicineDose(
        id: 'd-upcoming',
        medicineId: 'm1',
        scheduleId: 's1',
        scheduledFor: DateTime.utc(2026, 6, 1, 20),
        storedStatus: MedicineDoseStatus.upcoming,
        graceWindowMinutes: 30,
      );
      when(() => repo.materializeDoses(any())).thenAnswer((_) async {});
      when(
        () => repo.dosesInRange(any(), any()),
      ).thenAnswer((_) async => [upcomingDose, dueDose]);
      when(
        () => repo.markDoseDone(
          any(),
          fromOtherSource: any(named: 'fromOtherSource'),
        ),
      ).thenAnswer((_) async => const Result.success(null));

      await withClock(Clock.fixed(now), () async {
        await module.onQuickAction();
      });

      verify(
        () => repo.markDoseDone('d-due', fromOtherSource: false),
      ).called(1);
      verifyNever(
        () => repo.markDoseDone(
          'd-upcoming',
          fromOtherSource: any(named: 'fromOtherSource'),
        ),
      );
    },
  );

  test('onQuickAction no-ops when nothing is due', () async {
    when(() => repo.materializeDoses(any())).thenAnswer((_) async {});
    when(() => repo.dosesInRange(any(), any())).thenAnswer((_) async => []);

    await module.onQuickAction();

    verifyNever(
      () => repo.markDoseDone(
        any(),
        fromOtherSource: any(named: 'fromOtherSource'),
      ),
    );
  });

  test(
    'dayStatus classifies a day complete when every dose that day is done',
    () async {
      final dose = MedicineDose(
        id: 'd1',
        medicineId: 'm1',
        scheduleId: 's1',
        scheduledFor: DateTime.utc(2026, 6, 1, 8),
        storedStatus: MedicineDoseStatus.done,
        graceWindowMinutes: 30,
      );
      when(
        () => repo.dosesInRange(any(), any()),
      ).thenAnswer((_) async => [dose]);

      final status = await module.dayStatus(
        const DateRange(
          start: LocalDate(2026, 6, 1),
          end: LocalDate(2026, 6, 1),
        ),
      );
      expect(
        status[const LocalDate(2026, 6, 1)]!.kind,
        ModuleDayStatusKind.complete,
      );
      expect(status[const LocalDate(2026, 6, 1)]!.value, 1);
    },
  );

  test(
    'search matches medicine name and dosage note, case-insensitively',
    () async {
      const medicine = Medicine(
        id: 'm1',
        name: 'Paracetamol',
        dosageNote: '500mg',
        stockEnabled: false,
      );
      when(() => repo.allMedicines()).thenAnswer((_) async => [medicine]);

      final results = await module.search('paracet');
      expect(results, hasLength(1));
      expect(results.first.title, 'Paracetamol');
      expect(results.first.deepLinkRoute, '/medicine/m1');

      final noResults = await module.search('nomatch');
      expect(noResults, isEmpty);
    },
  );

  test(
    'importData restores doses and stock events with remapped ids',
    () async {
      const medicine = Medicine(
        id: 'new-med',
        name: 'Vitamin D',
        stockEnabled: false,
      );
      final schedule = MedicineSchedule(
        id: 'new-sched',
        medicineId: 'new-med',
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        startDate: const LocalDate(2026, 6, 1),
        createdAt: DateTime.utc(2026, 6),
      );
      when(
        () => repo.createMedicine(
          name: any(named: 'name'),
          stockEnabled: any(named: 'stockEnabled'),
          dosageNote: any(named: 'dosageNote'),
          stockCount: any(named: 'stockCount'),
          stockThreshold: any(named: 'stockThreshold'),
          stopWhenStockDepleted: any(named: 'stopWhenStockDepleted'),
          consumptionPerDose: any(named: 'consumptionPerDose'),
        ),
      ).thenAnswer((_) async => const Result.success(medicine));
      when(
        () => repo.createSchedule(
          medicineId: any(named: 'medicineId'),
          rule: any(named: 'rule'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          graceWindowMinutes: any(named: 'graceWindowMinutes'),
        ),
      ).thenAnswer((_) async => Result.success(schedule));
      when(() => repo.restoreDose(any())).thenAnswer((_) async => 'new-dose');
      when(() => repo.restoreStockEvent(any())).thenAnswer((_) async {});
      when(() => repo.materializeDoses(any())).thenAnswer((_) async {});

      await module.importData(
        const ModuleExport({
          'medicines': [
            {
              'id': 'old-med',
              'name': 'Vitamin D',
              'dosageNote': null,
              'stockEnabled': false,
              'stockCount': null,
              'stockThreshold': null,
              'stopWhenStockDepleted': false,
              'consumptionPerDose': 1,
            },
          ],
          'schedules': [
            {
              'id': 'old-sched',
              'medicineId': 'old-med',
              'frequencyType': 'fixed_daily',
              'intervalDays': null,
              'weekdaysMask': null,
              'timesOfDay': ['08:00'],
              'startDate': '2026-06-01',
              'endDate': null,
              'graceWindowMinutes': 30,
            },
          ],
          'doses': [
            {
              'id': 'old-dose',
              'medicineId': 'old-med',
              'scheduleId': 'old-sched',
              'scheduledFor': '2026-06-01T08:00:00.000Z',
              'status': 'done',
              'statusChangedAt': null,
              'stockDeltaApplied': -1,
              'graceWindowMinutes': 30,
            },
          ],
          'stockEvents': [
            {
              'medicineId': 'old-med',
              'doseId': 'old-dose',
              'delta': -1,
              'reason': 'dose_taken',
              'occurredAt': '2026-06-01T08:00:00.000Z',
            },
          ],
        }),
      );

      final capturedDoses = verify(
        () => repo.restoreDose(captureAny()),
      ).captured;
      expect(capturedDoses, hasLength(1));
      expect(
        (capturedDoses.single as MedicineDose).storedStatus,
        MedicineDoseStatus.done,
      );
      final capturedEvents = verify(
        () => repo.restoreStockEvent(captureAny()),
      ).captured;
      expect(capturedEvents, hasLength(1));
      expect((capturedEvents.single as MedicineStockEvent).doseId, 'new-dose');
    },
  );

  test('wipeData delegates to the repository', () async {
    when(() => repo.wipeAll()).thenAnswer((_) async {});
    await module.wipeData();
    verify(() => repo.wipeAll()).called(1);
  });
}
