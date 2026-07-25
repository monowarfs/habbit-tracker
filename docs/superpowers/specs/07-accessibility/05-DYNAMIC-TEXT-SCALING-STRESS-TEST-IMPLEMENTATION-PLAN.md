# Implementation Plan: 05 Dynamic Text Scaling Stress Test

## Overview

- **Spec:** Dynamic Text Scaling Stress Test
- **Complexity:** M
- **Estimated effort:** 1 day
- **Dependencies:** Should run after spec 01 (shares screen walkthrough). All module screens exist.
- **Prerequisites:** Simulator/emulator with OS text size set to 200%+.

---

## Implementation Tasks

### Task 1: Create shared text-scale test helper

**Files to create/modify:**
- `test/accessibility/text_scale_test_helper.dart` (new)

**Detailed changes:**
- Create a reusable test helper function `pumpAtTextScale(WidgetTester tester, Widget widget, double scale)` that:
  - Wraps the widget in `MediaQuery(textScaler: TextScaler.linear(scale))`.
  - Pumps the widget and asserts no `OverflowError` or `RenderFlex` overflow exception is thrown.
  - Uses `tester.pumpAndSettle()` to let animations settle.
- This helper is used by all per-module test files below.

**Integration:** Pure test utility, no production code.

### Task 2: Dashboard text-scale tests

**Files to create/modify:**
- `test/features/dashboard/presentation/dashboard_text_scale_test.dart` (new)

**Detailed changes:**
- Use the helper to pump `DashboardScreen` at 1.5x and 2.0x text scale.
- Assert no overflow exceptions.
- Test both light and dark themes by wrapping in `MaterialApp` with the appropriate theme.
- Test both en and bn locales by wrapping with the appropriate `Localizations` delegate.

**Integration:** Uses existing `DashboardScreen` widget.

### Task 3: Water module text-scale tests

**Files to create/modify:**
- `test/features/water/presentation/water_text_scale_test.dart` (new)

**Detailed changes:**
- Pump `WaterHomeScreen`, `WaterAddEntryScreen`, `WaterStatsScreen`, and `WaterSettingsScreen` at 2.0x.
- Assert no overflow.
- Pay special attention to the quick-add chips row and the stats chart axis labels.

**Integration:** Uses existing Water module screens.

### Task 4: Medicine module text-scale tests

**Files to create/modify:**
- `test/features/medicine/presentation/medicine_text_scale_test.dart` (new)

**Detailed changes:**
- Pump `MedicineHomeScreen`, `MedicineListScreen`, `MedicineDetailScreen`, and `MedicineStatsScreen` at 2.0x.
- Assert no overflow.
- Pay special attention to dose-timeline rows (dense text layout).

**Integration:** Uses existing Medicine module screens.

### Task 5: Prayer module text-scale tests

**Files to create/modify:**
- `test/features/prayer/presentation/prayer_text_scale_test.dart` (new)

**Detailed changes:**
- Pump `PrayerHomeScreen`, `PrayerStatsScreen`, `PrayerQadhaScreen`, and `PrayerSettingsScreen` at 2.0x.
- Assert no overflow.
- Pay special attention to prayer checklist rows.

**Integration:** Uses existing Prayer module screens.

### Task 6: Settings text-scale tests

**Files to create/modify:**
- `test/features/settings/presentation/settings_text_scale_test.dart` (new)

**Detailed changes:**
- Pump `SettingsScreen` at 2.0x.
- Assert no overflow.

**Integration:** Uses existing Settings screen.

### Task 7: Fix identified layout breakages

**Files to create/modify:**
- Various screen files (identified during testing)

**Detailed changes:**
- Common fixes based on audit findings:
  - **Fixed-height `Row` with text children:** Wrap text in `Flexible` with `overflow: TextOverflow.visible`, or switch to `Column`.
  - **Buttons with hardcoded dimensions:** Remove fixed `minWidth`/`height` or use `IntrinsicHeight`.
  - **Snackbar overflow:** Ensure `SnackBarBehavior.floating` with adequate width.
  - **Chart axis labels:** Set explicit text styles that scale with `MediaQuery` text scale.
  - **Bottom-nav labels:** Verify `BottomNavigationBarItem.label` allows wrapping; increase bottom-nav height if needed.
- All fixes should be language-agnostic (wrapping/flexible layout), not per-locale.

**Integration:** Each fix is a localized change to the specific widget that overflows.

### Task 8: Document results

**Files to create/modify:**
- `docs/superpowers/specs/07-accessibility/05-text-scaling-results.md` (new)

**Detailed changes:**
- Record screenshots at 200% for both en and bn locales, both light and dark themes.
- Document any fixes made and their rationale.

**Integration:** Repository artifact for traceability.

---

## Performance Considerations

- **Caching strategy:** N/A — layout fixes are static widget tree changes.
- **Lazy loading:** N/A.
- **Memory efficiency:** Flexible/wrapping layouts use the same memory as fixed layouts.

---

## Testing

- `test/accessibility/text_scale_test_helper.dart` — shared helper.
- `test/features/dashboard/presentation/dashboard_text_scale_test.dart`
- `test/features/water/presentation/water_text_scale_test.dart`
- `test/features/medicine/presentation/medicine_text_scale_test.dart`
- `test/features/prayer/presentation/prayer_text_scale_test.dart`
- `test/features/settings/presentation/settings_text_scale_test.dart`

---

## Localization

No new ARB keys needed — this audit fixes layout breakage from existing strings at large scales.

---

## Edge Cases

1. **Fixed-height `Row` widgets** — most common breakage; text wraps at 200% and overflows.
2. **Buttons with hardcoded dimensions** — don't accommodate scaled text.
3. **Snackbar text overflow** — especially in Bangla which is 20-40% longer.
4. **Chart axis labels** — `fl_chart` may not respect `MediaQuery` text scale automatically.
5. **Bottom-nav labels** — may truncate at 200% if `BottomNavigationBarItem.label` is constrained.
