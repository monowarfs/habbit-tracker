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

Complexity S — a targeted palette check against one theme extension and a handful of calendar widgets, not a redesign. Can run any time after the relevant calendars exist; cheap to do early since it only gets more expensive if more color-coded surfaces (e.g. Simple Mode, new heatmaps) are added on top of an unverified palette first.
