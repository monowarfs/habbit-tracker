import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
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

  test('materializeDoses fills a fixed-daily schedule\'s window and is '
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

  test('watchDosesForDay reflects a single day\'s flattened cross-medicine '
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
}
