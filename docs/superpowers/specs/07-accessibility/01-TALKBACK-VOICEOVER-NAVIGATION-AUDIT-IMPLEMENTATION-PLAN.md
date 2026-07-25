# Implementation Plan: 01 TalkBack/VoiceOver Navigation Audit

## Overview

- **Spec:** Full TalkBack/VoiceOver Navigation Audit
- **Complexity:** M
- **Estimated effort:** 2 days
- **Dependencies:** All 5 modules must be feature-complete (they are). Should run before specs 02, 06, 10, and 12.
- **Prerequisites:** Physical device or emulator with TalkBack (Android) and VoiceOver (iOS) enabled.

---

## Implementation Tasks

### Task 1: Create semantic-label helper and conventions

**Files to create/modify:**
- `lib/core/accessibility/semantic_labels.dart` (new)
- `lib/core/l10n/app_en.arb` (modify)
- `lib/core/l10n/app_bn.arb` (modify)

**Detailed changes:**
- Create `lib/core/accessibility/semantic_labels.dart` with a centralized helper class `SemanticLabels` that provides methods to build localized `Semantics` wrappers using `AppLocalizations.of(context)`. This avoids scattering `Semantics(label: ...)` with raw strings across the codebase.
- Add initial ARB keys (see Localization section below) to both `app_en.arb` and `app_bn.arb`.

**Integration:** This helper is consumed by all subsequent tasks that add semantic labels. It lives in `lib/core/accessibility/` alongside any future accessibility utilities.

### Task 2: Dashboard semantic labels

**Files to create/modify:**
- `lib/features/dashboard/presentation/dashboard_screen.dart` (modify)

**Detailed changes:**
- Wrap the day-completion indicator `IconButton` with `Semantics(label: AppLocalizations.of(context).semanticDayCompletionIndicator)`.
- Wrap the upcoming strip section in a `Semantics` widget with a descriptive label.
- Wrap the quick-actions section with `Semantics(label: AppLocalizations.of(context).semanticQuickActionsSection)`.
- Wrap the global month-calendar bottom-sheet trigger `IconButton` with `Semantics(label: AppLocalizations.of(context).semanticGlobalCalendarButton)`.
- Ensure the dashboard greeting text (`dashboardGreetingMorning`, etc.) already has implicit semantics from `Text` widget — verify no override is needed.

**Integration:** Uses existing `AppLocalizations` pattern. Each `Semantics` wrapper is a lightweight addition around existing widgets.

### Task 3: Water module semantic labels

**Files to create/modify:**
- `lib/features/water/presentation/water_home_screen.dart` (modify)
- `lib/features/water/presentation/water_stats_screen.dart` (modify)
- `lib/features/water/presentation/water_add_entry_screen.dart` (modify)
- `lib/features/water/presentation/water_settings_screen.dart` (modify)

**Detailed changes:**
- Wrap quick-add preset `ActionChip` widgets with `Semantics` labels (e.g. "Quick add 250 ml").
- Wrap the custom-add `IconButton` with `Semantics(label: AppLocalizations.of(context).semanticWaterQuickAddButton)`.
- Wrap the stats chart (`PeriodBarChart` instance) with `Semantics(label: AppLocalizations.of(context).semanticWaterStatsChart)` summarizing the chart data.
- Wrap the streak indicator card with `Semantics(label: ...)` including the streak count.
- Add `Semantics` labels to the stats/settings icon buttons in the app bar.

**Integration:** Follows existing Water module structure. `PeriodBarChart` wrapper is a single `Semantics` parent around the chart widget.

### Task 4: Medicine module semantic labels

**Files to create/modify:**
- `lib/features/medicine/presentation/medicine_home_screen.dart` (modify)
- `lib/features/medicine/presentation/medicine_stats_screen.dart` (modify)
- `lib/features/medicine/presentation/medicine_list_screen.dart` (modify)
- `lib/features/medicine/presentation/medicine_detail_screen.dart` (modify)

**Detailed changes:**
- Wrap the dose-timeline list items with `Semantics` labels including the medicine name and dose status (e.g. "Aspirin — Due").
- Wrap the "mark done" `IconButton` on each dose row with `Semantics(label: AppLocalizations.of(context).semanticMedicineDoseDoneButton)`.
- Wrap the stock indicator card with `Semantics(label: ...)` including remaining count.
- Wrap the medicine stats chart with a summary `Semantics` label.
- Add `Semantics` to the add-medicine FAB and all-icon-only app bar buttons.

**Integration:** Uses existing Medicine module data. Dose status strings already localized; semantic labels reference them.

### Task 5: Prayer module semantic labels

**Files to create/modify:**
- `lib/features/prayer/presentation/prayer_home_screen.dart` (modify)
- `lib/features/prayer/presentation/prayer_stats_screen.dart` (modify)
- `lib/features/prayer/presentation/prayer_qadha_screen.dart` (modify)
- `lib/features/prayer/presentation/prayer_settings_screen.dart` (modify)

**Detailed changes:**
- Wrap each prayer checklist toggle row with `Semantics` including the prayer name and current status (e.g. "Fajr — Due").
- Wrap the Qadha counter cards with `Semantics(label: AppLocalizations.of(context).semanticPrayerQadhaCounter)`.
- Wrap the prayer stats chart with a summary `Semantics` label.
- Add `Semantics` labels to the settings section headers and icon-only buttons.

**Integration:** Prayer status strings (`prayerStatusUpcoming`, `prayerStatusPrayed`, etc.) already exist in ARB files.

### Task 6: Settings module semantic labels

**Files to create/modify:**
- `lib/features/settings/presentation/settings_screen.dart` (modify)

**Detailed changes:**
- Wrap the theme toggle with `Semantics(label: AppLocalizations.of(context).semanticThemeToggle)`.
- Wrap the locale toggle with `Semantics(label: AppLocalizations.of(context).semanticLocaleToggle)`.
- Wrap the module toggle switches with `Semantics(label: ...)` including module name and state.
- Verify all `ListTile` widgets already announce their title/subtitle correctly via Flutter's default semantics (they do).

**Integration:** Minimal — most `ListTile` widgets already have implicit semantics. Only switches and icon buttons need explicit wrapping.

### Task 7: Verify live-region announcements

**Files to create/modify:**
- `lib/features/water/presentation/water_home_screen.dart` (modify — snackbar)
- `lib/features/medicine/presentation/medicine_home_screen.dart` (modify — snackbar)
- `lib/features/prayer/presentation/prayer_home_screen.dart` (modify — snackbar)

**Detailed changes:**
- After each success snackbar is shown (water log, dose marked done, prayer toggled), call `SemanticsService.announce(message, textDirection: TextDirection.ltr)` to push the confirmation to the screen reader.
- Import `package:flutter/semantics.dart` for `SemanticsService`.
- Place the `announce` call immediately after `ScaffoldMessenger.of(context).showSnackBar(...)`.

**Integration:** Uses Flutter's built-in `SemanticsService` — no dependency needed. Works on both Android and iOS.

### Task 8: Fix gesture-only controls

**Files to create/modify:**
- Any file with swipe-to-dismiss or gesture-only interaction (audit findings)

**Detailed changes:**
- For any `Dismissible` widget (e.g. swipe-to-delete on water entries or dose entries), add a `Semantics(label: AppLocalizations.of(context).semanticSwipeToDeleteHint)` with a hint describing the gesture.
- If an alternative button action exists (e.g. a delete icon button in a trailing position), verify it is reachable and labeled.

**Integration:** `Dismissible` already supports `Semantics` wrapping; this adds explicit labels.

### Task 9: Verify Bangla locale semantics

**Files to create/modify:**
- Run the same TalkBack/VoiceOver pass with the app set to Bangla locale.

**Detailed changes:**
- Confirm all new `Semantics` labels render in Bangla when `AppLocalizations.of(context)` resolves to bn.
- Check that the Bangla line-height adjustment (`app_theme.dart:142-148`) doesn't cause screen readers to misread line boundaries.
- Verify no English fallback text leaks into the semantic tree when bn locale is active.

**Integration:** No code changes expected — this is a verification pass.

### Task 10: Document findings

**Files to create/modify:**
- `docs/superpowers/specs/07-accessibility/01-audit-checklist.md` (new)

**Detailed changes:**
- Create a markdown checklist table with columns: Screen, Platform (TalkBack/VoiceOver), Label Present, Label Correct, Reading Order OK, Notes.
- Fill in one row per screen across all 5 modules.

**Integration:** Repository artifact for traceability.

---

## Performance Considerations

- **Caching strategy:** Semantic labels are resolved lazily via `AppLocalizations.of(context)`, which is already a `Localizations` lookup cached by the framework. No additional caching needed.
- **Lazy loading:** Semantic labels are string-only, no lazy loading required.
- **Memory efficiency:** `Semantics` widgets add a single node to the accessibility tree per widget — negligible memory overhead.

---

## Testing

- `test/features/dashboard/presentation/dashboard_semantics_test.dart` — verify dashboard has semantic labels on all interactive elements.
- `test/features/water/presentation/water_semantics_test.dart` — verify Water module screens have semantic labels.
- `test/features/medicine/presentation/medicine_semantics_test.dart` — verify Medicine module screens have semantic labels.
- `test/features/prayer/presentation/prayer_semantics_test.dart` — verify Prayer module screens have semantic labels.
- `test/features/settings/presentation/settings_semantics_test.dart` — verify Settings screen has semantic labels.
- `test/accessibility/semantics_coverage_test.dart` — enumerate all routes in `AppRoutes` and assert each has at least one `Semantics` node with a non-empty label.

---

## Localization

New ARB keys to add (both `app_en.arb` and `app_bn.arb`):

```
semanticDayCompletionIndicator
semanticUpcomingStrip
semanticQuickActionsSection
semanticGlobalCalendarButton
semanticWaterQuickAddButton
semanticWaterCustomLogButton
semanticWaterStatsChart
semanticWaterStreakIndicator
semanticMedicineDoseTimeline
semanticMedicineDoseDoneButton
semanticMedicineStockIndicator
semanticMedicineStatsChart
semanticPrayerChecklistToggle
semanticPrayerQadhaCounter
semanticPrayerStatsChart
semanticPrayerSettingsSection
semanticThemeToggle
semanticLocaleToggle
semanticSwipeToDeleteHint
```

---

## Edge Cases

1. **Icon-only buttons without visible text** — each `IconButton` must have a `Semantics` label or `tooltip`. Audit flags every instance.
2. **fl_chart custom painters** — `PeriodBarChart` returns an empty accessibility tree by default; wrapping in `Semantics` with a summary label is mandatory.
3. **Calendar day cells** — per-module history calendars and the dashboard month calendar need explicit `Semantics` for date + status per cell.
4. **Live-region announcements** — snackbar confirmations must use `SemanticsService.announce()`.
5. **Swipe/gesture controls** — `Dismissible` widgets need `Semantics` hint describing the gesture.
