# "Why This Matters" Micro-Education Cards

**Category:** Delightful · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Both Atomic Habits (the book this app draws its stacking/identity-based
framing from) and Finch share a pattern this app hasn't adopted yet:
teaching the "why" behind a habit briefly, once, at the moment it's most
relevant, instead of front-loading a tutorial nobody reads. A first-time
Water user doesn't necessarily know why hydration matters beyond "the app
told me to," and a first-time Qadha screen visitor may not know the
ruling context behind make-up prayers. A single dismissible one-liner the
first time a relevant screen opens gives a small credibility and
motivation boost without adding any onboarding friction — directly
serving Nusrat's stated aversion to anything that feels "medical or
heavy" and Rafiq's want for the app to explain things without being
preachy.

## Goals

- Show one short, dismissible educational line the first time a user
  opens specific screens (e.g., Water's goal screen, Prayer's Qadha
  screen).
- Never repeat once dismissed — a true one-time moment, not a recurring
  tip.
- Keep the tone factual and brief, not a lecture — one sentence, not a
  paragraph.
- Cover a small, curated set of genuinely useful moments rather than
  papering every screen with a tip.

## Non-goals / out of scope

- No forced onboarding tutorial or multi-step walkthrough — this
  explicitly replaces that pattern, not supplements it.
- No dynamic/personalized content — static, curated copy per screen is
  enough for v1.
- No in-app "tips library" or browsable help center — these are ambient,
  contextual, one-time only.
- Not a vehicle for feature announcements or growth messaging — strictly
  educational content tied to the habit itself.

## Proposed approach (high-level)

This is primarily a content and light state-tracking feature: a small
set of static strings (added to the existing en/bn localization files
like any other copy) paired with a per-module "has this card been shown"
flag, checked when the relevant screen opens and set once shown. The
natural place for this flag is alongside whatever settings/preferences
storage already tracks other one-time or per-module state, rather than a
new subsystem. Presentation-wise, a small dismissible card or banner at
the top of the screen (consistent with the app's general preference for
non-modal, low-friction UI elements already established for achievement
notices) fits better than any kind of popup or forced dialog.

## Dependencies & prerequisites

- New ARB copy (en/bn) for each chosen micro-education moment.
- A lightweight per-flag "first open" tracking mechanism — could reuse
  whatever settings persistence already exists, or a very small new
  table/preference set.
- Editorial decision-making: which screens actually warrant one of these
  (curated, not exhaustive).

## Open questions for the implementation round

- Which specific screens/moments make the initial curated list — Water's
  goal-setting screen, Prayer's Qadha screen, Medicine's stock/low-stock
  screen, others?
- Where does the "already shown" flag live — new small table, or
  shoehorned into existing settings storage?
- Should users be able to reset/replay these from Settings (e.g., "show
  tips again"), or is one-time truly one-time forever?
- Does content need review by someone knowledgeable on the specific
  claims (hydration science, Qadha rulings) to avoid stating something
  inaccurate or contested?

## Effort & sequencing notes

Complexity S — content plus a small flag-tracking mechanism, no new
domain logic. No dependency on other atlas items; low-risk to ship
whenever there's room, and pairs naturally with item 3's copy-tone audit
since both involve careful, reviewed prose.
