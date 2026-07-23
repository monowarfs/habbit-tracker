# [REQUIRES ACCOUNT] Caregiver Read-Only View Link

**Category:** Community · **Atlas complexity:** L · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
The caregiver persona — someone managing or checking in on a dependent's (a parent's, a child's) medicine adherence or prayer observance — is directly named as a gap: they currently have no way to check on a loved one's adherence without either sharing the device outright or asking in person. A time-limited, revocable read-only view link is a narrower, lower-risk version of full account sync — it doesn't require the caregiver to have their own persistent account or the dependent to expose everything, only a scoped, expiring, revocable window into specific adherence data. It's High retention impact because it directly serves a named, real use case (Medicine adherence is the most obvious fit, though Prayer/Water checklists could apply too), but it's also the largest and riskiest item in this category alongside item 06.

## Infrastructure implication
**REQUIRES A BACKEND** (a temporary relay service issuing and validating expiring tokens), even if it stops short of full user accounts. This is a materially smaller backend surface than item 06's persistent group accounts — no login, no persistent identity, just a token-scoped relay — but it is still a backend, still means data leaves the device, and still needs the same category of decision-making rigor as item 06: this is not an incremental feature, it's the app's second (alongside item 06) genuine architecture change away from "nothing leaves the device," and should be decided explicitly and separately, not bundled into an ordinary feature estimate.

## Goals (if the backend decision is made)
- Let a user (the dependent, or whoever manages the tracked person's data — e.g. a parent managing a child's Medicine module) generate a time-limited, revocable link that a caregiver can open (in a browser or a lightweight companion view) to see read-only adherence status.
- Scope what's visible tightly — most plausibly Medicine dose-taken/missed status and streak, not the full app, not raw personal details beyond what's needed to see "did they take their medicine."
- Make revocation immediate and easy — the dependent (or the account holder) can kill the link at any time, and expiry should also happen automatically after a bounded window even if never manually revoked.
- Require no account or app install on the caregiver's side for the simplest version — opening a link should be enough.

## Non-goals / out of scope
- Not building bidirectional sync, caregiver write-access, or caregiver-side reminders/notifications — this is read-only, one-directional visibility.
- Not building a persistent caregiver account or relationship model (e.g. no "caregiver dashboard" listing multiple dependents) in v1 — one link, one dependent, one bounded window.
- Not exposing raw entries (specific doses/times/amounts) by default — adherence status/streak only, mirroring the same coarse-signal principle used in item 06, unless a later, explicit design decision expands this.
- Not deciding, in this document, whether the backend/relay investment is justified — that's a separate product/security decision, same as item 06.

## Proposed approach (high-level)
Contingent on the backend decision: when a user opts to share caregiver access (likely initiated from Medicine's existing dose/adherence screens, reusing the same adherence/dose-status data `effectiveDoseStatus` and the adherence calculator already produce), the app requests a short-lived, scoped token from a minimal relay backend. That token becomes a URL the user shares (via the same native share sheet used in items 01/02) with the caregiver. Opening the link hits the relay, which validates the token hasn't expired or been revoked, and serves a read-only rendering of the relevant adherence data — pulled from the same data the token's issuing device last synced up, not a live continuous connection. The dependent's device retains a visible list of active/issued links with a one-tap revoke.

## Dependencies & prerequisites
- A temporary backend relay capable of issuing, validating, and expiring tokens, and serving a minimal read-only view — the primary and largest prerequisite, needing its own security review (expiring tokens are a common source of subtle vulnerabilities — token length/entropy, expiry enforcement, revocation propagation delay all need explicit design, not assumption).
- A privacy/consent review at least as rigorous as item 06's, since this exposes a specific named dependent's health-adherence data (Medicine, especially) to a third party (the caregiver) via a link that could in principle be forwarded or intercepted — the security model needs to account for a leaked link, not just an honest caregiver.
- Medicine's existing dose-status/adherence calculation logic as the data source (`effectiveDoseStatus`, the adherence calculator) — no new domain logic needed for what's *shown*, only for how it's securely relayed.
- share_plus (already a dependency per item 01/02) for distributing the generated link.

## Open questions for the implementation round
- What's the token's lifetime model — fixed expiry (e.g. 7 days) only, or also a maximum-uses/one-time-view option?
- Does the relay need to store any adherence data at rest (even temporarily), or can it proxy a live pull from the dependent's device on each caregiver view (which would avoid storing sensitive data server-side at all, at the cost of requiring the dependent's device to be reachable/online at view time)? This materially changes the security posture and is worth resolving early.
- Which modules are in scope for v1 — Medicine only (the most obviously caregiver-relevant), or Prayer/Water too?
- What does revocation look like from the caregiver's side — do they see a "this link has been revoked" message, or does it just silently stop working?
- Is there a risk of this feature being used coercively (e.g. a controlling relationship monitoring someone against their wishes) that needs UX safeguards — e.g. requiring the dependent to actively generate and share the link themselves, never letting a caregiver request/pull access unprompted?

## Effort & sequencing notes
Large (L) complexity and, alongside item 06, one of the two highest-risk items in this category because both require crossing the no-account/no-backend line. Unlike item 06, this one can plausibly use a smaller, token-only relay rather than full persistent accounts, which may make it a cheaper way to test whether *any* backend investment is worth making — but the backend/security decision still needs to be made explicitly and separately before this is estimated as ordinary feature work, not folded into a sprint by default.
