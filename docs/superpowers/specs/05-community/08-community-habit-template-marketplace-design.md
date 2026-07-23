# Community Habit-Template Marketplace

**Category:** Community · **Atlas complexity:** M (start) / L (full) · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
New users setting up Water, Medicine, or Prayer schedules currently start from a blank slate — every goal, repeat rule, and schedule is manually configured. TickTick's template gallery shows that offering ready-made presets (e.g. an intermittent-fasting water schedule, a common medicine-reminder pattern) lowers setup friction and gives users good defaults tuned by people who've solved the same problem before. This is a genuine onboarding and re-engagement win, and unlike most Community items, it doesn't need to start as user-generated content — a small curated set is enough to prove the concept.

## Infrastructure implication
Zero-infra for a v1 curated feed: a small, bundled/curated set of presets shipped with the app (or fetched from a simple static file the team controls), applied entirely on-device to create the corresponding module records (Water goals, Medicine schedules/repeat rules, Prayer settings). A full "users submit and share their own templates" version is a materially different, larger feature — it would need a submission pipeline, moderation, and a hosting backend, which is UGC infrastructure this app does not have today. That full version should be treated as a separate, later decision, not assumed as part of a v1 estimate.

## Goals
- Ship a small, curated library of habit-schedule presets per module (e.g. Water: "intermittent fasting hours," "office worker 8-5"; Medicine: "twice-daily with food," "every-other-day"; Prayer: standard Jumu'ah/reminder configurations).
- Let a user browse and apply a preset, which populates the relevant module's existing schedule/goal creation flow with sensible defaults the user can then edit normally.
- Keep applying a preset non-destructive — it should prefill an existing creation form, not silently overwrite existing data.

## Non-goals / out of scope
- Not building user-submission, voting, moderation, or any UGC pipeline in v1 — that's the explicitly separate "full" scope requiring a backend, deferred.
- Not building a ratings/reviews system for templates.
- No personalization/recommendation engine deciding which template to suggest — a simple browsable list is sufficient for v1.
- Not touching the underlying repeat-rule engine, goal model, or schedule domain logic in any module — presets only prefill existing creation flows, using the data shapes that already exist.

## Proposed approach (high-level)
Curate a small, static set of presets per module, each expressed in terms of that module's existing domain entities (Water's `WaterGoal`, Medicine's `MedicineSchedule`/`RepeatRule` variants, Prayer's settings/reminder configuration) so applying one is just prefilling that module's existing add/edit form rather than writing new database-write paths. Present them in a simple browsable list (could live in each module's settings or a small dedicated screen), where selecting one navigates into the existing creation flow pre-populated with the preset's values, leaving the user to review and confirm as normal.

## Dependencies & prerequisites
- A curated content set per module (content/product work, not engineering — deciding what the actual presets should be).
- Each module's existing schedule/goal creation entities and forms (Water's goal creation, Medicine's schedule/`RepeatRule` creation, Prayer's settings) — no new domain model needed for v1.
- If a "full" UGC version is ever pursued: a submission/moderation pipeline and a hosting backend — an explicit later decision, out of scope here.

## Open questions for the implementation round
- Are presets bundled at build time (simplest, but requires an app update to change) or fetched from a simple static remote file (lets curation update without a release, at the cost of a first network dependency for this feature)?
- How many presets per module for v1, and who curates them?
- Does applying a preset need any confirmation/preview step, or does prefilling the existing form's fields (which the user can already see and edit before saving) provide sufficient safety?
- Is there real demand for the "full" UGC version, or does the curated v1 satisfy the underlying need well enough that the backend investment is never justified?

## Effort & sequencing notes
Medium (M) for the curated v1 described above — no backend, no new domain logic, mostly content curation plus a browsing UI wired into each module's existing creation flow. The "full" version with user submissions is Large (L) and requires its own backend/moderation decision; do not conflate the two scopes when estimating.
