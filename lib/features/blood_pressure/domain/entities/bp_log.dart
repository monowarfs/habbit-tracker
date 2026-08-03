import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_classification.dart';

part 'bp_log.freezed.dart';

/// A single blood-pressure reading.
@freezed
sealed class BpLog with _$BpLog {
  const factory BpLog({
    required String id,
    required int systolic,
    required int diastolic,
    required DateTime loggedAt,
    required BpClassification classification,
    int? pulse,
    String? notes,
  }) = _BpLog;
}
