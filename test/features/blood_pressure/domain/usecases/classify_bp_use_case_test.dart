import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_classification.dart';
import 'package:habit_tracker/features/blood_pressure/domain/usecases/classify_bp_use_case.dart';

void main() {
  const useCase = ClassifyBpUseCase();

  test('normal: systolic < 120 and diastolic < 80', () {
    expect(
      useCase.execute(systolic: 110, diastolic: 70),
      BpClassification.normal,
    );
  });

  test('elevated: systolic 120-129, diastolic still < 80', () {
    expect(
      useCase.execute(systolic: 125, diastolic: 75),
      BpClassification.elevated,
    );
  });

  test('hypertension1: systolic 130-139 or diastolic 80-89', () {
    expect(
      useCase.execute(systolic: 135, diastolic: 70),
      BpClassification.hypertension1,
    );
    expect(
      useCase.execute(systolic: 115, diastolic: 85),
      BpClassification.hypertension1,
    );
  });

  test('hypertension2: systolic 140-179 or diastolic 90-119', () {
    expect(
      useCase.execute(systolic: 150, diastolic: 70),
      BpClassification.hypertension2,
    );
    expect(
      useCase.execute(systolic: 115, diastolic: 95),
      BpClassification.hypertension2,
    );
  });

  test('hypertensionCrisis: systolic >= 180 or diastolic >= 120', () {
    expect(
      useCase.execute(systolic: 185, diastolic: 70),
      BpClassification.hypertensionCrisis,
    );
    expect(
      useCase.execute(systolic: 115, diastolic: 125),
      BpClassification.hypertensionCrisis,
    );
  });

  test('the higher category wins when systolic and diastolic disagree', () {
    // Normal systolic, crisis diastolic.
    expect(
      useCase.execute(systolic: 110, diastolic: 121),
      BpClassification.hypertensionCrisis,
    );
  });
}
