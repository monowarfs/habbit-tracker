# Database Design

Engine: **Drift** (D-11). All SQL below is illustrative Drift-flavored SQL/DDL
for schema design purposes — actual table classes are generated from Drift's
Dart-SQL DSL in the implementation run, not written here (this is a
documentation-only run).

**Note added during Run 06 implementation — the one central, unavoidable
touchpoint:** unlike `architecture.md`'s `HabitModule` registry (a plain
Dart list any module can append to with zero coordination), Drift itself
requires every table class, from every module, to appear in one
`@DriftDatabase(tables: [...])` annotation on the single `AppDatabase`
class (`core/database/app_database.dart`) — this is a Drift code-generation
constraint, not a design choice this project made. Each module run adds
exactly one line to that list (its own table classes) and nothing else in
`core/database/` — the closest Drift gets to the module-registry pattern,
documented here since it's the one place a future module's own run must
remember to touch outside its own `features/<name>/` folder.

## Global rules (apply to every table below)

- **Primary key:** every table has `id TEXT PRIMARY KEY` — a UUID v7 string
  (D-12), generated client-side at row-creation time. No auto-increment
  integer PKs anywhere; auto-increment IDs are exactly what breaks
  import/merge on a future restore/sync, which this schema must not
  preclude (per `00-project-context.md`'s "design for it, do not build it").
- **Audit columns:** every table has `created_at INTEGER` (UTC epoch millis),
  `updated_at INTEGER` (UTC epoch millis, bumped on every write), and
  `deleted_at INTEGER NULL` (soft delete — see `offline-strategy.md` for why
  this exists now instead of hard deletes). No row is ever `DELETE`d by
  application code; deletion is `UPDATE ... SET deleted_at = ?`. All
  application queries filter `WHERE deleted_at IS NULL` unless explicitly
  querying history.
- **Timestamps vs. wall-clock definitions (D-14):** columns holding a
  concrete instant (`*_at` columns, `scheduled_for`) are UTC epoch millis.
  Columns holding a recurring local time-of-day (`times_of_day` on a
  schedule) or a local calendar-date bucket (`prayer_date`) are stored as
  plain local strings (`"08:00"`, `"2026-07-17"`) — never converted to UTC,
  because their meaning is inherently local-wall-clock, not a fixed instant.
- **Local-day bucketing rule:** "today" for streak/goal purposes is the
  device's *current* local calendar date. For `water_logs`, the local day a
  log belongs to is derived at query time from `logged_at` (UTC) converted
  through the device's current timezone — cheap, and the DST/travel edge
  case is accepted as documented (a user logging water while mid-flight
  across a timezone boundary is a rare, low-stakes case, unlike prayer
  timing). For `prayer_records`, the local date is instead materialized as
  an explicit `prayer_date` column at row-generation time, because prayer
  day-boundaries are correctness-critical (Qadha cutoff, custom Isha
  rollover, FR-P-05/D-08) and must not silently re-bucket if recomputed
  later from a raw UTC instant after the user has traveled.

---

## Common tables

### `app_settings` (singleton row — enforced by app code always upserting the one row with a fixed id `'singleton'`, not a DB constraint, since Drift has no native "exactly one row" constraint short of a trigger, and a trigger is unjustified complexity for an app-code-enforced invariant)

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | always `'singleton'` |
| locale | TEXT | `'en'` \| `'bn'` |
| theme_mode | TEXT | `'system'` \| `'light'` \| `'dark'` |
| water_unit | TEXT | `'ml'` \| `'fl_oz'` (D-01) |
| pin_enabled | INTEGER (bool) | |
| pin_lock_timeout_seconds | INTEGER | 0 = immediate |
| onboarding_completed_at | INTEGER NULL | UTC |
| created_at, updated_at | INTEGER | |

**Normalization note:** a single strongly-typed row (not a generic
`key TEXT, value TEXT` table) is deliberate — the set of app-wide settings
is small and fixed (FR-C-04/05/06, D-01), so typed columns give compile-time
safety and a real Drift query API for free; a generic KV table would only
be justified if settings were open-ended/plugin-defined, which they aren't.

**Note (D-15, `../strategies/security.md`):** the PIN's salted hash (and
the lockout failed-attempt counter) deliberately do **not** live in this
table — they're kept in `flutter_secure_storage` (OS Keychain/Keystore),
separate from this plaintext SQLite database, at effectively zero extra
cost. `app_settings` only tracks whether PIN lock is *enabled* and its
timeout, never the credential itself.

### `modules`

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | `'water'` \| `'medicine'` \| `'prayer'` (and future module ids) |
| enabled | INTEGER (bool) | FR-C-10 |
| position | INTEGER | dashboard/nav ordering |
| setup_completed_at | INTEGER NULL | UTC; null = never configured |
| created_at, updated_at | INTEGER | |

### `notification_ledger`

Records every notification the app has ever scheduled and what happened to
it — the audit trail behind FR-C-07/08/09 and the snooze-limit rule
(FR-M-07/FR-P-08).

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | |
| module_id | TEXT | `'water'` \| `'medicine'` \| `'prayer'` |
| source_type | TEXT | `'medicine_dose'` \| `'prayer_record'` \| `'water_reminder'` \| `'low_stock'` |
| source_id | TEXT | id of the row in the relevant module table (application-level reference only — see note below) |
| title | TEXT | notification display title |
| body | TEXT | notification display body |
| scheduled_for | INTEGER | UTC instant the OS was asked to fire at |
| fired_at | INTEGER NULL | UTC, set by the notification-received handler |
| action | TEXT NULL | `'done'` \| `'snooze'` \| `'skip'` \| null (not yet actioned) |
| action_at | INTEGER NULL | UTC |
| snooze_count | INTEGER | default 0, enforces the max-3 rule |
| deep_link_route | TEXT | e.g. `/medicine/dose/:id` — precomputed at scheduling time so the notification tap handler doesn't need a DB read to navigate |
| created_at, updated_at, deleted_at | INTEGER | |

**Added (Run 08 implementation):** `title`/`body` columns. A Snooze
reschedules the *same* notification at `now + 10min` (`strategies/
notifications.md`); without persisting the original content here, the
handler would have to ask the owning module to regenerate it, which isn't
reliable days later (settings may have changed, or — for a future
Medicine/Prayer module — the source row's data may have moved on). The
ledger already exists as this notification's durable record, so it's the
right place for its content, not just its audit trail.

**Why `source_id` isn't a SQL foreign key:** `notification_ledger` is
intentionally polymorphic (one ledger for three+ future source types,
satisfying the plugin-module requirement that new modules don't need schema
changes to existing tables). A real FK constraint would require a
`source_type`-conditional constraint, which Drift/SQLite can't express
declaratively; referential integrity here is enforced in the repository
layer instead. This is the one deliberate exception to "every relationship
is a real FK" below, and it exists specifically so a future "Sleep" module
can schedule notifications through this same table with zero migration.

**Indexes:** `(scheduled_for)` — the background rescheduling job and the
boot receiver both query "everything due soon" or "everything pending as of
now." `(source_type, source_id)` — action handlers look up the ledger row
for a specific dose/prayer instance.

### `achievements`

Backs the achievement/badge engine added in Run 15
(`../superpowers/specs/2026-07-19-dashboard-reports-achievements-design.md`).
Was schema-only groundwork through v1.0 (no achievement UI/logic shipped
before then) — this table's shape was fixed early so that run needed no
migration.

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | |
| module_id | TEXT | which module this achievement belongs to |
| key | TEXT | e.g. `'water_7_day_streak'` |
| progress_current | INTEGER | |
| progress_target | INTEGER | |
| unlocked_at | INTEGER NULL | UTC; null = not yet unlocked |
| created_at, updated_at, deleted_at | INTEGER | |

---

## Water module

### `water_goals`

Modeled as an **append-only history table**, not a single mutable field —
this directly satisfies FR-W-04 (a goal change mid-day must not retroactively
alter whether a past day counted as complete): each edit inserts a new row;
a given day's applicable goal is "the row with the latest `effective_from`
that is `<=` that day's local midnight."

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | |
| goal_ml | INTEGER | canonical unit is always ml (D-01) |
| effective_from | INTEGER | UTC instant the goal took effect |
| created_at, updated_at, deleted_at | INTEGER | |

**Index:** `(effective_from)` — every day's-total query resolves "which goal
applied" via a `WHERE effective_from <= :dayStart ORDER BY effective_from DESC LIMIT 1`.

### `water_logs`

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | |
| amount_ml | INTEGER | canonical ml regardless of display unit (D-01) |
| logged_at | INTEGER | UTC instant this entry represents (may be backdated, FR-W-05, capped at "now" by app logic, not a DB constraint) |
| source | TEXT | `'quick'` \| `'custom'` — **added during Run 07 implementation**, not in this doc's original pass; distinguishes a one-tap quick-add preset from a custom-amount entry (FR-W-03), shown as a different icon in the log list |
| created_at, updated_at, deleted_at | INTEGER | `created_at` differs from `logged_at` exactly when an entry was backdated — this difference is what a future audit view could use to show "logged retroactively," though no such UI is required in v1.0 |

**Index:** `(logged_at)` — every stats/calendar/streak query is a date-range
scan over this column (FR-W-07/08).

### `water_settings` (singleton row, same pattern as `app_settings`)

**Added during Run 07 implementation** — this doc's original pass had no
table for FR-W-03's configurable quick-add presets or FR-W-10's reminder
preferences; this is Water's own equivalent of `prayer_settings`.

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | always `'singleton'` |
| quick_add_amounts_ml | TEXT | JSON array of ml amounts, e.g. `"[250,500,750]"` (FR-W-03) |
| reminder_enabled | INTEGER (bool) | default false (FR-W-10) |
| reminder_interval_minutes | INTEGER | default 120 |
| reminder_window_start | TEXT | local `"HH:mm"`, default `"08:00"` |
| reminder_window_end | TEXT | local `"HH:mm"`, default `"22:00"` |
| created_at, updated_at | INTEGER | |

---

## Medicine module

### `medicines`

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | |
| name | TEXT | |
| dosage_note | TEXT NULL | free text, e.g. `"500mg"` |
| stock_enabled | INTEGER (bool) | |
| stock_count | INTEGER NULL | |
| stock_threshold | INTEGER NULL | low-stock trigger point |
| stop_when_stock_depleted | INTEGER (bool) | default false, D-04 |
| consumption_per_dose | INTEGER | default 1 |
| archived_at | INTEGER NULL | FR-M-10 soft-archive, distinct from `deleted_at` (archive is a user-facing, reversible "hide but keep for stats" state; `deleted_at` is the sync-groundwork soft-delete — see `offline-strategy.md` for why these two are kept separate) |
| created_at, updated_at, deleted_at | INTEGER | |

### `medicine_schedules`

One medicine can have multiple rows here concurrently (D-02).

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | |
| medicine_id | TEXT FK → medicines.id | |
| frequency_type | TEXT | `'fixed_daily'` \| `'every_n_days'` \| `'weekday_set'` \| `'prn'` |
| interval_days | INTEGER NULL | used only when `frequency_type = 'every_n_days'` (D-03) |
| weekdays_mask | INTEGER NULL | bitmask Mon=1..Sun=64, used only for `'weekday_set'` |
| times_of_day | TEXT | JSON array of local `"HH:mm"` strings, e.g. `["08:00","20:00"]` — local wall-clock, not UTC (D-14) |
| start_date | TEXT | local calendar date `"YYYY-MM-DD"`, anchor for `every_n_days` (D-03) |
| end_date | TEXT NULL | local calendar date, null = open-ended |
| grace_window_minutes | INTEGER | default 30, editable 0-180 (D-05) |
| created_at, updated_at, deleted_at | INTEGER | |

**Normalization note:** `frequency_type` + nullable pattern-specific columns
(rather than 4 separate schedule-type tables) is chosen because the
pattern-specific data is small (2-3 columns) and every query needs to treat
"a medicine's schedules" as one homogeneous list regardless of pattern —
splitting into subtype tables would require a `UNION` on every read for no
normalization benefit (none of the pattern-specific columns are themselves
relational).

### `medicine_doses`

Materialized rows, not computed on the fly (D-13) — one row per concrete
dose instance, generated for a rolling 30-day window.

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | |
| medicine_id | TEXT FK → medicines.id | denormalized alongside `schedule_id` so a dose survives being queried even if its generating schedule is later edited/replaced |
| schedule_id | TEXT FK → medicine_schedules.id | |
| scheduled_for | INTEGER | UTC instant — schedule's local time-of-day resolved against device timezone at generation time (D-14) |
| status | TEXT | `'upcoming'` \| `'due'` \| `'done'` \| `'missed'` \| `'skipped'` (FR-M-06) |
| status_changed_at | INTEGER NULL | UTC |
| stock_delta_applied | INTEGER | default 0; how much stock this specific dose has deducted, so an edit/undo of this dose reverses the exact right amount rather than re-deriving it |
| created_at, updated_at, deleted_at | INTEGER | |

**Indexes:** `(scheduled_for)` — "today's doses across all medicines" is the
single most common query (FR-C-03 dashboard, medicine home screen).
`(medicine_id, scheduled_for)` — per-medicine adherence stats (FR-M-08).

**Collision handling (FR-M-02):** the materialization job, not a DB
constraint, is responsible for deduplicating two schedules that would both
generate a dose at the same medicine+time+day (most-recently-created
schedule wins, per D-02) — expressing "no two schedules of the same medicine
may produce the same timestamp" as a DB constraint would require a
cross-schedule uniqueness check the generation job already performs more
cheaply at write time.

### `medicine_stock_events`

Append-only ledger — `medicines.stock_count` is a cached/derived value,
this table is the source of truth for "why did stock change," enabling
undo (marking a dose "not done" after all) and audit.

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | |
| medicine_id | TEXT FK → medicines.id | |
| dose_id | TEXT NULL FK → medicine_doses.id | null for manual refills/adjustments not tied to a dose |
| delta | INTEGER | negative = consumption, positive = refill/adjustment |
| reason | TEXT | `'dose_taken'` \| `'manual_refill'` \| `'manual_adjustment'` \| `'dose_undone'` |
| occurred_at | INTEGER | UTC |
| created_at, updated_at, deleted_at | INTEGER | |

---

## Prayer module

### `prayer_settings` (singleton row, same pattern as `app_settings`)

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | always `'singleton'` |
| calculation_method | TEXT | D-06 (`'mwl'`, `'isna'`, `'egyptian'`, `'umm_al_qura'`, `'karachi'`, `'tehran'`, `'dubai'`, `'kuwait'`, `'qatar'`, `'singapore'`) |
| asr_method | TEXT | `'standard'` \| `'hanafi'` (D-06) |
| observes_jumuah | INTEGER (bool) | default false (D-07) |
| location_mode | TEXT | `'auto'` \| `'manual'` (D-09) |
| manual_latitude | REAL NULL | used when `location_mode = 'manual'` |
| manual_longitude | REAL NULL | |
| manual_timezone | TEXT NULL | IANA tz id, e.g. `"Asia/Dhaka"` |
| isha_day_rollover_time | TEXT | local `"HH:mm"`, default `"00:00"` (D-08 cutoff) |
| created_at, updated_at | INTEGER | |

### `prayer_records`

Materialized rows (D-13), one per prayer per local day, rolling 30-day
window, same reasoning as `medicine_doses`.

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | |
| prayer_date | TEXT | local calendar date `"YYYY-MM-DD"` — materialized bucket key (see global rules above for why this one column breaks the "derive locally at query time" pattern) |
| prayer_name | TEXT | `'fajr'` \| `'dhuhr'` \| `'asr'` \| `'maghrib'` \| `'isha'` \| `'jumuah'` |
| scheduled_for | INTEGER | UTC instant, computed from `prayer_settings` + resolved location at generation time |
| status | TEXT | `'upcoming'` \| `'due'` \| `'prayed'` \| `'missed'` |
| status_changed_at | INTEGER NULL | UTC |
| created_at, updated_at, deleted_at | INTEGER | |

**Unique index:** `(prayer_date, prayer_name)` — prevents the materialization
job from double-generating the same prayer on the same day (also serves as
the natural lookup key for the daily checklist screen). **Index:**
`(scheduled_for)` for "next up" queries.

### `prayer_qadha_counters`

One row per prayer type, five total, created at first setup (D-08).
`jumuah` has no row — Jumu'ah shares Dhuhr's Qadha bucket (D-07/FR-P-03).

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | |
| prayer_name | TEXT | `'fajr'` \| `'dhuhr'` \| `'asr'` \| `'maghrib'` \| `'isha'` |
| count | INTEGER | default 0, floors at 0 (app-enforced) |
| updated_at | INTEGER | |

---

## Foreign key summary

```
medicines 1──* medicine_schedules
medicines 1──* medicine_doses (denormalized, also → schedule)
medicine_schedules 1──* medicine_doses
medicines 1──* medicine_stock_events
medicine_doses 0..1──* medicine_stock_events

water_goals (no FK — standalone history table)
water_logs (no FK — standalone)

prayer_settings (singleton, no FK)
prayer_records (no FK — settings resolved at generation time, not joined at read time)
prayer_qadha_counters (no FK — standalone)

notification_ledger (polymorphic reference to any module table by convention, not FK — see note above)
achievements (loose module_id reference, same reasoning as notification_ledger)
```

Full visual diagram: `erd.md`.
