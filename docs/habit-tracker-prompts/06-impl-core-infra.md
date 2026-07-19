# 06 — IMPLEMENTATION: CORE INFRASTRUCTURE

**Inputs:** `00-project-context.md`, `docs/technical/database-decision.md`,
`docs/technical/database-design.md`, `docs/technical/data-models.md`,
`docs/strategies/error-handling-logging.md`
**State your file plan + test list before writing code.**

## Scope

1. **Database layer** (per the DB chosen in run 02):
   - DB initialization provider (async, single instance, path handling)
   - Schema/collections for the **common** tables only
     (app_settings, notification_ledger, achievements). Module tables are
     created inside their module runs — verify the chosen DB supports
     incremental schema addition; if it forces a central schema file,
     document the controlled touchpoint and keep it to registration-only
     edits (mirroring the module registry pattern).
   - Migration scaffolding from day one, even with schema v1
2. **Settings repository**: typed settings (themeMode, locale, etc.) backed
   by the DB; replace run 05's in-memory seam. Theme + locale now persist
   across restarts.
3. **Error handling**: sealed `AppException` hierarchy + `Result`/either
   convention per the strategy doc; a top-level error widget/zone guard.
4. **Logging**: logger setup with levels per build mode, redaction helper,
   ring-buffer file output + "share logs" hook (UI arrives in run 12).
5. **Clock abstraction**: `Clock` provider used everywhere instead of
   `DateTime.now()`, plus local-day bucketing helpers (`localDayKey(dt)`)
   implementing the timezone rules from `database-design.md`. This is the
   foundation streaks depend on — test it hard.

## Out of scope
Module tables, notifications, any feature screens.

## Definition of Done
- Theme + language survive app restart
- Unit tests: day-bucketing across DST/timezone-change cases, settings
  round-trip on a temp DB, Result/exception mapping
- Analyze clean, tests pass, boots on both platforms
- Commit: `feat(core): database, settings persistence, errors, logging, clock`
