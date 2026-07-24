import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/stacking/habit_stack_suggestion_evaluator.dart';
import 'package:habit_tracker/core/stacking/habit_stack_suggestion_repository.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> seedMedicineSchedule(AppDatabase db) async {
    final medicineRepo = MedicineRepositoryImpl(db);
    final medicineResult = await medicineRepo.createMedicine(
      name: 'Aspirin',
      stockEnabled: false,
    );
    final medicine = (medicineResult as Success<Medicine>).value;
    final scheduleResult = await medicineRepo.createSchedule(
      medicineId: medicine.id,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 5, 20),
    );
    return (scheduleResult as Success<MedicineSchedule>).value.id;
  }

  test(
    'a real medicine -> water pattern over 7 days produces a pending '
    "'medicine_water' suggestion",
    () async {
      final medicineRepo = MedicineRepositoryImpl(db);
      final waterRepo = WaterRepositoryImpl(db);
      final scheduleId = await seedMedicineSchedule(db);
      final medicines = await medicineRepo.allMedicines();
      final medicineId = medicines.single.id;

      final today = DateTime.utc(2026, 6, 7);
      for (var i = 0; i < 7; i++) {
        final day = today.subtract(Duration(days: i));
        await medicineRepo.restoreDose(
          MedicineDose(
            id: '',
            medicineId: medicineId,
            scheduleId: scheduleId,
            scheduledFor: DateTime.utc(day.year, day.month, day.day, 8),
            storedStatus: MedicineDoseStatus.done,
            graceWindowMinutes: 30,
            statusChangedAt: DateTime.utc(
              day.year,
              day.month,
              day.day,
              8,
              5,
            ),
          ),
        );
        await waterRepo.addEntry(
          amountMl: 250,
          loggedAt: DateTime.utc(day.year, day.month, day.day, 8, 25),
          source: WaterEntrySource.quick,
        );
      }

      await withClock(
        Clock.fixed(today.add(const Duration(hours: 9))),
        () async {
          await evaluateStackSuggestions(db: db);
        },
      );

      final repository = HabitStackSuggestionRepository(db);
      final row = await repository.byId('medicine_water');
      expect(row, isNotNull);
      expect(row!.status, 'pending');
      expect(row.sourceModuleId, 'medicine');
      expect(row.targetModuleId, 'water');
      expect(row.qualifyingDays, greaterThanOrEqualTo(5));
    },
  );

  test(
    'a second evaluation within 24h does not re-evaluate (the row is '
    'left exactly as the first evaluation wrote it)',
    () async {
      final medicineRepo = MedicineRepositoryImpl(db);
      final waterRepo = WaterRepositoryImpl(db);
      final scheduleId = await seedMedicineSchedule(db);
      final medicineId = (await medicineRepo.allMedicines()).single.id;
      final today = DateTime.utc(2026, 6, 7);

      for (var i = 0; i < 7; i++) {
        final day = today.subtract(Duration(days: i));
        await medicineRepo.restoreDose(
          MedicineDose(
            id: '',
            medicineId: medicineId,
            scheduleId: scheduleId,
            scheduledFor: DateTime.utc(day.year, day.month, day.day, 8),
            storedStatus: MedicineDoseStatus.done,
            graceWindowMinutes: 30,
            statusChangedAt: DateTime.utc(
              day.year,
              day.month,
              day.day,
              8,
              5,
            ),
          ),
        );
        await waterRepo.addEntry(
          amountMl: 250,
          loggedAt: DateTime.utc(day.year, day.month, day.day, 8, 25),
          source: WaterEntrySource.quick,
        );
      }

      final firstRun = today.add(const Duration(hours: 9));
      await withClock(Clock.fixed(firstRun), () async {
        await evaluateStackSuggestions(db: db);
      });
      final repository = HabitStackSuggestionRepository(db);
      final firstEvaluatedAt =
          (await repository.byId('medicine_water'))!.lastEvaluatedAt;

      // Adds a same-day water log that would otherwise change the
      // computed result, to make the "no-op" observable.
      await waterRepo.addEntry(
        amountMl: 100,
        loggedAt: today.add(const Duration(hours: 10)),
        source: WaterEntrySource.quick,
      );
      await withClock(
        Clock.fixed(firstRun.add(const Duration(hours: 1))),
        () async {
          await evaluateStackSuggestions(db: db);
        },
      );

      final row = await repository.byId('medicine_water');
      expect(row!.lastEvaluatedAt, firstEvaluatedAt);
    },
  );

  test('no pattern at all leaves no row', () async {
    await seedMedicineSchedule(db);
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 7, 9)), () async {
      await evaluateStackSuggestions(db: db);
    });

    final repository = HabitStackSuggestionRepository(db);
    expect(await repository.byId('medicine_water'), isNull);
    expect(await repository.byId('prayer_water'), isNull);
  });
}
