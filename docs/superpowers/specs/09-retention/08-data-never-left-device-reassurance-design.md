# Periodic "Your Data Never Left This Device" Reassurance

**Category:** Long-Term Retention · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Trust is the kind of retention driver that's invisible when it's working and fatal when it erodes — and it erodes fastest through silence. A user who chose this app specifically because it's offline and account-free in month one can, by year two, simply forget that's true, especially as other apps in their life keep asking them to log in or sync to the cloud. Without an occasional, low-key restatement of the offline promise, that original reason for trust quietly fades from a stated fact to a vague assumption the user no longer feels reassured by — exactly the kind of erosion that makes a long-term user start to wonder, without ever being told otherwise.

## Goals
- Restate the offline/no-account/local-only-data promise somewhere the user will actually see it, on a rare, non-intrusive cadence.
- Keep it purely informational — no action required, no dismiss-tracking complexity.
- Reinforce trust without ever feeling like an ad or an upsell.

## Non-goals / out of scope
- No push notification for this — a notification about privacy would itself feel like an intrusion; this belongs inside a screen the user visits deliberately.
- No new privacy policy or legal copy changes — this is a UI reassurance, not a compliance document update.
- No tracking of whether the user has "seen" this message — it's meant to be encountered ambiently, not gated behind a one-time flag.

## Proposed approach (high-level)
The existing Data settings screen is already the natural home for this — it's where a user goes to think about their data, making it the right place for an ambient reminder rather than a popup elsewhere in the app. Add a small, permanent (not dismissible, not one-time) piece of copy inside that screen restating that all data stays on-device, nothing is uploaded, and there's no account. Because it lives on a screen the user visits only occasionally by nature (export/backup/data-management tasks), the "rare" cadence the goal calls for falls out naturally from placement rather than needing any scheduling mechanism at all.

## Dependencies & prerequisites
- The existing Data settings screen, as the sole surface this touches.
- Copy review to make sure the wording accurately reflects the app's actual data handling (no network calls, no analytics, no account) so the reassurance is truthful, not just comforting-sounding.

## Open questions for the implementation round
- Is a static copy block sufficient, or does the atlas intend something slightly more prominent (e.g. a small icon-and-caption card) to make it registered rather than skimmed past?
- Should this also appear once during onboarding, or is Settings > Data the only intended surface?
- Does this need bn localization parity from day one (yes, per the app's existing en/bn standard) — just flagging it's not optional.

## Effort & sequencing notes
Complexity S — copy addition to an existing screen, no new logic, no new schema. Very low effort, can be done at any time independent of the rest of this category; consider bundling it into the same pass as the data-longevity guarantee feature (#11) since both are trust-building copy additions to adjacent settings surfaces.
