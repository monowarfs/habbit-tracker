# Chart Data-Table Fallback

**Category:** Accessibility · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

This is a net-new feature layered on an existing shared widget. `period_bar_chart.dart` is the one reusable `fl_chart` bar chart used by Water's and Medicine's stats screens today, and Prayer's stats screen is expected to reuse it too. A bar chart conveys trend and magnitude visually; a screen-reader user gets little or nothing from it even after item #1's labeling audit adds a summary label. WCAG guidance calls for a non-visual equivalent for any data visualization that carries information not available elsewhere on the screen.

## Goals

- Give every screen that renders `period_bar_chart.dart` an accessible tabular alternative (period, value, and goal-target-met/missed where applicable) that a screen reader can read row by row.
- Make the fallback discoverable without visually cluttering the chart for sighted users (e.g. a toggle, an expandable section, or an always-present but visually de-emphasized table).
- Keep the same data the chart already renders — no new aggregation logic, just a second presentation of it.

## Non-goals / out of scope

- Redesigning the chart itself or changing its visual style.
- Building a generic "chart-to-table" framework for hypothetical future chart types — scope this to the one shared widget in active use.
- Exporting the table data (CSV/share) — that's a separate concern from accessibility if it comes up later.

## Proposed approach (high-level)

Add a data-table view that sits alongside `period_bar_chart.dart` wherever it's used (Water stats, Medicine stats, and Prayer stats once built), sourced from the same series data the chart already receives — this is a presentation-layer addition, not a new data pipeline. The simplest version is a toggle or disclosure control on each stats screen that swaps the chart for a plain data table (or reveals it below/instead of the chart), built from ordinary Flutter table/list widgets so default screen-reader semantics apply for free. Because all three modules already share the one chart widget, this fallback should be built once as a companion to `period_bar_chart.dart` and reused the same way the chart itself is reused, rather than three separate per-module implementations.

## Dependencies & prerequisites

- Depends on `period_bar_chart.dart` already exposing (or being extended to expose) the same series data in a plain, chart-independent form.
- Should follow item #1 (navigation audit) so the fallback's own labels/order are consistent with whatever labeling convention that audit establishes.
- Prayer's stats screen needs to exist (it's noted in CLAUDE.md as intended to reuse the shared chart) before this fallback can be wired into all three modules at once — otherwise it lands in Water/Medicine first and Prayer picks it up when its stats screen ships.

## Open questions for the implementation round

- Toggle control, always-visible table below the chart, or a separate accessible-only route reachable via a semantics action?
- Does the table need its own localization strings (column headers) in both en/bn ARBs, or can it reuse existing stats-screen strings?
- Should the "goal target met" indicator in the table use a symbol/text (per item #3's colorblind concerns) rather than color alone?

## Effort & sequencing notes

Complexity S — one shared widget, one companion view, reused three times. Sequence after item #1 (audit) so labeling conventions are settled; can proceed independently of items #4 through #12.
