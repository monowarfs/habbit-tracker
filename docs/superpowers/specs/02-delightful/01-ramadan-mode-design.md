# Ramadan Mode

**Category:** Delightful · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

For a Bangladesh-first, Muslim-persona-heavy app (Rafiq's prayer consistency goal,
the app's existing Hanafi Asr default and Qadha-without-guilt-tripping stance),
Ramadan is the single highest-salience month of the year and none of the
benchmarked apps (TickTick, Habitica, Streaks, Loop, Finch, Apple Health,
Atomic Habits) treat it as anything more than a generic calendar event, if at
all. During Ramadan, a water-reminder app that keeps nagging every 2 hours
through a 14-hour fast is actively hostile, and a prayer app that doesn't
foreground Sehri/Iftar timing is missing the month's actual rhythm. Getting
this right is a whole-app seasonal identity shift, not a skin — and it's the
kind of feature that turns a utility app into "the app that gets it" for a
huge slice of the target user base, once a year, at maximum emotional
salience.

## Goals

- Detect Ramadan (Hijri calendar) automatically and let the user confirm/
  toggle it, rather than requiring manual setup.
- Reshape Water's reminder cadence so no hydration nudges land inside
  fasting hours (roughly Fajr to Maghrib).
- Surface a live Sehri-ends / Iftar-begins countdown somewhere prominent
  (dashboard and/or Prayer module).
- Adjust Prayer's framing so Fajr and Maghrib read as fasting boundary
  events, not just ordinary prayer times, without changing the underlying
  calculation engine.
- Make the whole mode reversible/opt-out at any time (some users may not
  observe, or may not want the framing).

## Non-goals / out of scope

- No Ramadan-specific new prayer calculation method or fiqh logic beyond
  what Prayer already computes.
- No fasting-tracking module (meals, calories, water-intake-during-
  eating-hours logging) — this is about reminder/timing behavior, not a
  new habit type.
- No push-notification content in Arabic/Islamic-calendar localization
  beyond what en/bn ARBs already support.
- No changes to Medicine's scheduling (dose timing during fasting is a
  personal medical decision the app shouldn't silently reinterpret).

## Proposed approach (high-level)

Ramadan mode is best framed as a seasonal overlay that reads from Prayer's
existing location/time engine (it already knows Fajr and Maghrib for the
user's location) rather than a new source of truth. A lightweight Hijri-
date check (or a static/annually-updated date range as a pragmatic
fallback) flips a single app-wide "Ramadan active" flag, surfaced through
Settings. When active, Water's reminder planner consults that flag and
Prayer's Fajr/Maghrib times to compute an allowed reminder window instead
of its normal all-day interval, so scheduling logic changes but the
underlying reminder-planning system stays the same shape. A Sehri/Iftar
countdown widget (dashboard card, and reusing whatever "next upcoming"
mechanism the dashboard already has for other modules) reads the same
Fajr/Maghrib pair. Prayer's own screens get a thin presentational tweak —
Fajr row shows "Sehri ends," Maghrib row shows "Iftar," everything else
about the prayer list/checklist stays identical — so this is a display and
scheduling-window feature layered on existing engines, not new domain
logic.

## Dependencies & prerequisites

- Prayer's location/time engine and its Fajr/Maghrib outputs.
- Water's reminder planner (the piece that currently spaces reminders
  across the day).
- A Hijri-calendar date source (library or static yearly table) to detect
  Ramadan's start/end.
- Settings screen real estate for the opt-in/opt-out toggle.
- The dashboard's existing "upcoming" surface, if the countdown reuses it
  rather than becoming a new dashboard element.

## Open questions for the implementation round

- Hijri date detection: pull a dependency, or maintain a manually-updated
  date range per year (simpler, but needs annual maintenance)?
- Does the countdown live on the dashboard, inside Prayer, or both?
- Should Ramadan mode auto-activate based on detected dates, or always
  require explicit user opt-in the first time (safer default given some
  users may not observe Ramadan at all)?
- How does this interact with users who've disabled the Prayer module
  entirely but still want Water's fasting-aware reminder shift?
- What happens to reminders already scheduled for the day Ramadan mode is
  toggled mid-day?

## Effort & sequencing notes

Complexity M — touches two modules' scheduling/display logic but reuses
their existing engines rather than building new ones. No hard dependency
on other atlas items, but natural to sequence after any work that
generalizes the dashboard's "upcoming" widget (item 08, the prayer
countdown tile) since this feature's countdown could piggyback on that
same mechanism instead of being built twice.
