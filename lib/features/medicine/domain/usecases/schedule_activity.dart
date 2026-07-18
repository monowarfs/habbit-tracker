import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';

/// Whether [schedule] should still generate/notify doses as of [asOf]
/// (FR-M-05/FR-M-10, D-04). Zero stock alone never deactivates a
/// schedule — only an explicit end date, archiving, or the opt-in
/// `stopWhenStockDepleted` toggle does.
bool isScheduleActive({
  required Medicine medicine,
  required MedicineSchedule schedule,
  required LocalDate asOf,
}) {
  if (medicine.archivedAt != null) return false;
  if (schedule.endDate != null && asOf.compareTo(schedule.endDate!) > 0) {
    return false;
  }
  if (medicine.stopWhenStockDepleted &&
      medicine.stockEnabled &&
      (medicine.stockCount ?? 0) <= 0) {
    return false;
  }
  return true;
}
