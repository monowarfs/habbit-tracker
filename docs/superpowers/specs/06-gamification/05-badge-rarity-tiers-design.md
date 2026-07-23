# Badge Rarity Tiers

**Category:** Gamification · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

The existing badge gallery presents achievements as unlocked or not, with
no sense of how significant any given badge is. Mobile games have long
used common/rare/legendary framing to give long-tenured players something
to keep chasing after the easy, early badges are already collected —
without that framing, a user who's earned most of the obvious badges may
feel the gallery has nothing left to offer. Applying a rarity tier to
existing and future badges is a purely presentational change that extends
the life of the achievement system already in place.

## Goals

- Assign a rarity tier (e.g. common/rare/legendary) to every achievement
  definition, existing and future.
- Reflect rarity visually in the badge gallery (color, border, icon
  treatment) so it's evident at a glance.
- Make rarity a meaningful signal of actual difficulty/rareness, not a
  cosmetic label slapped on arbitrarily.

## Non-goals / out of scope

- Any mechanical reward tied to rarity (e.g. more XP for rarer badges) —
  this is a framing/presentation feature, not a new reward system, unless
  a later round chooses to connect it to XP.
- Dynamic/computed rarity based on how many users actually earned a badge
  — not meaningful in an offline-first, no-account app with no shared
  telemetry; rarity is authored per-definition, not measured.
- Retroactively re-tiering badges based on future player behavior.

## Proposed approach (high-level)

Each module already declares its own achievement definitions to the
achievements engine. A rarity tier is a small additional attribute on each
definition, authored alongside the existing badge name/description/
criteria when each module lists them. The badge gallery UI reads that
attribute to apply a tier-appropriate visual treatment (e.g. a legendary
badge gets a distinct border/glow versus a common badge's plain
treatment). No change to the achievement engine's evaluation logic is
needed — this only adds metadata and a rendering rule.

## Dependencies & prerequisites

- The achievements table/schema, to hold the new rarity attribute per
  definition.
- The badge gallery UI, for the tiered visual treatment.
- Editorial pass across all three modules' existing achievement
  definitions to assign sensible tiers.

## Open questions for the implementation round

- How many tiers (three vs. four) and what's the qualitative criteria for
  each (e.g. legendary = requires a long streak or a rare combination of
  conditions)?
- Do future modules need to supply a rarity tier as a required field, or
  is it optional with a sensible default?
- Should the "almost there" progress-bar feature (tracked separately)
  visually distinguish rarity while showing an unearned badge's progress?
- Does rarity ever change for an already-shipped badge, and if so, how is
  that migration handled for users who already earned it under the old
  framing?

## Effort & sequencing notes

Small — purely additive metadata plus a gallery rendering change, no new
subsystem. Can ship independently of everything else in this batch;
pairs naturally with the "almost there" progress-bar feature since both
touch the same gallery screen.
