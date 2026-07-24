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

## Resolved Dependencies
| Prerequisite | Status | Required by |
|---|---|---|
| Multi-profile data model | **Not built** — no concept of profiles exists in the schema. Must be added (separate Premium-category spec). | This spec |
| Premium subscription/billing | **Not built** — no subscription tiers or store integration exist. Required for household-tier monetization. | This spec |
| `installDate` tracking | **Not built** — no `installDate` field exists on any entity or settings table. Needed for tenure-based trigger. | This spec, anniversary badge, recap |
| Schema migration for `profiles` table | **Not built** — adding multi-profile support requires a new `profiles` Drift table with migration steps. | This spec |
| `app_settings` table extension for `install_date` | **Not built** — `installDate` must be persisted in `app_settings` (or a new `app_metadata` table). | This spec, Spec 07 |

## Dependencies & prerequisites
- **Multi-profile data model**: **Not built.** No concept of user profiles exists in the codebase. This is the single largest blocker — the entire household/family plan is inert without it. Must be designed and implemented as a standalone Premium-category feature before this spec can proceed. The data model needs at minimum: a `profiles` Drift table (id, name, is_primary, created_at), profile-scoped foreign keys on all habit tables, and a profile-switching mechanism in the UI.
- **Premium subscription/billing**: **Not built.** The household plan is fundamentally a monetization construct. Requires store integration (Google Play / App Store billing), subscription tier definitions, and entitlement checks. Belongs to the Premium category.
- **`installDate` tracking**: **Not built.** No `installDate` field exists anywhere. This spec needs it for the tenure-based trigger (surfacing the household offer after a meaningful period). Must be added to `app_settings` or `app_metadata` during first app launch. A cross-cutting gap — Spec 07 (onboarding), anniversary badge, and recap all need this too.
- **Schema migration infrastructure**: Adding `profiles` and `install_date` requires Drift migration steps. No migration beyond the initial schema exists yet. This is a cross-cutting gap that must be addressed before any new tables/columns are added.
- **Anniversary badge / recap features**: These depend on `installDate` too. Sequencing note: `installDate` should be added in the same migration step regardless of which spec lands first.

## Open questions for the implementation round
- **Tenure threshold for surfacing**: Decision — 12 months. Match the anniversary badge's existing anchor. This is consistent with the "year-two expansion" framing in the problem statement. Do not shorten to 6 months — that's too early for the user to have built the sustained-engagement habit that makes a household offer compelling.
- **Proactive vs. reactive surfacing**: Decision — both, but weighted toward reactive. Show a subtle, non-blocking banner on the Dashboard after the 12-month threshold (proactive), AND make the option discoverable in Settings > Profile at any time (reactive). The banner is dismissible; dismissal does not prevent the Settings path from working.
- **Migration for existing informal caregivers**: Decision — no migration path in v1. Users who currently track someone else's medicine on their own profile will need to manually re-enter that data into a new profile after multi-profile support lands. This is acceptable because the informal usage pattern is not tracked in the database (there's no way to distinguish "my medicine" from "someone else's medicine" in the current schema). A future release could add a "migrate data to new profile" wizard, but that's out of scope here.
- **Profile switching UX**: Decision — bottom sheet or Settings dropdown for profile switching in v1. Not a full-screen profile picker (too heavy for a habits app). The currently active profile is shown in the app bar; tapping it opens the switcher.

## Edge Cases & 3-4 Year Considerations
- **installDate clock skew**: If the user changes their device clock forward and then back, the `installDate` is unaffected (it's set once at first launch from `clock.now()`). However, tenure-based triggers could fire early if the user manipulates the clock. Accept this risk — it's a cosmetic trigger, not a security gate. Do not add clock-skew detection complexity.
- **Multi-profile and notifications**: Each profile's notifications must be independent. If Profile A has Medicine reminders and Profile B has Prayer reminders, they must not conflict. The notification engine (`core/notifications`) currently operates globally — it needs a profile-scoped variant. This is a significant cross-cutting concern.
- **Multi-profile and data isolation**: Profile A's data must be completely invisible to Profile B. Every Drift query in every module must be scoped to the active profile. This is a pervasive change — not just new tables, but modified queries across Water, Medicine, Prayer, and Dashboard. Budget accordingly.
- **Household plan and store subscriptions**: If a user's subscription lapses, what happens to the second profile's data? Decision for v1 — data is never deleted. The secondary profile becomes read-only (can view, cannot log new entries) until the subscription is renewed. This matches the "data never left this device" promise.
- **Profile deletion**: Users must be able to delete a secondary profile and its data. This requires a cascade delete across all habit tables. Drift supports this via foreign key constraints — ensure `onDelete: DeleteBehavior.cascade` on all profile-scoped foreign keys.
- **3-year data volume**: With 3-4 profiles, each logging daily entries across 3 modules, the database could grow to ~100K+ rows within 3 years. This is well within SQLite/Drift's comfort zone (millions of rows). No performance concern here, but ensure indexes exist on `profile_id` + `date` for the common query pattern.

## Acceptance Criteria
- [ ] `installDate` is persisted in `app_settings` (or `app_metadata`) on first app launch.
- [ ] A `profiles` Drift table exists with id, name, is_primary, created_at fields.
- [ ] All habit tables (Water, Medicine, Prayer) have a `profile_id` foreign key with cascade delete.
- [ ] Profile switching is available from Settings > Profile and from the app bar.
- [ ] The current profile's data is the only data visible in all module screens.
- [ ] A dismissible "Add a household member" banner appears on the Dashboard after 12 months of tenure.
- [ ] The banner links to a profile-creation flow (name entry, no billing in v1).
- [ ] Secondary profile data is read-only if subscription lapses (viewable, not loggable).
- [ ] Profile deletion cascades across all habit tables.
- [ ] Drift migration for `profiles` table and `profile_id` foreign keys succeeds cleanly.
- [ ] Notifications are scoped per-profile (Profile A's reminders don't fire for Profile B).

## Effort & sequencing notes
Complexity S for this spec's own scope (positioning + trigger reuse) — but it is fully blocked on multi-profile support and the Premium subscription feature, both larger prerequisites outside this category. Sequence this strictly after those land; until then this spec is a placeholder recording the intended year-two hook. The `installDate` cross-cutting gap should be addressed early since it unblocks multiple specs (this one, anniversary badge, recap, onboarding tenure logic).
