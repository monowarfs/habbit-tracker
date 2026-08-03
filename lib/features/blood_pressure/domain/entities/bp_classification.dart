/// AHA blood-pressure category (`professional.heart.org` guidelines).
enum BpClassification {
  /// Systolic under 120 and diastolic under 80.
  normal,

  /// Systolic 120-129 and diastolic under 80.
  elevated,

  /// Systolic 130-139 or diastolic 80-89.
  hypertension1,

  /// Systolic 140-179 or diastolic 90-119.
  hypertension2,

  /// Systolic 180+ or diastolic 120+ — needs immediate medical attention.
  hypertensionCrisis,
}
