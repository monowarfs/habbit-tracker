# Weather-Aware Water Nudge Copy

**Category:** Delightful · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

None of the benchmarked apps attach situational, real-world context to a
hydration reminder — every water reminder in TickTick, Streaks, Loop, or
a typical water-tracker is the same templated string regardless of
conditions. A reminder that instead says "it's 34°C in Dhaka today"
attached to the nudge makes the ask feel earned and specific rather than
robotic, which matters for exactly the kind of low-friction habit Nusrat
is trying to build — she doesn't want the app to feel heavy, but a
reminder that clearly "knows" something real about her day reads as
attentive rather than templated. This is the one item in this batch that
requires opt-in network access in an otherwise fully offline-first app,
so it needs to be handled as a deliberate, clearly-scoped exception
rather than a casual addition.

## Goals

- Attach a short, situational reason (current or forecast temperature/
  weather) to Water's reminder notification copy, when available.
- Make the network call and location use fully opt-in, with a clear
  explanation of what's being requested and why, consistent with the
  app's existing permission-explainer pattern used for notifications.
- Degrade gracefully to the existing templated reminder copy whenever
  weather data isn't available (no connectivity, permission denied, API
  failure) — never block or delay a reminder waiting on a network call.
- Keep any weather API usage within a free/low-cost tier appropriate for
  a no-account, no-subscription app.

## Non-goals / out of scope

- No general in-app weather display/forecast screen — this is reminder-
  copy enrichment only, not a weather feature.
- No changes to Water's actual reminder timing/cadence based on weather
  (that's a separate, larger idea — hotter days getting more frequent
  reminders — and is out of scope here).
- No mandatory location or network permission — users who decline must
  get the exact same experience as today.
- No weather-based adjustments for Prayer or Medicine.

## Proposed approach (high-level)

This slots into Water's existing reminder-content generation as an
optional enrichment step: when composing a reminder's notification text,
the system attempts (with a short timeout) to fetch a current condition
for the user's last-known or roughly-approximate location, and if
successful, appends a situational clause to the otherwise-unchanged
reminder copy; if the fetch fails or the user hasn't opted in, the
existing templated copy is used unchanged. Given the app's WorkManager-
based top-up and multi-day scheduling window for notifications, weather
data would need to be fetched at generation/scheduling time rather than
truly real-time delivery time, so the copy is necessarily a forecast/
recent-reading approximation rather than an instant reading — that's an
acceptable tradeoff given this is flavor text, not the core reminder
function. Location resolution can piggyback conceptually on the same
GPS/manual-location pattern Prayer already uses for its own location
resolver, rather than inventing a new location-permission flow from
scratch.

## Dependencies & prerequisites

- Opt-in device location access (geolocator or equivalent — Prayer
  already has a location resolver pattern to reference for permission UX,
  though this would be a separate opt-in, not shared state, since a user
  might want Prayer's location but not weather network calls, or vice
  versa).
- A weather API with a viable free tier and offline-safe failure mode.
- Water's existing reminder-content/notification-copy generation point,
  where the enrichment would be inserted.
- Settings UI for the explicit opt-in toggle and its explainer copy.

## Open questions for the implementation round

- Which weather API — cost, reliability, and privacy policy all matter
  given the app's stated no-cloud-by-default identity; this needs
  explicit vetting before selection.
- Does declining this opt-in ever get asked again, or is it a one-time
  ask like the existing notification permission explainer?
- Should the location used for weather be independent of Prayer's
  location setting, or shared (with the user's awareness) to avoid asking
  twice?
- How stale can a cached weather reading be before the copy stops using
  it (e.g., don't say "34°C today" from a reading fetched 18 hours ago)?
- Does this need its own reliability/fallback documentation similar to
  the notification reliability-stub screen, given it's the app's first
  network dependency for a core-feeling flow?

## Effort & sequencing notes

Complexity M — modest in isolation, but carries real weight as the
app's first opt-in network dependency, which raises the bar on privacy
messaging and failure-mode handling beyond the code itself. No hard
dependency on other atlas items; best sequenced with extra care around
the opt-in/permission UX given it's a first-of-its-kind exception to the
app's offline-first identity.
