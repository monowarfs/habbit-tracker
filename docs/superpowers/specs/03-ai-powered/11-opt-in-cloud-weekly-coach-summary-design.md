# Opt-In Cloud "Weekly Coach" Summary

**Category:** AI-Powered · **Atlas complexity:** L · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Fitbit/Whoop-style AI-written weekly recaps ("here's how your week went,
in plain language") are a proven engagement pattern — a short, readable
narrative summary is more digestible and more likely to be read than a
chart. This app's Reports module already computes the structured data
such a summary would draw from (streak records, adherence rates,
week-over-week comparisons), so the gap is purely the "write it in plain
language" step, which is genuinely better done by an LLM than by
hand-authored templated copy for every possible data shape. **This is
the one deliberately-cloud item in this category** — everything else in
this atlas section is scoped to on-device heuristics specifically
because this app's entire trust story is offline-first and
account-free. This feature is the single exception, and it must be
built as an isolated, clearly-bounded opt-in layer, not a precedent that
quietly normalizes future network calls elsewhere in the app.

## Goals
- Offer users who explicitly opt in a short, LLM-generated plain-language
  weekly recap summarizing their own already-locally-computed stats
  (streaks, adherence, notable changes week-over-week).
- Keep the feature fully inert (no network calls, no data leaves the
  device) for every user who has not explicitly opted in — which should
  be the overwhelming majority given the app's positioning.
- Treat every item in the consent checklist below as a hard, sequential
  prerequisite gate — not a parallel workstream, not a footnote, not
  something to revisit "after" the feature ships.

## Non-goals / out of scope
- Not a general-purpose chat/assistant feature — a single, scheduled,
  bounded weekly summary generation, not open-ended conversation.
- Not a default-on or opt-out feature under any circumstances — off by
  default, and staying off is the only acceptable state absent explicit,
  affirmative user action.
- Does not send raw per-entry data (specific medicine names, dosages,
  specific prayer times, specific dates) off-device if it can be avoided
  — the goal is to send the same kind of coarse, aggregated figures the
  existing `AnalyticsEvent` design already treats as the redaction
  boundary (counts, rates, streak lengths), not granular health records.
  The exact data-minimization boundary is itself part of the health-data
  sensitivity review below, not a decision to make casually in code.
- Not scoped to build in this pass at all unless/until the consent
  checklist gate is explicitly cleared by a product/legal decision — this
  spec documents the shape of the feature so it isn't designed from
  scratch under time pressure later, not a green light to start building.

## Proposed approach (high-level)
**This is the sole feature in this atlas category that leaves the
device.** Where every other item in "AI-Powered" is on-device arithmetic
or a rule-based parser, this one calls a real LLM API over the network,
and that difference has to be architecturally visible, not buried: the
network call, the request/response payload shape, and the opt-in gate
should live in a clearly separate, clearly named module (distinct from
`core/notifications`, `core/achievements`, and `core/reports`, though it
reads from Reports' aggregated output as its input), so it's easy for
any future contributor to see at a glance which single feature in the
whole app talks to the network and why. The Reports module's existing
`aggregate_report_usecase` output (week/month summaries, streak records)
is the only data source — no new per-entry data collection is
introduced for this feature. That aggregated payload is sent to an LLM
API, which returns a short plain-language recap displayed to the user
(e.g. on the Reports screen or dashboard, clearly labeled as
AI-generated and requiring an active opt-in toggle in Settings to be
visible at all). Network reachability failures degrade silently to "no
summary this week" — never a jarring error state — since this is a
nice-to-have narrative layer on top of data the user can already see in
structured form regardless.

## The consent checklist gate (from `docs/strategies/analytics-future.md`)
This feature must clear every one of the six prerequisites
`analytics-future.md` lays out for *any* feature sending data off-device,
before a single line of network-calling code ships — restated here in
full because this spec is exactly the situation that checklist exists
for:

1. **Affirmative, off-by-default opt-in** — a separate, explicit consent
   action, not a pre-checked toggle or an implied consent from enabling
   a module. The app's current "no data collected" promise is a real
   commitment to existing users; this feature cannot retroactively break
   it for anyone who hasn't explicitly opted in.
2. **Store listing updates** — both Play Console's Data Safety form and
   App Store Connect's App Privacy details currently state no data is
   collected; both must be updated accurately before this ships, as a
   compliance requirement, not a courtesy.
3. **Health-data sensitivity review** — even aggregated adherence/streak
   figures are an inference about a user's health situation (medicine
   adherence, prayer consistency), which several jurisdictions'
   regulations treat as sensitive/special-category data. "It's just
   aggregated numbers, not names" is not sufficient justification on its
   own to skip this review.
4. **A vendor decision made deliberately** — which LLM API provider,
   under what data-retention/training-use terms, and whether region-
   hosted or self-hosted alternatives were genuinely evaluated rather
   than defaulting to whichever SDK is most convenient.
5. **A durable off switch** — a visible, working Settings toggle that
   turns this back off at any time, with an immediate effective stop to
   further network calls — a one-time consent that can't be revoked
   isn't real consent.
6. **A deletion story** — if a user who opted in later requests deletion
   of any data the LLM vendor might have retained (prompts, logs), there
   must be an actual path to reach that data, independent of this app's
   own on-device soft-delete mechanism, which only ever governed data
   that stayed on-device.

None of these six are negotiable or reorderable — clearing five and
treating the sixth as a fast-follow is the exact failure mode this
checklist exists to prevent.

## Dependencies & prerequisites
- All six consent-checklist items above, cleared as a genuine
  product/legal decision before implementation begins.
- The Reports module's aggregated output as the sole data source.
- An LLM API vendor selection and integration (network client, API key
  management, error/timeout handling).
- Network reachability handling that fails silently/gracefully, given
  the rest of the app has no expectation of connectivity.
- Settings UI for the opt-in toggle and its durable off switch.

## Open questions for the implementation round
- Which LLM vendor, and under what data-retention/training-opt-out
  contractual terms — this is a decision requiring input beyond
  engineering alone.
- What exact aggregated fields are safe to send given the health-data
  sensitivity review's findings — the data-minimization boundary needs
  to be explicit and reviewed, not inferred from "seems coarse enough."
- Does the recap generation happen client-side calling the LLM API
  directly, or via a thin backend proxy this app doesn't otherwise have
  — the latter is a bigger architectural addition (this app currently
  has zero backend) worth weighing against direct-from-client calls.
- What does the UI look like for a user who opts in but has no network
  connectivity that week, or whose API call fails/times out — the
  silent-degradation approach above needs concrete UX.
- How is cost (LLM API usage cost per user per week) accounted for,
  given this app has no account/subscription/payment layer today?

## Effort & sequencing notes
Complexity L, and that's before counting the non-engineering effort
(legal review, store listing updates, vendor evaluation) the checklist
above requires — the consent-gate work alone likely dwarfs the
engineering effort of the summary feature itself. This should be
sequenced last among all "AI-Powered" items, and only taken up at all
once the product/legal decision to clear the checklist has actually been
made — not scheduled as ordinary engineering backlog work in the
meantime.
