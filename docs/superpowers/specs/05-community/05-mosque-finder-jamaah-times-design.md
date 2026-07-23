# Mosque-Finder / Jamaah Times Layer

**Category:** Community · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Prayer's current calculation gives a user their own personal (calculated) prayer times, but says nothing about the congregation (jamaah) times at a nearby mosque, which frequently differ from the calculated Adhan time by a fixed offset. Muslim Pro and similar apps treat this as core functionality. It's a genuine gap for the Prayer persona specifically — someone wanting to attend congregational prayer needs the mosque's actual jamaah schedule, not just the astronomically-calculated time this app already produces.

## Infrastructure implication
Zero-infra achievable for a first version, following the same pattern as Prayer's existing bundled 65-city dataset: ship a static, curated dataset of known mosques and their jamaah offsets/schedules, matched against the user's existing GPS/manual location resolver. A live, always-current, comprehensive mosque directory (arbitrary mosque anywhere, live-updated timings) would require a backend/crowdsourcing service — that's a materially bigger feature and should be scoped as a v2 if ever pursued, not assumed as part of this v1.

## Goals
- Show nearby mosques (from a bundled/curated dataset) alongside their jamaah prayer times, offset from or independent of the calculated Adhan times Prayer already shows.
- Reuse Prayer's existing GPS/manual location resolver rather than building a second location system.
- Keep the feature fully offline — no live network lookup required for the bundled dataset to work.

## Non-goals / out of scope
- Not building a live, crowdsourced, continuously-updated mosque directory in v1 — that's a backend-requiring v2 scope, explicitly deferred.
- Not letting arbitrary users submit/edit mosque data in-app (that's a moderation and data-quality problem out of scope here).
- Not replacing or changing the existing personal Adhan-time calculation (`calculatePrayerTimes` / the `adhan_dart` wrapper) — this is an additive display layer, not a recalculation.
- No mosque reviews, ratings, or social features attached to mosque listings.

## Proposed approach (high-level)
Extend Prayer's existing bundled-city-data pattern with a second curated dataset: known mosques (name, location, jamaah offsets or fixed times per prayer) for a starting set of cities/regions, likely overlapping the existing 65-city coverage. Reuse the Prayer module's existing GPS/manual location resolver to find the user's location, then match against the nearest bundled mosque entries and display their jamaah times alongside (not instead of) the calculated personal times already shown. This slots in as an additional screen or section within the Prayer module, not a new top-level module.

## Dependencies & prerequisites
- A curated mosque dataset (name/location/jamaah times) — a content/data-sourcing effort, not just an engineering one; likely the single biggest cost driver here.
- Prayer's existing GPS/manual location resolver (already built).
- Prayer's existing bundled-asset pattern (the 65-city dataset) as a structural template for shipping and loading the new dataset.

## Open questions for the implementation round
- How is the mosque dataset sourced and kept from going stale — one-time curation at ship time, or a plan for periodic app-update refreshes?
- What's the fallback UX when no bundled mosque exists near the user's location (likely the common case outside major cities)?
- Is a fixed offset-from-Adhan model suf­ficient for jamaah times, or do some mosques need fully independent schedules (e.g. differing Friday Jumu'ah slot times, which Prayer's settings already track separately)?
- Does this warrant its own screen within Prayer, or a section on an existing Prayer screen?

## Effort & sequencing notes
Medium (M) for a bundled-dataset v1 that follows Prayer's existing 65-city precedent closely. The live/crowdsourced version implied by "mosque finder" in the fullest sense would be substantially larger (effectively a backend service) and should be treated as a distinct, later decision rather than folded into this scope.
