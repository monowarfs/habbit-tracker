# Personalized Greeting on Dashboard Open

**Category:** Delightful · **Atlas complexity:** S · **Retention impact:** Low-Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Finch's whole identity leans on making an otherwise utilitarian tracking
app feel warm and personal, and one of its cheapest tricks is a greeting
that changes with time of day and addresses the user by name. This app's
dashboard, since Run 15, already opens with a day-completion indicator
and an upcoming strip — both informational, neither personal. A one-line,
time-of-day-aware greeting above that content ("Good morning, Rafiq")
costs almost nothing to build (the display name already exists in
Settings, the clock utility already exists for DST-safe time handling)
but adds a small, genuine moment of warmth that a purely functional
dashboard currently skips entirely.

## Goals

- Show a short greeting line at the top of the dashboard that varies by
  time of day (morning/afternoon/evening/night).
- Include the user's display name when one is set in Settings; degrade
  gracefully to a name-less greeting when it isn't (no forced name entry
  during onboarding).
- Keep it purely presentational — no new data storage, no new
  functionality beyond the greeting text itself.

## Non-goals / out of scope

- No forced display-name prompt if one doesn't already exist — this
  feature must work identically whether or not a name is set.
- No dynamic/contextual greeting content beyond time-of-day (e.g., no
  "you missed your dose" messaging folded into the greeting — that
  belongs to the day-completion indicator, not this).
- No per-module or per-achievement variation in greeting text in v1 — one
  consistent greeting line.

## Proposed approach (high-level)

This is presentation-layer work on the dashboard's existing header area,
above the day-completion indicator: at dashboard build/open time, the
current hour (from the app's existing clock utility, kept consistent with
how the rest of the app already avoids raw `DateTime.now()`) selects one
of a small set of time-of-day greeting templates, and the display name
already stored in Settings (if any) is interpolated in. No new state,
storage, or provider plumbing beyond reading two things the app already
has — the clock and the settings-backed display name — making this one
of the lowest-cost items in this entire category relative to its
warmth payoff.

## Dependencies & prerequisites

- The app's existing clock utility (for time-of-day determination,
  staying consistent with how domain logic elsewhere avoids raw
  `DateTime.now()`).
- The existing Settings-stored display name (if the app already collects
  one; if not, this may need a very small addition to Settings to capture
  an optional name, which would be the one small new piece of scope here).
- The dashboard's existing header/layout area, where the greeting would
  be inserted above the day-completion indicator.

## Open questions for the implementation round

- Does a display-name field already exist in Settings, or does this
  feature need to add one (optional, never required) as a small
  prerequisite?
- What are the time-of-day boundary hours, and should they be localized/
  culturally adjusted (e.g., does "evening" start at a different hour by
  convention)?
- Should the greeting vary at all by day-completion state (e.g., a
  slightly different tone once everything for the day is already done),
  or stay strictly time-based to keep this simple?
- Bangla greeting conventions may differ meaningfully from a literal
  translation of English time-of-day greetings — does this need its own
  small localization judgment call rather than a direct translation?

## Effort & sequencing notes

Complexity S — minimal engineering, mostly a small UI addition plus
possibly one new optional Settings field. No dependency on other atlas
items; one of the cheapest, safest items to schedule early in this
category.
