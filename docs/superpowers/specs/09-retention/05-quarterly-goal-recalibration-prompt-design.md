# Quarterly Goal-Recalibration Prompt

**Category:** Long-Term Retention · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
A goal set on day one — a water target, a medicine schedule — is right for the life the user had on day one. By month six or year two, that life has usually changed: a new job, a new season, a new prescription, a body that needs less or more. Apps that never revisit the original setup quietly become less accurate over time, and an inaccurate goal is a slow, invisible reason a long-term user disengages ("this app thinks I should drink 2.5L but I stopped needing that months ago"). A periodic, low-friction "still right for you?" check-in is a small nudge that keeps the app's model of the user from going stale across a multi-year relationship.

## Goals
- Periodically (roughly quarterly) surface a dismissible prompt asking whether a module's current goal still fits.
- Make the prompt one tap to dismiss and one tap to jump into the relevant settings/goal-editing screen.
- Keep it infrequent and skippable enough that it never feels naggy — this is a check-in, not a gate.
- Cover the goal-bearing entities that plausibly go stale (Water's daily target, at minimum; Medicine schedules if the atlas intends it broadly).

## Non-goals / out of scope
- No automatic goal adjustment or AI-suggested new targets — this only prompts the user to look, it never changes a goal itself.
- No recalibration for Prayer (its "goal" is a fixed set of five daily prayers, not a tunable target) — scope to Water and, if desired, Medicine schedule review.
- No complex scheduling engine — a simple "last shown" timestamp per module is enough, not a general-purpose campaign scheduler.
- No in-app survey/feedback collection tied to this — it's a direct link to settings, not a questionnaire.

## Proposed approach (high-level)
This is a lightweight, mostly presentation-layer feature: a periodic check (on app open, similar in spirit to other periodic checks already in the app) comparing "time since this module's goal was last confirmed or edited" against a quarterly threshold, sourced from each module's existing settings/goal entity (Water's goal entity already has the amount and, implicitly, whenever it was last changed). When the threshold is crossed, show a small dismissible banner or bottom-sheet prompt on the relevant module's screen, linking directly to its existing goal-editing UI. Dismissing resets the timer; editing the goal also resets it naturally since the goal's own last-modified point moves forward.

## Dependencies & prerequisites
- Water's goal entity (and Medicine's schedule entity, if included) — needs a "last confirmed/edited" timestamp to compare against.
- The settings entity, for storing a lightweight "last shown" marker per module if the goal entity itself doesn't already carry a usable timestamp.
- Each module's existing goal-editing screen, as the destination the prompt links to — no new editing UI.
- **Cross-cutting gap (schema migration):** Adding `last_shown_at` to the settings entity requires a Drift schema migration. If the goal entity is extended, that migration must be coordinated to avoid version conflicts.
- **Cross-cutting gap (installDate):** The quarterly cadence is anchored to the user's install date (or last goal edit). The `installDate` field (needed by Spec 06 as well) must exist in the settings entity before this spec can reference it for the "time since install" calculation.

## Resolved Dependencies
Prerequisites that must be built **before** this spec can be implemented:
1. `installDate` field added to `AppSettings` (Drift table + entity) — first-launch timestamp captured once.
2. Drift schema migration for `last_shown_at` on the settings entity (or a new `recalibration_markers` table if preferred).
3. The dashboard's periodic-check hook (app-resume or similar) must be available to inject the recalibration check.

## Open questions for the implementation round
- ~~Is "quarterly" a fixed 90-day interval from install date, or from the last time the goal was actually touched?~~ → **Decision: From last goal edit.** The recalibration prompt appears 90 days after the goal was last edited or confirmed. On first install, the anchor is the install date. This keeps the prompt relevant — if the user just updated their goal last week, they don't need another prompt.
- ~~Should dismissing "not now" differ from dismissing "yes it's still right" (the latter could reset the timer further out, the former sooner)?~~ → **Decision: Yes, they differ.** "Yes, it's still right" resets the timer to 90 days from now. "Not now" resets to 30 days from now. The UI presents two buttons: "Still right" and "Remind later".
- ~~Does this need its own settings toggle to opt out entirely for users who find any prompt intrusive?~~ → **Decision: Yes.** A "Goal recalibration prompts" toggle in the Settings screen, defaulting to ON. Turning it off suppresses all recalibration prompts.
- ~~Where does it render — dashboard-level banner, or per-module screen only?~~ → **Decision: Per-module screen only.** The prompt renders as an inline card at the top of each module's screen (Water screen, Medicine screen). No dashboard-level banner — keep it contextual.

## Edge Cases & 3-4 Year Considerations
- **Goal edited during a pause:** If the user pauses a module (Spec 04), the recalibration timer should continue ticking. When the module resumes, if 90 days have passed since the last goal edit, the prompt should appear on the first app open after resume.
- **Multiple modules, multiple prompts:** After 3–4 years, a user may have 3+ modules each needing recalibration simultaneously. Cap at one prompt per module, but show at most 2 recalibration prompts per app session (prioritize the module whose goal is oldest). The rest appear on subsequent opens.
- **Prompt fatigue over years:** A user who dismisses "Remind later" repeatedly may see the same prompt every 30 days for the same module. After 3 consecutive dismissals without an edit, extend the interval to 60 days, then 90 days — a gentle backoff.
- **Goal entity doesn't carry a timestamp:** If Water's goal entity doesn't have a usable "last modified" timestamp, the recalibration logic must fall back to `installDate`. This is a known gap — the implementation must audit each module's goal entity and add a `lastEditedAt` field if missing.
- **Install date is unknown:** If `installDate` is somehow null (e.g., data migration from an older version), fall back to 90 days from app open as the initial anchor and log a warning.
- **Schema migration coordination:** Both this spec and Spec 06 need `installDate`. The migration must be authored once (in whichever spec is implemented first) and the other spec must depend on it, not create a duplicate field.
- **User changes module settings without touching the goal:** If the user changes reminder times or other non-goal settings, the recalibration prompt should NOT reset — only actual goal/schedule edits reset the timer.

## Acceptance Criteria
- [ ] **Install date captured:** `AppSettings` has an `installDate` field. On first launch, it is set to `DateTime.now()` (using injected clock). On subsequent launches, it remains unchanged.
- [ ] **Last-shown tracking:** The system tracks when the recalibration prompt was last shown per module. On first install, "last shown" defaults to `installDate`.
- [ ] **Prompt appears on schedule:** If 90+ days have passed since the last goal edit and the prompt has not been shown in the last 30 days, the recalibration card renders on the module's screen.
- [ ] **"Still right" action:** Tapping "Still right" dismisses the prompt and resets the timer to 90 days from now.
- [ ] **"Remind later" action:** Tapping "Remind later" dismisses the prompt and resets the timer to 30 days from now.
- [ ] **Goal edit resets timer:** Editing the goal/schedule resets the "last shown" timer to now (effectively 90 days until next prompt).
- [ ] **Opt-out toggle:** A "Goal recalibration prompts" toggle exists in Settings, defaulting to ON. When OFF, no recalibration prompts appear for any module.
- [ ] **Per-module rendering:** The prompt renders as an inline card at the top of the relevant module's screen, not on the dashboard.
- [ ] **No regression:** Existing goal-editing screens and settings persistence are unaffected.

## Effort & sequencing notes
Complexity S — a timestamp comparison and a dismissible banner, no new domain logic. Low-risk, can be built independently of everything else in this category; reasonable to slot in whenever a quiet sprint needs a small win.
