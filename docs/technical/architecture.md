# Architecture

Clean Architecture, feature-first, per `00-project-context.md`'s
non-negotiable rules. This document defines the layer boundaries and — the
core scalability requirement — the `HabitModule` plugin contract that lets
Water/Medicine/Prayer (and any future module) be added without editing
existing module code.

## Layer diagram and dependency rule

```
┌─────────────────────────────────────────────────────────┐
│  presentation/   (Flutter widgets, Riverpod providers)   │
│  - screens, widgets, controllers                         │
│  - depends on → domain                                    │
└───────────────────────┬───────────────────────────────────┘
                         │ depends on
                         ▼
┌─────────────────────────────────────────────────────────┐
│  domain/   (pure Dart, ZERO Flutter imports)              │
│  - entities (Freezed), repository interfaces, use cases   │
│  - depends on → nothing (this is the center)               │
└───────────────────────▲───────────────────────────────────┘
                         │ implements
                         │ (dependency INVERSION — data depends on
                         │  domain's interfaces, not the other way)
┌─────────────────────────────────────────────────────────┐
│  data/   (Drift tables/DAOs, repository implementations)  │
│  - depends on → domain (implements its repository          │
│    interfaces), and on core/database                      │
└─────────────────────────────────────────────────────────┘
```

**The rule in one sentence:** `domain/` never imports from `presentation/`
or `data/`; both of those depend on `domain/`, never the reverse. This is
what `functional-requirements.md`'s domain-logic unit tests rely on — every
FR-tagged calculation (streak logic, dose-status state machine, Qadha
counter logic) is testable with zero Flutter/Drift dependency in the test
file.

## Feature module internal structure

Each of `lib/features/water/`, `lib/features/medicine/`,
`lib/features/prayer/` (and any future module) follows this shape — see
`folder-structure.md` for the literal file tree:

```
features/<name>/
  domain/
    entities/          — Freezed models (WaterEntry, MedicineSchedule, ...)
    repositories/       — abstract interfaces only (WaterRepository)
    usecases/           — LogWaterEntry, CalculateStreak, ...
  data/
    tables/             — Drift table definitions
    daos/               — Drift DAO classes
    repositories/        — concrete WaterRepositoryImpl implementing the domain interface
  presentation/
    screens/
    widgets/
    providers/           — Riverpod providers wiring use cases to UI
  <name>_module.dart      — the HabitModule implementation (see below)
```

## The module plugin contract: `HabitModule`

Every module (present or future) registers itself by implementing one
interface and adding one line to one list. This is the concrete answer to
`00-project-context.md`'s "addable later without modifying existing module
code" requirement — it is built here, informed by Water's real
implementation (per `../product/roadmap.md`'s Run 05→06 sequencing), not
designed in the abstract before any module exists.

```dart
abstract class HabitModule {
  String get id;                              // 'water', 'medicine', 'prayer'
  ModuleMetadata get metadata;                 // display name, icon, color
  List<RouteBase> get routes;                  // this module's GoRouter routes
  Widget dashboardSummary(WidgetRef ref);       // FR-C-03 dashboard tile
  Widget? settingsEntry(WidgetRef ref);          // this module's Settings section
  Future<List<PendingNotification>> pendingNotifications(); // for the boot receiver, FR-C-08
  Future<ModuleExport> exportData();             // v1.1 backup groundwork, offline-strategy.md
  Future<void> importData(ModuleExport data);
}
```

**Registration** — the *only* shared touchpoint every module has with every
other module — is one list, built in `core/`:

```dart
final habitModules = <HabitModule>[
  WaterModule(),
  MedicineModule(),
  PrayerModule(),
];
```

`core/` code (router setup, dashboard screen, Settings screen, the boot
receiver, the export/import screen) iterates this list. None of that code
contains a `case 'water':` branch anywhere — it calls `module.routes`,
`module.dashboardSummary(ref)`, etc., uniformly. Concretely: adding a future
`SleepModule` means writing `lib/features/sleep/` (following the same
`domain/data/presentation` shape) and adding one line,
`SleepModule()`, to the list above. No existing file in `lib/features/water/`,
`medicine/`, or `prayer/`, and no line of `core/` router/dashboard/settings
code, is touched.

**What's deliberately NOT in the contract:** a generic "module settings
schema" or "module data type registry" — those would be speculative
abstractions serving no concrete module today (per
`00-project-context.md`'s "avoid overengineering... except the module-plugin
contract, which is an explicit requirement" — the contract itself is the one
approved abstraction; extending it further isn't).

## `notification_ledger` as the plugin seam for notifications

Per `database-design.md`, `notification_ledger.source_type`/`source_id` is a
polymorphic, app-enforced (not DB-FK) reference specifically so
`pendingNotifications()` from any module can write into the same shared
table without a migration. The boot receiver (FR-C-08) queries this one
table for everything pending, regardless of which module scheduled it.

## Laravel mapping (for the developer's existing mental model)

| Flutter/Riverpod concept | Laravel equivalent | Notes |
|---|---|---|
| Repository interface (`domain/repositories/`) + implementation (`data/repositories/`) | A `Repository` interface + an Eloquent-backed implementation class, bound in a service provider | Same pattern, same motivation: swap the implementation (e.g. an in-memory fake for tests) without touching anything that depends on the interface |
| Use case (`domain/usecases/`, e.g. `LogWaterEntryUseCase`) | An "Action" class (`LogWaterEntryAction::execute()`), the increasingly common Laravel pattern of one class = one business operation, instead of fat controllers/models | Use cases are the layer that enforces FR-level business rules (e.g. FR-W-04's "don't rewrite past streak days") — they're where product decisions from `../product/decisions.md` actually get implemented |
| Riverpod `Provider`/`Provider.autoDispose` | A container binding (`app()->bind(...)`) | Both are "ask the container for this, get a resolved instance" |
| Riverpod `StreamProvider` watching a Drift `Stream<List<Row>>` query | Closest Laravel analogue: **none** — Eloquent has no push-based query subscription; the nearest mental model is "imagine every `Model::where(...)->get()` automatically re-ran and pushed new results to the browser via a websocket, without you writing any broadcast code" | This is the single biggest new concept for a backend-only developer — see `state-management.md` for the full explanation |
| Widget rebuild on state change | **No good Laravel analogue** (Laravel is request/response, not a long-lived reactive UI) | A rebuild is Flutter re-running a `build()` method for the smallest widget subtree that reads a changed provider's value — think of it as re-rendering a single Blade partial automatically whenever the data it reads changes, with the framework figuring out which partial, not you |
| `riverpod_generator` `@riverpod` annotation + `build_runner` | Closest: a service-container binding generated from a docblock/attribute instead of hand-written in a provider's `register()` | Removes hand-written boilerplate the same way Laravel's newer attribute-based routing reduces hand-written route files |

## Cross-cutting: where background/refresh jobs live

The dose/prayer-record materialization job (D-13) and the daily
midnight-refresh (D-09/prayer recompute) are **not** part of any single
module's `domain/` — they're orchestration that touches multiple modules'
repositories. They live in `core/jobs/`, invoked from each module's
`HabitModule` implementation via a small `refreshableJob` hook the contract
exposes (kept out of the 6-method sketch above for brevity, documented here
rather than speculatively drawn into the interface before a second module
exists to validate the shape).
