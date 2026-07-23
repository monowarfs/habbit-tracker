# [REQUIRES ACCOUNT] Cloud Accountability Groups

**Category:** Community · **Atlas complexity:** L · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Small accountability groups — a handful of people who can see each other's streak *completion* (not raw health data) — are one of the strongest retention mechanics in the category, per Habitica's parties and Strava's social feed. But this app is currently, deliberately, a no-account, offline-first, zero-server product (see `docs/strategies/analytics-future.md`'s equivalent stance on analytics, and the same posture almost certainly extends to any data leaving the device today). This is the first feature on the entire Community atlas that cannot be built without crossing that line. It should not be treated as a routine feature request — it is a foundational architecture and product-values decision that every other "REQUIRES ACCOUNT" item on this atlas would then piggyback on.

## Infrastructure implication
**REQUIRES ACCOUNTS + BACKEND.** This is not a checkbox to tick lightly. Building this means the app acquires, for the first time: user identity (even if pseudonymous/device-linked rather than email/password), a server that stores and serves other users' data to a client, an account-recovery story, a terms-of-service/privacy-policy obligation that goes beyond today's "nothing leaves the device" claim, and an ongoing operational cost and security surface. Every one of these is a durable, hard-to-reverse commitment, not an incremental feature toggle. This decision should be made explicitly by whoever owns the product direction, independent of and prior to any engineering estimate for the feature itself.

## Goals (if the account/backend decision is made)
- Let a small, opt-in group of users (e.g. 2-10 people) see a coarse signal of each other's adherence — most plausibly a boolean "completed today" or streak-length number per module, never raw entries (e.g. never "took 200mg at 8am", never specific prayer times, never water amounts).
- Preserve the local-first experience for everyone *not* opted into a group — group membership must be fully additive, never a requirement to use the app's core modules.
- Give every group member a clear, easy way to leave a group and have their data stop being shared.

## Non-goals / out of scope
- Not deciding, in this document, whether to build accounts at all — that decision sits above this spec.
- No raw data sharing (specific medicine names/doses, specific prayer times, water log entries) — only aggregate completion/streak signals, mirroring the "coarse events only" redaction principle already established for the no-op analytics design.
- No public/global groups — accountability groups are explicitly small and invite-only.
- No chat/messaging between group members in this scope (that's an additional, separate feature if ever wanted).

## Proposed approach (high-level)
Contingent on the account/backend decision being made affirmatively and separately: introduce a lightweight account concept (likely device-linked/pseudonymous rather than full email/password, to minimize scope) purely to support group membership and sync of the coarse completion signals — not to gate any existing local functionality. A backend service stores group membership and the minimal per-day/per-module completion booleans or streak counts each member opts to share; the existing per-module day-status/streak calculations (already used by `core/reports` and each module's own streak use cases) become the *source* of the shared signal, computed locally and only the coarse result transmitted, never raw entries. Sync is pull/push at low frequency (this is not a real-time chat feature) to keep backend cost and complexity down.

## Dependencies & prerequisites
- An explicit, separate product decision to introduce accounts and a backend — the primary and largest prerequisite, requiring its own review (legal/privacy/ops), not something this spec can approve on its own.
- A privacy/consent review at least as rigorous as the checklist in `docs/strategies/analytics-future.md` (affirmative opt-in, updated store data-safety disclosures on both Play Console and App Store Connect, a durable off switch, a deletion story) — arguably a stricter bar than analytics since this shares data with other named people, not just an aggregate metrics vendor.
- A backend build-or-buy decision (self-hosted minimal service vs. a BaaS vendor) with its own security review, since it now handles data about specific individuals' health/religious-observance habits.
- A group invitation/membership mechanism (invite codes or links) and an account-recovery story for lost devices.

## Open questions for the implementation round
- Pseudonymous device-linked identity vs. full account (email, phone, or social login)? This materially changes scope and the account-recovery story.
- What exact signal is shared — a boolean per day, a streak integer, or something richer? Where is the line drawn to keep it "completion, not raw health data"?
- What happens to a user's shared history if they later delete the app or request deletion — does it disappear from other group members' views retroactively?
- Self-hosted minimal backend vs. an existing BaaS (Firebase, Supabase, etc.) — each carries different privacy/vendor-lock-in trade-offs.
- Does this feature depend on or block item 09 (Ramadan community challenge), which is listed as needing "the accountability-groups feature above" as its own dependency?

## Effort & sequencing notes
Large (L) complexity, and the single highest-risk item in the Community category precisely because it's the one that breaks the app's current architectural promise. Should not be estimated or scheduled as ordinary feature work — the account/backend decision needs to happen first, on its own timeline, separately from any sprint planning for the feature's UI/UX. If approved, this also becomes a prerequisite for item 09 and lowers the bar for item 07 and item 11, since all three assume some form of backend already exists.
