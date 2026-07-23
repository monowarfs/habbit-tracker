# Milestone Certificate Image

**Category:** Gamification · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Milestones like a 100-day streak currently have no artifact of their own
beyond an entry in the badge gallery. Apps like Strava mark big milestones
with a shareable, dignified image (a race medal, a finisher card) rather
than a childish sticker — a framing that fits this app's health-adjacent,
adult audience better than a cartoon badge. A generated certificate image
gives users something concrete to save or share outside the app, extending
the milestone's value beyond the moment it unlocks.

## Goals

- Generate a shareable image for significant milestones (e.g. streak
  length thresholds) with the user's name/stat and date on it.
- Reuse the app's existing visual language (theme, module accents) so the
  certificate feels native to the app rather than a bolted-on template.
- Make the image easy to save or share via the platform's normal share
  sheet.

## Non-goals / out of scope

- A full custom template designer or user-chosen certificate styles — one
  clean design per milestone type for v1.
- Certificates for every achievement — reserved for genuinely significant
  milestones (e.g. streak-length thresholds), not every small badge.
- Cloud upload/hosting of the generated image — it is rendered and shared
  locally, consistent with the app's offline-first design.

## Proposed approach (high-level)

If the app already has a recap-card renderer (a mechanism that composes a
shareable image from app data and theme), a certificate is a new template
on top of that same rendering path rather than a new image-generation
system — it needs the same inputs (a stat, a date, the app's theme/accent
colors) that a recap card already knows how to lay out. The trigger would
be the achievements engine recognizing a qualifying milestone (e.g. a
streak-length achievement unlocking) and offering the certificate as a
follow-up action, handed to the platform's native share sheet.

## Dependencies & prerequisites

- An existing recap-card (or equivalent shareable-image) renderer to
  extend with a certificate template.
- The achievements engine, to identify which unlocks qualify as
  certificate-worthy milestones.
- Platform share-sheet integration (if not already used elsewhere in the
  app for sharing).

## Open questions for the implementation round

- Which milestones actually warrant a certificate — every streak-length
  achievement, or only a curated subset (e.g. 30/100/365 days)?
- Is the certificate generated once and stored, or regenerated on demand
  each time the user wants to share it?
- Does the certificate include the module (e.g. "100-Day Water Streak")
  or is it framed as an overall achievement, and does that depend on
  whether the cross-module XP/level system exists by then?
- What happens on locales/languages other than English/Bangla — does the
  certificate need its own localized template text?

## Effort & sequencing notes

Small, assuming a recap-card renderer already exists to extend; otherwise
this absorbs the cost of building that rendering path first, which would
push it toward Medium. No hard dependency on other gamification features
in this batch, though it pairs naturally with milestone-triggering
features like the streak system and XP levels once those exist.
