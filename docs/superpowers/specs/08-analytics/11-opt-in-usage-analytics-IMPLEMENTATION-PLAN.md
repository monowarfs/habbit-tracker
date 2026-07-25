# Implementation Plan: Opt-In Anonymous Usage Analytics

**Spec:** `11-opt-in-usage-analytics-design.md`
**Complexity:** L · **Estimated effort:** Deferred
**Depends on:** Six-point product/legal gate — BLOCKED

---

## BLOCKED

This spec is explicitly NOT scheduled work. The six-point gate from
`docs/strategies/analytics-future.md` must clear before any
implementation begins:

1. Affirmative opt-in consent
2. Store listing updates
3. Health-data sensitivity review
4. Vendor decision
5. Durable off switch
6. Deletion story

---

## When gate clears:

### Task 1: Implement AnalyticsService

**File:** `lib/core/analytics/analytics_service.dart`

Replace `NoOpAnalyticsService` with real implementation that sends
coarse events to the chosen vendor.

### Task 2: Wire existing call sites

The call sites (module enabled, dose actioned, streak milestone) already
exist in the code — they're deliberately inert. Wire them to the real
service.

### Task 3: Add opt-in prompt

**File:** `lib/features/settings/presentation/screens/settings_home_screen.dart`

Add analytics opt-in toggle with privacy explanation.

### Task 4: Add durable off switch

Settings toggle to disable analytics at any time.

### Task 5: Update store data-safety

Update Google Play Data Safety and App Store Connect App Privacy.

---

## Performance considerations

- **Event queue:** buffer events locally, send in batches.
- **Network:** best-effort, no retry on failure.

## Testing

- Unit test: real AnalyticsService sends events correctly.
- Widget test: opt-in prompt and settings toggle.
- Integration test: end-to-end event flow.

## Localization

All analytics UI needs en/bn ARB keys (deferred until gate clears).
