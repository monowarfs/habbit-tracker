import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/expand_repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/schedule_activity.dart';

/// A dose instance still to be inserted — the repository assigns its id
/// at insert time (ids are never generated in pure domain code, same
/// precedent as every other use case in this app).
typedef PlannedDose = ({
  String medicineId,
  String scheduleId,
  DateTime scheduledFor,
  int graceWindowMinutes,
});

/// Plans which new [MedicineDose] rows need to exist for
/// `[windowStart, windowEnd]` (D-13's 30-day rolling window), given every
/// active schedule and every dose row that already exists in that range.
///
/// Pure gap-filler: a slot that already has *any* dose row (regardless of
/// its status) is left untouched — this function never regenerates or
/// overwrites an existing row. Editing a schedule's future doses (FR-M-09)
/// is a separate, explicit repository operation
/// (`MedicineRepositoryImpl.updateSchedule`), not this periodic pass.
List<PlannedDose> planDoseMaterialization({
  required List<Medicine> medicines,
  required List<MedicineSchedule> schedules,
  required List<MedicineDose> existingDoses,
  required LocalDate windowStart,
  required LocalDate windowEnd,
}) {
  final medicinesById = {for (final m in medicines) m.id: m};
  final existingSlots = {
    for (final d in existingDoses) (d.medicineId, d.scheduledFor),
  };

  // D-02: if two schedules of the same medicine collide on the same
  // instant, the most-recently-created schedule wins.
  final winners = <(String, DateTime), MedicineSchedule>{};
  for (final schedule in schedules) {
    final medicine = medicinesById[schedule.medicineId];
    if (medicine == null) continue;
    if (!isScheduleActive(
      medicine: medicine,
      schedule: schedule,
      asOf: windowStart,
    )) {
      continue;
    }
    final rangeStart = schedule.startDate.compareTo(windowStart) > 0
        ? schedule.startDate
        : windowStart;
    final rangeEnd = schedule.endDate == null
        ? windowEnd
        : (schedule.endDate!.compareTo(windowEnd) < 0
              ? schedule.endDate!
              : windowEnd);
    if (rangeStart.compareTo(rangeEnd) > 0) continue;

    final instants = expandRepeatRule(
      rule: schedule.rule,
      anchor: schedule.startDate,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    for (final instant in instants) {
      final key = (schedule.medicineId, instant);
      final current = winners[key];
      if (current == null || schedule.createdAt.isAfter(current.createdAt)) {
        winners[key] = schedule;
      }
    }
  }

  final planned = <PlannedDose>[];
  winners.forEach((key, schedule) {
    final (medicineId, scheduledFor) = key;
    if (existingSlots.contains((medicineId, scheduledFor))) return;
    planned.add((
      medicineId: medicineId,
      scheduleId: schedule.id,
      scheduledFor: scheduledFor,
      graceWindowMinutes: schedule.graceWindowMinutes,
    ));
  });
  return planned;
}
