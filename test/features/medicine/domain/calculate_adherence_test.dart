import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/calculate_adherence.dart';

void main() {
  final now = DateTime.utc(2026, 6, 10);

  MedicineDose dose({
    required DateTime scheduledFor,
    required MedicineDoseStatus storedStatus,
    DateTime? statusChangedAt,
    int graceWindowMinutes = 30,
  }) => MedicineDose(
    id: 'd',
    medicineId: 'm1',
    scheduleId: 's1',
    scheduledFor: scheduledFor,
    storedStatus: storedStatus,
    statusChangedAt: statusChangedAt,
    graceWindowMinutes: graceWindowMinutes,
  );

  test('classifies on-time, late, missed, and skipped doses', () {
    final scheduled = DateTime.utc(2026, 6, 1, 8);
    final stats = calculateAdherence(
      doses: [
        dose(
          scheduledFor: scheduled,
          storedStatus: MedicineDoseStatus.done,
          statusChangedAt: scheduled.add(const Duration(minutes: 10)),
        ), // on time
        dose(
          scheduledFor: scheduled,
          storedStatus: MedicineDoseStatus.done,
          statusChangedAt: scheduled.add(const Duration(minutes: 45)),
        ), // late
        dose(
          scheduledFor: scheduled,
          storedStatus: MedicineDoseStatus.upcoming,
        ), // -> missed (now is far past)
        dose(scheduledFor: scheduled, storedStatus: MedicineDoseStatus.skipped),
      ],
      now: now,
    );
    expect(stats.takenOnTime, 1);
    expect(stats.takenLate, 1);
    expect(stats.missed, 1);
    expect(stats.skipped, 1);
    expect(stats.total, 4);
  });

  test('upcoming/due doses are excluded from the total (not yet resolved)', () {
    final stats = calculateAdherence(
      doses: [
        dose(
          scheduledFor: now.add(const Duration(hours: 1)),
          storedStatus: MedicineDoseStatus.upcoming,
        ),
      ],
      now: now,
    );
    expect(stats.total, 0);
  });
}
