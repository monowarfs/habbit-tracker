import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/plan_dose_materialization.dart';

void main() {
  final medicine = Medicine(id: 'm1', name: 'Amoxicillin', stockEnabled: false);

  test('generates a PlannedDose per schedule instant within the window', () {
    final schedule = MedicineSchedule(
      id: 's1',
      medicineId: 'm1',
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
      createdAt: DateTime.utc(2026, 5),
    );
    final planned = planDoseMaterialization(
      medicines: [medicine],
      schedules: [schedule],
      existingDoses: const [],
      windowStart: const LocalDate(2026, 6, 1),
      windowEnd: const LocalDate(2026, 6, 2),
    );
    expect(planned, hasLength(2));
    expect(planned.every((p) => p.medicineId == 'm1' && p.scheduleId == 's1'), isTrue);
    expect(planned.every((p) => p.graceWindowMinutes == 30), isTrue);
  });

  test('never re-plans a slot that already has a dose row', () {
    final schedule = MedicineSchedule(
      id: 's1',
      medicineId: 'm1',
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
      createdAt: DateTime.utc(2026, 5),
    );
    final existing = MedicineDose(
      id: 'd1',
      medicineId: 'm1',
      scheduleId: 's1',
      scheduledFor: DateTime(2026, 6, 1, 8, 0).toUtc(),
      storedStatus: MedicineDoseStatus.done,
      graceWindowMinutes: 30,
    );
    final planned = planDoseMaterialization(
      medicines: [medicine],
      schedules: [schedule],
      existingDoses: [existing],
      windowStart: const LocalDate(2026, 6, 1),
      windowEnd: const LocalDate(2026, 6, 1),
    );
    expect(planned, isEmpty);
  });

  test(
    'D-02 collision: two schedules at the same medicine+time+day dedupe to '
    'the most-recently-created one',
    () {
      final older = MedicineSchedule(
        id: 'old',
        medicineId: 'm1',
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        startDate: const LocalDate(2026, 6, 1),
        createdAt: DateTime.utc(2026, 1),
      );
      final newer = MedicineSchedule(
        id: 'new',
        medicineId: 'm1',
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        startDate: const LocalDate(2026, 6, 1),
        createdAt: DateTime.utc(2026, 2),
        graceWindowMinutes: 45,
      );
      final planned = planDoseMaterialization(
        medicines: [medicine],
        schedules: [older, newer],
        existingDoses: const [],
        windowStart: const LocalDate(2026, 6, 1),
        windowEnd: const LocalDate(2026, 6, 1),
      );
      expect(planned, hasLength(1));
      expect(planned.single.scheduleId, 'new');
      expect(planned.single.graceWindowMinutes, 45);
    },
  );

  test('an inactive schedule (archived medicine) plans nothing', () {
    final schedule = MedicineSchedule(
      id: 's1',
      medicineId: 'm1',
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
      createdAt: DateTime.utc(2026, 5),
    );
    final planned = planDoseMaterialization(
      medicines: [medicine.copyWith(archivedAt: DateTime.utc(2026, 5))],
      schedules: [schedule],
      existingDoses: const [],
      windowStart: const LocalDate(2026, 6, 1),
      windowEnd: const LocalDate(2026, 6, 1),
    );
    expect(planned, isEmpty);
  });

  test('a schedule ending mid-window is clipped to its endDate', () {
    final schedule = MedicineSchedule(
      id: 's1',
      medicineId: 'm1',
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
      endDate: const LocalDate(2026, 6, 2),
      createdAt: DateTime.utc(2026, 5),
    );
    final planned = planDoseMaterialization(
      medicines: [medicine],
      schedules: [schedule],
      existingDoses: const [],
      windowStart: const LocalDate(2026, 6, 1),
      windowEnd: const LocalDate(2026, 6, 5),
    );
    expect(planned, hasLength(2)); // 6/1 and 6/2 only
  });
}
