# Implementation Plan: Trend Arrows vs. Previous Period

**Spec:** `04-trend-arrows-design.md`
**Complexity:** S · **Estimated effort:** 0.5 day
**Depends on:** Per-module aggregation use cases

---

## Task 1: Create trend arrow widget

**File:** `lib/core/widgets/trend_arrow.dart`

A reusable widget showing up/down/flat arrow with delta percentage:

```dart
class TrendArrow extends StatelessWidget {
  final double current;
  final double previous;
  final String? label;

  TrendDirection get direction {
    if (current > previous * 1.05) return TrendDirection.up;
    if (current < previous * 0.95) return TrendDirection.down;
    return TrendDirection.flat;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(direction.icon, color: direction.color),
        Text('${delta.abs().toStringAsFixed(0)}%'),
      ],
    );
  }
}

enum TrendDirection { up, down, flat }
```

---

## Task 2: Create trend calculation helper

**File:** `lib/core/analytics/trend_calculator.dart`

```dart
class TrendCalculator {
  /// Calculates percentage change from [previous] to [current].
  /// Returns null if previous is zero.
  static double? calculateDelta(double current, double previous) {
    if (previous == 0) return null;
    return ((current - previous) / previous) * 100;
  }
}
```

---

## Task 3: Wire to stats screens

**Files:** Per-module stats screens

Add trend arrow next to headline numbers:
```dart
TrendArrow(
  current: thisWeekValue,
  previous: lastWeekValue,
  label: 'vs last week',
)
```

---

## Task 4: Add localization strings

```json
"trendArrowUp": "Improving",
"trendArrowDown": "Declining",
"trendArrowFlat": "Stable",
"trendArrowVsPrevious": "vs. previous {period}"
```

---

## Performance considerations

- **Trend calculation:** O(1) — two numbers compared.
- **Previous period fetch:** call aggregation use case twice (current +
  previous). Two cheap DB queries.

## Testing

- Unit test: trend calculation (up/down/flat/partial).
- Unit test: zero-to-nonzero edge case.
- Widget test: arrow display with various states.

## Localization

ARB keys listed in Task 4.
