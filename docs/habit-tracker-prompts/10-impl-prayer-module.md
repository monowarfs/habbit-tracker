# 10 — IMPLEMENTATION: PRAYER TRACKER MODULE

**Inputs:** `00-project-context.md`, FR-P-* requirements,
`docs/strategies/prayer-times.md`, run 08's engine

## Scope

Complete module in `lib/features/prayer/` + registry entry.

### Prayer time calculation (offline)
- Implement per the strategy doc's chosen approach (verified library or
  in-house algorithm). **Correctness gate:** golden tests comparing computed
  times for Dhaka, Kuala Lumpur, and London on fixed dates against published
  timetables (cite the source used for the expected values in the test file).
  Tolerance ±2 minutes; investigate anything beyond it.
- Settings: calculation method (Karachi default), Asr madhab (Hanafi default
  — sensible for the primary audience; both are user-changeable), manual
  location (city picker from a bundled offline city list + manual lat/long),
  optional one-shot GPS with graceful denial handling
- High-latitude rule handling per strategy doc

### Domain
- Daily record: five prayers, each unmarked / prayed / prayed-late / missed;
  Friday: Jumu'ah replaces Dhuhr when the user's setting says so
- Qadha ledger: missed prayers accumulate; user can mark Qadha made up
  (decrement per prayer type); manual adjustment allowed (people start using
  the app with existing Qadha — allow an initial balance)
- Streak definition per FR doc (e.g. all five marked prayed for the day);
  auto-missed marking after day rollover, evaluated lazily

### Presentation
- Prayer tab: today's times with countdown to next prayer, checklist with
  tap-to-cycle states, Hijri + Gregorian date
- History calendar: per-day completion coloring, day drill-down
- Qadha screen: balances per prayer, make-up flow
- Stats: completion %, streaks, per-prayer breakdown charts
- Reminders: per-prayer notification toggles + offset (at time / N min
  before) through the run 08 engine; recompute schedule when
  location/method/timezone changes
- Full en + bn localization (this module especially benefits from careful
  Bangla wording — flag any term you're unsure how to translate rather than
  guessing)

## Definition of Done
- Golden prayer-time tests pass; unit tests for Qadha arithmetic, streaks,
  Friday logic, timezone-change recomputation
- Manual script incl. changing location and verifying times + reminders
  update; Bangla pass
- Analyze clean, tests pass, commit:
  `feat(prayer): complete prayer tracking module`
