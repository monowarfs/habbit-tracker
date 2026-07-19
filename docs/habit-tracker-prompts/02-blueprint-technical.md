# 02 — TECHNICAL BLUEPRINT (documentation only — NO code)

**Inputs:** `00-project-context.md`, `docs/product/*` (from run 01)
**Outputs:** files under `docs/technical/`

## 1. `database-decision.md` — REQUIRED FIRST
Compare **Isar vs. Drift** (and briefly ObjectBox/Hive) for this app on:
active maintenance as of today (check pub.dev — do not rely on memory),
query power needed for stats/calendars, migration story, multi-isolate access
(needed because notification callbacks may run in a background isolate),
JSON export friendliness, and learning curve for a SQL-fluent developer.
Recommend ONE and record it in `decisions.md`. Everything below uses the
chosen DB.

## 2. `database-design.md`
Full schema for all three modules + common. Must include:
- Per-module entities (water_logs, medicines, medicine_schedules,
  medicine_doses, medicine_stock_events, prayer_records, prayer_settings…)
  — you design the actual shape; justify normalization choices
- **Dose materialization decision:** are medicine doses generated ahead of
  time as rows, or computed on the fly from repeat rules? Compare both
  (notification scheduling needs concrete future instances; on-the-fly needs
  no backfill jobs). Recommend one.
- Common tables: reminders, notification_ledger (what was scheduled/fired/
  acted on), achievements, app_settings
- All timestamps stored as UTC + the rule for local-day bucketing
  (day boundary = user's local midnight; document DST/timezone-travel
  handling — this materially affects streaks and prayer times)
- Stable UUIDs on every exportable row (auto-increment IDs break
  import/merge)
- Indexes justified by the actual queries in the stats/calendar features

## 3. `erd.md`
Mermaid ER diagram of the full schema.

## 4. `data-models.md`
For each entity: the domain model (Freezed) fields with types and nullability,
the DB collection/table mapping, and the JSON export shape. Note where domain
model ≠ persistence model and why.

## 5. `architecture.md` — Clean Architecture design
- Layer diagram and dependency rule (presentation → domain ← data)
- **The module plugin contract** (the core scalability requirement): define a
  `HabitModule` abstraction that each module registers — id, display metadata,
  routes, dashboard summary widget builder, reminder contributions, stats
  contributions, export/import handlers. Show how a hypothetical future
  "Sleep" module plugs in with zero edits to existing modules; the only
  shared touchpoint is a single registration list.
- Map concepts to Laravel for the developer: Repository ↔ repository class,
  UseCase ↔ action class, Provider ↔ service container binding, Widget
  rebuild ↔ (no good Laravel analogue — explain reactive rebuilds properly)

## 6. `state-management.md`
- Riverpod with code generation: which provider types for which job
  (streams from DB → UI, controllers for mutations, keepAlive policy)
- Rule: UI never touches repositories directly; UI ← providers ← use cases
  ← repositories
- How DB change-streams drive reactive UI (log water → dashboard updates
  without manual refresh)

## 7. `offline-strategy.md`
- Single source of truth = local DB
- Future-sync readiness NOW, cheaply: every row carries `updatedAt` and
  soft-delete `deletedAt` instead of hard deletes. Explain why this is the
  minimum viable groundwork for later sync and costs almost nothing today.
  Explicitly do NOT build sync queues/conflict resolution yet.

## 8. `folder-structure.md`
Full tree for `lib/`, `test/`, `docs/`. Feature-first. Show exactly where a
new module's folder goes and what files it must contain.

## Rules
- Every non-obvious decision: 2–4 sentence comparison + recommendation,
  appended to `decisions.md`.
- No Dart implementation code; short illustrative interface sketches
  (≤15 lines) are allowed where prose is insufficient.
