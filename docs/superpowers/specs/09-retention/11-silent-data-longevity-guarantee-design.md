# Silent Data-Longevity Guarantee

**Category:** Long-Term Retention · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
A user with two years of logged water, doses, and prayers has built something that only has value if it's still there tomorrow — and unlike a cloud service where retention policy is at least discoverable, a local-first app's silence about its own retention behavior can quietly seed a fear that an update might prune old history, cap it, or otherwise "clean up" the database without asking. That fear costs nothing to have and everything to act on: a user who half-believes their history could vanish on the next update has a hidden reason to disengage or stop trusting the app's longevity, exactly the kind of erosion this whole category exists to prevent. Stating the guarantee explicitly turns a silent assumption into a documented commitment.

## Goals
- Publish a clear, plain-language commitment (in Settings > About) that local history is never pruned, capped, or reduced by app version or update.
- Back the commitment with an actual audit confirming the current database retention behavior matches what's claimed (no silent caps or cleanup jobs already exist that would make the statement false).
- Keep the commitment visible somewhere a user would naturally look when wondering "is my history safe" — About screen, alongside other trust statements.

## Non-goals / out of scope
- No new backup/export mechanism — this is a retention-policy statement, not a new data-safety feature (export/import already exists via the Data settings screen).
- No migration tooling changes in this pass — if the audit finds an actual retention risk (e.g. a rolling-window table meant to cap history), fixing that is a separate, possibly larger, engineering task flagged for follow-up, not silently bundled into this copy-focused spec.
- No legal/contractual guarantee language — plain, honest product copy, not a formal SLA.

## Proposed approach (high-level)
Two parts: first, an audit of actual current retention behavior across the database — most modules keep full history, but Medicine's dose table is explicitly described as a rolling window, which needs to be understood clearly before making a blanket "never pruned" claim (a rolling operational window for upcoming/near-term doses is different from summary history/streak data being capped, but the guarantee's wording needs to be accurate about which is which rather than overpromising). Second, once the actual behavior is confirmed safe to promise, add the commitment as copy in the About screen alongside whatever other trust-building statements exist there (or alongside the offline-data reassurance in Data settings, if that's a better fit). This is fundamentally a documentation-and-copy task gated on a real audit, not new engineering, unless the audit surfaces something that needs fixing first.

## Resolved Dependencies
The following must be built and merged before this spec can begin implementation:

1. **Data settings reassurance feature (#8)** — The offline-data reassurance copy in the Data settings screen must ship first so this spec can reference consistent phrasing and placement. Both are trust-copy additions; pairing them in one pass avoids duplication.
2. **About screen** — Must exist (or the Data settings screen must be extended) to host the retention guarantee copy. If neither exists, the implementation must create the surface first.
3. **Schema migration for any new audit-tracking table** — If the spec decides to persist audit results (recommended for ongoing validation), a schema migration and `schemaVersion` bump in `app_database.dart` are required. This is the cross-cutting gap: no migration strategy was called out in the original spec.
4. **Notification ledger cleanup mechanism** — The `notification_ledger` table currently has no bounded growth strategy. Before claiming "your data is never pruned," the spec must either (a) confirm the ledger is bounded (e.g. capped at N entries with FIFO eviction), or (b) document that ledger pruning is excluded from the guarantee. This is a cross-cutting infrastructure gap.
5. **Backup/export large-dataset handling** — The existing export/import in Data settings must handle datasets that grow over 3-4 years (e.g. 10,000+ water entries, 2,000+ medicine doses). If it currently loads everything into memory, that's a scalability risk that should be addressed or documented before this spec claims longevity.

## Dependencies & prerequisites
- An About screen (or equivalent) to host the copy — confirm it exists or identify the nearest equivalent settings surface.
- A retention-policy audit across all tables in the central database, specifically distinguishing rolling/derived windows (like the Medicine dose materialization window) from permanent history/log tables, so the guarantee is worded precisely rather than overstated.
- Coordination with the Data settings reassurance feature (#8), since both are trust-copy additions and may want consistent phrasing/placement.
- **Cross-cutting gap: near-duplicate privacy copy** — The Data settings and About screen may both contain trust statements. The audit should identify any overlapping copy and consolidate into a single source of truth to avoid maintenance drift.
- **Cross-cutting gap: notification ledger unbounded growth** — The `notification_ledger` table has no documented cleanup policy. The guarantee must either exclude ledger entries from "never pruned" claims or confirm the ledger has a bounded strategy.
- **Cross-cutting gap: no schema migration documented** — If the audit produces a persistent result (e.g. a "last audited" timestamp or a table-level audit log), the migration and `schemaVersion` bump must be part of this spec's implementation plan.
- **Cross-cutting gap: backup/export does not handle large datasets** — The export mechanism must be verified (or flagged for follow-up) against multi-year data volumes before this spec's guarantee is published, since a user who reads "your data is safe" and then tries to export 5 years of data into a crash is a trust violation.

## Edge Cases & 3-4 Year Considerations

**Edge cases:**
- **Medicine dose materialization window vs. permanent history** — The `medicine_doses` table is a rolling 30-day operational window; dose *history* (what the user actually took) lives in `medicine_records` or equivalent permanent log. The guarantee must be precise: "your dose history is never pruned; the near-term upcoming-dose projection is regenerated as needed." Conflating the two makes the guarantee false.
- **Notification ledger as "data"** — Users may not consider notification history "their data," but if the ledger grows unbounded, it becomes a storage concern. The guarantee should explicitly state whether notification metadata is included in the commitment.
- **App update wipes local storage** — On Android, app updates do not normally wipe data, but a version migration that changes the schema could theoretically drop tables if the migration function is buggy. The guarantee assumes correct migrations — the audit should confirm no migration has ever dropped user data.
- **First-launch data seeding** — Settings tables seed default rows on first read. If a future version changes defaults, old users keep their original values (correct behavior). The guarantee should confirm this: "your settings are never overwritten by app updates."
- **Device storage full** — If the device is out of storage, new entries may fail silently. The guarantee should note that it covers data integrity, not storage availability — a subtle but important distinction.

**3-4 year scalability concerns:**
- **Database size at 3-4 years** — A heavy user could accumulate 50,000+ water entries, 5,000+ medicine dose records, and 10,000+ prayer records. The Drift database and SQLite should handle this fine, but the export/import mechanism may not (see cross-cutting gap above).
- **Schema migration compounding** — Each feature run bumps `schemaVersion`. At 3-4 years with 10+ feature runs, the migration chain must be tested end-to-end. The audit should confirm that cumulative migrations don't break older installs upgrading across multiple versions.
- **Achievement table at scale** — With the cross-module achievement layer (Run 15), the `achievements` table could grow with cosmetic unlocks, tenure milestones, and module-specific achievements. At 3-4 years, this table should remain modest (<100 rows per user), but the evaluator must not re-scan the entire table on every app open.
- **Audit freshness** — If the audit is a one-time event, the guarantee becomes stale as new tables are added. A standing checklist item (schema changes must be reviewed against the longevity guarantee) should be documented, even if not automated.

## Acceptance Criteria
1. A retention guarantee statement exists in the About screen (or Data settings) in both `en` and `bn` localization files.
2. The statement accurately distinguishes permanent history tables from rolling/operational windows (e.g. Medicine dose materialization).
3. A retention-policy audit document exists (e.g. `docs/engineering/retention-audit.md`) listing every table, its retention behavior (permanent/rolling/capped), and whether it falls under the guarantee.
4. The audit confirms no silent data pruning, capping, or cleanup jobs exist in the current codebase.
5. The guarantee copy is consistent with (does not contradict) the Data settings reassurance copy — no near-duplicate or conflicting statements.
6. The `notification_ledger` table's growth behavior is documented in the audit, and the guarantee either includes it (with a bounded strategy) or explicitly excludes it.
7. The export/import mechanism is verified to handle at least 10,000 rows without crashing or excessive memory usage (or this is documented as a known limitation with a follow-up ticket).
8. The schema migration path is tested: an app upgraded from `schemaVersion` N-1 to N with existing data does not lose any rows.
9. `flutter test` passes for all new/modified test files; `flutter analyze` shows no new warnings.

## Open questions for the implementation round
- ~~Does the rolling dose-materialization window need caveat language in the guarantee ("your dose history is never pruned; only the near-term upcoming-dose projection is periodically regenerated"), or is that distinction confusing to a general user and better left unsaid/reworded?~~ **Decision: Include the caveat in plain language.** The About screen copy says: "Your dose history is always saved. The app also generates a short-term forecast of upcoming doses, which is updated regularly — this forecast is not your history and is regenerated as needed." Precision matters more than simplicity here; users who understand the distinction trust the app more.
- ~~Is About screen the right home, or should this live in Data settings next to the offline reassurance instead?~~ **Decision: Data settings screen**, next to the existing offline-data reassurance. This keeps all data-trust statements in one place, avoids duplication, and is where a user thinking about data safety would naturally navigate.
- ~~Does this commitment need to be revisited/re-audited as a standing checklist item on future schema changes, to stay true over time?~~ **Decision: Yes.** Add a line to `docs/engineering/schema-migration-checklist.md` (or equivalent): "Verify new tables/changes against the data-longevity guarantee in Data settings. Flag any rolling-window or capped tables for explicit exclusion." This is documentation, not automation.
- ~~Is the notification ledger bounded, and should it be included in the longevity guarantee?~~ **Decision: Exclude from the guarantee.** The `notification_ledger` is operational metadata (scheduling records for notification delivery), not user-generated content. It should have its own bounded cleanup policy (e.g. FIFO eviction of entries older than 90 days) documented separately. The longevity guarantee covers user-authored data only: water logs, medicine doses/history, prayer records, settings, and achievements.

## Effort & sequencing notes
Complexity S for the copy itself; the audit is the part worth taking seriously since the guarantee is only as good as it is true. Natural to pair with the offline-data reassurance feature (#8) in the same implementation pass, given both are short trust-building copy additions to adjacent settings surfaces.
