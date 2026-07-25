# In-App Feedback / Feature-Request Board

**Category:** Community · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Users currently have no channel to tell the team what they want built next, short of an app-store review. A lightweight "vote on what we build next" surface, Canny-style, gives users a sense of being heard and gives the team a prioritization signal — without requiring any social features *between* users (this is user-to-team feedback, not user-to-user community). It's a low retention-impact feature on its own, but it's cheap and complements the more social items in this category well.

## Infrastructure implication
Effectively zero-infra from this app's perspective if a third-party feedback widget/board (Canny or similar) is embedded — the vendor hosts the board, voting, and moderation entirely outside this app's own backend-less architecture. The only in-app footprint is a link or embedded view pointing at the vendor's hosted board. A fully custom in-app-only board (no vendor) would instead require this app's own backend to store submissions/votes, which is a materially bigger and less justified build for a Low-impact feature.

## Goals
- Give users a way to submit feature requests and vote on existing ones.
- Surface it from Settings (or a similar low-friction entry point), not as an intrusive prompt.
- Keep the team's own moderation/triage workload low by leaning on an existing third-party tool rather than building bespoke admin tooling.

## Non-goals / out of scope
- Not building a custom in-app voting/backend system — a vendor widget or even a simple external form is preferred given the Low retention impact doesn't justify custom infrastructure.
- No user-to-user discussion/comments beyond whatever the chosen vendor tool natively supports.
- No SLA or commitment that submitted requests get built — this is a listening mechanism, not a roadmap contract.

## Proposed approach (high-level)
Add a single entry point (Settings, likely alongside the external-community-link item) that opens a third-party feedback/voting tool (Canny or an equivalent), either as an external browser link or an embedded web view if the vendor supports one. No new domain logic, no new local data model — this is presentation-layer only, similar in shape to item 03's external community link.

## Dependencies & prerequisites
- A third-party feedback-widget account (Canny or equivalent) — a vendor/tooling decision, not an engineering one.
- Alternatively, if avoiding any third-party vendor entirely is preferred, a plain external form (e.g. a simple hosted form) could substitute, trading away voting/upvoting functionality for zero vendor dependency.

## Open questions for the implementation round
- Vendor choice (Canny vs. a lighter-weight/free alternative) — driven by cost and whether a paid tier is justified for a Low-impact feature.
- External link vs. embedded web view — an embedded view keeps users in-app but adds a WebView dependency; an external link is simpler and consistent with item 03's approach.
- Does using a third-party vendor here require any update to the app's store data-safety disclosures, given the vendor may collect its own analytics on submissions/votes even though this app's own backend remains untouched?

## Effort & sequencing notes
Small (S), independent of every other Community item, similar in shape and effort to item 03 (external community link) — the two could reasonably be scheduled together since both are single Settings entries pointing at external, vendor- or team-hosted destinations.

## Database schema

No new tables. The feedback board is entirely external — the app only
opens a link or web view to the vendor's hosted board.

## Localization

New ARB keys (en/bn):
- `feedbackTitle` — "Feedback & Feature Requests"
- `feedbackDescription` — "Tell us what you'd like to see next"
- `feedbackOpenButton` — "Open Feedback Board"
- `feedbackLoadingError` — "Could not open feedback board"

## Edge cases & error handling

- **No internet:** show a "No internet connection" message with a
  "Copy Link" fallback so the user can visit later.
- **Vendor link changes:** the link is a hardcoded constant in the
  settings screen. If it changes, an app update is required.
- **WebView failure (if embedded):** fall back to external browser.
- **Store data-safety:** if the vendor collects analytics, update
  store data-safety disclosures accordingly.

## Cross-references

- Related: Spec 05-community/03 (external community link) — sibling
  Settings entry, same pattern.
- Settings screen: `lib/features/settings/presentation/screens/settings_home_screen.dart`.

## Test strategy

- Widget test: settings entry navigates correctly.
- Widget test: no-internet fallback state.
- Widget test: WebView vs. external link behavior.
