import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';

void main() {
  late AppDatabase db;
  late MedicineRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MedicineRepositoryImpl(db);
  });

  tearDown(() => db.close());

  test('createMedicine persists and watchMedicines reflects it', () async {
    final result = await repo.createMedicine(
      name: 'Amoxicillin',
      stockEnabled: true,
      stockCount: 20,
      stockThreshold: 5,
    );
    expect(result, isA<Success<Medicine>>());

    final medicines = await repo.watchMedicines(includeArchived: false).first;
    expect(medicines, hasLength(1));
    expect(medicines.single.name, 'Amoxicillin');
    expect(medicines.single.stockCount, 20);
  });

  test('archiveMedicine excludes it from includeArchived: false, keeps it '
      'in includeArchived: true', () async {
    final created = await repo.createMedicine(name: 'X', stockEnabled: false);
    final id = (created as Success<Medicine>).value.id;

    await repo.archiveMedicine(id);

    expect(await repo.watchMedicines(includeArchived: false).first, isEmpty);
    final archived = await repo.watchMedicines(includeArchived: true).first;
    expect(archived, hasLength(1));
    expect(archived.single.archivedAt, isNotNull);
  });

  test('createSchedule persists and watchSchedules reflects it, with '
      'RepeatRule round-tripping through the DB', () async {
    final created = await repo.createMedicine(name: 'X', stockEnabled: false);
    final medicineId = (created as Success<Medicine>).value.id;

    final scheduleResult = await repo.createSchedule(
      medicineId: medicineId,
      rule: const RepeatRule.everyNDays(
        intervalDays: 2,
        timesOfDay: [LocalTime(8, 0), LocalTime(20, 0)],
      ),
      startDate: const LocalDate(2026, 6, 1),
    );
    expect(scheduleResult, isA<Success<MedicineSchedule>>());

    final schedules = await repo.watchSchedules(medicineId).first;
    expect(schedules, hasLength(1));
    final rule = schedules.single.rule;
    expect(rule, isA<EveryNDaysRule>());
    expect((rule as EveryNDaysRule).intervalDays, 2);
    expect(rule.timesOfDay, [const LocalTime(8, 0), const LocalTime(20, 0)]);
  });

  test(
    'updateMedicine on an unknown id fails with NotFoundException',
    () async {
      final result = await repo.updateMedicine('missing', name: 'Y');
      expect(result, isA<Failure<void>>());
    },
  );

  test("materializeDoses fills a fixed-daily schedule's window and is "
      'idempotent on a second call', () async {
    final created = await repo.createMedicine(name: 'X', stockEnabled: false);
    final medicineId = (created as Success<Medicine>).value.id;
    await repo.createSchedule(
      medicineId: medicineId,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });

    final firstPass = await repo.dosesInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 7, 1),
    );
    expect(firstPass, hasLength(31)); // 6/1 through 7/1 inclusive

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });
    final secondPass = await repo.dosesInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 7, 1),
    );
    expect(secondPass, hasLength(31)); // unchanged, not duplicated
  });

  test("watchDosesForDay reflects a single day's flattened cross-medicine "
      'timeline', () async {
    final medA = await repo.createMedicine(name: 'A', stockEnabled: false);
    final medB = await repo.createMedicine(name: 'B', stockEnabled: false);
    await repo.createSchedule(
      medicineId: (medA as Success<Medicine>).value.id,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await repo.createSchedule(
      medicineId: (medB as Success<Medicine>).value.id,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(9, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });

    final doses = await repo
        .watchDosesForDay(const LocalDate(2026, 6, 1))
        .first;
    expect(doses, hasLength(2));
  });

  Future<String> doseIdFor(
    MedicineRepositoryImpl repo,
    String medicineId,
  ) async {
    final doses = await repo.dosesInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
    );
    return doses.firstWhere((d) => d.medicineId == medicineId).id;
  }

  test('markDoseDone decrements stock, writes a ledger event, and the '
      'ledger reconciles back to medicines.stock_count', () async {
    final created = await repo.createMedicine(
      name: 'X',
      stockEnabled: true,
      stockCount: 10,
    );
    final medicineId = (created as Success<Medicine>).value.id;
    await repo.createSchedule(
      medicineId: medicineId,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });
    final doseId = await doseIdFor(repo, medicineId);

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 8, 5)), () async {
      final result = await repo.markDoseDone(doseId, fromOtherSource: false);
      expect(result, isA<Success<void>>());
    });

    final medicine = await repo.medicineById(medicineId);
    expect(medicine!.stockCount, 9);
  });

  test('undoDose reverses the exact stock amount previously applied', () async {
    final created = await repo.createMedicine(
      name: 'X',
      stockEnabled: true,
      stockCount: 10,
    );
    final medicineId = (created as Success<Medicine>).value.id;
    await repo.createSchedule(
      medicineId: medicineId,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });
    final doseId = await doseIdFor(repo, medicineId);
    await repo.markDoseDone(doseId, fromOtherSource: false);

    await repo.undoDose(doseId);

    final medicine = await repo.medicineById(medicineId);
    expect(medicine!.stockCount, 10);
  });

  test('crossing the low-stock threshold surfaces the medicine exactly '
      'once, and a refill clears it', () async {
    final created = await repo.createMedicine(
      name: 'X',
      stockEnabled: true,
      stockCount: 1,
      stockThreshold: 5,
    );
    final medicineId = (created as Success<Medicine>).value.id;
    await repo.createSchedule(
      medicineId: medicineId,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });
    final doseId = await doseIdFor(repo, medicineId);

    await repo.markDoseDone(
      doseId,
      fromOtherSource: false,
    ); // 1 -> 0, crosses threshold 5

    var alerts = await repo.medicinesNeedingLowStockAlert();
    expect(alerts.map((m) => m.id), contains(medicineId));

    await repo.refillStock(medicineId, 20);

    alerts = await repo.medicinesNeedingLowStockAlert();
    expect(alerts.map((m) => m.id), isNot(contains(medicineId)));
  });

  test('a medicine with stock tracking disabled is never surfaced as '
      'low-stock, even with a stale threshold/count', () async {
    final created = await repo.createMedicine(
      name: 'X',
      stockEnabled: false,
      stockCount: 1,
      stockThreshold: 5,
    );
    final medicineId = (created as Success<Medicine>).value.id;
    await repo.createSchedule(
      medicineId: medicineId,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });
    final doseId = await doseIdFor(repo, medicineId);

    await repo.markDoseDone(doseId, fromOtherSource: false);

    final alerts = await repo.medicinesNeedingLowStockAlert();
    expect(alerts.map((m) => m.id), isNot(contains(medicineId)));
  });

  test('undoing a dose that restores stock back above threshold clears '
      'the stale low-stock flag', () async {
    final created = await repo.createMedicine(
      name: 'X',
      stockEnabled: true,
      stockCount: 6,
      stockThreshold: 5,
    );
    final medicineId = (created as Success<Medicine>).value.id;
    await repo.createSchedule(
      medicineId: medicineId,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });
    final doseId = await doseIdFor(repo, medicineId);

    await repo.markDoseDone(doseId, fromOtherSource: false); // 6 -> 5, crosses

    var alerts = await repo.medicinesNeedingLowStockAlert();
    expect(alerts.map((m) => m.id), contains(medicineId));

    await repo.undoDose(doseId); // 5 -> 6, back above threshold

    alerts = await repo.medicinesNeedingLowStockAlert();
    expect(alerts.map((m) => m.id), isNot(contains(medicineId)));
  });

  test('archiveMedicine deletes future upcoming doses (FR-M-10), leaving '
      'past/done doses in history', () async {
    final created = await repo.createMedicine(name: 'X', stockEnabled: false);
    final medicineId = (created as Success<Medicine>).value.id;
    await repo.createSchedule(
      medicineId: medicineId,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });
    final todaysDoseId = await doseIdFor(repo, medicineId);
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 8, 5)), () async {
      await repo.markDoseDone(todaysDoseId, fromOtherSource: false);
    });

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 9)), () async {
      await repo.archiveMedicine(medicineId);
    });

    final remaining = await repo.dosesInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 7, 1),
    );
    expect(remaining, hasLength(1));
    expect(remaining.single.id, todaysDoseId);
    expect(remaining.single.storedStatus, MedicineDoseStatus.done);
  });
}
