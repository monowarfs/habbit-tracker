# Colorblind-Safe Streak/Heatmap Palette Check

**Category:** Accessibility · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

This is an audit-and-fix item, not a net-new feature. Each module's history calendar colors days by status (done/missed/partial/skipped), and the dashboard's month calendar adds a cross-module view on top of that. These palettes were chosen to "look fine" to a sighted designer, but nobody has run them through a deuteranopia/protanopia simulation. Red/green is the single most common colorblind failure mode, and it's also the most common choice for "done" vs. "missed" in habit-tracking UIs — exactly the risk this item exists to catch.

## Goals

- Run every per-day coloring surface (each module's history calendar, the dashboard's global month calendar, and any future heatmap) through a deuteranopia and protanopia simulation and confirm status categories remain visually distinguishable.
- Where a palette fails, adjust it (hue, lightness, or added texture/icon) rather than relying on hue alone to carry meaning.
- Treat this as a check against the existing `AppSemanticColors` theme extension and per-module accent colors, not a redesign of the whole theme.

## Non-goals / out of scope

- Building a full alternate color-vision-deficiency theme mode users can toggle — the goal is one palette that works for everyone, not multiple palettes.
- Any new data or status category — this only affects presentation of statuses that already exist.
- Fixing charts (that's item #2's accessible-table fallback, a different mitigation for a different problem).

## Proposed approach (high-level)

Audit the color values used by the history calendar's per-day coloring and the dashboard's month calendar against the current light and dark themes and the two most common colorblindness simulations, using an existing simulation tool (e.g. a browser/design-tool CVD simulator applied to screenshots) rather than building simulation into the app. Where two statuses are only distinguishable by hue and that hue pair fails a simulation, adjust the palette in the `AppSemanticColors` extension (or add a secondary non-color cue — an icon glyph or fill pattern per status) so status is legible without color. Because per-module accents and the shared semantic-success color already exist as a single theme touch point, fixes should land there rather than per-module.

## Dependencies & prerequisites

- Requires the `AppSemanticColors` theme extension and all per-module history calendars (Water, Medicine, Prayer) plus the dashboard's month calendar to exist — they already do per current project state.
- Should happen before or alongside item #6 (Simple Mode) if Simple Mode introduces its own color-coded status indicators, so the fix isn't done twice.
- Independent of the screen-reader work in item #1 — this is a purely visual/color concern.

## Open questions for the implementation round

- Does light mode and dark mode each need a separate simulation pass, or is one palette expected to hold in both given the existing `ColorScheme.fromSeed` approach?
- Is adding a non-color cue (icon/pattern) an acceptable app-wide convention, or should the fix stay hue/lightness-only to avoid visual clutter?
- Should this become a recurring check (re-run whenever a new status color is added) rather than a one-time audit?

## Effort & sequencing notes

Complexity S — a targeted palette check against one theme extension and a handful of calendar widgets, not a redesigned. Can run any time after the relevant calendars exist; cheap to do early since it only gets more expensive if more color-coded surfaces (e.g. Simple Mode, new heatmaps) are added on top of an unverified palette first.

## Localization

- No new ARB keys are expected if the fix stays within hue/lightness adjustments (no new on-screen text).
- If a secondary non-color cue is added (icon glyph or pattern per status), the icon's `Semantics` label needs a new ARB key:
  - `calendar_status_done_label` — e.g. "Completed" / "সম্পন্ন"
  - `calendar_status_missed_label` — e.g. "Missed" / "মিস হয়েছে"
  - `calendar_status_partial_label` — e.g. "Partial" / "আংশিক"
  - `calendar_status_skipped_label` — e.g. "Skipped" / "বাদ দিয়েছে"
- These strings serve double duty: they support both the colorblind-safe icon labels and the screen-reader labels for calendar cells (aligning with #1's audit).
- Add to both `app_en.arb` and `app_bn.arb`.

## Edge cases & error handling

1. **Light mode vs. dark mode palette divergence** — a hue pair that is distinguishable in light mode may become indistinguishable in dark mode due to reduced contrast; both themes must be tested separately against CVD simulations.
2. **Module-specific accent colors clashing with semantic status colors** — each module's accent color (Water teal, Medicine blue, Prayer green) may interact differently with the status palette; verify each module's calendar independently, not just the dashboard's global calendar.
3. **New status categories added later** — if a future module introduces a new status (e.g. "snoozed"), the palette check must be re-run to confirm the new color is distinguishable from all existing statuses under CVD simulation.
4. **Existing `AppSemanticColors.success` green vs. red deuteranopia conflict** — this is the highest-probability failure point since green/red is the default done/missed pairing; the fix must land in `AppSemanticColors`, not per-module.
5. **Icons/patterns as secondary cues adding visual clutter** — if icons are added, they must be small enough to not overwhelm the calendar cell layout, especially at the existing cell size used in the dashboard's month calendar bottom sheet.

## Cross-references

- `docs/superpowers/specs/07-accessibility/01-talkback-voiceover-navigation-audit-design.md` — screen-reader labels for calendar cells are complementary to color-based cues.
- `docs/superpowers/specs/07-accessibility/02-chart-data-table-fallback-design.md` — the table's "goal met" indicator should use the same non-color cue convention established here.
- `docs/superpowers/specs/07-accessibility/06-simple-mode-large-button-layout-design.md` — Simple Mode's status indicators must inherit this verified palette.
- `lib/core/theme/app_theme.dart` — `AppSemanticColors` extension is the single theme touch point for palette fixes.
- `lib/features/water/presentation/` — Water history calendar.
- `lib/features/medicine/presentation/` — Medicine dose timeline calendar.
- `lib/features/prayer/presentation/` — Prayer history calendar.
- `lib/features/dashboard/presentation/` — Dashboard global month calendar.

## Test strategy

- **Golden tests**: Create `test/core/theme/colorblind_palette_test.dart` that renders each status color (done/missed/partial/skipped) at a fixed size, captures a golden image, and (if a CVD simulation library is available as a dev dependency, e.g. `flutter_colorblind_test` or equivalent) applies deuteranopia/protanopia transforms and asserts the transformed colors remain above a minimum contrast ratio against each other. If no simulation library is available, this becomes a manual verification step documented in the spec.
- **Widget tests**: `test/features/dashboard/presentation/calendar_colorblind_test.dart` — render the dashboard month calendar with all four status types present and verify that each day cell's `Semantics` node (from #1's audit) includes a text label, not just a color value, confirming non-color cues are in place.
- **Regression-prevention strategy**: Add a lint/comment convention in `app_theme.dart` near `AppSemanticColors` requiring any new status color to be checked against a CVD simulator before merge. Optionally add a CI step that screenshots the calendar at a known state and compares against a baseline golden to catch accidental palette regressions.
- **Manual audit**: Document a one-time CVD simulation pass in `docs/superpowers/specs/07-accessibility/03-palette-audit-results.md` with screenshots showing before/after under deuteranopia and protanopia simulation for both light and dark themes.
