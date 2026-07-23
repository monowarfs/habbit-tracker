# Household/Family Plan Long-Term Hook

**Category:** Long-Term Retention · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
A user who has stayed a full year is the exact profile most likely to be managing habits for someone else too — a parent tracking a child's medicine, a caregiver watching an aging parent's prayer or medication adherence. Right now that user has no path to bring a second person into the app they already trust; they either juggle a second install or give up and use something else for that person. The natural year-two expansion isn't a new feature for the existing user, it's inviting the people they already care for into the relationship they've already built with the app — which is also, not incidentally, the natural point to introduce a household-tier subscription.

## Goals
- Establish the conceptual and commercial hook for a household/family plan, once multi-profile support exists.
- Position it specifically as a year-two-and-beyond upsell aimed at users who have already demonstrated sustained engagement, not a day-one pricing tier.
- Keep this spec scoped to the retention/positioning rationale — the actual multi-profile data model and subscription/billing mechanics belong to their own specs (Premium category, multi-profile foundation).

## Non-goals / out of scope
- No multi-profile data model design in this spec — that is an explicit prerequisite feature living outside this category (Premium category).
- No billing/subscription/store-integration mechanics — those belong to the Premium-category feature that owns monetization.
- No caregiver-specific UI (shared dashboards, permission levels) designed here — this spec only establishes that the hook exists and roughly when it should be surfaced, not how it's built.

## Proposed approach (high-level)
This is a positioning and sequencing spec more than an implementation one: it exists to record that once a multi-profile foundation is built, a household-tier offering should be surfaced to long-tenured single-profile users as a natural next step, not cold-marketed to new users. The trigger for surfacing this offer should reuse the same tenure signal the anniversary-badge and recap features rely on — a user who has passed some meaningful tenure threshold (a year is the natural anchor already used elsewhere in this category) is shown an "add a household member" prompt, most plausibly from Settings or the same recap/anniversary moment where the app is already reflecting on the relationship's length. No new tracking is needed beyond what tenure-based features already require.

## Dependencies & prerequisites
- Multi-profile support (a foundational feature living outside this category — this spec is inert without it).
- The Premium-category feature that defines subscription tiers and billing, since "household plan" is fundamentally a monetization construct.
- The same install-date/tenure tracking the anniversary-badge and recap features depend on, reused for surfacing the offer at the right moment rather than immediately.

## Open questions for the implementation round
- What tenure threshold (one year, matching the anniversary badge, or something shorter/longer) is right for surfacing a household upsell?
- Does the offer surface proactively (a prompt) or only reactively (discoverable in Settings when the user goes looking)?
- How does this interact with users who already use Medicine/Prayer for someone else's care today, informally, on the same profile — is there a migration path?

## Effort & sequencing notes
Complexity S for this spec's own scope (positioning + trigger reuse) — but it is fully blocked on multi-profile support and the Premium subscription feature, both larger prerequisites outside this category. Sequence this strictly after those land; until then this spec is a placeholder recording the intended year-two hook.
