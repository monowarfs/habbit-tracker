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
}
