# Implementation Plan: Adherence-by-Medicine Breakdown

**Spec:** `08-adherence-by-medicine-design.md`
**Complexity:** S · **Estimated effort:** 1 day
**Depends on:** `calculateAdherence` use case, `medicine_doses` table

---

## Task 1: Create per-medicine adherence calculator

**File:** `lib/features/medicine/domain/usecases/per_medicine_adherence.dart`

```dart
class PerMedicineAdherence {
  /// Groups doses by medicine_id and calculates adherence per group.
  List<MedicineAdherenceResult> calculate({
    required List<MedicineDose> allDoses,
    required List<Medicine> medicines,
  }) {
    final results = <MedicineAdherenceResult>[];
    for (final medicine in medicines) {
      final doses = allDoses.where((d) => d.medicineId == medicine.id).toList();
      if (doses.length < 7) continue; // minimum sample
      final taken = doses.where((d) => d.status == 'done').length;
      results.add(MedicineAdherenceResult(
        medicineId: medicine.id,
        medicineName: medicine.name,
        adherenceRate: taken / doses.length,
        dosesTaken: taken,
        dosesTotal: doses.length,
      ));
    }
    return results..sort((a, b) => a.adherenceRate.compareTo(b.adherenceRate));
  }
}
```

---

## Task 2: Create provider

**File:** `lib/features/medicine/presentation/providers/per_medicine_provider.dart`

Query `medicine_doses` for the selected period, group by medicine,
calculate adherence per group.

---

## Task 3: Add to Medicine stats screen

**File:** `lib/features/medicine/presentation/screens/medicine_stats_screen.dart`

Add "Adherence by Medicine" section below the main chart, sorted by
ascending adherence (worst first).

---

## Task 4: Handle PRN medicines

PRN (as-needed) medicines don't have scheduled adherence. Show them
separately with "As-needed" framing.

---

## Task 5: Add localization strings

```json
"adherenceByMedicineTitle": "Adherence by Medicine",
"adherenceByMedicineRate": "{name}: {percent}%",
"adherenceByMedicineSorted": "Sorted by adherence (lowest first)",
"adherenceByMedicinePrn": "As-needed"
```

---

## Performance considerations

- **Grouping:** O(n) over doses, n=total doses in period. Fast.
- **Minimum sample:** skip medicines with < 7 doses.

## Testing

- Unit test: per-medicine grouping and adherence calculation.
- Unit test: PRN medicine handling.
- Unit test: minimum sample enforcement.
- Widget test: adherence breakdown list sorted correctly.

## Localization

ARB keys listed in Task 5.
