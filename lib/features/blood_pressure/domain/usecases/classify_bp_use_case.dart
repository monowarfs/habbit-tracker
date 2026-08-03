import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_classification.dart';

/// Classifies a blood-pressure reading per AHA guidelines
/// (`professional.heart.org`) — the higher category between systolic and
/// diastolic wins.
class ClassifyBpUseCase {
  /// Creates the classifier (stateless — a pure function wrapper).
  const ClassifyBpUseCase();

  /// Classifies [systolic]/[diastolic].
  BpClassification execute({required int systolic, required int diastolic}) {
    if (systolic >= 180 || diastolic >= 120) {
      return BpClassification.hypertensionCrisis;
    }
    if (systolic >= 140 || diastolic >= 90) {
      return BpClassification.hypertension2;
    }
    if (systolic >= 130 || diastolic >= 80) {
      return BpClassification.hypertension1;
    }
    if (systolic >= 120) {
      return BpClassification.elevated;
    }
    return BpClassification.normal;
  }
}
