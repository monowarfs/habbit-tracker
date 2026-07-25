# Implementation Plan: 03 Colorblind-Safe Streak/Heatmap Palette Check

## Overview

- **Spec:** Colorblind-Safe Streak/Heatmap Palette Check
- **Complexity:** S
- **Estimated effort:** 0.5 day
- **Dependencies:** Requires `AppSemanticColors` theme extension and all per-module history calendars to exist (they do). Should run before spec 06.
- **Prerequisites:** A CVD simulation tool (Sim Daltonism, browser extension, or design tool).

---

## Implementation Tasks

### Task 1: Audit current palette against CVD simulations

**Files to create/modify:**
- None (manual audit pass, no code changes yet)

**Detailed changes:**
- Run screenshots of each module's history calendar (Water, Medicine, Prayer) and the dashboard's global month calendar through deuteranopia and protanopia simulation.
- Use `AppSemanticColors.light` (success: `0xFF2E7D32`) and `AppSemanticColors.dark` (success: `0xFF81C784`) as the baseline.
- Test both light and dark themes.
- Document which color pairs fail (expected: red/green done/missed pair is the primary failure point).

**Integration:** This is a manual/design-tool pass that produces findings, not code.

### Task 2: Adjust `AppSemanticColors` for colorblind safety

**Files to create/modify:**
- `lib/core/theme/app_theme.dart` (modify)

**Detailed changes:**
- If the green/red pair fails deuteranopia/protanopia simulation, adjust the `success` color or add additional status colors:
  - Add `missed` color to `AppSemanticColors` (e.g. a warm amber/orange that's distinguishable from green under CVD).
  - Add `partial` color if needed.
  - Add `skipped` color if needed.
- Keep adjustments within `AppSemanticColors` — do not create per-module color overrides.
- The adjusted colors must maintain sufficient contrast against both light and dark backgrounds (WCAG AA 4.5:1 minimum).

**Integration:** `AppSemanticColors` is already used by calendar cell renderers. Adding new color fields propagates automatically.

### Task 3: Add non-color cues (icons/patterns) where needed

**Files to create/modify:**
- `lib/features/water/presentation/` history calendar cells (modify)
- `lib/features/medicine/presentation/` history calendar cells (modify)
- `lib/features/prayer/presentation/` history calendar cells (modify)
- `lib/features/dashboard/presentation/` global month calendar cells (modify)

**Detailed changes:**
- If hue/lightness adjustments alone are insufficient, add small icon glyphs inside calendar day cells as secondary cues:
  - Done status: checkmark icon (`Icons.check`)
  - Missed status: X icon (`Icons.close`)
  - Partial status: minus icon (`Icons.remove`)
  - Skipped status: dash icon (`Icons.horizontal_rule`)
- Keep icons small (12-14px) to avoid overwhelming the cell layout, especially in the dashboard's compact month calendar.
- Each icon must have a `Semantics` label (using the ARB keys below) so screen readers announce the status, not just the icon.

**Integration:** Calendar cell renderers already exist; this adds a conditional icon inside each cell based on status.

### Task 4: Add ARB keys for status icons

**Files to create/modify:**
- `lib/core/l10n/app_en.arb` (modify)
- `lib/core/l10n/app_bn.arb` (modify)

**Detailed changes:**
- Add keys: `calendarStatusDoneLabel`, `calendarStatusMissedLabel`, `calendarStatusPartialLabel`, `calendarStatusSkippedLabel`.
- These serve double duty: colorblind icon labels AND screen-reader labels for calendar cells (aligning with spec 01).

**Integration:** Standard `gen_l10n` flow.

### Task 5: Document findings

**Files to create/modify:**
- `docs/superpowers/specs/07-accessibility/03-palette-audit-results.md` (new)

**Detailed changes:**
- Record before/after color values under deuteranopia and protanopia simulation for both light and dark themes.
- Include screenshots if possible.

**Integration:** Repository artifact for traceability and future re-runs.

---

## Performance Considerations

- **Caching strategy:** No caching needed — color values are constants in the theme extension.
- **Lazy loading:** N/A — palette is static.
- **Memory efficiency:** Icon glyphs inside calendar cells add negligible overhead (one `Icon` widget per cell).

---

## Testing

- `test/core/theme/colorblind_palette_test.dart` — renders each status color at a fixed size and captures golden; if a CVD simulation library is available, applies transforms and asserts minimum contrast ratio between status pairs.
- `test/features/dashboard/presentation/calendar_colorblind_test.dart` — renders the dashboard month calendar with all four status types and verifies each day cell's `Semantics` node includes a text label.

---

## Localization

New ARB keys:
```
calendarStatusDoneLabel
calendarStatusMissedLabel
calendarStatusPartialLabel
calendarStatusSkippedLabel
```

---

## Edge Cases

1. **Light vs. dark mode divergence** — both themes must be tested separately under CVD simulation.
2. **Module-specific accent colors** — Water teal, Medicine blue, Prayer green may interact differently with status colors; verify each module's calendar independently.
3. **New status categories** — any future status must be checked against CVD simulation before merge.
4. **Icons adding visual clutter** — icons must be small (12-14px) and positioned to not overwhelm the calendar cell layout.
