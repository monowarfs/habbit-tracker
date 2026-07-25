# Implementation Plan: Comparison-to-Past-Self Chart

**Spec:** `06-comparison-to-past-self-design.md`
**Complexity:** M · **Estimated effort:** 1 day
**Depends on:** `period_bar_chart.dart`, 1 year of data

---

## Task 1: Extend `period_bar_chart.dart` for overlay series

**File:** `lib/core/widgets/charts/period_bar_chart.dart`

Add optional overlay parameter:

```dart
class PeriodBarChart extends StatelessWidget {
  final List<BarChartPoint> points;
  final List<BarChartPoint>? overlayPoints; // NEW
  final String? overlayLabel; // "Last year"
  // ...
}
```

Render overlay bars in a lighter/transparent color behind the main bars.

---

## Task 2: Create year-over-year data fetcher

**File:** `lib/core/analytics/year_comparison_use_case.dart`

```dart
class YearComparisonUseCase {
  /// Fetches current period and same period last year.
  Future<YearComparison> fetch({
    required HabitModule module,
    required LocalDate periodAnchor,
    required ReportPeriod period,
  }) async {
    final currentRange = _rangeForPeriod(period, periodAnchor);
    final lastYearRange = DateRange(
      start: currentRange.start.addDays(-365),
      end: currentRange.end.addDays(-365),
    );

    final current = await module.dayStatus(currentRange);
    final lastYear = await module.dayStatus(lastYearRange);

    return YearComparison(current: current, lastYear: lastYear);
  }
}
```

---

## Task 3: Create comparison screen

**File:** `lib/features/analytics/presentation/screens/year_comparison_screen.dart`

Shows chart with overlay and "vs. last year" label.

---

## Task 4: Handle leap year edge cases

When "this month" has 31 days but "last year this month" had 28,
clip the current month to 28 days for fair comparison.

---

## Task 5: Add eligibility check

Only show "vs. last year" option if the user has 1+ year of data.

---

## Task 6: Add localization strings

```json
"comparisonTitle": "vs. Last Year",
"comparisonCurrentLabel": "This {period}",
"comparisonPastLabel": "Last year",
"comparisonEmptyState": "Not enough history yet (need 1 year)"
```

---

## Performance considerations

- **Two date range queries:** each is O(n) over the range. Fast.
- **Caching:** cache both ranges for 5 minutes.

## Testing

- Unit test: date-range alignment with leap year edge cases.
- Unit test: partial-overlap comparison.
- Widget test: chart overlay rendering.
- Widget test: empty state for < 1 year of data.

## Localization

ARB keys listed in Task 6.
