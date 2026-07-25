# Implementation Plan: GitHub-Style Adherence Heatmap

**Spec:** `01-adherence-heatmap-design.md`
**Complexity:** M · **Estimated effort:** 2 days
**Depends on:** Reports module, `dayStatus(DateRange)` per module

---

## Task 1: Create heatmap grid widget

**File:** `lib/core/widgets/heatmap_grid.dart`

A GitHub-contribution-style grid:
- 52 columns (weeks) × 7 rows (weekdays)
- Each cell colored by completion status
- Scrollable horizontally for year view

```dart
class HeatmapGrid extends StatelessWidget {
  final Map<LocalDate, ModuleDayStatus> dayStatus;
  final int year;
  final Color Function(ModuleDayStatusKind) colorForStatus;

  @override
  Widget build(BuildContext context) {
    // Build 52×7 grid
    // Color cells by status
    // Show tooltip on tap
  }
}
```

---

## Task 2: Create color mapping

**File:** `lib/core/widgets/heatmap_color_scheme.dart`

```dart
class HeatmapColorScheme {
  static Color colorForStatus(ModuleDayStatusKind kind) {
    switch (kind) {
      case ModuleDayStatusKind.complete: return Colors.green;
      case ModuleDayStatusKind.partial: return Colors.yellow;
      case ModuleDayStatusKind.missed: return Colors.red;
      case ModuleDayStatusKind.none: return Colors.grey.shade200;
      case ModuleDayStatusKind.paused: return Colors.blue;
    }
  }
}
```

---

## Task 3: Create tooltip widget

**File:** `lib/core/widgets/heatmap_tooltip.dart`

Shows date and status on cell tap:
```dart
"25 Jul 2026 — Completed"
"24 Jul 2026 — Partially completed"
```

---

## Task 4: Create heatmap provider

**File:** `lib/features/analytics/presentation/providers/heatmap_provider.dart`

```dart
@riverpod
Future<Map<LocalDate, ModuleDayStatus>> heatmapData(
  Ref ref, {
  required String moduleId,
  required int year,
}) async {
  final modules = ref.watch(habitModulesProvider);
  final module = modules.firstWhere((m) => m.id == moduleId);
  final range = DateRange(
    start: LocalDate(year, 1, 1),
    end: LocalDate(year, 12, 31),
  );
  return module.dayStatus(range);
}
```

---

## Task 5: Create heatmap screen

**File:** `lib/features/analytics/presentation/screens/heatmap_screen.dart`

Shows per-module heatmaps with year selector:
```dart
class HeatmapScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.heatmapTitle)),
      body: Column(
        children: [
          // Year selector
          // Per-module heatmaps
          // Legend
        ],
      ),
    );
  }
}
```

---

## Task 6: Add entry point

**File:** `lib/features/reports/presentation/screens/reports_screen.dart`

Add "Year at a Glance" button navigating to the heatmap screen.

---

## Task 7: Add localization strings

```json
"heatmapTitle": "Year at a Glance",
"heatmapTooltipDone": "Completed",
"heatmapTooltipPartial": "Partially completed",
"heatmapTooltipMissed": "Missed",
"heatmapTooltipNone": "No data"
```

---

## Performance considerations

- **365 cells:** trivial rendering cost. No virtualization needed.
- **dayStatus call:** O(n) over the date range, n=365. Fast.
- **Caching:** cache the dayStatus result for 5 minutes to avoid
  re-querying when switching modules.

## Testing

- `test/core/widgets/heatmap_grid_test.dart` — widget test for grid
  rendering with mock data.
- Unit test: color mapping for each status kind.
- Golden test: heatmap visual output for regression.

## Localization

ARB keys listed in Task 7. Month/day labels are locale-aware.
