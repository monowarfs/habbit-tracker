# Cross-Module Correlation Insight — Implementation Plan

**Spec:** [09-cross-module-correlation-insight-design.md](./09-cross-module-correlation-insight-design.md)
**Run:** TBD
**Estimated effort:** M (14 tasks, mostly small, one M-sized pure use case)
**Estimated duration:** 1–2 focused sessions
**Dependencies:** Reports module's existing `day_status_streaks` and `aggregate_report_usecase` day-level data; at least 2 active modules with history

## Pre-requisites

- Flutter SDK `^3.12.2` installed and `flutter pub get` working
- Reports module fully functional with `dayStatus(range)` working for all modules
- `HabitModule` contract supporting `dayStatus(range)` for Water, Medicine, Prayer
- `localDayKey()` and `DateRange` utilities available from `core/utils/`
- Drift database at schema version 7 (this spec bumps to 8 — coordinate with spec 08 if also bumping)
- `module_registry.dart` providing `habitModulesProvider`
- `core/insights/` directory created (or will be created as part of this spec)

## Tasks

### Task 1: Create `CorrelationInsight` freezed entity
**Effort:** S
**Files to create:** `lib/core/insights/domain/entities/correlation_insight.dart`
**Description:** Freezed entity with fields: `moduleA` (first module id, alphabetically sorted), `moduleB`, `pattern` (InsightPattern enum: positiveCorrelation/negativeCorrelation), `strength` (0.0–1.0), `description` (plain-language sentence), `sampleDays`, `isDismissed`. Include `InsightPattern` enum.
**Acceptance criteria:** Freezed codegen succeeds; all fields compile.
**Test:** N/A (data class — tested via use case tests)

### Task 2: Create `DismissedInsightsTable` Drift table
**Effort:** S
**Files to create:** `lib/core/database/tables/dismissed_insights_table.dart`
**Description:** Lightweight table for persisting dismissed insights: `modulePairKey` (TEXT, PK — sorted module ids joined with '+', e.g. 'medicine+prayer'), `dismissedAt` (INTEGER — UTC epoch millis).
**Acceptance criteria:** Table definition compiles; `@DataClassName('DismissedInsightRow')` generated.
**Test:** N/A (schema definition — verified via repository tests)

### Task 3: Register table in `AppDatabase`, bump schema
**Effort:** S
**Files to modify:** `lib/core/database/app_database.dart`
**Description:** Import `DismissedInsightsTable`, add to `@DriftDatabase(tables: [...])`. Bump `schemaVersion` from 7 to 8 (or 9 if spec 08 already took 8). Add migration: `if (from < 8) { await m.createTable(dismissedInsightsTable); }`.
**Acceptance criteria:** `build_runner build` succeeds; schema version correct; migration creates the table on upgrade.
**Test:** `dart run build_runner build --delete-conflicting-outputs` succeeds without errors.

### Task 4: Create `DismissedInsightsRepository`
**Effort:** S
**Files to create:** `lib/core/insights/data/dismissed_insights_repository.dart`
**Description:** CRUD over `dismissed_insights` table:
- `allDismissedKeys()` → `Future<Set<String>>`
- `dismiss(modulePairKey)` → `Future<void>`
- `restore(modulePairKey)` → `Future<void>`
**Acceptance criteria:** All CRUD operations work; `allDismissedKeys` returns correct set; `dismiss` and `restore` toggle correctly.
**Test:** `test/core/insights/data/dismissed_insights_repository_test.dart` — CRUD operations with Drift test DB.

### Task 5: Create `DetectCorrelationInsightsUseCase` (pure, heavily tested)
**Effort:** M
**Files to create:** `lib/core/insights/domain/usecases/detect_correlation_insights_usecase.dart`
**Description:** Pure use case computing co-occurrence patterns between module pairs over a rolling window of day statuses:
- Parameters: `minSampleDays` (default 14), `minStrength` (default 0.3), `maxInsights` (default 3), `lookbackDays` (default 90)
- Input: `dayStatuses` (Map of moduleId → Map of LocalDate → ModuleDayStatus), `dismissedPairs` (Set of String)
- Algorithm per module pair (A, B):
  1. Find intersection of days where both modules have non-`none` data
  2. Convert to binary: 1 = completed, 0 = not completed
  3. Require `sampleDays >= minSampleDays`
  4. Skip if either module has zero variance (all complete or all missed)
  5. Compute Pearson r over binary vectors
  6. Interpret: `r > minStrength` → positiveCorrelation; `r < -minStrength` → negativeCorrelation; `|r| < minStrength` → skip
  7. Generate plain-language description with intensity word ("strongly" if `strength > 0.6`)
- Returns insights sorted by strength descending, capped at `maxInsights`, excluding dismissed pairs
**Acceptance criteria:** All algorithm cases correct; handles edge cases (insufficient data, zero variance, dismissed pairs); plain-language descriptions generated correctly.
**Test:** `test/core/insights/domain/usecases/detect_correlation_insights_usecase_test.dart` — strong negative correlation (both missed same 10/14 days), strong positive correlation (both completed same 12/14 days), random/no pattern → empty, only 1 module → empty, only 10 days shared → below minSampleDays, one module all complete → zero variance skipped, dismissed pair excluded, 3 modules → up to 3 insights capped, strength > 0.6 → "strongly" in description.

### Task 6: Create `DismissInsightUseCase`
**Effort:** S
**Files to create:** `lib/core/insights/domain/usecases/dismiss_insight_usecase.dart`
**Description:** Simple persistence use case: takes moduleA and moduleB, generates sorted pair key (`sorted[0]+sorted[1]`), calls `repository.dismiss(key)`.
**Acceptance criteria:** Correct key generation; dismiss calls repository.
**Test:** `test/core/insights/domain/usecases/dismiss_insight_usecase_test.dart` — correct key generation, dismiss/restore.

### Task 7: Create insight providers
**Effort:** M
**Files to create:**
- `lib/core/insights/presentation/providers/insights_providers.dart`
- `lib/core/insights/presentation/providers/insights_repository_providers.dart`
**Description:**
- `insights_repository_providers.dart`: `@riverpod(keepAlive: true)` provider for `DismissedInsightsRepository`
- `insights_providers.dart`: `@riverpod` `correlationInsights` provider that:
  1. Gets all modules from `habitModulesProvider`
  2. Returns empty if < 2 modules
  3. Collects `dayStatus(range)` for each module over 90-day window
  4. Filters modules with any non-`none` data
  5. Loads dismissed pairs from repository
  6. Calls `DetectCorrelationInsightsUseCase.execute()`
**Acceptance criteria:** Provider compiles; returns empty for < 2 modules; computes insights from real module data.
**Test:** N/A (provider wiring — tested via integration)

### Task 8: Create `CorrelationInsightsSection` widget
**Effort:** M
**Files to create:** `lib/features/reports/presentation/widgets/correlation_insights_section.dart`
**Description:** `ConsumerWidget` showing up to 3 correlation insights at the bottom of the Reports screen:
- Section title: "Patterns You Might Notice"
- Each insight as `_InsightCard`: module icons, plain-language description, dismiss button (top-right)
- Empty state: `SizedBox.shrink()` (no section shown)
- Styling: `Card` with `tonalSurface` color, not alarming
- Dismiss button calls `DismissInsightUseCase`
**Acceptance criteria:** Shows insights when data exists; empty state hides section; dismiss button works and hides the card.
**Test:** `test/features/reports/presentation/widgets/correlation_insights_section_test.dart` — shows insights when data exists, empty state, dismiss button works.

### Task 9: Wire insights section into Reports screen
**Effort:** S
**Files to modify:** `lib/features/reports/presentation/screens/reports_screen.dart`
**Description:** Add `_CorrelationInsightsSection(modules: modules)` in the `ListView` below existing module report cards, separated by `SizedBox(height: 16)`.
**Acceptance criteria:** Insights section appears below module cards; no regression in existing report UI.
**Test:** N/A (integration — manual verification)

### Task 10: Add L10n strings (en/bn)
**Effort:** S
**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`
**Description:** Add insight-related localization keys (see Localization Keys section below). Run `flutter gen-l10n` after adding.
**Acceptance criteria:** All new keys present in both ARB files; `flutter gen-l10n` generates without errors.
**Test:** N/A (localization only)

### Task 11: Write unit tests for `DetectCorrelationInsightsUseCase`
**Effort:** M
**Files to create:** `test/core/insights/domain/usecases/detect_correlation_insights_usecase_test.dart`
**Description:** Test all algorithm cases with synthetic `Map<LocalDate, ModuleDayStatus>` data (no DB or module mocks needed — pure computation):
- Strong negative correlation: both missed on same 10/14 days
- Strong positive correlation: both completed on same 12/14 days
- Random/no pattern: returns empty (below threshold)
- Only 1 module: returns empty
- Only 10 days shared: below minSampleDays, returns empty
- One module all complete, other mixed: zero variance, skipped
- Dismissed pair: excluded from results
- Three modules: up to 3 insights (one per pair), capped at maxInsights
- Strength > 0.6: "strongly" in description; 0.3–0.6: without "strongly"
**Acceptance criteria:** All test cases pass; edge cases covered.
**Test:** `test/core/insights/domain/usecases/detect_correlation_insights_usecase_test.dart`

### Task 12: Write unit tests for dismiss flow
**Effort:** S
**Files to create:** `test/core/insights/domain/usecases/dismiss_insight_usecase_test.dart`
**Description:** Test `DismissInsightUseCase`: correct sorted pair key generation for various module id combinations, dismiss calls repository, restore calls repository.
**Acceptance criteria:** All test cases pass.
**Test:** `test/core/insights/domain/usecases/dismiss_insight_usecase_test.dart`

### Task 13: Write widget tests for insights section
**Effort:** S
**Files to create:** `test/features/reports/presentation/widgets/correlation_insights_section_test.dart`
**Description:** Test `CorrelationInsightsSection`: shows insights when data exists, empty state returns `SizedBox.shrink()`, dismiss button triggers callback and hides card.
**Acceptance criteria:** Widget renders correctly in all states.
**Test:** `test/features/reports/presentation/widgets/correlation_insights_section_test.dart`

### Task 14: Run `build_runner build`, verify no analysis errors
**Effort:** S
**Files to modify:** (none — verification step)
**Description:** Run `dart run build_runner build --delete-conflicting-outputs` to generate all `*.g.dart` files. Run `flutter analyze` to verify no lint or analysis errors. Run `dart format --output=none --set-exit-if-changed .` to verify formatting.
**Acceptance criteria:** All generated files produced; zero analysis errors; formatting clean.
**Test:** `flutter analyze` passes; `dart format` clean.

## Schema Migration

**New table: `dismissed_insights`**

Migration in `app_database.dart`:
```dart
if (from < 8) {
  await m.createTable(dismissedInsightsTable);
}
```

Column definitions:
| Column | Type | Notes |
|--------|------|-------|
| `modulePairKey` | TEXT | Primary key. Sorted module ids joined with '+' (e.g. 'medicine+prayer') |
| `dismissedAt` | INTEGER | UTC epoch millis when dismissed |

**Note:** If spec 08 (Adaptive Quest Difficulty) also bumps to schema 8, coordinate — one spec takes 8, the other takes 9. Check spec 08's implementation before starting.

## Localization Keys

**English (`app_en.arb`):**
```json
"insightsTitle": "Patterns You Might Notice",
"insightDismissTooltip": "Dismiss this insight",
"insightNoData": "Not enough data yet for insights. Keep logging!",
"insightPositiveStrong": "Days you complete {moduleA}, you also strongly tend to complete {moduleB}.",
"insightPositiveWeak": "Days you complete {moduleA}, you also tend to complete {moduleB}.",
"insightNegativeStrong": "Days you miss {moduleA}, you also strongly tend to miss {moduleB}.",
"insightNegativeWeak": "Days you miss {moduleA}, you also tend to miss {moduleB}."
```

**Bangla (`app_bn.arb`):** Corresponding Bangla translations for all keys above.

## Risk Notes

1. **Schema version coordination:** This spec bumps `schemaVersion` to 8. If spec 08 (Adaptive Quest Difficulty) also adds a table, coordinate version numbers — one takes 8, the other takes 9. Check spec 08's implementation before starting.
2. **Minimum sample size:** 14 days is the default `minSampleDays`. With only 2 modules active for 2 weeks, correlations may be noisy. The threshold is tunable via constructor parameter.
3. **Spurious correlations:** With small sample sizes, random patterns can look like correlations. The `minStrength` threshold (0.3) and `minSampleDays` (14) are conservative defaults. Tune based on real usage.
4. **Module name mapping:** The `description` template uses module names (e.g. "Water", "Medicine"). These come from `HabitModule.name` or localized strings. Ensure consistent naming between the use case's plain-language output and the app's module display names.
5. **Dismissal persistence:** Dismissed insights stay hidden across sessions. If a user wants to "un-dismiss" an insight, there's no UI for that yet — the `restore()` method exists in the repository but is not wired to any widget. Consider adding this in a future run.
6. **Performance:** The correlation computation is O(n * m^2) where n is days and m is modules. With 90 days and 3 modules, this is negligible. No optimization needed.
7. **Positive vs negative framing:** The spec supports both positive and negative correlations. Negative correlations ("days you miss X, you also tend to miss Y") are more actionable but potentially discouraging. The plain-language templates use gentle wording ("tend to") rather than deterministic language.
