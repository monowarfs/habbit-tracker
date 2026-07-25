# Implementation Plan: Composite Daily "Consistency Score"

**Spec:** `05-consistency-score-design.md`
**Complexity:** M · **Estimated effort:** 2 days
**Depends on:** Each module's `dayStatus()` data

---

## Task 1: Create consistency score calculator

**File:** `lib/core/analytics/consistency_score_calculator.dart`

```dart
class ConsistencyScoreCalculator {
  /// Calculates a 0-100 composite score from per-module completion.
  static int calculate({
    required Map<String, ModuleDayStatus> moduleStatuses,
    Map<String, double> weights = const {},
  }) {
    if (moduleStatuses.isEmpty) return 0;

    final defaultWeights = {'water': 1.0, 'medicine': 1.5, 'prayer': 1.2};
    final w = weights.isEmpty ? defaultWeights : weights;

    double totalScore = 0;
    double totalWeight = 0;

    for (final entry in moduleStatuses.entries) {
      final moduleWeight = w[entry.key] ?? 1.0;
      final moduleScore = _scoreForStatus(entry.value.kind);
      totalScore += moduleScore * moduleWeight;
      totalWeight += moduleWeight;
    }

    return (totalScore / totalWeight * 100).round().clamp(0, 100);
  }

  static double _scoreForStatus(ModuleDayStatusKind kind) {
    switch (kind) {
      case ModuleDayStatusKind.complete: return 1.0;
      case ModuleDayStatusKind.partial: return 0.5;
      case ModuleDayStatusKind.missed: return 0.0;
      case ModuleDayStatusKind.none: return 0.0;
      case ModuleDayStatusKind.paused: return 0.0;
    }
  }
}
```

---

## Task 2: Create score provider

**File:** `lib/features/analytics/presentation/providers/consistency_provider.dart`

```dart
@riverpod
Future<int> consistencyScore(Ref ref) async {
  final modules = ref.watch(habitModulesProvider);
  final today = LocalDate.fromDateTime(clock.now());
  final range = DateRange(start: today, end: today);

  final moduleStatuses = <String, ModuleDayStatus>{};
  for (final module in modules) {
    final status = await module.dayStatus(range);
    if (status.containsKey(today)) {
      moduleStatuses[module.id] = status[today]!;
    }
  }

  return ConsistencyScoreCalculator.calculate(moduleStatuses: moduleStatuses);
}
```

---

## Task 3: Create score display widget

**File:** `lib/core/widgets/consistency_score_display.dart`

Shows:
- Score number (0-100) with color coding
- Breakdown per module
- Label ("Excellent!", "Good", "Keep going!")

---

## Task 4: Add to dashboard

**File:** `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

Add consistency score below the day-completion indicator.

---

## Task 5: Add localization strings

```json
"consistencyScoreTitle": "Consistency Score",
"consistencyScoreValue": "{score}/100",
"consistencyScoreExcellent": "Excellent!",
"consistencyScoreGood": "Good",
"consistencyScoreNeedsWork": "Keep going!"
```

---

## Performance considerations

- **Score calculation:** O(1) per module. Trivial.
- **Single-module:** show raw percentage, not composite.
- **Partial day:** show score with "(in progress)" indicator.

## Testing

- Unit test: scoring formula with various module combinations.
- Unit test: single-module degenerate case.
- Widget test: score display with color coding.

## Localization

ARB keys listed in Task 5.
