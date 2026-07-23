# Cross-Module Correlation Insight

**Category:** AI-Powered · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Each module today reports on itself in isolation — Water's stats screen
shows Water history, Prayer's shows Prayer history — but a user managing
several habits at once likely has real behavioral correlations between
them (missing Asr correlating with also missing an evening water goal,
for instance) that no screen currently surfaces. Apple Health's trends
feature demonstrates the value of exactly this kind of cross-signal
observation for user self-awareness, without needing to explain *why*
the correlation exists — just surfacing "here's a pattern" is often
enough for a user to notice something they hadn't consciously connected.

## Goals
- Detect statistically notable co-occurrence patterns between two
  modules' day-level completion status (e.g. missed-day correlations)
  using the Reports module's existing aggregated day-status data.
- Surface a small number of plain-language observations ("Days you miss
  X, you also tend to miss Y") rather than a raw correlation coefficient.
- Keep the framing strictly observational, never diagnostic or
  prescriptive — a locally-computed note, not a claim about causation.

## Non-goals / out of scope
- No causal inference, no machine learning, no statistical modeling
  beyond a straightforward co-occurrence/correlation calculation over
  day-level pass/fail data already produced by the Reports module.
- Not a general-purpose analytics dashboard — a small, bounded number of
  the most notable patterns, not an exhaustive matrix of every
  module-pair combination.
- Does not send any data anywhere — entirely computed and displayed
  on-device, consistent with every other item in this category except
  the one cloud item.

## Proposed approach (high-level)
Pure local statistics on top of data the Reports module already
aggregates: `aggregate_report_usecase`'s day-completion-streaks output
(and the underlying `day_status_streaks` per-module day status) gives a
pass/fail signal per module per day. For each pair of enabled modules,
compute a simple co-occurrence measure over a rolling window (e.g. how
often a "missed" day in module A coincides with a "missed" day in module
B, compared to how often B is missed on days A is completed) and, when
the difference is large enough to be worth mentioning, generate a
plain-language sentence describing it. This becomes a new, small
insights section on the existing Reports screen, reusing its existing
week/month/year aggregation machinery rather than introducing a
parallel data pipeline.

## Dependencies & prerequisites
- The Reports module's existing `day_status_streaks` and
  `aggregate_report_usecase` day-level data.
- Enough days of history across at least two active modules before any
  correlation is statistically meaningful — a fresh install or single-
  module user has nothing to correlate.
- Copy/tone guidance so generated sentences read as gentle observations,
  not clinical or alarming statements.

## Open questions for the implementation round
- What's the minimum sample size (days) and correlation-strength
  threshold before a pattern is surfaced, to avoid noisy/spurious
  correlations from short histories?
- How many patterns get shown at once — just the single strongest one,
  or a short ranked list?
- Does this only compare "missed" days, or also positive correlations
  (completing both consistently), and does that framing add or dilute
  the insight's usefulness?
- Should a user be able to dismiss/mute a specific insight they don't
  find useful, similar to how other dismissible UI elements work
  elsewhere in the app?

## Effort & sequencing notes
Complexity M — the correlation arithmetic itself is simple, but
generating trustworthy, non-spurious, plain-language observations from
noisy real-world data (especially with limited history) is the harder
design problem. Natural to sequence after the Reports module has
accumulated real usage data to validate against.

---

## Implementation Plan (Low-Level)

### 1. Schema changes

**None.** This feature is entirely computed from existing data. The
`dayStatus(range)` method on each `HabitModule` already provides the
per-day, per-module pass/fail signal. No new tables, no new columns.

### 2. Domain entities

#### `CorrelationInsight`

**File to create:** `lib/core/insights/domain/entities/correlation_insight.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'correlation_insight.freezed.dart';

/// A plain-language observation about co-occurrence between two modules.
@freezed
class CorrelationInsight with _$CorrelationInsight {
  const factory CorrelationInsight({
    required String moduleA,         // first module id (alphabetically sorted)
    required String moduleB,         // second module id
    required InsightPattern pattern, // positive or negative correlation
    required double strength,        // 0.0–1.0, strength of association
    required String description,     // plain-language sentence
    required int sampleDays,         // how many days of data were used
    required bool isDismissed,       // user dismissed this insight
  }) = _CorrelationInsight;
}

/// Whether modules tend to succeed together or fail together.
enum InsightPattern {
  /// When module A is missed, module B is also more likely to be missed.
  negativeCorrelation,

  /// When module A is completed, module B is also more likely to be completed.
  positiveCorrelation,
}
```

#### `DismissedInsight` (for persistence)

**File to create:** `lib/core/insights/domain/entities/dismissed_insight.dart`

```dart
/// Tracks which insight pairs the user has dismissed, keyed by
/// sorted module-pair. Persisted so dismissed insights stay hidden
/// across sessions.
@freezed
class DismissedInsight with _$DismissedInsight {
  const factory DismissedInsight({
    required String modulePairKey,  // e.g. "medicine+prayer"
    required DateTime dismissedAt,
  }) = _DismissedInsight;
}
```

### 3. Schema addition (dismissible state)

To persist dismissed insights across sessions, add a lightweight core
table.

**File to create:** `lib/core/database/tables/dismissed_insights_table.dart`

```dart
import 'package:drift/drift.dart';

@DataClassName('DismissedInsightRow')
class DismissedInsightsTable extends Table {
  @override
  String get tableName => 'dismissed_insights';

  /// Composite key: sorted module ids joined with '+' (e.g. 'medicine+prayer').
  TextColumn get modulePairKey => text()();

  /// UTC epoch millis when dismissed.
  IntColumn get dismissedAt => integer()();

  @override
  Set<Column> get primaryKey => {modulePairKey};
}
```

**File to modify:** `lib/core/database/app_database.dart`

Add import + table to `@DriftDatabase(tables: [...])`:
```dart
import 'package:habit_tracker/core/database/tables/dismissed_insights_table.dart';
// ...
tables: [
  // ... existing tables ...
  DismissedInsightsTable,  // ← new
],
```

Bump `schemaVersion` from 7 to 8 and add migration:
```dart
if (from < 8) {
  await m.createTable(dismissedInsightsTable);
}
```

(If spec 08 also bumps to 8, coordinate — one spec takes 8, the other 9.)

### 4. Use cases

#### `DetectCorrelationInsightsUseCase` (pure)

**File to create:** `lib/core/insights/domain/usecases/detect_correlation_insights_usecase.dart`

```dart
/// Pure use case: computes co-occurrence patterns between module pairs
/// over a rolling window of day statuses.
class DetectCorrelationInsightsUseCase {
  const DetectCorrelationInsightsUseCase({
    this.minSampleDays = 14,     // minimum days of shared history
    this.minStrength = 0.3,      // minimum correlation strength to surface
    this.maxInsights = 3,        // cap on displayed insights
    this.lookbackDays = 90,      // rolling window for computation
  });

  final int minSampleDays;
  final double minStrength;
  final int maxInsights;
  final int lookbackDays;

  /// Detects notable correlations from [dayStatuses].
  ///
  /// [dayStatuses] is a map of moduleId → (LocalDate → ModuleDayStatus),
  /// one entry per active module (only modules with data are included).
  ///
  /// Returns insights sorted by strength descending, capped at [maxInsights],
  /// excluding dismissed pairs ([dismissedPairs]).
  List<CorrelationInsight> execute({
    required Map<String, Map<LocalDate, ModuleDayStatus>> dayStatuses,
    required Set<String> dismissedPairs,
  }) { ... }
}
```

**Algorithm (Pearson co-occurrence over binary day-status):**

For each pair of modules (A, B):
1. Find the intersection of days where both modules have non-`none` data.
2. Convert each day to binary: 1 = completed, 0 = not completed (partial or missed).
3. Require `sampleDays >= minSampleDays`.
4. Compute correlation coefficient:
   ```
   If either module has zero variance (all complete or all missed) → skip.
   Otherwise: Pearson r over binary vectors.
   ```
5. Interpret:
   - `r > minStrength` → `positiveCorrelation` ("Days you complete X, you also tend to complete Y")
   - `r < -minStrength` → `negativeCorrelation` ("Days you miss X, you also tend to miss Y")
   - `|r| < minStrength` → skip (not noteworthy)
6. Generate plain-language `description` string from template.

**Plain-language templates:**

```dart
String _generateDescription({
  required String moduleAName,
  required String moduleBName,
  required InsightPattern pattern,
  required double strength,
}) {
  final intensity = strength > 0.6 ? 'strongly' : '';
  return switch (pattern) {
    InsightPattern.positiveCorrelation =>
      'Days you complete $moduleAName, you also tend to '
      '${intensity} complete $moduleBName.',
    InsightPattern.negativeCorrelation =>
      'Days you miss $moduleAName, you also tend to '
      '${intensity} miss $moduleBName.',
  };
}
```

#### `DismissInsightUseCase` (simple persistence)

**File to create:** `lib/core/insights/domain/usecases/dismiss_insight_usecase.dart`

```dart
/// Persists a user's dismissal of a specific insight pair.
class DismissInsightUseCase {
  const DismissInsightUseCase({required this.repository});
  final DismissedInsightsRepository repository;

  Future<void> execute({
    required String moduleA,
    required String moduleB,
  }) {
    final key = _sortedPairKey(moduleA, moduleB);
    return repository.dismiss(key);
  }

  String _sortedPairKey(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}+${sorted[1]}';
  }
}
```

### 5. Data layer

#### Repository

**File to create:** `lib/core/insights/data/dismissed_insights_repository.dart`

```dart
/// CRUD over the `dismissed_insights` table.
class DismissedInsightsRepository {
  DismissedInsightsRepository(this._db);
  final AppDatabase _db;

  /// All dismissed module-pair keys.
  Future<Set<String>> allDismissedKeys() async { ... }

  /// Mark [modulePairKey] as dismissed.
  Future<void> dismiss(String modulePairKey) async { ... }

  /// Un-dismiss (restore) a previously dismissed pair.
  Future<void> restore(String modulePairKey) async { ... }
}
```

### 6. Integration: Reports screen

**File to modify:** `lib/features/reports/presentation/screens/reports_screen.dart`

Add a new section below the module cards in the `ListView`:

```dart
// After the existing module report cards:
const SizedBox(height: 16),
_CorrelationInsightsSection(modules: modules),
```

#### `_CorrelationInsightsSection` widget

**File to create:** `lib/features/reports/presentation/widgets/correlation_insights_section.dart`

```dart
/// Shows up to 3 correlation insights at the bottom of the Reports screen.
class CorrelationInsightsSection extends ConsumerWidget {
  const CorrelationInsightsSection({required this.modules});
  final List<HabitModule> modules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(correlationInsightsProvider);
    return insightsAsync.when(
      data: (insights) {
        if (insights.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                AppLocalizations.of(context)!.insightsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            for (final insight in insights)
              _InsightCard(insight: insight, onDismiss: () { ... }),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
```

#### `_InsightCard` widget

Each card shows:
- Module icons for the two modules involved
- The plain-language `description` string
- A small "dismiss" (close) button in the top-right corner
- Subtle styling — `Card` with `tonalSurface` color, not alarming

### 7. Presentation providers

**File to create:** `lib/core/insights/presentation/providers/insights_providers.dart`

```dart
/// Computes correlation insights from all modules' day statuses.
@riverpod
Future<List<CorrelationInsight>> correlationInsights(Ref ref) async {
  final modules = ref.watch(habitModulesProvider);
  if (modules.length < 2) return []; // need at least 2 modules

  final today = localDayKey(clock.now());
  final lookback = today.addDays(-90); // 90-day window

  // Collect day statuses for all modules
  final dayStatuses = <String, Map<LocalDate, ModuleDayStatus>>{};
  for (final module in modules) {
    final status = await module.dayStatus(
      DateRange(start: lookback, end: today),
    );
    if (status.values.any((s) => s.kind != ModuleDayStatusKind.none)) {
      dayStatuses[module.id] = status;
    }
  }

  // Load dismissed pairs
  final dismissedRepo = ref.watch(dismissedInsightsRepositoryProvider);
  final dismissedPairs = await dismissedRepo.allDismissedKeys();

  return const DetectCorrelationInsightsUseCase().execute(
    dayStatuses: dayStatuses,
    dismissedPairs: dismissedPairs,
  );
}
```

**File to create:** `lib/core/insights/presentation/providers/insights_repository_providers.dart`

```dart
@riverpod(keepAlive: true)
DismissedInsightsRepository dismissedInsightsRepository(Ref ref) {
  return DismissedInsightsRepository(ref.watch(databaseProvider));
}
```

### 8. L10n strings

**Files to modify:** `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`

New keys:
```json
"insightsTitle": "Patterns You Might Notice",
"insightDismissTooltip": "Dismiss this insight",
"insightNoData": "Not enough data yet for insights. Keep logging!",
"insightPositiveStrong": "Days you complete {moduleA}, you also strongly tend to complete {moduleB}.",
"insightPositiveWeak": "Days you complete {moduleA}, you also tend to complete {moduleB}.",
"insightNegativeStrong": "Days you miss {moduleA}, you also strongly tend to miss {moduleB}.",
"insightNegativeWeak": "Days you miss {moduleA}, you also tend to miss {moduleB}."
```

### 9. Testing strategy

| Test file | What it covers | Type |
|-----------|---------------|------|
| `test/core/insights/domain/usecases/detect_correlation_insights_usecase_test.dart` | All algorithm cases (see below) | Unit |
| `test/core/insights/domain/usecases/dismiss_insight_usecase_test.dart` | Correct key generation, dismiss/restore | Unit |
| `test/core/insights/data/dismissed_insights_repository_test.dart` | CRUD operations on dismissed_insights table | Unit (Drift test DB) |
| `test/features/reports/presentation/widgets/correlation_insights_section_test.dart` | Shows insights when data exists, empty state, dismiss button works | Widget |

**Key test cases for `DetectCorrelationInsightsUseCase`:**
- Two modules, both missed on same 10 days out of 14 → strong negative correlation
- Two modules, both completed on same 12 days out of 14 → strong positive correlation
- Two modules, random/no pattern → no insight returned (below threshold)
- Only 1 module → empty list
- Only 10 days of shared data → below `minSampleDays`, empty list
- One module all complete, other mixed → zero variance, skipped
- Dismissed pair → excluded from results
- Three modules → up to 3 insights (one per pair), capped at `maxInsights`
- `strength > 0.6` → "strongly" in description; `0.3–0.6` → without "strongly"

**Test data pattern:** Create synthetic `Map<LocalDate, ModuleDayStatus>`
maps in tests — no need to touch real DB or modules. All computation is
pure.

### 10. Complete file list

**Files to create (7):**
- `lib/core/insights/domain/entities/correlation_insight.dart`
- `lib/core/insights/domain/entities/dismissed_insight.dart`
- `lib/core/insights/domain/usecases/detect_correlation_insights_usecase.dart`
- `lib/core/insights/domain/usecases/dismiss_insight_usecase.dart`
- `lib/core/insights/data/dismissed_insights_repository.dart`
- `lib/core/insights/presentation/providers/insights_providers.dart`
- `lib/core/insights/presentation/providers/insights_repository_providers.dart`
- `lib/features/reports/presentation/widgets/correlation_insights_section.dart`
- `lib/core/database/tables/dismissed_insights_table.dart`

**Files to modify (5):**
- `lib/core/database/app_database.dart` — add `DismissedInsightsTable`, bump schema
- `lib/features/reports/presentation/screens/reports_screen.dart` — add insights section below cards
- `lib/core/l10n/app_en.arb` — add insight strings
- `lib/core/l10n/app_bn.arb` — add Bangla insight strings

**Test files to create (4):**
- `test/core/insights/domain/usecases/detect_correlation_insights_usecase_test.dart`
- `test/core/insights/domain/usecases/dismiss_insight_usecase_test.dart`
- `test/core/insights/data/dismissed_insights_repository_test.dart`
- `test/features/reports/presentation/widgets/correlation_insights_section_test.dart`

### 11. Sequencing and effort estimates

| # | Task | Depends on | Effort |
|---|------|-----------|--------|
| 1 | Create `CorrelationInsight` freezed entity | — | S |
| 2 | Create `DismissedInsightsTable` Drift table | — | S |
| 3 | Register table in `AppDatabase`, bump schema | 2 | S |
| 4 | Create `DismissedInsightsRepository` | 2, 3 | S |
| 5 | Create `DetectCorrelationInsightsUseCase` (pure, heavily tested) | 1 | M |
| 6 | Create `DismissInsightUseCase` | 4 | S |
| 7 | Create insight providers (`insights_providers.dart`) | 4, 5 | M |
| 8 | Create `CorrelationInsightsSection` widget | 1, 7 | M |
| 9 | Wire insights section into Reports screen | 8 | S |
| 10 | Add L10n strings (en/bn) | — | S |
| 11 | Write unit tests for `DetectCorrelationInsightsUseCase` | 5 | M |
| 12 | Write unit tests for dismiss flow | 6 | S |
| 13 | Write widget tests for insights section | 8 | S |
| 14 | Run `build_runner build`, verify no analysis errors | all | S |

**Total effort: M** (14 tasks, mostly small, one M-sized pure use case)
**Estimated duration: 1–2 focused sessions**
