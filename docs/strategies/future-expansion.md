# Future Expansion — Adding a New Module

The step-by-step recipe for adding a habit module beyond Water/Medicine/
Prayer, using the `HabitModule` plugin contract (`../technical/
architecture.md`). Proven against two paper examples chosen specifically
to stress the contract in different ways: **Sleep** (a checklist/scheduled
habit, like Medicine/Prayer) and **Blood Pressure** (a measurement/free-log
habit, like Water, but with a genuinely new domain concern). If the
contract survives both without needing to change, it's proof the
abstraction was built at the right level — not just that it worked once.

## The recipe

1. Create `lib/features/<name>/` with the standard `domain/data/
   presentation` shape (`../technical/folder-structure.md`'s template) —
   copy Water's or Medicine's structure depending on which of the two
   shapes below the new habit resembles.
2. **Domain:** entities (Freezed), a repository interface, use cases.
   Decide up front: is this a **checklist/scheduled** habit (materialized
   rows ahead of time, D-13, like Medicine/Prayer) or a **free-log**
   habit (entries created only when the user logs something, no
   materialization, like Water)? This decision shapes everything else.
3. **Data:** Drift tables following the global rules in `../technical/
   database-design.md` (UUID v7 PKs, `created_at`/`updated_at`/
   `deleted_at` on every table), a DAO, a repository implementation.
4. Add the new tables to `core/database/app_database.dart`'s table list.
   **Honest note:** this — and step 7 below — are the two small,
   append-only exceptions to "zero edits to existing code": neither
   requires reading or understanding another module's code, both are
   one-line additions to a manifest, which is exactly the "only shared
   touchpoint is a single [list]" property `architecture.md` describes,
   just realized as two lists (DB tables, module registry) instead of one.
5. **Presentation:** screens/widgets/providers, following the
   loading/empty/populated/error state pattern (`../strategies/
   testing.md`/`accessibility.md`).
6. Implement `<name>_module.dart`, implementing `HabitModule`: `id`,
   `metadata` (including a new per-module accent color, `theme.md`),
   `routes`, `dashboardSummary`, `settingsEntry`, `pendingNotifications`
   (an empty list if the habit has no scheduled component — see Blood
   Pressure below), `exportData`/`importData` (`backup-import-export.md`).
7. Register: one line, `<Name>Module()`, added to `core/modules/
   module_registry.dart`.
8. Localization: new ARB keys in **both** `app_en.arb` and `app_bn.arb`
   at once (`localization.md`) — a new *module* ships bilingual
   immediately, unlike a whole new *language*, which is the separate,
   unlimited-later axis `00-project-context.md` describes.
9. Notification integration only if the habit needs scheduled reminders —
   follow D-13's materialization + `notifications.md`'s N-day sliding
   window; skip entirely if it doesn't (the contract doesn't force every
   module through the notification pipeline).
10. Tests, per `testing.md`'s pyramid: domain unit tests for whatever
    calculation is unique to this habit, one repository test against a
    temp DB, widget tests for the new screens' key states.
11. Add the module to `../product/roadmap.md`'s run sequence — project
    tracking, not something the module needs to function.

## Paper example 1: Sleep — a checklist/scheduled habit

**Shape:** like Prayer, not like Water — two daily checkpoints (bedtime,
wake time) rather than free-form entries.

- **Domain:** `SleepSettings` (target bedtime, target wake time) —
  singleton, same shape as `PrayerSettings`. `SleepRecord` (date,
  `wentToBedAt?`, `wokeUpAt?`, a status per checkpoint: on-time/late/
  missed) — same shape as `PrayerRecord`, just 2 checkpoints/day instead
  of 5.
- **Reuses directly, unchanged:** D-13's materialization pattern (copy
  Prayer's rolling-window job configuration), and — the more interesting
  reuse — the **shared Done/Snooze/Skip notification-action component**
  already proven once when Prayer (Run 10) reused Medicine's (Run 08)
  version. Sleep reusing it a third time is what actually validates the
  component generalizes, rather than having been coincidentally reusable
  exactly twice.
- **New tables:** `sleep_settings`, `sleep_records` — nothing about
  `medicine_*` or `prayer_*` tables changes.
- **Dashboard tile:** "Bedtime in 2h" or "Woke up on time" — a status
  summary, not a streak-in-progress number, showing `dashboardSummary()`
  is free to render whatever fits the habit, not a fixed template.
- **What this proves:** a *third* checklist-shaped module needs zero
  changes to Medicine's or Prayer's own code — confirming the pattern
  generalizes past "it worked for the second module too," which is a
  weaker claim than "it works for an arbitrary Nth module."

## Paper example 2: Blood Pressure — a measurement/free-log habit, with a new domain concern

**Shape:** like Water — entries logged whenever the user takes a reading,
no scheduled "due" state, no materialization.

- **Domain:** `BloodPressureReading` (`systolic: int`, `diastolic: int`,
  `pulse: int?`, `loggedAt`, `note?`) — structurally like `WaterEntry`,
  but with **two-to-three numeric fields instead of one**, which already
  mildly stresses the "one amount field" shape Water established.
- **The genuinely new domain concern:** a derived **classification** —
  Normal / Elevated / Hypertension Stage 1 / Stage 2 / Crisis — computed
  from `(systolic, diastolic)` by a use case that has no equivalent
  anywhere in Water, Medicine, or Prayer (none of the first three modules
  classify a value against a health-threshold table). This is the real
  test: does adding a use case shape the existing three modules never
  needed require any change to `HabitModule` itself? **No** — the
  classification use case lives entirely inside `features/blood_pressure/
  domain/`, called from that module's own screens and its own
  `dashboardSummary()`; nothing about the contract needed to anticipate
  "some future module will need a threshold-classification concept."
- **No natural streak.** Unlike Water/Medicine/Prayer, a blood-pressure
  reading habit doesn't have an obvious "did you complete the day" streak
  concept — `dashboardSummary()` instead shows "last reading: 128/82,
  Normal," proving the contract doesn't implicitly assume every module has
  a streak, just because the first three happen to.
- **`pendingNotifications()` legitimately returns an empty list** — a
  reading habit isn't reminder-driven the way a medicine dose or a prayer
  time is (an optional "remind me to check today" nudge could reuse
  Water's interval-reminder pattern later, but nothing requires it).
  Confirms the contract's notification hook is opt-in per module, not a
  mandatory implementation burden for a module that doesn't need it.

## Synthesis

Together, the two examples stress the contract along its two real axes:
checklist/scheduled-habit shape (now proven three times — Medicine,
Prayer, Sleep) and free-log/measurement-habit shape (now proven twice —
Water, Blood Pressure) — and the one genuinely new domain concern Blood
Pressure introduces (multi-value classification) required precisely zero
changes to `HabitModule` itself. That's the actual bar for "the
abstraction was built at the right level": not that it was reused, but
that reusing it never required going back and changing it.
