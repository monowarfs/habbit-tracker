# Implementation Plan: Goal-Attainment Rate Over Time

**Spec:** `09-goal-attainment-rate-design.md`
**Complexity:** S · **Estimated effort:** 0.5 day
**Depends on:** Water's `dayStatus()` with goal resolution

---

## Task 1: Create goal attainment calculator

**File:** `lib/core/analytics/goal_attainment_use_case.dart`

```dart
class GoalAttainmentUseCase {
  /// Counts days where goal was met vs. total active days.
  GoalAttainmentResult calculate({
    required Map<LocalDate, ModuleDayStatus> dayStatus,
  }) {
    final activeDays = dayStatus.values
        .where((s) => s.kind != ModuleDayStatusKind.none)
        .length;
    final metDays = dayStatus.values
        .where((s) => s.kind == ModuleDayStatusKind.complete)
        .length;

    return GoalAttainmentResult(
      metDays: metDays,
      totalDays: activeDays,
      rate: activeDays > 0 ? metDays / activeDays : 0,
    );
  }
}
```

---

## Task 2: Create provider

**File:** `lib/features/analytics/presentation/providers/goal_attainment_provider.dart`

Query `dayStatus()` for the selected period, calculate attainment rate.

---

## Task 3: Add to Water stats screen

**File:** `lib/features/water/presentation/screens/water_stats_screen.dart`

Add "Goal Attainment" section showing "X/Y days (Z%)".

---

## Task 4: Add localization strings

```json
"goalAttainmentTitle": "Goal Attainment",
"goalAttainmentRate": "{hit}/{total} days ({percent}%)",
"goalAttainmentEmpty": "No data for this period"
```

---

## Performance considerations

- **Calculation:** O(n) over dayStatus map. Fast.
- **No-data exclusion:** days with `kind == none` excluded from
  denominator.

## Testing

- Unit test: attainment count with various data patterns.
- Unit test: no-data day exclusion.
- Unit test: zero denominator handling.
- Widget test: attainment display.

## Localization

ARB keys listed in Task 4.
