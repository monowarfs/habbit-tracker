# Performance

## Cold-start budget

Targets already set in `../technical/non-functional-requirements.md`
(NFR-01): < 2.0s to interactive dashboard on the low-mid Android reference
device, < 1.5s on the iOS baseline. This document covers the two
architectural levers that keep the app inside that budget as it grows to
three modules: lazy module initialization, and not doing more DB work at
startup than the dashboard actually needs.

## Lazy module initialization

**A disabled module does no startup work.** `HabitModule`
(`architecture.md`) exposes an `initialize()` lifecycle hook, called only
for modules where `modules.enabled = true` (per `ModuleState`,
`data-models.md`) — not unconditionally for all three at app launch. A
water-only user (the Nusrat persona, `../product/personas.md`) never pays
the cost of Prayer's location resolution + calculation-method setup, or
Medicine's schedule/dose-materialization check, at cold start, because
those modules' `initialize()` is simply never called. This is the direct
performance payoff of the plugin architecture existing at all — it's not
just an extensibility mechanism, it's what keeps cold start proportional
to *enabled* feature surface, not total feature surface, as more modules
are added later.

Within an enabled module, `initialize()` itself stays cheap by design:
D-13's rolling-window materialization check (medicine doses, prayer
records) runs as a background task kicked off after first frame, not
awaited before the dashboard renders — the dashboard shows whatever's
already materialized from the last session first, then updates reactively
(`state-management.md`'s stream-provider pattern) if the top-up job adds
anything. A cold start never blocks on "regenerate 30 days of rows" before
showing a screen.

## Chart data: query raw vs. maintain daily rollup rows

**Options considered** for yearly stats/calendar views (FR-W-08, FR-M-08,
FR-P-10):

- **A. Query raw on demand** — a `GROUP BY` date-truncated query directly
  against `water_logs`/`medicine_doses`/`prayer_records` each time a stats
  screen opens.
- **B. Maintain a `daily_rollup` table** — one precomputed row per local
  day per module (`total_ml`, `doses_taken`/`missed`/`skipped` counts,
  `prayers_prayed` count), upserted incrementally on every write, so a
  yearly chart is a single indexed range scan with no aggregation at read
  time.

**Recommendation: A — query raw — for v1.0.**

**Reasoning:** this is a single-user, on-device database, not a
multi-tenant analytics workload — the scale rollup tables exist to solve.
`non-functional-requirements.md` NFR-04 anticipates 5 years of daily data
as the outer bound, which works out to roughly 1,825 rows per
daily-cadence entity — trivially small for SQLite to `GROUP BY` over an
indexed date column well within NFR-03's 300ms interaction-latency budget.
Option B trades a small write-path cost (an extra upsert on every log/
status-change, plus the ongoing risk of rollup drift if some future write
path forgets to update it) for a read-time guarantee this app's actual data
volume doesn't need yet. Building the rollup table now would be optimizing
for a scale problem before measuring whether it exists — revisit only if
Run 14's real-device performance pass (`../product/roadmap.md`) shows the
raw query genuinely missing NFR-02/03 at realistic 5-year data volumes,
which is the point at which a rollup table would earn its added
write-path complexity.

## `build_runner` hygiene

Generated files (`*.g.dart` from `riverpod_generator`/`json_serializable`,
`*.freezed.dart`, Drift's generated database code) are **not committed** —
added to `.gitignore`. They regenerate deterministically from source via
`dart run build_runner build --delete-conflicting-outputs`, which CI runs
before `flutter analyze`/`flutter test`/`flutter build`. Committing
generated code creates merge-conflict noise on every schema/model change
and risks staleness (a committed generated file silently drifting from its
source if someone forgets to regenerate before committing) — not
committing them removes both problems at the cost of every clone/checkout
needing one `build_runner` pass before first run, which is normal,
expected Flutter/Riverpod-codegen workflow, not a burden specific to this
project.

## Image/asset policy

- **Prefer built-in Material Symbols (`Icon(IconData)`) over custom icon
  assets** wherever a stock icon adequately represents the concept —
  avoids bundling icon font/SVG files for things the SDK already ships.
- **Custom vector assets only for the three module-identity icons**
  (Water/Medicine/Prayer, `theme.md`'s per-module accent colors need a
  matching identity mark Material Symbols doesn't provide) — via
  `flutter_svg` (verified active on pub.dev 2026-07-17: v2.3.0, published
  2026-05-08), one small SVG per module rather than a full custom icon
  font for three icons.
- **Bundled data assets kept minimal and purposeful:** the Bangla font
  files (`localization.md`, bundled specifically to satisfy the offline
  requirement) and the manual-city dataset (`prayer-times.md`, a small
  curated JSON, not a full world-cities database) are the two largest
  deliberate asset additions — both directly required by a stated FR/NFR,
  not speculative inclusion.
- **Raster assets** limited to what `flutter create`'s platform scaffolding
  already requires (launcher icons at standard mipmap densities) — no
  additional raster image assets bundled without a concrete screen that
  needs them. This discipline is what keeps `non-functional-requirements.md`
  NFR-06's < 50MB install-size target achievable without a dedicated
  asset-size review late in the project.
