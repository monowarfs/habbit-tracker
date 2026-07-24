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

## Resolved Dependencies
| Prerequisite | Status | Required by |
|---|---|---|
| Data settings screen | **Built** — exists in `lib/features/settings/presentation/` | This spec |
| en/bn localization | **Built** — `app_en.arb`/`app_bn.arb` with generated `AppLocalizations` | This spec |
| Privacy copy review | **Not done** — wording must be audited against actual data handling before shipping | This spec |

## Dependencies & prerequisites
- **Data settings screen**: Already exists in `lib/features/settings/presentation/`. This is the sole surface the reassurance copy touches.
- **Near-duplicate privacy copy**: The existing Settings > Data screen and any existing privacy-related copy elsewhere in the app must be audited for overlap. If two screens already state "data stays on device," this addition must not create a third redundant instance. Consolidate into one authoritative location.
- **Copy review**: Must verify the reassurance wording accurately reflects actual data handling — no network calls, no analytics SDK, no account system. Check `pubspec.yaml` for any packages that make network requests; confirm `flutter_local_notifications` does not phone home. The reassurance must be truthful, not just comforting-sounding.
- **Schema migration**: Not needed for this spec — no new tables or columns.
- **Cross-cutting gap:** Near-duplicate privacy copy — existing privacy-related strings across the app must be audited and consolidated before this spec adds new copy, to avoid redundant or conflicting trust statements (see Resolved Dependencies row 3).

## Open questions for the implementation round
- **Static copy vs. icon-and-caption card**: Decision — use a small card with a shield/lock icon and 2-3 sentences. A plain text block will be skimmed past; a visually distinct card registers without being intrusive. The card should use the `AppSemanticColors` success green to visually reinforce the positive message.
- **Onboarding surface**: Decision — no. Settings > Data is the only surface. Adding it to onboarding creates visual noise during an already-complex flow, and the user has no data context yet during onboarding to appreciate the reassurance.
- **bn localization**: Decision — yes, en/bn parity from day one. Add both strings to `app_en.arb`/`app_bn.arb` and include in generated `AppLocalizations`.
- **Near-duplicate copy resolution**: Decision — audit existing privacy-related strings across the app. If any other screen states the offline promise, replace with a cross-reference ("See Settings > Data for privacy details") rather than repeating the full copy.

## Edge Cases & 3-4 Year Considerations
- **Future analytics integration**: If analytics is ever added (even privacy-respecting local analytics), the reassurance copy must be updated immediately. The wording "no analytics, no tracking" must remain accurate — this is a trust contract, not marketing.
- **Future account/sync feature**: If cloud sync or accounts are ever added, the reassurance must be removed or reworded to reflect the new reality. A stale privacy promise is worse than no promise. Add a code comment near the copy noting it must be revisited if data handling changes.
- **Localization drift**: New locales added beyond en/bn must include this copy. The `AppLocalizations` generated code makes this enforceable at compile time — missing keys cause errors, not silent fallbacks.
- **Screen layout changes**: If the Data settings screen is restructured in a future run, the reassurance card must be preserved. Add it to the screen's widget tree as a dedicated, named widget (`DataPrivacyReassuranceCard`) so it's easy to find and relocate.

## Acceptance Criteria
- [ ] A visually distinct card (icon + 2-3 sentences) appears on the Data settings screen stating the offline/no-account/local-only-data promise.
- [ ] The card uses `AppSemanticColors` for visual consistency with the existing theme.
- [ ] Wording is audited and verified accurate against actual data handling (no network calls, no analytics, no account).
- [ ] en/bn strings are added to `app_en.arb`/`app_bn.arb` and present in generated `AppLocalizations`.
- [ ] Near-duplicate privacy copy elsewhere in the app is consolidated or cross-referenced (not repeated verbatim).
- [ ] The card is non-dismissible (permanent fixture on the Data settings screen).
- [ ] No new Drift tables or schema migrations required.

## Effort & sequencing notes
Complexity S — copy addition to an existing screen, no new logic, no new schema. Very low effort, can be done at any time independent of the rest of this category; consider bundling it into the same pass as the data-longevity guarantee feature (#11) since both are trust-building copy additions to adjacent settings surfaces. The near-duplicate audit is the only prerequisite that might touch other files.
