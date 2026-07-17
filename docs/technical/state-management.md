# State Management — Riverpod (code-gen)

## Provider types, mapped to their job

| Job | Provider type | Example |
|---|---|---|
| DB row(s) → reactive UI (read path) | `@riverpod` **stream** provider wrapping a Drift `Stream<List<Row>>` query | `todaysWaterEntriesProvider` streams `water_logs` for today's local-day range; the ring/list widget rebuilds automatically on every insert/edit/delete, no manual refresh call anywhere |
| A single mutation (write path) | `@riverpod` class (`Notifier`/`AsyncNotifier`) exposing an imperative method, e.g. `logEntry(int amountMl)` | The controller calls the use case, the use case calls the repository, the repository writes to Drift — the stream provider above picks up the change automatically because Drift's stream re-queries on write, not because the controller manually invalidates anything |
| Cross-module aggregation (dashboard) | `@riverpod` provider that combines each module's own stream providers via `ref.watch` on each — never a bespoke "dashboard repository" | Keeps the dashboard from becoming a fourth thing every module must know about; it just watches what already exists per module (this is also why `HabitModule.dashboardSummary(ref)` in `architecture.md` takes a `WidgetRef` — each module owns exactly how its own tile watches its own providers) |
| App-wide singletons (settings, theme, locale) | `@Riverpod(keepAlive: true)` | `appSettingsProvider` — must not be disposed when its last listener unmounts, since Settings-derived state (theme, locale, PIN) needs to persist across the whole app lifetime, not just while a particular screen is open |
| Screen-scoped derived state (form state, filters) | plain `@riverpod` (auto-dispose, the default) | e.g. a "selected stats date range" provider — disposed when the stats screen is popped, so it doesn't leak state into the next time the screen opens |

## `keepAlive` policy — the rule, stated once

**Default to auto-dispose (no `keepAlive`).** Mark a provider `keepAlive:
true` only when it holds state that must survive its last listener
unmounting — in practice: `appSettingsProvider`, `moduleRegistryProvider`
(the enabled/disabled state driving nav, FR-C-10), and the notification
scheduler's own internal state. Every module's day-to-day data providers
(today's water entries, today's doses) are auto-dispose — they're cheap to
re-subscribe to when a screen reopens, and auto-dispose is what prevents
stale streams silently piling up as the user navigates between the three
modules over a long session.

## The rule: UI never touches repositories directly

```
UI (widget) → provider (Riverpod) → use case (domain) → repository (domain interface, data impl) → Drift
```

A widget calls `ref.watch(todaysWaterEntriesProvider)` or
`ref.read(waterControllerProvider.notifier).logEntry(500)` — it never
imports `WaterRepositoryImpl` or a Drift table class directly. This is
enforced by folder structure and import discipline (`presentation/` files
importing from `data/` should not happen — a lint rule can flag this in Run
13's polish pass), not by a runtime check; the payoff is that
`functional-requirements.md`'s domain-logic tests (streak calculation, dose
state machine) run against the use case directly, with a fake repository, with
zero widget/Drift setup.

## How DB change-streams drive reactive UI, end to end

Concrete trace for "log water → dashboard updates without manual refresh"
(the specific example `00-project-context.md` implicitly promises):

1. User taps a quick-add button → widget calls
   `ref.read(waterControllerProvider.notifier).logEntry(250)`.
2. The controller (an `@riverpod` `Notifier`) calls
   `LogWaterEntryUseCase.execute(250)`.
3. The use case calls `WaterRepository.addEntry(...)`, which resolves to
   `WaterRepositoryImpl` in `data/`, which runs a Drift `insert` on the
   `water_logs` table.
4. Drift's generated DAO exposes the day's entries as a `Stream<List<WaterLogRow>>`
   built from a `select(...).watch()` query. Drift re-runs and re-emits that
   stream automatically whenever a write touches a table the query reads
   from — this is a Drift-provided mechanism, not something this app's code
   implements.
5. `todaysWaterEntriesProvider` (a `StreamProvider` wrapping step 4's
   stream) re-emits its new value.
6. Every widget that did `ref.watch(todaysWaterEntriesProvider)` — the
   Water screen's progress ring AND the Dashboard's water summary tile
   simultaneously — rebuilds with the new total. No widget called
   `setState`, no controller called `.refresh()`, no explicit "notify the
   dashboard" wiring exists anywhere.

The same trace shape applies to a notification action (FR-C-06) writing a
dose's `status` from a background isolate: the write happens through the
same repository (via a `NativeDatabase.createInBackground` connection per
`database-decision.md`), and any foreground stream watching that table
re-emits identically whether the write came from the app's own UI or from a
background-isolate notification handler — this uniformity is exactly why
Drift's multi-isolate story mattered in the DB decision.
