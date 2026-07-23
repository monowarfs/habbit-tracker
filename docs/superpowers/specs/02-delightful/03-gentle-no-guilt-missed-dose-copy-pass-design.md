# Gentle No-Guilt Missed-Dose Copy Pass

**Category:** Delightful · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

The app's own persona work already names this explicitly: Rafiq wants to
"slowly rebuild prayer consistency without a judgmental or preachy app
tone," and Qadha tracking is called out as needing to work "without guilt-
tripping UI copy." Medicine's dose-status model has an explicit `missed`
state and Prayer has missed-prayer/Qadha detection — both are exactly the
places where copy tone matters most, and both were built across several
runs by different passes of work, which is precisely when tonal drift
creeps in (one screen says "Missed!", another says "You didn't take this,"
a third uses red exclamation-mark styling that undercuts even careful
wording). Finch is the most-cited benchmark for getting this right: it
treats a lapse as neutral information, never a scolding. This is a pure
writing/audit pass, not new functionality, but it ships as a discrete
piece of work because it touches every "missed"/"skipped"/"Qadha" string
across two languages.

## Goals

- Audit every user-facing string in both ARB files that touches a missed
  dose, missed prayer, Qadha, or skipped anything, for tone as well as
  literal translation accuracy.
- Establish (and write down) a short house-style guideline for this
  category of copy, so future runs don't have to rediscover the same
  judgment call per string.
- Apply corrected copy consistently across notification text, in-app
  status labels, and any related iconography/color that reinforces a
  guilt tone (e.g., alarming red where a neutral tone would do).
- Make sure the Bangla (bn) strings get the same tonal scrutiny as
  English, not just a literal translation of an English pass.

## Non-goals / out of scope

- No changes to the underlying missed/skipped state machine logic
  (Medicine's dose-status derivation, Prayer's missed-prayer detection) —
  copy only.
- No redesign of the Qadha screen's layout or the −1 make-up control
  itself, beyond label text.
- No new localization infrastructure or additional languages.
- Not a full app-wide copy audit — scoped specifically to the missed/
  skipped/Qadha semantic category.

## Proposed approach (high-level)

This is best run as a review pass across the existing en/bn ARB source
files rather than anything architectural: enumerate every string key used
by Medicine's dose-status displays, Prayer's missed-prayer/Qadha surfaces,
and the notification content those two modules generate for missed/
skipped states, then re-word each one against a simple test ("would this
make Rafiq feel bad about himself, or just informed?"). Any icon/color
choices that carry an implicit guilt signal (hard red, exclamation marks,
words like "failed") get flagged alongside the copy even though this spec
is primarily about text, since tone is carried by more than words alone.
The output is a small, reviewable style note plus the corrected ARB
entries — no new screens, no new state.

## Dependencies & prerequisites

- Full inventory of missed/skipped/Qadha-related keys in both `app_en.arb`
  and `app_bn.arb`.
- A native or highly fluent Bangla speaker's review, not just a
  translated-from-English pass, so the Bangla tone is judged on its own
  terms.
- Awareness of where color/iconography (not just text) reinforces status,
  since a "gentle" string next to a harsh red icon still reads as guilt-
  tripping.

## Open questions for the implementation round

- Does this pass also cover onboarding/empty-state copy that references
  "you haven't started yet," or stay strictly scoped to missed/skipped
  states?
- Should the house-style guideline live as a short doc future contributors
  check before adding new strings, to prevent regression?
- Are there existing strings that are fine in English but land harsher in
  Bangla idiom (or vice versa) — does this need a bilingual reviewer
  working the two languages side by side rather than sequentially?

## Effort & sequencing notes

Complexity S — no code logic changes, bounded to string content in two
files plus any icon/color follow-ups it surfaces. No dependency on other
atlas items; cheap to do any time, and arguably worth doing before other
Delightful-category copy-heavy features (like item 6's micro-education
cards or item 11's greeting) so the tone guideline exists before more
copy gets written.
