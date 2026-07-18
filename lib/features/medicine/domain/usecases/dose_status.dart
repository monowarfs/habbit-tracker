import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';

/// Derives a dose's live status (FR-M-06, D-05). [storedStatus] is only
/// ever `upcoming`/`done`/`skipped` in the database — `due`/`missed` are
/// computed here, at read time, so nothing needs a background job to
/// scan and flip rows as time passes.
MedicineDoseStatus effectiveDoseStatus({
  required MedicineDoseStatus storedStatus,
  required DateTime scheduledFor,
  required DateTime now,
  required int graceWindowMinutes,
}) {
  if (storedStatus != MedicineDoseStatus.upcoming) return storedStatus;
  if (now.isBefore(scheduledFor)) return MedicineDoseStatus.upcoming;
  final graceEnd = scheduledFor.add(Duration(minutes: graceWindowMinutes));
  if (!now.isAfter(graceEnd)) return MedicineDoseStatus.due;
  return MedicineDoseStatus.missed;
}
