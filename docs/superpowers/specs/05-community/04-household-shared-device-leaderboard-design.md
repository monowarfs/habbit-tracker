# Household Shared-Device Leaderboard

**Category:** Community · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Families often share a single phone, or multiple family members each have the app installed and compare progress informally already (e.g. "who prayed more this week"). Habitica's "party" mechanic shows this kind of light competition drives engagement, but this app has no concept of multiple people at all yet. Once multi-profile support exists (a Premium-category feature, tracked separately), a same-device leaderboard comparing profiles is a natural, low-risk extension — it needs no network since every profile's data already lives on the one device.

## Infrastructure implication
Zero-infra *conditional on* multi-profile already existing. This feature itself adds no server, no account, no network call — it's pure local aggregation across profiles that already live in the same on-device database. The real prerequisite is the Premium-category multi-profile feature; this spec assumes that lands first and does not re-plan it here.

## Goals
- Once multiple profiles exist on one device, show a simple comparative view (e.g. streak length, adherence %, day-completion rate) across profiles for the current household.
- Keep the comparison friendly/motivational in tone (this is a household, not a public leaderboard) — framing should avoid shaming a family member who's behind.
- Reuse existing per-module streak/adherence/day-status calculations rather than inventing new scoring logic.

## Non-goals / out of scope
- Not building multi-profile support itself — that's a separate, already-tracked Premium-category feature and a hard prerequisite, not something re-planned here.
- No cross-device sync — this is explicitly same-device only, since that's what makes it zero-infrastructure. Comparing across two different phones would require the account/backend features (items 6/11) instead.
- No public/global leaderboard — that's a different, much larger feature (would require accounts).
- No notifications/nudges based on leaderboard standing in v1 (e.g. "you're behind Mom this week") — that's an enhancement to consider later, not part of this spec.

## Proposed approach (high-level)
Once multi-profile exists, add a household comparison view (likely on the Dashboard or Reports screen) that reads each profile's existing streak/day-status/adherence data — the same `core/reports` aggregation and per-module streak use cases (Water's streak calculator, Medicine's adherence calculator, Prayer's streak/adherence calculators) already used for the single-profile Reports screen — and renders them side by side per profile, scoped to the local device only.

## Dependencies & prerequisites
- Multi-profile support (Premium category) — hard prerequisite, must exist first.
- Existing `core/reports` aggregation logic and each module's streak/adherence use cases.

## Open questions for the implementation round
- What exactly does multi-profile mean in this app's data model once it ships — separate database rows scoped by profile id, or fully separate databases? That shapes how cheap or expensive cross-profile aggregation queries are.
- What's the comparison metric — day-completion %, streak length, or a composite score? Does it need to be configurable, or is one metric enough for v1?
- How is tone handled for family members who are behind (e.g. a child managing medicine adherence) — is there a risk of this feeling punitive rather than motivating?
- Does this live on the Dashboard, a dedicated screen, or inside Reports?

## Effort & sequencing notes
Medium (M) complexity, but entirely gated on multi-profile shipping first — this cannot be scheduled independently. Once that prerequisite lands, the feature itself is mostly presentation/aggregation work reusing existing calculators, not new domain logic.
