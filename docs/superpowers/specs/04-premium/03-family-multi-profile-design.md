# Family / Multi-Profile

**Category:** Premium · **Atlas complexity:** L · **Retention impact:** High
**Date:** 2026-07-23 · **Revised:** 2026-07-25
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
This is roadmap.md's #4 v1.1+ candidate, and directly matches the
caregiver persona (Farida) that recurs throughout this project's planning
docs — someone tracking medicine/water/prayer adherence for a parent or
child, not just themselves. Right now the app is single-profile, single-
device, single-user by construction. Caregivers are explicitly called out
in the roadmap as the persona most likely to ask for this, making it the
most-requested premium feature this persona set implies, even though it's
sequenced last among the roadmap's top candidates because it's most
valuable once sync also exists.

## What stays free vs. what's paywalled
A single user tracking their own habits stays entirely free, with no
change to today's experience. What's paywalled is managing more than one
profile from one installation — e.g. a caregiver switching between "Mom"
and "Dad" profiles, or a parent managing a child's medicine schedule
alongside their own — and any cross-device caregiving view (checking a
parent's adherence from the caregiver's own phone). The free tier is not
artificially capped at "1 profile" as a trick; today's app simply has no
profile concept at all, so this is additive premium depth, not a
retroactive restriction.

## Goals
- Let a single installation hold multiple independent profiles, each with
  its own Water/Medicine/Prayer data, switchable without re-onboarding.
- Support the caregiver use case: viewing/managing another profile's data
  from the caregiver's own device, once sync (item #2) exists to move
  that data between devices.
- Keep each profile's data model identical to today's single-profile
  model — this is a scoping/partitioning feature, not a new data shape.

## Non-goals / out of scope
- Not building real-time multi-user collaboration (two people editing the
  same profile simultaneously) — one profile still has one primary owner.
- Not solving cross-device caregiving without sync already in place —
  that combination is explicitly why this is sequenced after item #2.
- Not designing permission/sharing UX in detail here — that's for the
  implementation round once sync's data-movement model is settled.

## Proposed approach (high-level)
Introduce a profile-scoping concept above the existing database schema:
every module's tables (`water_*`, `medicine_*`, `prayer_*`, plus
`settings`) would need a profile identifier added to their row scope, the
same kind of append-only manifest-level change future-expansion.md
already establishes as acceptable for adding a new module's tables (a
one-line addition to a shared list, not a rewrite of existing module
code). The `HabitModule` contract itself likely doesn't need to change —
profile scoping is a cross-cutting concern below the repository layer,
similar in shape to how sync (item #2) would be layered in. A profile
switcher becomes a new top-level UI surface (likely near Settings), and
cross-device caregiving views build on whatever sync already established
for moving one profile's data between devices.

### Profile data model

A new `profiles` table stores profile metadata:

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | UUID v7 |
| display_name | TEXT | e.g. "Mom", "Dad", "Ahmed" |
| avatar_color | TEXT | hex color for profile switcher UI |
| created_at, updated_at | INTEGER | |

Profile switching is a local-only UI action — no re-authentication
needed. The active profile ID is stored in `app_settings` (a new
`active_profile_id TEXT` column) so it persists across app restarts.

### Database migration strategy
Every existing module table gains a `profile_id TEXT NOT NULL` column
defaulting to a single system profile ID (created during migration). This
is the largest schema-touching change in the premium batch:

- `water_goals`, `water_logs`, `water_settings` → add `profile_id`
- `medicines`, `medicine_schedules`, `medicine_doses`,
  `medicine_stock_events` → add `profile_id`
- `prayer_settings`, `prayer_records`, `prayer_qadha_counters` → add
  `profile_id`
- `app_settings` → add `active_profile_id` (points to current profile;
  the `app_settings` row itself stays singleton but now tracks which
  profile is active)
- `achievements` → add `profile_id`
- `habit_stack_suggestions` → add `profile_id`
- `notification_ledger` → add `profile_id`

The Drift migration adds the column with a default value (the system
profile ID) so existing data is preserved without a destructive
rewrite. All existing queries must be updated to filter on
`profile_id = :activeProfile` — this is a systematic but mechanical
change across every repository.

### Profile-aware query pattern
Every repository query gains a `profileId` parameter:
```dart
// Before:
Future<List<WaterLog>> getLogs(DateRange range);

// After:
Future<List<WaterLog>> getLogs(DateRange range, {required String profileId});
```

This is threaded through use cases and controllers, never through domain
entities — the domain layer stays profile-unaware.

### Profile switcher UX
A profile switcher appears:
- As a dropdown/chip in the app bar (alongside the existing display
  name), showing the active profile's name and avatar color.
- In Settings, with a "Manage Profiles" entry to add/remove/rename
  profiles.

Switching profiles:
1. Saves the new `active_profile_id` to `app_settings`.
2. Refreshes all providers (Riverpod invalidation of the active profile
  provider).
3. Re-plans notifications for the new profile's schedules.
4. Updates widget data for the new profile.

### Notification handling with multiple profiles
When multiple profiles exist on one device:
- Only the **active** profile's reminders fire as OS notifications.
- Background notification planning (WorkManager top-up) plans for the
  active profile only.
- The notification `profile_id` is stored in `notification_ledger` so
  the action handler knows which profile's data to mutate on Done/Snooze/
  Skip.

### Profile deletion
Deleting a profile:
1. Shows a confirmation dialog warning that all data for that profile
   will be permanently removed.
2. Soft-deletes all rows matching that `profile_id` (sets `deleted_at`).
3. Removes the profile from the `profiles` table.
4. If the deleted profile was the active one, switches to the first
   remaining profile (or creates a default one if none remain).

## Database changes
- New `profiles` table (see above).
- Every existing table gains `profile_id TEXT NOT NULL` column (default
  to system profile ID during migration).
- `app_settings` gains `active_profile_id TEXT` column.

## Dependencies & prerequisites
- Multi-device sync (this spec set's item #2) should exist first for the
  cross-device caregiving scenario to be meaningful — a caregiver
  managing a parent's data on the parent's own device requires that data
  to move between devices at all.
- A profile-scoping change to the database schema (every existing table
  gains a profile reference) — the single largest schema-touching item
  in this whole premium batch.
- Entitlement/IAP infrastructure (spec 07) for premium gating.
- Decide whether Settings (theme/locale/etc.) is global-per-device or
  per-profile — an open design question with real UX consequences.

## Localization
- Profile names support user-entered text in any script (Bangla, English,
  Arabic, etc.) — no locale constraint on profile display names.
- The profile switcher UI and "Manage Profiles" screen need en/bn
  localization.
- Profile-related error messages (e.g. "Cannot delete the last profile")
  need en/bn ARB keys.

## Edge cases & error handling
- **Only one profile exists:** profile switcher is hidden or shows a
  single entry with no switch UI. "Manage Profiles" still visible to
  allow adding a second.
- **Profile switch while notification is in flight:** the action handler
  uses the `profile_id` stored in the notification's ledger row, not the
  currently active profile — so a Done action on a notification always
  mutates the correct profile's data.
- **Profile switch during active timer/ongoing action:** complete the
  current action in the old profile's context, then switch.
- **Storage growth:** each profile effectively multiplies the data
  storage. Surface a storage usage indicator in "Manage Profiles" for
  transparency.

## Open questions for the implementation round
- Is a "profile" fully independent (its own achievements, streaks,
  settings) or does some state (theme, locale) stay device-level and
  shared across profiles on that device?
- What's the caregiver permission model — full read/write on another
  profile, or a lighter-weight read-only view for a subset of data?
- How many profiles can exist per installation? (Suggested: 5 max to
  prevent abuse and manage storage.)
- Does switching profiles require re-authentication of any kind, or is it
  purely a local UI selector (no sync) until sync exists?

## Effort & sequencing notes
L complexity — comparable in size to sync because it touches every
existing table's scoping. Sequenced after sync (#2) validates and builds
the data-movement machinery a caregiver's cross-device use case actually
needs; building this before sync would only cover the single-device
"manage two profiles on my own phone" case, a smaller but not worthless
partial version worth flagging to the implementation round.
