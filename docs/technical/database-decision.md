# Database Decision

**This document gates every other file in `docs/technical/`.** Every schema,
data-model, and offline-strategy document that follows assumes the engine
chosen here.

## Live pub.dev data (checked 2026-07-17, via `pub.dev` API, not memory)

| Package | Latest version | Published | Pub score | Likes | Downloads/30d | Notes |
|---|---|---|---|---|---|---|
| `isar` (isar.dev) | 3.1.0+1 | **2023-04-25** | 130/160 | 2,446 | 5,165 | No release in 3+ years. Original maintainer (Simon Choi) went quiet; this is the version most existing tutorials/CLAUDE.md-style docs still reference. |
| `isar_community` (isar-community.dev) | 3.3.2 | 2026-03-23 | 140/160 | 156 | 84,001 | Community fork continuing where original stalled. Genuinely active, but a fork with a smaller, younger publisher reputation and likes count (most historical likes stayed on the original package name). |
| `drift` (simonbinder.eu) | 2.34.2 | **2026-07-14** (3 days before this document) | **160/160** | 2,431 | **998,339** | Tagged `is:flutter-favorite`. Actively released, largest install base of the four by a wide margin. |
| `objectbox` (objectbox.io) | 5.3.2 | 2026-05-20 | 160/160 | 1,574 | 147,327 | Active, well-maintained. |
| `hive` (original) | 2.2.3 | 2022-06-30 | — | — | — | Abandoned ~4 years, superseded by `hive_ce`. |
| `hive_ce` | 2.19.3 | 2026-02-03 | — | — | — | Active community fork, but Hive is a key-value box store, not a query engine — ruled out early, see below. |

**Immediate implication:** any decision built on the original `isar` package
name is building on a dead dependency. The real choice is between
`isar_community`, `drift`, and `objectbox`. `hive`/`hive_ce` is excluded from
the comparison table below — it has no query language, no joins, no indexes
beyond box keys, which fails the "query power for stats/calendars"
requirement outright regardless of maintenance status.

## Comparison

| Criterion | `isar_community` | `drift` | `objectbox` |
|---|---|---|---|
| **Active maintenance** | Yes, but small team, package renamed mid-flight (migration friction for any tutorial/example built on `isar`) | Yes, most active of the three, Flutter Favorite, weekly-cadence releases | Yes, corporate-backed (ObjectBox GmbH), steady release cadence |
| **Query power (joins, group-by, date-range aggregation for stats/calendars)** | NoSQL object store — supports filters and sort, but no real joins; cross-entity stats (e.g. "medicine adherence % joined with schedule metadata") require manual application-side joins | Full SQL (SQLite dialect) — `GROUP BY`, date functions, joins, window functions all native. This is the single biggest differentiator for the stats/calendar-heavy feature set in `functional-requirements.md` (FR-W-08, FR-M-08, FR-P-10) | Same limitation as Isar — NoSQL object store, relational queries done in Dart, not SQL |
| **Migration story** | Schema migrations exist but are less mature/less documented than Drift's; breaking schema changes have historically required more manual handling | First-class: versioned schema, `drift_dev` generates migration scaffolding, has a dedicated schema-verification test harness (`drift_dev schema` + `verifySelf`) precisely to catch migration bugs before release | Has schema migration support, generally considered solid, but less tooling around *verifying* migrations than Drift |
| **Multi-isolate access** (needed: notification action callbacks run in a background isolate per FR-C-07) | Supports isolate access via its native FFI binding, but the API for sharing a DB instance across isolates is less documented than the other two | First-class: `NativeDatabase.createInBackground()` and `DatabaseConnection` are designed specifically for a background isolate talking to the same SQLite file safely; this is a commonly-documented pattern in the Flutter notification-plugin ecosystem | Supports a "Store" object that can be reopened per isolate (each isolate opens its own attachment to the same file); works, comparable ergonomics to Drift here |
| **JSON export friendliness** (FR: local export/import is a named v1.1 candidate) | Objects are Dart classes; JSON serialization is manual/via `toJson` you write yourself, same amount of work regardless of DB | Query results are plain rows/typed classes generated from your SQL — trivially mapped to JSON, and because it's relational, a full-database export is just "dump every table," which maps cleanly onto a portable JSON/SQL export format | Same manual-mapping situation as Isar |
| **Learning curve for a SQL-fluent, Laravel/Eloquent-background developer** | New concept: NoSQL object/collection model, its own query builder DSL, no transferable SQL knowledge | **Direct match.** You write real SQL (or Drift's typed Dart-SQL DSL, which is closer to a query builder than an ORM) against real tables with real foreign keys — a `medicine_doses` table with a `medicine_id` foreign key is exactly the mental model of an Eloquent migration + model | Another new NoSQL-style API to learn, similar gap to Isar |

## Recommendation: **Drift**

**Reasoning:**

1. **Query power decides it.** This app's hardest technical requirement is
   not storage, it's the stats/calendar/adherence features (FR-W-08,
   FR-M-08, FR-P-09/10) — "last 30 days," "on-time vs. late vs. missed
   percentage," "streak = consecutive days meeting a condition." These are
   textbook `GROUP BY`/date-range SQL queries. Isar/ObjectBox force those
   computations into Dart application code, which is more code to write,
   more code to test, and slower for large datasets (NFR-04: 5 years of
   daily data across 3 modules) than letting SQLite's query planner and
   indexes do the work.
2. **The developer's existing SQL fluency is a real asset, not a
   footnote.** Per `00-project-context.md`, this developer has "strong SQL,
   API design, and clean-code instincts" from Laravel/Eloquent. Drift's
   table/column/foreign-key model — and its generated typed query API — is
   the one option here that lets that experience transfer directly, instead
   of requiring a second query paradigm learned from scratch.
3. **Maintenance health is unambiguous.** A package released 3 days before
   this document was written, with a perfect pub score and a Flutter
   Favorite badge and ~1M monthly downloads, is the safest long-term bet of
   the three for a project that needs years of runway. The original `isar`
   package this project's `00-project-context.md` was written against is
   dead; continuing to plan around it would be planning around a
   dependency that already stopped receiving updates in 2023.
4. **Multi-isolate support is well-trodden ground specifically for this
   app's exact use case** (a `flutter_local_notifications` action callback
   running in a background isolate needs to write a "dose marked Done" row
   to the same database the foreground UI reads from) — Drift's
   `NativeDatabase.createInBackground` pattern is the standard, documented
   solution to this exact problem.
5. **Trade-off acknowledged:** Drift requires writing schema in Dart-SQL
   (or raw `.drift` files) and running `build_runner`, which is marginally
   more upfront ceremony than Isar's annotation-only collections. This cost
   is paid once per schema change and is smaller than the ongoing cost of
   hand-rolling relational queries in Dart for every stats feature.

**Superseded guidance:** `00-project-context.md`'s tech stack line ("Isar\*")
is superseded by this document per its own footnote ("If [the technical
blueprint] selected Drift instead of Isar, follow the document"). All
subsequent technical docs in this run assume Drift.

Recorded as **D-11** in `../product/decisions.md` (single running decisions
log for the whole project — this technical run appends to it rather than
starting a second log file, so there is one place to check for every
product+technical decision made so far).
