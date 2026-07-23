# Opt-In Anonymous Usage Analytics

**Category:** Analytics · **Kind:** Product telemetry (gated, separate decision) · **Atlas complexity:** L · **Retention impact:** Low-to-team / N/A-to-user-retention
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## This item is different from every other spec in this batch

Every other spec in `08-analytics/` is **personal analytics**: the user's
own on-device dashboard, expanded freely, with nothing ever leaving the
device. This spec is **product telemetry**: usage data sent to the app's
own team, to understand feature adoption. It is the only item in the
entire Feature Atlas gap-analysis that is not about the user's own
device — it is about what the team building the app gets to see. Those
are two entirely different things that happen to share the word
"analytics," and conflating them would be a real mistake: nothing else in
this directory implies any change to what data leaves the device.

`docs/strategies/analytics-future.md` already exists precisely to make
this distinction structural, not just a matter of naming discipline: the
app currently ships a `NoOpAnalyticsService` — instrumentation call sites
exist in the code, wired as an ordinary Riverpod-provided dependency, but
every one of them currently does nothing. That document is the
authoritative source for this item; this spec restates it at the
planning level and does not relax anything it says.

## Problem / opportunity

The team currently has no visibility into feature adoption — which
modules users actually enable, which stats screens get visited, whether a
new feature (like any of the ten personal-analytics items above) actually
gets used once shipped. That's a real product-development gap. But
closing it is explicitly **not** a code-writing task that can be scheduled
like the other ten items in this batch — it is a product/legal decision
gated behind a hard prerequisite checklist, and no implementation work
should start until every item on that checklist is independently cleared.

## Goals (of *this planning spec*, not of shipping analytics)

- Keep the six-point gate visible and enumerated wherever this feature is
  discussed, so it is never miscategorized as a routine feature to
  schedule.
- Ensure any future round that revisits this item re-reads
  `analytics-future.md` in full rather than working from a summary.
- Preserve the existing no-op instrumentation points and their
  deliberately coarse `AnalyticsEvent` shape (module id, action type,
  streak day-count — never a medicine name, dosage, or prayer-specific
  detail) as the starting design if/when this is ever activated, rather
  than redesigning the event taxonomy from scratch at that point.

## Non-goals / out of scope

- **Not scheduled work.** This spec does not authorize writing an
  analytics SDK integration, choosing a vendor, or flipping
  `NoOpAnalyticsService` to a real implementation.
- Not a code change of any kind in this pass — no dependency additions,
  no new call sites beyond what already exists as no-ops.
- Not a decision-making document — the six-point checklist below is
  restated from `analytics-future.md`, not adjudicated here; each point
  requires its own dedicated product/legal/compliance decision process
  entirely separate from a code-planning spec.

## The six-point gate (hard prerequisite, not a footnote)

All six must be cleared, in full, before any real analytics implementation
ships — not sequenced as "ship then fix," but resolved before the first
line of non-no-op code:

1. **Affirmative, off-by-default opt-in.** Not opt-out. The app's current
   store-listing promise is "no data collected" for every existing user;
   enabling analytics for anyone without an explicit, separate consent
   action retroactively breaks a promise those users already relied on
   when installing.
2. **Store listing updates.** Both Google Play's Data Safety form and
   Apple's App Store Connect App Privacy details currently state no data
   is collected. Both must be updated accurately *before* any real
   analytics code ships — this is a store-compliance requirement with
   real rejection/policy-violation consequences, not a courtesy step.
3. **Health-data sensitivity review.** Even coarse, non-identifying events
   (e.g. "medicine module enabled") are an inference about a user's
   health situation, which regulations such as GDPR's special-category
   data provisions treat more strictly than ordinary usage analytics.
   "The events are just counts, not names" is explicitly not sufficient
   justification to skip this review.
4. **A deliberate vendor decision.** A typical analytics SaaS reintroduces
   the same always-on network dependency the project already ruled out
   for crash reporting. Self-hosted or region-hosted alternatives must be
   evaluated alongside default big-vendor SDKs, not defaulted into by
   inertia.
5. **A durable off switch.** Even after a user consents, Settings must
   retain a visible, working toggle to turn analytics back off at any
   time — a one-time, non-revocable consent is not real consent.
6. **A deletion story.** A user's request to delete their analytics data
   must reach wherever that data actually lives, independent of the
   app's own local soft-delete mechanism, which only ever governed data
   that stayed on-device and does not reach any external analytics store.

## Proposed approach (high-level, contingent on the gate clearing)

If and only if all six points above are cleared through their own
proper (non-engineering) decision processes, the technical path is
already scaffolded by design: the existing `AnalyticsService` interface
and its coarse `AnalyticsEvent` union stay as the intended shape, and
`NoOpAnalyticsService` is swapped for a real implementation bound at the
same Riverpod provider seam already in place. No new call sites should be
needed at that point — the call sites (module enabled, dose/prayer action,
streak milestone) already exist in the code, deliberately inert. This
means the *engineering* lift, once gated, is comparatively small — the
size of this item in the Atlas (L) is overwhelmingly about the six-point
decision process, store-listing updates, and compliance review, not about
writing Dart.

## Dependencies & prerequisites

- All six checklist points above, each independently resolved, in order
  before any of the rest of this proceeds.
- `docs/product/release-plan.md`'s current store data-safety answers,
  which must be updated in lockstep with point 2.
- `docs/strategies/error-handling-logging.md`'s crash-reporting
  no-network-dependency precedent, which point 4's vendor evaluation must
  explicitly weigh against, not ignore.
- Legal/compliance input beyond engineering's own judgment for points 1,
  2, 3, and 6 — none of these are decisions an implementation round can
  make unilaterally.

## Open questions for the implementation round

- (Not applicable until the six-point gate clears — there is no
  implementation round to scope yet.) Once it does clear, open questions
  will include: which vendor (if any) was chosen under point 4, what the
  opt-in UI/copy looks like, and where in Settings the durable off switch
  (point 5) lives.

## Effort & sequencing notes

Atlas complexity: L — but almost none of that size is engineering effort;
it is the six-point product/legal/compliance gate. This item should not
be sequenced alongside the other ten personal-analytics items in this
batch at all — it belongs in a completely separate track owned by
product/legal, revisited only if/when the team deliberately decides to
pursue it, per `analytics-future.md`'s explicit instruction that this
"isn't scheduled work" and must never be evaluated as a one-line
dependency add.
