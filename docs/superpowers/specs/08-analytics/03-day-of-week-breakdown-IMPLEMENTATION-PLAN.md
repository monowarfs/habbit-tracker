# Implementation Plan: Best/Worst Day-of-Week Breakdown

**Spec:** `03-day-of-week-breakdown-design.md`
**Complexity:** S · **Estimated effort:** 0.5 day
**Depends on:** Reports module, `dayStatus(DateRange)` per module

---

## Task 1: Create weekday aggregation use case

**File:** `lib/core/analytics/weekday_breakdown_use_case.dart`

```dart
class WeekdayBreakdownUseCase {
  /// Groups day-status data by weekday and calculates completion %.
  List<WeekdayStats> compute({
    required Map<LocalDate, ModuleDayStatus> dayStatus,
  }) {
    final buckets = List.filled(7, _Bucket()); // Mon-Sun
    for (final entry in dayStatus.entries) {
      final weekday = entry.key.toDateTimeUtc().weekday - 1; // 0=Mon
      buckets[weekday].total++;
      if (entry.value.kind == ModuleDayStatusKind.complete) {
        buckets[weekday].completed++;
      }
    }
    return buckets.asMap().entries.map((e) => WeekdayStats(
      weekday: e.key,
      completionRate: e.value.total > 0
          ? e.value.completed / e.value.total
          : null,
    )).toList();
  }
}
```

---

## Task 2: Create weekday breakdown widget

**File:** `lib/core/widgets/weekday_breakdown_chart.dart`

A horizontal bar chart showing completion rate per weekday:
- Mon through Sun bars
- Color-coded (green for high, yellow for medium, red for low)
- "Best day" and "Worst day" labels

---

## Task 3: Create provider

**File:** `lib/features/analytics/presentation/providers/weekday_provider.dart`

```dart
@riverpod
Future<List<WeekdayStats>> weekdayBreakdown(
  Ref ref, {
  required String moduleId,
  required int daysBack,
}) async {
  final modules = ref.watch(habitModulesProvider);
  final module = modules.firstWhere((m) => m.id == moduleId);
  final now = LocalDate.fromDateTime(clock.now());
  final range = DateRange(
    start: now.addDays(-daysBack),
    end: now,
  );
  final dayStatus = await module.dayStatus(range);
  return WeekdayBreakdownUseCase().compute(dayStatus: dayStatus);
}
```

---

## Task 4: Add to stats screens

**Files:** Per-module stats screens

Add "Best/Worst Day" section below the main chart.

---

## Task 5: Add localization strings

```json
"dayOfWeekBest": "Best day: {day}",
"dayOfWeekWorst": "Worst day: {day}",
"dayOfWeekMon": "Monday",
"dayOfWeekSun": "Sunday",
"dayOfWeekInsufficientData": "Not enough data yet"
```

---

## Performance considerations

- **Aggregation:** O(n) over dayStatus map, n=daysBack. Fast.
- **Minimum sample:** require 28 days before showing results.

## Testing

- Unit test: weekday grouping and percentage calculation.
- Unit test: minimum sample size enforcement.
- Widget test: breakdown chart renders correctly.

## Localization

ARB keys listed in Task 5.
