# Seasonal Theme Accents (Eid/New Year)

**Category:** Delightful · **Atlas complexity:** M · **Retention impact:** Low-Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

The Google Doodle pattern — a subtle, temporary visual shift around
notable dates — is a proven, low-cost way to make a utility product feel
alive and attentive without becoming gimmicky, and this app's user base
(Bangladesh-first, Muslim-majority persona set) has real, predictable
calendar moments — Eid-ul-Fitr, Eid-ul-Adha, Bengali New Year (Pohela
Boishakh) — that carry genuine cultural weight but currently get zero
acknowledgment from the app. A subtle palette shift around these dates,
fully opt-out in Settings for users who'd rather the app never change its
look, is festive without being loud, and reuses theming infrastructure
(the `ColorScheme.fromSeed` light/dark setup, per-module accents) that
already exists rather than requiring a new theming system.

## Goals

- Apply a subtle, temporary color/accent shift around a small, curated
  set of major dates (Eid-ul-Fitr, Eid-ul-Adha, Pohela Boishakh at
  minimum).
- Make the shift tasteful and light — an accent/seed-color nudge, not a
  full skin change or added decorative chrome.
- Provide a Settings opt-out so users who prefer the app's look to never
  change can disable this entirely.
- Revert cleanly to the normal theme once the date window passes, with
  no lingering state.

## Non-goals / out of scope

- No user-created/custom seasonal themes — a small, curated, app-defined
  set of occasions only.
- No changes to per-module accent colors' semantic meaning (e.g., Water's
  accent shouldn't stop being identifiably "Water" just because a
  seasonal tint is applied).
- No new illustration/decorative assets tied to this specifically (that
  would be a larger, separate scope) — accent color only for v1.
- No overlap/interaction logic with Ramadan mode's own framing beyond
  both reading from the same date-awareness mechanism if convenient —
  Ramadan mode (item 1) is a functional/scheduling feature, this is purely
  cosmetic.

## Proposed approach (high-level)

The existing theme setup already centers on a single seed color driving
`ColorScheme.fromSeed` plus a layer of per-module accents — the seasonal
feature is best framed as a date-gated variant of that same seed rather
than a parallel theming mechanism, so on a recognized occasion the app
computes its color scheme from a seasonal seed color instead of the
default teal, and everything downstream (per-module accents, semantic
colors, dark/light variants) continues to derive the same way it already
does. Date detection needs a small calendar-awareness piece (Gregorian
dates for Pohela Boishakh, Hijri/lunar dates for the two Eids, likely
needing the same kind of date source considered for Ramadan mode) that
flips which seed is active for a bounded window (e.g., the day itself
plus a day or two either side). The Settings opt-out is a simple boolean
that, when set, keeps the app on its default seed regardless of date.

## Dependencies & prerequisites

- The existing `app_theme.dart` seed-color/`ColorScheme.fromSeed`
  mechanism and the `ModuleAccents`/`AppSemanticColors` extension it
  already feeds.
- A Hijri/lunar date source for the two Eid dates (potentially shared
  with Ramadan mode's own date-detection need, if that feature exists by
  the time this is built).
- Settings UI space for the opt-out toggle.
- A small curated color palette per occasion (design decision, not
  engineering).

## Open questions for the implementation round

- Should this share its date-detection mechanism with Ramadan mode (item
  1), or are they independent enough to build separately without
  coordination risk?
- How wide is each occasion's active window — single day only, or a few
  days around it (Eid especially tends to be experienced as a short
  multi-day period)?
- Does the opt-out toggle disable seasonal theming entirely, or offer
  granular per-occasion control (likely overkill for v1)?
- Are there other dates worth including in the curated set (e.g.,
  Independence Day, Victory Day) or does this stay strictly to the three
  named occasions to keep scope tight?

## Effort & sequencing notes

Complexity M — the theming mechanism itself is a small, contained change
riding on existing infrastructure, but date-detection (especially lunar
Eid dates) adds real complexity disproportionate to the visual payoff.
Natural to sequence alongside or after Ramadan mode (item 1) if both end
up sharing a Hijri-date-detection dependency, to avoid solving that
problem twice.
