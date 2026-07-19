# Dashboard, Reports, Achievements — design

Run: **Run 15** (new — not `phases-and-dod.md`'s existing Run 13, which
covers dashboard aggregation + module enable/disable + PIN lock only, and
predates this scope). This run ships v1.1-class functionality: richer
dashboard (day-completion indicator, upcoming strip, quick actions),
weekly/monthly/yearly cross-module reports, an achievement/badge engine,
longest-streak records, cross-module search, and a global month calendar.
Entry criteria: Run 14 merged (v1.0 shipped) — this run does not block
v1.0 and is sequenced after it.

Implements new `FR-C-11..16` (`docs/product/functional-requirements.md`)
and new `D-16..19` (`docs/product/decisions.md`) — proposed text below;
adding them to those two files is itself part of this run's scope, per
`phases-and-dod.md`'s DoD rule 6 ("documentation this run's implementation
revealed as wrong or incomplete is corrected in the same PR"). Also
corrects `database-design.md`'s `achievements` table comment ("no
achievement UI/logic ships in v1.0") — that statement is superseded by
this run.

## Scope decisions (resolved during brainstorming)

- **Numbering:** new Run 15, appended to `roadmap.md`/`feature-
  breakdown.md`/`phases-and-dod.md`. Run 13's own dashboard/PIN/enable-
  disable scope is untouched — not merged or renumbered.
- **Achievement evaluation trigger:** module calls
  `AchievementEngine.evaluate(moduleId)` from its own write path right
  after the write commits (e.g. end of `LogWaterEntryUseCase`, mark-dose-
  done, mark-prayed) — not a periodic sweep. Precise, no unlock lag; new
  call sites in each module's existing use cases, same shape as any other
  post-write side effect already in this codebase.
- **`dayStatus(range)` is one shared contract method**, reused by both
  Reports (bucketed into week/month/year) and the global calendar
  (rendered as-is) and the dashboard's day-completion indicator (today's
  slice only) — not three separate methods. Matches this project's
  existing reuse precedent (D-13's materialization planner reused by both
  the rolling window and the notification engine).
- **Search is a full contract method**, `search(String) -> List<
  SearchResult>`, implemented by every module (Water/Prayer mostly return
  `[]` — they have no free-text-searchable named entities) rather than a
  Medicine-only special case. Keeps `core/` uniform (no module-specific
  branch), consistent with `architecture.md`'s stated principle.
- **Dashboard upcoming-items strip and quick actions are two new contract
  methods** (`nextUpcoming`, `quickActions`), not an expansion of the
  existing `dashboardSummary` tile — keeps "today's total" and "what's
  next / what can I do right now" as separate concerns per module.
- **Longest-streak records have no dedicated contract method** — computed
  generically in `core/reports/` from `dayStatus()`'s `complete`-day runs
  over an all-time range. One shared function, reused by every module,
  rather than N per-module streak-record methods.

## Proposed `functional-requirements.md` additions

**FR-C-11** — Dashboard shows, in addition to each enabled module's
existing summary tile (FR-C-03): an overall day-completion indicator
(complete modules / enabled modules, evaluated for today), an upcoming-
items strip (next dose, next prayer, water pace — one entry per module
that has something upcoming), and a quick-actions row (one-tap actions
each enabled module chooses to expose, e.g. Water's quick-add). A module
with nothing upcoming or no quick action contributes nothing to that
strip/row, not an empty placeholder.

**FR-C-12** — Reports screen aggregates every enabled module's daily data
into weekly/monthly/yearly views, with period navigation (previous/next)
and empty states for periods before a module's earliest recorded data
(not a zero-filled chart).

**FR-C-13** — An achievement engine evaluates module-contributed
achievement definitions (first log, 7/30/100-day streaks, perfect week,
etc.) after relevant writes; progress and unlock state persist in the
`achievements` table (`database-design.md`). A badge gallery screen shows
locked (progress) and unlocked (with unlock date) badges. Unlocking shows
a subtle, non-blocking moment (e.g. a snackbar on the screen that
triggered it) — never an intrusive modal popup.

**FR-C-14** — Reports surfaces each module's longest-streak record
alongside its current streak.

**FR-C-15** — A cross-module search (accessible from the dashboard) finds
named user-entered data across modules (e.g. medicine names/dosage notes)
and deep-links to the matching record. A module with no free-text-
searchable data (e.g. Water, Prayer) simply contributes no results, not
an error or empty-but-present section.

**FR-C-16** — A global calendar (month view) merges every enabled
module's per-day status into one combined coloring per day (all modules
complete / some incomplete / all missed / no data), with day drill-down
to see the per-module breakdown for that day.

## Proposed `decisions.md` additions

**D-16: Achievement evaluation trigger.** Decision: module-side call
after its own write commits (not a periodic sweep). Reasoning: precise,
zero lag on unlock, and every module already has well-defined write call
sites (log entry, mark dose done, mark prayed) to hook — a periodic sweep
would need every achievement definition to be re-derivable from a full
DB scan instead of an event, for no benefit here. Affects: FR-C-13.

**D-17: `dayStatus(range)` as one shared contract method** vs. separate
calendar/report methods. Decision: one shared method,
`Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange)`, consumed
differently by each caller (calendar renders per-day; reports buckets by
period; dashboard reads today's entry only). Reasoning: avoids duplicate
per-module range-query logic for what is fundamentally the same question
("what happened on day X") asked three ways. Affects: FR-C-11, FR-C-12,
FR-C-16.

**D-18: Search — full contract method vs. Medicine-only special case.**
Decision: full contract method, `search(String) -> List<SearchResult>`,
every module implements it (Water/Prayer return `[]`). Reasoning: keeps
`core/`'s search screen free of any module-id branching, matching
`architecture.md`'s explicit rule; the cost is a few one-line `[]`
overrides in modules with nothing searchable, not a real burden. Affects:
FR-C-15.

**D-19: Dashboard upcoming/quick-actions — new contract methods vs.
richer `dashboardSummary`.** Decision: two new methods,
`Widget? nextUpcoming(WidgetRef)` and `List<Widget> quickActions(WidgetRef)`.
Reasoning: `dashboardSummary`'s job (today's aggregate total/progress) is
a different concern from "what's the next actionable thing" and "what can
I do right now without navigating" — conflating them would make the
existing tile widget do two jobs. Affects: FR-C-11.

## Contract extensions (`lib/core/modules/habit_module.dart`)

```dart
abstract class HabitModule {
  // ...existing members unchanged...

  /// Per-day status for [range], used by the global calendar (as-is), the
  /// Reports screen (bucketed by period), and the dashboard's
  /// day-completion indicator (today's entry only). D-17.
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range);

  /// The next actionable item this module wants surfaced on the dashboard
  /// strip (e.g. "next dose at 8pm"), or `null` if there's nothing
  /// upcoming or the module has no data yet. D-19.
  Widget? nextUpcoming(WidgetRef ref);

  /// One-tap actions this module wants exposed on the dashboard's
  /// quick-actions row (e.g. Water's quick-add). Empty list if none. D-19.
  List<Widget> quickActions(WidgetRef ref);

  /// Free-text search over this module's own named user data. Modules
  /// with nothing free-text-searchable (Water, Prayer) return `[]`. D-18.
  Future<List<SearchResult>> search(String query);

  /// Achievement definitions this module contributes, evaluated by
  /// `core/achievements/achievement_engine.dart` after this module's own
  /// writes call `AchievementEngine.evaluate(id)`. D-16.
  List<AchievementDefinition> get achievementDefinitions;
}

enum ModuleDayStatusKind { complete, partial, missed, none }

@immutable
class ModuleDayStatus {
  const ModuleDayStatus({required this.kind, required this.value});
  final ModuleDayStatusKind kind;
  final num value; // ml logged / doses taken / prayers completed, etc.
}

@immutable
class SearchResult {
  const SearchResult({
    required this.title,
    required this.subtitle,
    required this.deepLinkRoute,
  });
  final String title;
  final String subtitle;
  final String deepLinkRoute;
}

@immutable
class AchievementDefinition {
  const AchievementDefinition({
    required this.key,          // e.g. 'water_7_day_streak'
    required this.moduleId,
    required this.titleKey,     // l10n key, not a raw string
    required this.descriptionKey,
    required this.target,
    required this.currentProgress, // closure over the module's own repo
  });
  final String key;
  final String moduleId;
  final String titleKey;
  final String descriptionKey;
  final int target;
  final Future<int> Function() currentProgress;
}
```

`DateRange` (`{LocalDate start, LocalDate end}`) is a new small value type
in `lib/core/utils/date_range.dart`, alongside `LocalDate`/`LocalDay`.

Every existing module (`WaterModule`, `MedicineModule`, `PrayerModule`)
implements all five new methods. This is the only touchpoint every
existing module's file is touched in this run — no other module-internal
file changes.

## `core/achievements/`

- `achievement_engine.dart` — `AchievementEngine.evaluate(String moduleId)`:
  looks up that module's `achievementDefinitions`, runs each
  `currentProgress()`, upserts the matching `achievements` row
  (`progress_current`/`progress_target`), and sets `unlocked_at` exactly
  once when progress first reaches target — same one-shot-crossing shape
  as Medicine's low-stock detection (FR-M-04) and Prayer's Qadha
  increment (FR-P-05), applied to a progress threshold instead of a stock
  count or missed-prayer event. Re-evaluating an already-unlocked
  definition is a no-op (checked via `unlocked_at IS NOT NULL` before any
  write).
- `achievement_repository.dart` — Drift-backed, no DAO (same precedent as
  Settings/Water/Medicine/Prayer — one caller).
- Definitions module-side, not core-side: each module's `*_module.dart`
  exposes `achievementDefinitions` as a getter returning definitions whose
  `currentProgress` closures call that module's own repository/streak use
  cases. `core/achievements/` never queries a module's tables directly.

Seeded definitions per module (symmetric set, no module richer than
another without a stated reason):

| Module | Definitions |
|---|---|
| Water | first log, 7-day streak, 30-day streak, 100-day streak, perfect week (goal met 7/7 days) |
| Medicine | first dose logged, 7-day adherence streak, 30-day adherence streak |
| Prayer | first prayer logged, 7-day streak, 30-day streak, 100-day streak, perfect week |

## `core/reports/`

- `longest_streak_from_day_status.dart` — pure function,
  `int longestStreak(Map<LocalDate, ModuleDayStatus> dayStatus)`: longest
  run of consecutive `complete` days. One implementation, called by every
  module's Reports contribution — not duplicated per module.
- `aggregate_report_usecase.dart` — `AggregateReportUseCase(DateRange
  range)`: calls `dayStatus(range)` on every enabled module (from
  `habitModulesProvider`), buckets each module's `ModuleDayStatus.value`
  into the requested period (week/month/year) using the existing
  DST-safe `localDayKey` bucketing, returns one series per module for
  `PeriodBarChart` plus each module's longest-streak record.

## Dashboard (`lib/features/dashboard/`)

`DashboardScreen` rewritten to iterate `ref.watch(habitModulesProvider)`:

- Per-module summary card: existing `dashboardSummary(ref)`, unchanged.
- Day-completion indicator: one ring/bar showing
  `complete modules today / enabled modules count`, from each module's
  `dayStatus` on today's single-day range.
- Upcoming strip: horizontal list of non-null `nextUpcoming(ref)` widgets.
- Quick actions: row of all modules' `quickActions(ref)` widgets,
  flattened, skipping empty lists.
- Search entry point: app-bar search icon (see below).
- Global calendar entry point: app-bar or menu action opening the month
  view (see below).
- 0 modules enabled: existing empty state (`emptyDashboardMessage`)
  unchanged — none of the new widgets render without at least one module.

## Reports (`lib/features/reports/`, new — `domain` + `presentation` only,
no `data` layer; it aggregates other modules' repositories, owns none of
its own)

- `ReportsScreen` — period-type selector (week/month/year), prev/next
  period navigation, one `PeriodBarChart` (`core/widgets/charts/`, reused
  — no new chart widget) per enabled module plus its longest-streak
  record, using `AggregateReportUseCase`.
- Empty state: if the selected period is entirely before a module's
  earliest `dayStatus` entry, that module's card shows "no data for this
  period" instead of a zero-filled chart.

## Achievements (`lib/features/achievements/`, new — `presentation` only;
the domain-level `AchievementDefinition`/evaluation lives in
`core/achievements/` since it's module-contributed, cross-cutting data,
not this feature's own)

- `AchievementGalleryScreen` — grid of every module's
  `achievementDefinitions` joined with their `achievements` table row:
  locked = greyed icon + progress bar (`current/target`), unlocked = full
  color + unlock date.
- Unlock moment: a `SnackBar` shown on whichever screen triggered the
  crossing (the same screen the user is already on after logging/marking
  something) — no modal, no dedicated "you unlocked X!" screen.

## Search

- Dashboard app-bar search icon → a simple debounced query field →
  `Future.wait` over `search(query)` on every enabled module → flat,
  merged `List<SearchResult>` sorted title-prefix-match first, then
  contains-match → tap navigates via `context.go(result.deepLinkRoute)`.
- No dedicated search screen route persisted in history — it's a
  transient overlay/route popped on navigation, same UX weight as a
  typical in-app search.

## Global calendar (`lib/core/widgets/global_month_calendar.dart`, new —
lives in `core/widgets/` since it's module-agnostic, unlike the existing
per-module history calendars e.g. `water_history_calendar.dart`)

- Month grid, one combined color per day derived from all enabled
  modules' `dayStatus` for that day: all `complete` → success color, any
  `partial`/mixed → warning color, all `missed` (where data exists) →
  error color, no module has data for that day → neutral/empty.
- Day tap → drill-down sheet listing each enabled module's individual
  status for that day (reuses `ModuleDayStatus` directly, one row per
  module).
- Opened from the dashboard; not a bottom-nav tab of its own (doesn't
  warrant one, per the existing five-tab nav — Dashboard/Water/Medicine/
  Prayer/Settings stays as-is).

## Decoupling proof (DoD requirement)

`test/features/dashboard/dashboard_screen_test.dart`: wraps
`DashboardScreen` in a `ProviderScope` with `habitModulesProvider`
overridden to `[]`, then `[WaterModule(fakeRepo)]`, then all three
(fakes/mocktail, same precedent as Water's existing test fakes) —
asserts empty state / 1 summary card / 3 summary cards respectively.
Separately, a manual check during implementation: comment out one
module's line in `module_registry.dart`'s `buildHabitModules` list, run
`flutter analyze` + boot the app — confirms no `core/` file (dashboard,
reports, achievements, search, calendar) imports that module's package
directly; only the registry line changes.

## Localization

Full en/bn for every new string: dashboard strip/quick-action labels,
Reports period labels and empty states, achievement titles/descriptions
(`titleKey`/`descriptionKey` resolved through `AppLocalizations`, never
raw strings in `AchievementDefinition`), search placeholder/no-results
text, global calendar legend. Any Bangla term uncertain during
implementation gets flagged in-place rather than guessed, same rule as
Prayer's run.

## Testing / Definition of Done

- Unit: `AchievementEngine.evaluate` (progress calculation, one-shot
  unlock crossing, re-evaluating an unlocked definition is a no-op),
  `longestStreak` (from a `dayStatus` map, including a gap that should
  break the run), `AggregateReportUseCase`'s period-bucketing (week/
  month/year boundaries, DST-safe via existing `localDayKey`), search
  result ranking (prefix vs. contains).
- Widget: dashboard with 0/1/3 modules registered (decoupling proof,
  above), Reports empty-state rendering, search debounce + result tap
  navigates to the right route, global calendar day-coloring for
  all-complete/mixed/all-missed/no-data days.
- Manual: seed 4+ weeks of data across all three modules → Reports shows
  sane weekly/monthly/yearly numbers and longest-streak records → badge
  gallery shows a mix of locked/unlocked badges → global calendar
  coloring matches per-day status → search finds a seeded medicine name →
  full Bangla pass on every new string.
- `flutter analyze` clean, `dart format --output=none --set-exit-if-changed .`
  clean, `flutter test` green.
- `functional-requirements.md` gets `FR-C-11..16`, `decisions.md` gets
  `D-16..19` (text above), `database-design.md`'s `achievements` table
  comment corrected — all in the same PR (DoD rule 6).
- Commit: `feat(dashboard): cross-module dashboard, reports, achievements`.
