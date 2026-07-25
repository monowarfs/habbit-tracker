# Extended Stats Range / Multi-Year Trends

**Category:** Premium · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23 · **Revised:** 2026-07-25
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
The Reports module (Run 15) already covers week/month/year views and
longest-streak records — a genuinely generous free tier. Long-term users
(the kind most likely to stick with a habit tracker for years) eventually
want to see multi-year trend lines: "how has my Water streak changed
year over year," or "my Prayer on-time percentage across three years."
This is depth for power users, matching Apple Health's own approach of
keeping recent history free and unlocking longer trend views as a
premium depth feature, not an access restriction.

## What stays free vs. what's paywalled
The existing Reports module's week/month/year views and longest-streak
records stay free, covering a generous window (e.g. the trailing year)
for every user regardless of tier — nothing about today's Reports screen
changes or gets newly restricted. What's paywalled is viewing trend
lines and aggregates *beyond* that generous free window — genuinely
long-term, multi-year, all-time trend charts for users with enough
history to make them meaningful.

## Goals
- Let premium users select an "all-time" or custom multi-year range on
  the existing Reports screen's charts, beyond the free window.
- Reuse the Reports module's existing aggregation use cases unchanged —
  this is a date-range parameter extension, not new calculation logic.
- Make the free window generous enough (e.g. 1 year) that this never
  feels like an artificial cap on a fairly new user — it only matters
  once someone has genuinely multi-year history.

## Non-goals / out of scope
- Not building new chart types or new aggregation dimensions — the same
  charts, just over a longer date range.
- Not retroactively restricting anything the Reports module already
  shows today (week/month/year, longest-streak records) — those stay
  free regardless of how this feature is scoped.
- Not solving performance concerns for arbitrarily large date ranges in
  this pass — flagged as an open question below.

## Proposed approach (high-level)
Extend the Reports module's existing date-range selection (which already
supports week/month/year via `ReportPeriod` enum in `core/reports/
aggregate_report_usecase.dart`) with an additional "all-time"/custom-range
option, gated by a purchase check at the point the user selects a range
beyond the free window. The underlying aggregate calculations (day-
status-streaks, aggregate-report use case) should already be generic
over an arbitrary date range internally — this is primarily a UI-level
range-picker addition plus a paywall gate, not new domain logic, assuming
the Reports module's use cases don't hardcode their range handling to the
three current presets.

### Current Reports module analysis

The `AggregateReportUseCase` in `core/reports/aggregate_report_usecase.dart`
already accepts an arbitrary `DateRange` internally — the `_rangeForPeriod`
method computes the range from a `ReportPeriod` enum, but the actual
aggregation in `execute()` uses the computed `DateRange` directly. This
means the underlying logic IS range-generic — only the UI picker and
the period enum need extending.

The `_bucketPoints` method handles two cases:
- **Week/month:** one bar per day.
- **Year:** one bar per month (12 bars).

For multi-year ranges, the bucketing strategy needs extending:
- **Multi-year (2-5 years):** one bar per quarter (4 bars per year).
- **All-time (>5 years):** one bar per year.

### Extended ReportPeriod enum

```dart
enum ReportPeriod {
  week,
  month,
  year,
  // New premium periods:
  custom,    // user-selected date range
  allTime,   // from first log to now
}
```

### UI changes to Reports screen

The existing period selector (week/month/year chips or tabs) gains:
1. An "All Time" option, gated behind a premium check.
2. A "Custom Range" option (date range picker), gated behind premium.
3. A subtle lock icon on premium options for non-premium users.

```
┌─────────────────────────────────────────┐
│  Reports                    [Export →]  │
├─────────────────────────────────────────┤
│  [Week] [Month] [Year] [All Time 🔒]   │
│                            [Custom 🔒]  │
├─────────────────────────────────────────┤
│  Chart area (adjusted for selected      │
│  range's bucketing strategy)            │
├─────────────────────────────────────────┤
│  Summary stats for selected range       │
└─────────────────────────────────────────┘
```

### Performance considerations for large ranges

Multi-year data aggregation on budget devices (this app's persona set)
needs care:

1. **Day-level granularity for long ranges is impractical.** A 5-year
   range at daily granularity = 1,825 data points — too many for a bar
   chart. Bucket by quarter or year instead.
2. **SQLite can handle multi-year scans efficiently** since the data is
   already indexed by `logged_at`/`scheduled_for` columns. The main
   cost is Dart-side iteration, not DB queries.
3. **No pre-aggregation cache needed** for v1 — the existing
   `dayStatus()` method returns a `Map<LocalDate, ModuleDayStatus>` and
   the aggregation is O(n) over the map entries. For 5 years of daily
   data, that's ~1,800 entries — trivial.

### Free window definition

The free window is **1 year of data** — the existing `ReportPeriod.year`
view covers this. "All Time" and "Custom Range" beyond 1 year are
premium. This means:
- A user with <1 year of data sees no difference between free and
  premium (all their data fits in the free year view).
- A user with exactly 1 year of data sees no difference.
- A user with >1 year of data gets value from the premium range options.

## Database changes
- No new tables — this feature is purely a UI/gating addition to the
  existing Reports module.

## Dependencies & prerequisites
- The Reports module's existing aggregate use cases and date-range
  handling — this is additive to that, not a rebuild.
- Entitlement/IAP infrastructure (spec 07) for premium gating.
- The `AggregateReportUseCase._rangeForPeriod` method must be confirmed
  to accept arbitrary `DateRange` inputs (it currently does — verified
  by reading the source).

## Localization
- "All Time" and "Custom Range" labels need en/bn ARB keys.
- Date range picker labels need localization.
- Premium upsell text ("Upgrade to view all-time trends") needs
  localization.

## Edge cases & error handling
- **No data in range:** show "No data available for this range" instead
  of an empty chart. This is already handled by the existing Reports
  module (it skips modules with no data).
- **User with <1 year of data taps "All Time":** show their data as-is
  (it's all within the free window anyway). No need to gate this — the
  user gets value from seeing "all my data" even if it's less than a
  year.
- **Custom range spanning into the future:** clamp to today's date.
- **Very large data set (10+ years):** bucket by year (max 10-12 bars).
  The chart already handles year-level bucketing via `_bucketPoints`.

## Open questions for the implementation round
- Do the Reports module's aggregate use cases already accept an arbitrary
  date range internally, or are they currently hardcoded to
  week/month/year presets — this determines whether the underlying logic
  needs any change at all versus purely a UI/gating addition.
  (Answered above: they DO accept arbitrary ranges — confirmed.)
- What exactly counts as "generous" for the free window — a fixed 1 year,
  or something tied to how long the user has had the app installed?
  (Recommendation: fixed 1 year for simplicity.)
- Are there performance implications for aggregating multi-year data on
  lower-end devices (this app's persona set skews toward budget devices)
  that need caching or pre-aggregation consideration?
  (Answered above: not needed for v1 — O(n) over ~1,800 entries is
  trivial.)
- Does this interact with item #5 (PDF/CSV export) — should exported
  reports also respect the same free/premium range split?
  (Recommendation: yes — exported reports use the same date range the
  user selects in the Reports screen.)

## Effort & sequencing notes
S complexity — assuming the Reports module's aggregation logic is
already range-generic, this is close to a pure UI + paywall-gating
change. Pairs naturally with item #5 (exportable reports) since both
extend the same Reports module's date-range handling.
