# Implementation Plan: Analytics Features (08-analytics)

**Specs:** 11 files | **Total estimated effort:** 10-12 days
**Created:** 2026-07-25

---

## Dependency Graph

All specs in this directory are mostly independent — they all read from
existing day-status/report data. The only exception is Spec 10 (Prayer
on-time/late) which requires a schema change.

## Recommended Implementation Order

### Wave 1: Simple presentation additions (3-4 days)
| Spec | Effort | Notes |
|---|---|---|
| 04 Trend Arrows | 0.5 day | Call aggregation twice, show arrow |
| 02 Personal Record Tracking | 1 day | Persist + display longest streak |
| 03 Day-of-Week Breakdown | 0.5 day | Group by weekday, show best/worst |
| 09 Goal Attainment Rate | 0.5 day | Count goal-hit days |
| 07 Notification Effectiveness | 0.5 day | Aggregate notification_ledger |

### Wave 2: Moderate complexity (4-5 days)
| Spec | Effort | Notes |
|---|---|---|
| 08 Adherence by Medicine | 1 day | Group doses by medicine_id |
| 10 Prayer On-Time vs Late | 2 days | Requires PrayerStatus schema change |
| 01 Adherence Heatmap | 2 days | New grid widget |
| 05 Consistency Score | 2 days | Design scoring formula |

### Wave 3: Low priority (1 day)
| Spec | Effort | Notes |
|---|---|---|
| 06 Comparison to Past Self | 1 day | Requires 1 year of data |

### Deferred
| Spec | Effort | Notes |
|---|---|---|
| 11 Opt-In Usage Analytics | L | Blocked on 6-point product/legal gate |

---

## Per-Spec Task Breakdown

### 01 Adherence Heatmap
1. Create `lib/core/widgets/heatmap_grid.dart` — GitHub-style grid
2. Wire to `dayStatus(DateRange)` for full-year data
3. Implement color scale (done/partial/missed/none)
4. Add tooltip on cell tap
5. Place in Reports screen or own entry point
6. Add en/bn ARB keys
7. Tests

### 02 Personal Record Tracking
1. Create `lib/core/analytics/personal_record_repository.dart`
2. Add `personal_records` Drift table
3. Implement record detection (compare against persisted max)
4. Add record display to per-module stats screens
5. Add "New Record!" celebration toast
6. Backfill records on feature first launch
7. Add en/bn ARB keys
8. Tests

### 03 Day-of-Week Breakdown
1. Implement weekday grouping from day-status data
2. Calculate per-weekday completion percentage
3. Build breakdown UI (bar/strip chart)
4. Enforce minimum sample size (28 days)
5. Add period selector (30/90/all-time)
6. Add en/bn ARB keys
7. Tests

### 04 Trend Arrows
1. Create `lib/core/widgets/trend_arrow.dart` — shared widget
2. Call aggregation use case twice (current + previous period)
3. Calculate delta percentage
4. Handle partial-period comparison
5. Handle zero-to-nonzero edge case
6. Add en/bn ARB keys
7. Tests

### 05 Consistency Score
1. Design scoring formula (weighted average recommended)
2. Implement score calculation from day-status data
3. Add score display to dashboard
4. Handle single-module degenerate case
5. Handle partial-day scoring
6. Add score color coding (green/yellow/red)
7. Add en/bn ARB keys
8. Tests

### 06 Comparison to Past Self
1. Extend `period_bar_chart.dart` to accept overlay series
2. Fetch current period + same period last year
3. Handle leap year / month-length mismatch
4. Add eligibility threshold (1 year of data)
5. Add empty state for users with < 1 year
6. Add en/bn ARB keys
7. Tests

### 07 Notification Effectiveness
1. Query `notification_ledger` for action outcomes
2. Implement 4-hour time window for action attribution
3. Classify snooze as "partial positive"
4. Calculate per-module effectiveness percentage
5. Display in Settings notification reliability screen
6. Add "Last 90 days" data window label
7. Add en/bn ARB keys
8. Tests

### 08 Adherence by Medicine
1. Group `medicine_doses` by `medicine_id`
2. Call `calculateAdherence` per group
3. Sort by ascending adherence (worst first)
4. Handle PRN medicines separately
5. Enforce minimum sample size (7 doses)
6. Add en/bn ARB keys
7. Tests

### 09 Goal Attainment Rate
1. Count days where `dayStatus.kind == complete`
2. Divide by total active days (exclude no-data days)
3. Start with Water only (cleanest goal concept)
4. Add period selector
5. Handle zero denominator
6. Add en/bn ARB keys
7. Tests

### 10 Prayer On-Time vs Late
1. Add `prayedLate` to `PrayerStatus` enum
2. Modify `effectivePrayerStatus` to check timing
3. Update `calculateAdherence` for new status
4. Update `notification_action_handler` (notification = on-time)
5. Add three-way split to Prayer stats screen
6. Handle backward compatibility (existing `prayed` = on-time)
7. Add en/bn ARB keys
8. Tests + migration test

### 11 Opt-In Usage Analytics
1. **BLOCKED:** Six-point product/legal gate must clear first
2. When gate clears: implement `AnalyticsService` (not `NoOp`)
3. Wire existing call sites to real service
4. Add opt-in prompt in Settings
5. Add durable off switch
6. Update store data-safety disclosures
7. Tests
