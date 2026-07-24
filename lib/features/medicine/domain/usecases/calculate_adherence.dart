import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/dose_status.dart';

/// Per-medicine adherence breakdown (FR-M-08).
typedef AdherenceStats = ({
  int takenOnTime,
  int takenLate,
  int missed,
  int skipped,
  int total,
});

/// Classifies [doses] into on-time/late/missed/skipped as of [now].
/// `upcoming`/`due` doses (not yet resolved one way or another) are
/// excluded from every count, including the total count.
///
/// [pausedDays] are skipped entirely — doses on paused days are excluded
/// from all counts.
AdherenceStats calculateAdherence({
  required List<MedicineDose> doses,
  required DateTime now,
  Set<LocalDate> pausedDays = const {},
}) {
  var onTime = 0;
  var late = 0;
  var missed = 0;
  var skipped = 0;
  for (final dose in doses) {
    // Skip doses on paused days.
    final doseDay = LocalDate.fromDateTime(dose.scheduledFor.toLocal());
    if (pausedDays.contains(doseDay)) {
      continue;
    }
    final status = effectiveDoseStatus(
      storedStatus: dose.storedStatus,
      scheduledFor: dose.scheduledFor,
      now: now,
      graceWindowMinutes: dose.graceWindowMinutes,
    );
    switch (status) {
      case MedicineDoseStatus.done:
        final changedAt = dose.statusChangedAt;
        final onTimeCutoff = dose.scheduledFor.add(
          Duration(minutes: dose.graceWindowMinutes),
        );
        if (changedAt != null && !changedAt.isAfter(onTimeCutoff)) {
          onTime++;
        } else {
          late++;
        }
      case MedicineDoseStatus.missed:
        missed++;
      case MedicineDoseStatus.skipped:
        skipped++;
      case MedicineDoseStatus.upcoming:
      case MedicineDoseStatus.due:
        break;
    }
  }
  return (
    takenOnTime: onTime,
    takenLate: late,
    missed: missed,
    skipped: skipped,
    total: onTime + late + missed + skipped,
  );
}
