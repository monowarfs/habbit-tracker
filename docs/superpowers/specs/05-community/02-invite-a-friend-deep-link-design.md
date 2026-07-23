# Invite-a-Friend Deep Link

**Category:** Community · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Users who like the app currently have no lightweight way to invite someone else — they'd have to manually find and paste a store link. A generic "invite a friend" action (a store link with a referral tag baked into the query string) is a standard, zero-infrastructure growth lever that doesn't require an account or a server round-trip to work at a basic level. It matters less for retention of the inviting user than item 01, but it's cheap enough to bundle alongside it.

## Infrastructure implication
Zero-infra for the core mechanic (share a tagged URL via the OS share sheet). Attribution — actually knowing "user B installed because of user A's link" — needs a deep-link parsing library on the receiving side, but that's still on-device parsing of a URL, not a backend. No account, no server required for either half.

## Goals
- Give users a one-tap "invite a friend" action that shares a store link (Play Store / App Store) with an embedded referral identifier.
- On the receiving end, if the app is freshly installed via that link, recognize the referral tag on first launch (best-effort, on-device only).
- Keep the whole flow functioning with zero network dependency beyond the OS store's own install mechanics.

## Non-goals / out of scope
- No server-side attribution/analytics pipeline — this is explicitly not building a referral-tracking backend.
- No reward/incentive mechanic (e.g. "invite 3 friends, unlock X") in this feature; that would be a separate, later product decision layered on top.
- No cross-platform (Android referrer API vs iOS) parity guarantee — the two platforms have very different native referral mechanisms and this spec doesn't commit to matching them exactly.

## Proposed approach (high-level)
Reuse the same native share-sheet mechanism as item 01 (share-a-streak) to send a plain store URL with a query-string referral tag identifying the inviter (e.g. a locally-generated anonymous device/install id, never a real identity). On the receiving device, use a deep-link/app-links parsing library to detect if the app was opened via such a link on first cold start, and store a local flag noting "this install came from a referral" — purely informational, no round-trip to confirm it, no dependency on any backend to function.

## Dependencies & prerequisites
- `share_plus` (shared with item 01).
- `app_links` (or equivalent) for parsing the referral tag out of a deep link on first launch.
- A decision on what identifier is embedded in the tag (must not be a real account id, since this app has none — a random locally-generated string is enough).

## Open questions for the implementation round
- Is Android Play Install Referrer API in scope, or is a plain deep-link (App Links / Universal Links) parse sufficient for v1?
- Where does the "invited by a friend" flag get surfaced, if anywhere — is it purely internal bookkeeping with no UI, or does it unlock anything?
- Given no backend, is there any actual value in tracking attribution at all, or is a bare "share this app" link (no tag) sufficient for v1, deferring the tagged/attributed version entirely?
- Does the store listing's data-safety disclosure need any update for a locally-generated referral identifier being embedded in a shared link?

## Effort & sequencing notes
Small (S), and naturally pairs with item 01 since both use `share_plus` and the native share sheet. Worth asking at scheduling time whether the attribution half is worth building at all given the low retention impact — the plain untagged share link alone may be the pragmatic v1.
