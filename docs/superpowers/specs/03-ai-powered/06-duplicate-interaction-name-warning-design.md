# Duplicate/Interaction Name Warning

**Category:** AI-Powered · **Atlas complexity:** L · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
A user managing multiple medicines (or a caregiver managing them on
someone's behalf) has no signal today if two active medicines they've
entered happen to be a common brand/generic pairing (e.g. adding both a
brand-name and its generic equivalent without realizing they're the same
active ingredient) or a well-known interacting pair. Medisafe ships a
live drug-interaction check backed by a maintained external database;
this app's offline-first, no-account, no-network posture rules that
architecture out, but a small bundled reference table covering the most
common, well-established pairings is still a meaningful safety net
without compromising the app's trust story.

## Goals
- Warn the user, at the point of adding/editing a medicine, if its
  name matches a known brand/generic duplicate or a well-documented
  interacting pair already present among their other active medicines.
- Keep the warning clearly scoped as informational, not medical advice —
  point the user to consult a pharmacist/doctor, never assert a
  diagnosis or dosing recommendation.
- Ship with a bundled, offline dataset covering a deliberately small,
  well-vetted set of common pairings rather than attempting broad
  coverage.

## Non-goals / out of scope
- No live drug-interaction API call of any kind — this stays fully
  offline, matching the app's no-network trust story.
- Not a comprehensive interaction-checking feature — the atlas explicitly
  scopes this as a bundled reference table, not a substitute for a
  pharmacist consultation or a full drug-interaction database.
- No attempt to cover every medicine name/spelling variant, dosage-form
  interaction nuance, or non-common-pairing edge case in the first pass.

## Proposed approach (high-level)
A small bundled dataset (shipped as an app asset, similar in spirit to
Prayer's bundled city dataset) maps known brand names to generic
equivalents and lists a short set of well-established interacting name
pairs. When a medicine is added or edited, MedicineModule checks the new
name against the user's other currently-active medicines using simple
string/alias matching against this bundled table — no external call, no
inference beyond table lookup. A match surfaces as a dismissible warning
banner on the add/edit form, worded carefully as an informational flag
("these are commonly the same/interacting medicine — check with your
pharmacist") rather than a diagnosis. This is squarely a data/content
problem more than a code problem: the bulk of the effort is compiling
and vetting the bundled dataset, not the matching logic itself.

## Dependencies & prerequisites
- A vetted, bundled interaction/duplicate-name dataset — this requires
  legal/medical review before shipping, given it's health-adjacent
  content presented to users making real medication decisions.
- A clear, reviewed disclaimer/copy treatment so the warning can't be
  misread as medical advice.
- MedicineModule's existing add/edit flow as the integration point.

## Open questions for the implementation round
- Who sources and vets the bundled dataset, and what's the process for
  keeping it accurate/updated across app releases (a static asset can go
  stale)?
- What's the legal review bar for shipping any health-adjacent warning
  content, even clearly caveated as informational?
- Does the warning block adding the medicine (requiring explicit
  acknowledgment) or just display non-blocking, given the risk of
  training users to reflexively dismiss safety warnings?
- Should this cover only exact/near-exact name matches, or attempt
  fuzzy matching against common misspellings/brand variants — the latter
  meaningfully increases both matching complexity and false-positive risk.

## Effort & sequencing notes
Complexity L — despite simple matching logic, the dataset-sourcing and
legal/medical review requirements make this the heaviest-effort item in
the category, and retention impact is Low since it's a safety/trust
feature rather than an engagement driver. Reasonable to sequence last
among the on-device items, pending a decision on whether the legal review
overhead is worth taking on at all for a first cut.
