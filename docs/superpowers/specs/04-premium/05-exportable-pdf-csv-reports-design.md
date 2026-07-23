# Exportable PDF/CSV Reports

**Category:** Premium · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
The app already has a Reports module (built in Run 15) covering
week/month/year aggregation and longest-streak records entirely in-app.
What it lacks is any way to take that data out of the app for a doctor's
visit — a caregiver or patient managing Medicine adherence, or a Prayer
user tracking Qadha counts over time, regularly needs a printable or
shareable artifact, not just an in-app chart. This mirrors Apple Health's
export-for-a-clinician pattern and is a genuinely premium-worthy *output
format*, distinct from paywalling the underlying stats themselves.

## What stays free vs. what's paywalled
All in-app stats, charts, and the Reports screen (week/month/year views,
longest-streak records) stay free exactly as they exist today — nothing
about viewing your own data in-app is restricted. What's paywalled is
generating a polished, exportable PDF (formatted for printing/sharing,
e.g. with a doctor) or a raw CSV dump of the underlying data for
spreadsheet use. The premium value is in the *output artifact and its
formatting*, not in unlocking data that was otherwise hidden.

## Goals
- Let a premium user generate a PDF report (e.g. Medicine adherence over
  a date range, Prayer on-time percentage, Water streak history) suitable
  for printing or emailing to a healthcare provider.
- Let a premium user export the same underlying data as CSV for their own
  spreadsheet analysis.
- Reuse the existing Reports module's aggregation logic as the data
  source for both formats — no duplicate calculation logic.

## Non-goals / out of scope
- Not building a new stats engine — this is purely a rendering/export
  layer on top of the Reports module's existing aggregate calculations.
- Not covering per-entry raw export (that's closer to the free local
  backup/export feature's job) — this is specifically formatted,
  report-shaped output for sharing, not a full data dump for restore
  purposes.
- Not building in-app sharing infrastructure beyond the OS share sheet —
  export, then hand off to whatever the user already uses to share files.

## Proposed approach (high-level)
Add a PDF/CSV generation layer that consumes the Reports module's
existing aggregate use cases (the same day-status-streaks and
aggregate-report calculations already powering the in-app Reports
screen) rather than recomputing anything. A new "Export" action on the
Reports screen would let the user pick a date range and format, generate
the file using a PDF-rendering package, and hand off to the OS share
sheet. Because the data source is the same aggregation use cases already
proven for the in-app screen, per-module differences (Medicine's
adherence percentage vs. Prayer's on-time percentage vs. Water's streak)
should require no new per-module logic — only a presentation template
per report type.

## Dependencies & prerequisites
- The Reports module (Run 15) as the data source — this feature is
  purely additive on top of it.
- A PDF-generation package (e.g. `pdf`/`printing`) for layout and
  print/share integration.
- IAP/purchase-gating plumbing shared with other premium features.

## Open questions for the implementation round
- Does the paywall gate the export action itself, or gate specific date
  ranges (e.g. free CSV export of the last 30 days, premium for
  arbitrary ranges)? This interacts with item #8 (extended stats range).
- What's the visual design for the PDF template — one generic template
  across modules, or per-module templates matching each module's accent
  color and content shape?
- Should CSV export include raw per-entry data or only the aggregated
  report numbers already shown in-app?
- Does this need bilingual (en/bn) PDF templates from day one, matching
  the rest of the app's localization posture?

## Effort & sequencing notes
M complexity — bounded because it reuses the Reports module's existing
aggregation logic entirely; the new work is template design and
PDF/CSV rendering, not new domain calculations. No hard sequencing
dependency on other premium items, though it pairs naturally with item #8
(extended stats range) since both touch the Reports module's date-range
handling.
