# Analytics — Future

**Ships in v1.0: nothing.** No analytics SDK, no event collection, no
network call of any kind for usage data — consistent with FR-C-01 and the
crash-reporting trade-off already made in `error-handling-logging.md`.
This document exists so instrumentation *points* are in the codebase from
day one (cheap, structural), without any of them doing anything yet.

## The no-op interface

```dart
abstract class AnalyticsService {
  void logEvent(AnalyticsEvent event);
}

sealed class AnalyticsEvent {
  const factory AnalyticsEvent.moduleEnabled(String moduleId) = ModuleEnabledEvent;
  const factory AnalyticsEvent.doseActioned(String moduleId, String action) = DoseActionedEvent;
  const factory AnalyticsEvent.streakMilestone(String moduleId, int days) = StreakMilestoneEvent;
}

class NoOpAnalyticsService implements AnalyticsService {
  @override
  void logEvent(AnalyticsEvent event) {} // ponytail: no-op until analytics is ever approved
}
```

`AnalyticsService` is bound as a Riverpod provider like any other
dependency (`state-management.md`) — use cases call
`ref.read(analyticsServiceProvider).logEvent(...)` at the handful of
points that would matter later (a module gets enabled, a dose/prayer
action happens, a streak milestone is hit), and today that call does
precisely nothing. **The typed `AnalyticsEvent` union is deliberately
coarse** — module id, action type, streak day-count — never a medicine
name, dosage, or prayer-specific detail, matching `error-handling-
logging.md`'s redaction rule; this is a design constraint on the event
shape itself, not just a promise about how it'd be used later.

## What would be required before this is ever switched on

Turning `NoOpAnalyticsService` into a real implementation is not a small
follow-up code change — it's a product/legal decision with real
prerequisites, listed here so it isn't casually flipped on later without
them:

1. **Affirmative, off-by-default opt-in** — not opt-out. The app's current
   promise (`../product/release-plan.md`'s store data-safety answers: "no
   data collected") is a real commitment; enabling analytics for any user
   without an explicit, separate consent action would break that promise
   retroactively for people who installed the app under it.
2. **Store listing updates** — both Play Console's Data Safety form and
   App Store Connect's App Privacy details currently state no data is
   collected (`release-plan.md`). Enabling analytics requires updating
   both, accurately, before the change ships — this is a store-compliance
   requirement, not an optional courtesy.
3. **Health-data sensitivity review** — even coarse events like "medicine
   module enabled" are an inference about a user's health situation, which
   several jurisdictions' privacy regulations (e.g. GDPR's special-category
   data provisions) treat more strictly than ordinary usage analytics.
   "The events are just counts, not names" is not sufficient reasoning on
   its own to skip this review.
4. **A vendor decision made deliberately, not by default** — a typical
   analytics SaaS reintroduces the same always-on network dependency
   `error-handling-logging.md` ruled out for crash reporting. If ever
   pursued, self-hosted or region-hosted options should be evaluated
   alongside the default big-vendor SDKs, not assumed away.
5. **A durable off switch** — even after consent, Settings must retain a
   visible, working toggle to turn analytics back off; a one-time consent
   that can't be revoked isn't real consent.
6. **A deletion story** — if a user requests their data be deleted, that
   request has to reach whatever holds the analytics copy, independently
   of this app's own local soft-delete mechanism (`offline-strategy.md`),
   since that mechanism only ever governed data that stayed on-device.

None of this is scheduled work — it's the checklist a future decision to
add analytics would need to clear, kept here so "just add Firebase
Analytics" isn't evaluated as a one-line dependency add when it's
revisited.
