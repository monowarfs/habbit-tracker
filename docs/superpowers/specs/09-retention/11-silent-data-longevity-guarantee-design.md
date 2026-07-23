# Silent Data-Longevity Guarantee

**Category:** Long-Term Retention · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
A user with two years of logged water, doses, and prayers has built something that only has value if it's still there tomorrow — and unlike a cloud service where retention policy is at least discoverable, a local-first app's silence about its own retention behavior can quietly seed a fear that an update might prune old history, cap it, or otherwise "clean up" the database without asking. That fear costs nothing to have and everything to act on: a user who half-believes their history could vanish on the next update has a hidden reason to disengage or stop trusting the app's longevity, exactly the kind of erosion this whole category exists to prevent. Stating the guarantee explicitly turns a silent assumption into a documented commitment.

## Goals
- Publish a clear, plain-language commitment (in Settings > About) that local history is never pruned, capped, or reduced by app version or update.
- Back the commitment with an actual audit confirming the current database retention behavior matches what's claimed (no silent caps or cleanup jobs already exist that would make the statement false).
- Keep the commitment visible somewhere a user would naturally look when wondering "is my history safe" — About screen, alongside other trust statements.

## Non-goals / out of scope
- No new backup/export mechanism — this is a retention-policy statement, not a new data-safety feature (export/import already exists via the Data settings screen).
- No migration tooling changes in this pass — if the audit finds an actual retention risk (e.g. a rolling-window table meant to cap history), fixing that is a separate, possibly larger, engineering task flagged for follow-up, not silently bundled into this copy-focused spec.
- No legal/contractual guarantee language — plain, honest product copy, not a formal SLA.

## Proposed approach (high-level)
Two parts: first, an audit of actual current retention behavior across the database — most modules keep full history, but Medicine's dose table is explicitly described as a rolling window, which needs to be understood clearly before making a blanket "never pruned" claim (a rolling operational window for upcoming/near-term doses is different from summary history/streak data being capped, but the guarantee's wording needs to be accurate about which is which rather than overpromising). Second, once the actual behavior is confirmed safe to promise, add the commitment as copy in the About screen alongside whatever other trust-building statements exist there (or alongside the offline-data reassurance in Data settings, if that's a better fit). This is fundamentally a documentation-and-copy task gated on a real audit, not new engineering, unless the audit surfaces something that needs fixing first.

## Dependencies & prerequisites
- An About screen (or equivalent) to host the copy — confirm it exists or identify the nearest equivalent settings surface.
- A retention-policy audit across all tables in the central database, specifically distinguishing rolling/derived windows (like the Medicine dose materialization window) from permanent history/log tables, so the guarantee is worded precisely rather than overstated.
- Coordination with the Data settings reassurance feature (#8), since both are trust-copy additions and may want consistent phrasing/placement.

## Open questions for the implementation round
- Does the rolling dose-materialization window need caveat language in the guarantee ("your dose history is never pruned; only the near-term upcoming-dose projection is periodically regenerated"), or is that distinction confusing to a general user and better left unsaid/reworded?
- Is About screen the right home, or should this live in Data settings next to the offline reassurance instead?
- Does this commitment need to be revisited/re-audited as a standing checklist item on future schema changes, to stay true over time?

## Effort & sequencing notes
Complexity S for the copy itself; the audit is the part worth taking seriously since the guarantee is only as good as it is true. Natural to pair with the offline-data reassurance feature (#8) in the same implementation pass, given both are short trust-building copy additions to adjacent settings surfaces.
