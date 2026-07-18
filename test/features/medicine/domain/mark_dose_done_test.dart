import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/dose_status.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/schedule_activity.dart';

void main() {
  group('effectiveDoseStatus (D-05 grace-window state machine)', () {
    final scheduledFor = DateTime.utc(2026, 6, 1, 8);

    test('before scheduled time: upcoming', () {
      expect(
        effectiveDoseStatus(
          storedStatus: MedicineDoseStatus.upcoming,
          scheduledFor: scheduledFor,
          now: scheduledFor.subtract(const Duration(minutes: 1)),
          graceWindowMinutes: 30,
        ),
        MedicineDoseStatus.upcoming,
      );
    });

    test('exactly at scheduled time: due', () {
      expect(
        effectiveDoseStatus(
          storedStatus: MedicineDoseStatus.upcoming,
          scheduledFor: scheduledFor,
          now: scheduledFor,
          graceWindowMinutes: 30,
        ),
        MedicineDoseStatus.due,
      );
    });

    test('exactly at the grace window boundary: still due (inclusive)', () {
      expect(
        effectiveDoseStatus(
          storedStatus: MedicineDoseStatus.upcoming,
          scheduledFor: scheduledFor,
          now: scheduledFor.add(const Duration(minutes: 30)),
          graceWindowMinutes: 30,
        ),
        MedicineDoseStatus.due,
      );
    });

    test('one minute past the grace window: missed', () {
      expect(
        effectiveDoseStatus(
          storedStatus: MedicineDoseStatus.upcoming,
          scheduledFor: scheduledFor,
          now: scheduledFor.add(const Duration(minutes: 31)),
          graceWindowMinutes: 30,
        ),
        MedicineDoseStatus.missed,
      );
    });

    test('a done dose stays done regardless of elapsed time', () {
      expect(
        effectiveDoseStatus(
          storedStatus: MedicineDoseStatus.done,
          scheduledFor: scheduledFor,
          now: scheduledFor.add(const Duration(days: 1)),
          graceWindowMinutes: 30,
        ),
        MedicineDoseStatus.done,
      );
    });

    test('a skipped dose stays skipped', () {
      expect(
        effectiveDoseStatus(
          storedStatus: MedicineDoseStatus.skipped,
          scheduledFor: scheduledFor,
          now: scheduledFor.add(const Duration(minutes: 1)),
          graceWindowMinutes: 30,
        ),
        MedicineDoseStatus.skipped,
      );
    });
  });

  group('isScheduleActive (D-04 stock-exhaustion behavior)', () {
    const medicine = Medicine(
      id: 'm1',
      name: 'Amoxicillin',
      stockEnabled: true,
      stockCount: 0,
      stockThreshold: 5,
    );
    final schedule = MedicineSchedule(
      id: 's1',
      medicineId: 'm1',
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 1, 1),
      createdAt: DateTime.utc(2026),
    );

    test(
      'zero stock does NOT stop the schedule when stopWhenStockDepleted '
      'is false (D-04 default)',
      () {
        expect(
          isScheduleActive(
            medicine: medicine,
            schedule: schedule,
            asOf: const LocalDate(2026, 6, 1),
          ),
          isTrue,
        );
      },
    );

    test(
      'zero stock DOES stop the schedule when stopWhenStockDepleted is true',
      () {
        expect(
          isScheduleActive(
            medicine: medicine.copyWith(stopWhenStockDepleted: true),
            schedule: schedule,
            asOf: const LocalDate(2026, 6, 1),
          ),
          isFalse,
        );
      },
    );

    test('an archived medicine is never active', () {
      expect(
        isScheduleActive(
          medicine: medicine.copyWith(archivedAt: DateTime.utc(2026, 5)),
          schedule: schedule,
          asOf: const LocalDate(2026, 6, 1),
        ),
        isFalse,
      );
    });

    test('past the schedule end date is never active', () {
      expect(
        isScheduleActive(
          medicine: medicine.copyWith(stockCount: 100),
          schedule: schedule.copyWith(endDate: const LocalDate(2026, 5, 1)),
          asOf: const LocalDate(2026, 6, 1),
        ),
        isFalse,
      );
    });
  });
}
