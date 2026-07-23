# Sunrise/Sunset Countdown Widget for Next Prayer

**Category:** Delightful · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Muslim Pro-class apps have popularized a live "Asr in 42 min" style
countdown as an ambient way to stay aware of the next prayer without
needing a fixed reminder to fire — it's a fundamentally different feel
from a notification (which interrupts) versus a glanceable tile (which
informs). This app already shipped home-screen widgets and Wear OS
complications as a foundation (per the widgets+wearable work already
landed), and Prayer's calculation engine already produces accurate prayer
times per the golden-tested reference. What's missing is a live-updating
countdown surface, which is a more ambient and arguably more useful
companion to the existing fixed-time reminders, done tastefully rather
than as a cluttered multi-line dashboard tile.

## Goals

- Provide a live-updating (or periodically-refreshed) "next prayer in
  X" countdown, usable from the existing home-screen widget surface.
- Reuse Prayer's existing time-calculation engine as the sole source of
  truth for what "next prayer" and its time actually are.
- Keep the widget visually simple — one line of live information, not a
  dashboard crammed into widget space.
- Make the countdown update at a sensible cadence given home-screen
  widgets' platform-level refresh constraints (they are not truly
  real-time on either Android or iOS).

## Non-goals / out of scope

- No new prayer-time calculation logic — purely a display of what
  Prayer's engine already computes.
- No countdown for Water or Medicine in this item (though the same
  underlying widget mechanism could plausibly support them later).
- No interactive actions from the widget itself (marking a prayer done,
  snoozing) in v1 — display only.
- No in-app countdown screen redesign — this is specifically about the
  home-screen widget surface, not the in-app Prayer screens (though a
  smaller in-app version could be a natural follow-on).

## Proposed approach (high-level)

The existing home-widget infrastructure (already used for whatever
Water/Medicine/Prayer summaries currently ship as widgets) is the
natural host — this feature adds a new widget variant, or a new display
mode of an existing prayer widget, that shows a countdown rather than a
static "today's times" list. The underlying data — which prayer is next
and how far away it is — is a straightforward derivation from Prayer's
existing calculated times and the app's clock utility, no new domain
logic required. The harder part is entirely platform mechanics: Android
and iOS home-screen widgets both have real limits on how often they can
refresh, so "live-updating" in practice means periodic refresh (likely
minute-level at best, driven by whatever periodic update mechanism the
existing widget infrastructure already uses) rather than a literal
ticking clock — the copy and UX need to be honest about that constraint
rather than implying second-by-second accuracy.

## Dependencies & prerequisites

- The existing home_widget-based widget infrastructure and whatever
  periodic-refresh mechanism it already has (likely shared with
  WorkManager's existing periodic top-up pattern on Android).
- Prayer's calculation engine's next-prayer-time output.
- The app's clock utility for computing the remaining-time delta.
- Platform-specific widget refresh-rate constraints on both Android and
  iOS need to be understood before committing to a specific "how live is
  live" promise in the UI copy.

## Open questions for the implementation round

- What's the realistic minimum refresh interval on each platform given
  OS-level widget update budgets, and how does that shape the countdown's
  precision (minutes vs. seconds)?
- Does this become a new widget size/variant, or a toggle/mode on an
  existing prayer widget?
- Should the countdown roll over to the next day's Fajr automatically
  right after Isha passes, and how is that transition worded?
- Does the Wear OS complication get an equivalent countdown, or does this
  stay phone-widget-only for v1?

## Effort & sequencing notes

Complexity M — the domain calculation is trivial (already exists);
nearly all effort is platform widget mechanics and refresh-rate
constraints on two OSes. No hard dependency on other atlas items, but
naturally reuses whatever periodic-refresh pattern the existing widget
foundation already established, so it's cheaper once that pattern is
well understood rather than being re-derived from scratch.
