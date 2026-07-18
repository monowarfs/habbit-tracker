import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';

part 'medicine_schedule.freezed.dart';

/// One of a medicine's (possibly several, D-02) active schedules.
@freezed
sealed class MedicineSchedule with _$MedicineSchedule {
  /// Creates a schedule.
  const factory MedicineSchedule({
    required String id,
    required String medicineId,
    required RepeatRule rule,
    required LocalDate startDate,

    /// Breaks same-slot collisions between two schedules of the same
    /// medicine (D-02: most-recently-created wins).
    required DateTime createdAt,
    LocalDate? endDate,
    @Default(30) int graceWindowMinutes,
  }) = _MedicineSchedule;
}
