# Additional Habit Modules Pack (Sleep, Blood Pressure, Mood, Exercise)

**Category:** Premium · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23 · **Revised:** 2026-07-25
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
This is roadmap.md's #5 v1.1+ candidate. `docs/strategies/future-expansion.md` has already
proven, on paper, that the `HabitModule` contract cleanly supports both a
checklist/scheduled habit (Sleep, worked through as a paper example) and a
free-log/measurement habit with a new domain concern (Blood Pressure,
also worked through). That means adding modules beyond the free core
three is now a comparatively cheap, well-understood exercise rather than
a research problem — which is exactly what makes bundling several of
them into a paid pack an efficient way to widen the app's health-tracking
breadth (closer to Apple Health's) without inflating the always-free core.

## What stays free vs. what's paywalled
The three existing modules — Water, Medicine, Prayer — stay free forever,
along with any future module the team later decides belongs in the free
core. What's paywalled here is a specific *additional pack* of modules
(Sleep, Blood Pressure, Mood, Exercise are the four named candidates)
bundled together as a premium unlock — not a per-module micro-purchase,
and not a cap that makes any of today's three modules feel incomplete.

## Goals
- Ship Sleep, Blood Pressure, Mood, and Exercise as additional
  `HabitModule` implementations, reusing the recipe from
  `docs/strategies/future-expansion.md` step by step.
- Gate the pack behind a single premium unlock, not per-module purchases
  — keep the purchase decision simple.
- Prove the `HabitModule` contract holds for a fourth, fifth, sixth, and
  seventh module with zero changes required to the contract itself or to
  Water/Medicine/Prayer's own code.

## Non-goals / out of scope
- Not designing each module's full domain/data/presentation slice in this
  pass — `docs/strategies/future-expansion.md`'s Sleep and Blood Pressure
  paper examples are a strong head start, but Mood and Exercise still need
  their own domain sketches at implementation time.
- Not deciding per-module pricing or a la carte unlocks — scoped here as
  one bundled pack.
- Not building cross-module correlation features (e.g. "sleep affects
  mood") — each module stays independent per the existing architecture.

## Proposed approach (high-level)
Follow `docs/strategies/future-expansion.md`'s recipe once per module: a
`lib/features/<name>/` slice with the standard domain/data/presentation
shape, new Drift tables added to the central table manifest (`AppDatabase`
in `core/database/app_database.dart`), a `<name>_module.dart`
implementing `HabitModule`, registration in `module_registry.dart`, and
bilingual ARB keys from day one. Sleep and Blood Pressure already have
worked-through paper designs to start from (Sleep as checklist/scheduled
reusing Medicine/Prayer's shared Done/Snooze/Skip notification component;
Blood Pressure as free-log with its own classification use case, no
materialization, no natural streak). Mood and Exercise would need
equivalent shape decisions (Mood likely free-log/checklist-hybrid;
Exercise likely free-log like Water/Blood Pressure). The premium gate
itself is a purchase-state check controlling whether these four modules'
entries even appear in the module registry or dashboard/settings — not a
change to how any module works internally.

### Module shape summary

| Module | Shape | Streak? | Notifications? | Key domain concern |
|---|---|---|---|---|
| Sleep | Checklist/scheduled (like Medicine) | Yes — consecutive nights | Done/Snooze/Skip (shared component) | Bedtime/wake logging, sleep duration calc |
| Blood Pressure | Free-log (like Water) | No natural streak | Low-stock style alerts only | Systolic/diastolic classification, trend |
| Mood | Free-log/checklist-hybrid | Possible (daily logging streak) | Optional daily check-in reminder | Mood scale (1-5 or emoji), optional note |
| Exercise | Free-log (like Water) | Yes — consecutive days | Optional workout reminder | Duration/type logging, weekly minutes goal |

### Premium gate mechanism
The gate lives at the module registry level — the cleanest single
checkpoint since `module_registry.dart` is already the shared touchpoint
for "which modules exist":

```dart
// In module_registry.dart, the premium modules are conditionally included:
final allModules = [
  // ... existing free modules (water, medicine, prayer) ...
  if (isPremiumUnlocked) ...[
    (id: 'sleep', module: SleepModule(...)),
    (id: 'blood_pressure', module: BloodPressureModule(...)),
    (id: 'mood', module: MoodModule(...)),
    (id: 'exercise', module: ExerciseModule(...)),
  ],
];
```

The `isPremiumUnlocked` flag comes from the shared entitlement/IAP
system (established by whichever premium feature ships first — likely
icon packs given their S complexity). When the flag is false, the
premium modules simply don't appear in the registry, which means they're
invisible to the dashboard, settings, router, and notification engine
— zero runtime cost for free users.

### Non-premium user visibility
Two options for the implementation round:
1. **Hidden entirely** — premium modules don't appear anywhere. Cleanest,
   but zero discoverability.
2. **Locked preview** — premium modules appear in Settings with a lock
  icon and "Upgrade to unlock" CTA. Better for conversion, but adds a
  new UI state to manage.

Recommendation: option 2 (locked preview) for better discoverability,
flagged for implementation-round decision.

### New Drift tables per module

**Sleep module:**
- `sleep_logs` — `id`, `profile_id` (if multi-profile exists), `bed_time`
  (UTC), `wake_time` (UTC), `duration_minutes` (derived), `quality`
  (nullable 1-5), `created_at`, `updated_at`, `deleted_at`

**Blood Pressure module:**
- `blood_pressure_logs` — `id`, `profile_id`, `systolic` (INTEGER),
  `diastolic` (INTEGER), `pulse` (INTEGER NULL), `logged_at` (UTC),
  `note` (TEXT NULL), `created_at`, `updated_at`, `deleted_at`
- `blood_pressure_classifications` — `id`, `range_label` (`'normal'` |
  `'elevated'` | `'hypertension_1'` | `'hypertension_2'` |
  `'hypertension_crisis'`), `systolic_min`, `systolic_max`,
  `diastolic_min`, `diastolic_max` — reference table for classification

**Mood module:**
- `mood_logs` — `id`, `profile_id`, `mood_value` (INTEGER 1-5),
  `emoji` (TEXT NULL), `note` (TEXT NULL), `logged_at` (UTC),
  `created_at`, `updated_at`, `deleted_at`

**Exercise module:**
- `exercise_logs` — `id`, `profile_id`, `exercise_type` (TEXT),
  `duration_minutes` (INTEGER), `calories` (INTEGER NULL),
  `logged_at` (UTC), `note` (TEXT NULL), `created_at`, `updated_at`,
  `deleted_at`
- `exercise_settings` — singleton row: `weekly_minutes_goal` (INTEGER),
  `reminder_enabled`, `reminder_time` (local HH:mm)

## Database changes
- 7 new Drift tables across 4 modules (listed above).
- Each module's table classes added to `AppDatabase`'s table manifest.
- No changes to existing Water/Medicine/Prayer tables.

## Dependencies & prerequisites
- The `HabitModule` contract as it exists today, already proven against
  two of these four modules on paper.
- Entitlement/IAP infrastructure (spec 07) — the premium gate for these
  modules uses the same `core/premium/entitlement_service.dart` and
  `premium_gate_widget.dart` as other premium features.
- `docs/strategies/future-expansion.md`'s step-by-step recipe as the
  implementation guide for each module.

## Localization
- All four modules need en/bn ARB keys for: module display name,
  settings labels, notification titles/bodies, onboarding text, error
  messages, stats labels.
- Mood and Exercise need locale-aware time/duration formatting.

## Edge cases & error handling
- **Sleep logging with overlapping times:** if a user logs sleep that
  overlaps with a previous entry (e.g. two entries for the same night),
  show a warning but allow it (users may log naps separately).
- **Blood Pressure classification boundaries:** use standard AHA
  guidelines; values exactly on the boundary use the higher classification.
- **Exercise type taxonomy:** free-text entry initially, with suggested
  types based on common exercises. No enum constraint — users should
  type what they actually do.
- **Mood logging frequency:** allow multiple mood logs per day (mood
  fluctuates); the daily streak is "at least one log per day."

## Open questions for the implementation round
- Does the premium gate hide these modules entirely from a non-premium
  user, or show them as a locked/preview state (better discoverability,
  more purchase-intent surface)?
- Are Mood and Exercise's domain shapes settled before implementation
  starts, or does this round need its own mini design pass for those two
  (Sleep/Blood Pressure already have one)?
- Does purchasing the pack unlock all four modules simultaneously, or can
  the pack grow over time (a 5th module added later to the same
  purchase)?
- How do achievements/reports treat pack modules — do they count toward
  cross-module reports and the achievement gallery on the same terms as
  the free three?

## Effort & sequencing notes
M complexity per `docs/strategies/future-expansion.md`'s own framing —
"each is cheap to build" given the proven recipe — though bundling four
modules multiplies that cost roughly four-fold even if each is
individually cheap. Sequenced last among the roadmap's top candidates
since there's no urgency to add a fourth module before the core three
are proven with real users. Note: if multi-profile (spec 03) is
implemented before this spec, each new module's tables should include
the `profile_id` column from the start to avoid a migration later.
