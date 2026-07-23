# Family / Multi-Profile

**Category:** Premium · **Atlas complexity:** L · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
This is roadmap.md's #4 v1.1+ candidate, and directly matches the
caregiver persona (Farida) that recurs throughout this project's planning
docs — someone tracking medicine/water/prayer adherence for a parent or
child, not just themselves. Right now the app is single-profile, single-
device, single-user by construction. Caregivers are explicitly called out
in the roadmap as the persona most likely to ask for this, making it the
most-requested premium feature this persona set implies, even though it's
sequenced last among the roadmap's top candidates because it's most
valuable once sync also exists.

## What stays free vs. what's paywalled
A single user tracking their own habits stays entirely free, with no
change to today's experience. What's paywalled is managing more than one
profile from one installation — e.g. a caregiver switching between "Mom"
and "Dad" profiles, or a parent managing a child's medicine schedule
alongside their own — and any cross-device caregiving view (checking a
parent's adherence from the caregiver's own phone). The free tier is not
artificially capped at "1 profile" as a trick; today's app simply has no
profile concept at all, so this is additive premium depth, not a
retroactive restriction.

## Goals
- Let a single installation hold multiple independent profiles, each with
  its own Water/Medicine/Prayer data, switchable without re-onboarding.
- Support the caregiver use case: viewing/managing another profile's data
  from the caregiver's own device, once sync (item #2) exists to move
  that data between devices.
- Keep each profile's data model identical to today's single-profile
  model — this is a scoping/partitioning feature, not a new data shape.

## Non-goals / out of scope
- Not building real-time multi-user collaboration (two people editing the
  same profile simultaneously) — one profile still has one primary owner.
- Not solving cross-device caregiving without sync already in place —
  that combination is explicitly why this is sequenced after item #2.
- Not designing permission/sharing UX in detail here — that's for the
  implementation round once sync's data-movement model is settled.

## Proposed approach (high-level)
Introduce a profile-scoping concept above the existing database schema:
every module's tables (`water_*`, `medicine_*`, `prayer_*`, plus
`settings`) would need a profile identifier added to their row scope, the
same kind of append-only manifest-level change future-expansion.md
already establishes as acceptable for adding a new module's tables (a
one-line addition to a shared list, not a rewrite of existing module
code). The `HabitModule` contract itself likely doesn't need to change —
profile scoping is a cross-cutting concern below the repository layer,
similar in shape to how sync (item #2) would be layered in. A profile
switcher becomes a new top-level UI surface (likely near Settings), and
cross-device caregiving views build on whatever sync already established
for moving one profile's data between devices.

## Dependencies & prerequisites
- Multi-device sync (this spec set's item #2) should exist first for the
  cross-device caregiving scenario to be meaningful — a caregiver
  managing a parent's data on the parent's own device requires that data
  to move between devices at all.
- A profile-scoping change to the database schema (every existing table
  gains a profile reference) — the single largest schema-touching item
  in this whole premium batch.
- Decide whether Settings (theme/locale/etc.) is global-per-device or
  per-profile — an open design question with real UX consequences.

## Open questions for the implementation round
- Is a "profile" fully independent (its own achievements, streaks,
  settings) or does some state (theme, locale) stay device-level and
  shared across profiles on that device?
- How does notification scheduling work with multiple profiles active on
  one device — whose reminders fire, and how are they distinguished in
  the notification tray?
- What's the caregiver permission model — full read/write on another
  profile, or a lighter-weight read-only view for a subset of data?
- Does switching profiles require re-authentication of any kind, or is it
  purely a local UI selector (no sync) until sync exists?

## Effort & sequencing notes
L complexity — comparable in size to sync because it touches every
existing table's scoping. Sequenced after sync (#2) validates and builds
the data-movement machinery a caregiver's cross-device use case actually
needs; building this before sync would only cover the single-device
"manage two profiles on my own phone" case, a smaller but not worthless
partial version worth flagging to the implementation round.
