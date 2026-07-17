# Testing

## Test pyramid for this app

```
                      ▲
                     ╱ ╲     1 integration smoke test
                    ╱───╲    (full onboarding → log → dashboard flow)
                   ╱─────╲
                  ╱       ╲  Widget tests — key states per screen
                 ╱─────────╲
                ╱           ╲ Repository tests — real Drift ops, temp DB
               ╱─────────────╲
              ╱                ╲ Domain unit tests — pure Dart, no Flutter/DB
             ╱──────────────────╲ (streak math, repeat-rule expansion,
                                    prayer-time golden values, state machines)
```

Weighted toward the base per Clean Architecture's own logic
(`../technical/architecture.md`): the highest-risk, highest-complexity
logic in this app (D-03's every-other-day anchoring, D-05's grace-window
state machine, D-08's Qadha counter) is pure Dart domain logic with zero
Flutter/DB dependency, so it's cheap to test exhaustively and there's no
excuse not to.

## Mandatory rule: injected clock, no `DateTime.now()` in domain code

Every piece of domain logic that reasons about "today," "now," or elapsed
time (streak evaluation, grace-window/missed-dose transitions, Qadha
cutoff, dose/prayer-record materialization) takes time as an **injected
dependency**, never calling `DateTime.now()` directly. Uses the `clock`
package (verified active on pub.dev 2026-07-17: v1.1.2, dart-lang's own
`tools.dart.dev` publisher, 6.4M downloads/30 days — the standard,
official mechanism for this exact problem, so no custom `Clock` interface
is hand-rolled). In production code, `clock.now()` reads the real system
clock; in tests, `withClock(Clock.fixed(someDateTime), () { ... })` pins
time to an arbitrary instant — which is the only way to deterministically
test "is this dose missed at 8:31am when the grace window ends at 8:30am"
or "does day 47 of an every-other-day schedule fall on a dose day"
without the test's pass/fail depending on what day it happens to be run.

## The 10 highest-value test suites

1. **`calculate_water_streak_test.dart`** — streak counting across
   consecutive/broken days, including the FR-W-04 case: a goal changed
   mid-day must not retroactively alter whether an already-completed past
   day still counts toward the streak.
2. **`resolve_goal_for_date_test.dart`** — `water_goals`' append-only
   history resolves the *correct* goal for an arbitrary past date (D-01's
   normalization choice, exercised directly).
3. **`repeat_rule_every_n_days_test.dart`** — D-03's every-other-day
   anchoring, run across a 14-day window that **includes a DST transition
   date**, verifying the anchor never drifts. This is the single riskiest
   piece of domain logic in the app (US-M-02) and gets the most dedicated
   test attention of any suite here.
4. **`mark_dose_done_test.dart`** — the full dose status state machine
   (upcoming → due → done/missed/skipped) across the grace-window boundary
   (D-05), plus the D-04 stock-exhaustion behavior (reminders continue
   past zero stock unless `stopWhenStockDepleted` is set).
5. **`medicine_stock_events_test.dart`** — stock deduction on "Done,"
   reversal on undo, and that `medicine_stock_events` (the audit ledger)
   always reconciles back to `medicines.stock_count`.
6. **`prayer_time_golden_values_test.dart`** — `adhan_dart`'s output
   checked against **known, published prayer timetables** for at least 3
   calculation methods (Karachi, MWL, Umm al-Qura) at a fixed date/location,
   within a small tolerance (±1 minute) — this is the test that actually
   validates the library choice in `../strategies/prayer-times.md` produces
   *correct*, not just *plausible*, times; a golden-value regression here
   is the single highest-trust-impact bug this app could ship (`prd.md`'s
   top risk).
7. **`qadha_counter_test.dart`** — auto-increment at cutoff (D-08), floor
   at 0 (never negative), and that Jumu'ah shares Dhuhr's bucket rather
   than maintaining its own counter (D-07).
8. **`notification_ledger_snooze_test.dart`** — the max-3-snooze limit
   (`notifications.md`) and the conveyor-belt re-plan (each fired/actioned
   notification schedules exactly one replacement at the window's far
   edge, keeping the N-day window intact).
9. **Repository tests against a temp/in-memory Drift database** (one suite
   per module: `water_repository_impl_test.dart`,
   `medicine_repository_impl_test.dart`, `prayer_repository_impl_test.dart`)
   — soft-delete filtering (`WHERE deleted_at IS NULL` behavior is actually
   applied, not just documented), UUID stability round-trip through
   insert/read, and that a schema migration (once one exists) doesn't
   silently drop data.
10. **Widget tests for the 4 densest/most-visited screens' key states**
    (empty / loading / populated / error each): Water home screen,
    Medicine dose list (today's flattened cross-schedule view, FR-M-02's
    most complex UI surface), Prayer checklist, and the Dashboard
    aggregate (which must render correctly with zero, one, two, or all
    three modules enabled — FR-C-03/FR-C-10's combinatorial surface).

Plus **one integration smoke test**: fresh install → onboarding (language →
enable all three modules) → log a water entry → mark a medicine dose done
→ mark a prayer done → verify the dashboard reflects all three → force-quit
and relaunch → verify all data persisted. This is the one test that
exercises the real Drift database, real Riverpod provider wiring, and real
navigation together — everything else in the pyramid deliberately isolates
one layer at a time.
