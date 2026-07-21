import 'package:freezed_annotation/freezed_annotation.dart';

part 'medicine_dose.freezed.dart';

/// A materialized dose instance (D-13). The storedStatus is only ever
/// `upcoming`, `done`, or `skipped` — `due`/`missed` are never persisted,
/// they're derived at read time by `effective_dose_status.dart` (FR-M-06,
/// "evaluated lazily, no background job").
enum MedicineDoseStatus {
  /// Not yet due, and not yet acted on.
  upcoming,

  /// Past `scheduledFor`, within the grace window — derived only.
  due,

  /// Marked taken.
  done,

  /// Past the grace window, never acted on — derived only.
  missed,

  /// Explicitly dismissed.
  skipped,
}

/// A single concrete dose instance (`technical/database-design.md`).
@freezed
sealed class MedicineDose with _$MedicineDose {
  /// Creates a dose.
  const factory MedicineDose({
    required String id,
    required String medicineId,
    required String scheduleId,
    required DateTime scheduledFor,
    required MedicineDoseStatus storedStatus,

    /// Denormalized from the generating schedule at materialization time
    /// (implementation refinement over the design spec — avoids a join
    /// on the hottest read path).
    required int graceWindowMinutes,
    DateTime? statusChangedAt,
    @Default(0) int stockDeltaApplied,
    String? notes,
  }) = _MedicineDose;
}
