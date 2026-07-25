# Implementation Plan: Extended Stats Range / Multi-Year Trends

**Spec:** `08-extended-stats-range-multi-year-trends-design.md`
**Complexity:** S · **Estimated effort:** 1-2 days
**Depends on:** Reports module (Run 15), spec 07 (entitlements)

---

## Task 1: Extend `ReportPeriod` enum

**File:** `lib/core/reports/aggregate_report_usecase.dart`

Add new values:
```dart
enum ReportPeriod {
  week,
  month,
  year,
  custom,    // user-selected date range (premium)
  allTime,   // from first log to now (premium)
}
```

---

## Task 2: Update `_rangeForPeriod` method

**File:** `lib/core/reports/aggregate_report_usecase.dart`

Add cases for `custom` and `allTime`:
- `custom`: accept start/end `LocalDate` parameters.
- `allTime`: query the earliest log date across all modules, use that
  as the start date.

---

## Task 3: Update `_bucketPoints` for multi-year ranges

Add bucketing strategies:
- **2-5 years:** one bar per quarter (4 bars per year).
- **>5 years:** one bar per year.

---

## Task 4: Update Reports screen UI

**File:** `lib/features/reports/presentation/screens/reports_screen.dart`

Add to the period selector:
- "All Time" chip (gated behind premium check).
- "Custom Range" chip (gated behind premium, opens date range picker).

---

## Task 5: Create date range picker widget

**File:** `lib/features/reports/presentation/widgets/date_range_picker.dart`

A modal bottom sheet with:
- Start date picker.
- End date picker (clamped to today).
- "Apply" button.

---

## Task 6: Add entitlement gate

Gate "All Time" and "Custom Range" behind spec 07's entitlement check.
Non-premium users see a lock icon with "Upgrade" CTA.

---

## Task 7: Add localization strings

en/bn ARB keys for "All Time", "Custom Range", date picker labels.

---

## Review checklist

- [ ] "All Time" shows data from first log to now.
- [ ] "Custom Range" respects user-selected dates.
- [ ] Bucketing strategy adapts to range length.
- [ ] Entitlement gate works for non-premium users.
- [ ] Performance is acceptable for multi-year ranges.
