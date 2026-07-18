# Phases and Definition of Done

Ten implementation runs, 05-14, per the sequencing proposed in
`../product/roadmap.md`/`feature-breakdown.md`/`user-stories.md` (flagged
there as an assumption since the input brief didn't fix this numbering —
still followed consistently here). Each run's entry criteria, scope
boundary, feature-demo checklist, and rollback note are below; the
Definition of Done checklist is identical across every run and stated once
here rather than repeated ten times.

**Renumbered during Run 06 implementation:** the original pass through
this document only had nine runs (05-13), with Run 06 = Water. Once Run 05
was actually built, it became clear a dedicated "core infrastructure" run
(database, settings persistence, error handling, logging, clock) needed to
land *before* the first real module, not be folded into Water's own run —
so it was inserted as Run 06, and every run from the old Run 06 onward
shifted down by one (old 06→07, 07→08, 08→09, 09→10, 10→11, 11→12, 12→13,
13→14). The run list below is the actual executed sequence; cross-links
in other docs (`roadmap.md`, `feature-breakdown.md`, `user-stories.md`)
have been updated to match.

**Diverged during Run 08 implementation:** this section originally
planned Run 08 as "Medicine module: domain & data," with
`flutter_local_notifications` not entering the picture until Run 09
(Medicine's own presentation run), and the shared cross-module engine only
hardened later in Run 12. In practice, Run 08 was executed as the
**Notification & Reminder Engine** instead — `core/notifications/`
(planner, ledger repository, `NotificationService`, background-isolate
action handler, Android WorkManager top-up), validated end-to-end against
Water's already-stored-but-unscheduled reminder prefs (FR-W-10), extending
the `HabitModule` contract with `onNotificationAction` in the process
(`../technical/architecture.md`). Rationale: building the highest-risk
subsystem against the one module that already existed, rather than
bundling it with Medicine's first real module work, de-risks Medicine's
own Run 09+ (it now just plugs into a proven engine instead of building
it and a whole module simultaneously). The Medicine/Prayer runs described
below (still labelled 08/09/10/11/12) have **not** been renumbered or
re-scoped to reflect this — that's a real re-planning decision (how much
of the old "Run 09 notifications integration" and "Run 12 hardening" scope
is now redundant vs. still needed) that hasn't been made yet. Read
"Run 09 — Medicine module: presentation & notifications" as needing its
own reconciliation pass before that run starts: it should reuse
`core/notifications` rather than re-integrate `flutter_local_notifications`
from scratch, and "Run 12 — Notification system hardening" should be
re-scoped to whatever the engine still needs once Medicine/Prayer are real
consumers, not a from-scratch hardening pass.

## Universal Definition of Done (every run, no exceptions)

1. `flutter analyze` — zero issues.
2. `dart format --output=none --set-exit-if-changed .` — clean, no diff.
3. This run's named test suites (per `../strategies/testing.md` where
   applicable) passing.
4. App boots without crashing on an Android emulator and an iOS simulator.
5. This run's feature-demo checklist (below, per run) walked through and
   confirmed working.
6. Any documentation this run's implementation revealed as wrong or
   incomplete is corrected in the same PR — not left for later.
7. Exactly **one** conventional commit lands on `dev` for this run's
   merged work (`../engineering/git-strategy.md`).
8. No `// TODO` left in code without a linked GitHub issue number in the
   comment.

**Rollback principle, stated once:** a run's branch is merged to `dev`
only once its DoD is fully met. If it isn't, the branch simply isn't
merged, and `dev`/`staging`/`main` remain at the previous run's state —
which was itself shippable, by the same rule applied one run earlier.
"Main is always shippable" is maintained by induction on this rule, not by
a separate rollback mechanism bolted on afterward.

---

## Run 05 — App shell & common foundation

- **Entry criteria:** Docs 00-04 complete (true as of this run). No app
  code exists yet beyond the bare `flutter create` scaffold.
- **Scope in:** `core/`/`features/` folder skeleton, Riverpod + GoRouter
  wiring (including the `/lock` guard *stub*), Material 3 theme
  (light/dark/system), localization scaffold (`en`/`bn` ARB + `gen_l10n`),
  onboarding flow shell (language → module select → empty dashboard),
  the `HabitModule` contract interface + an empty `module_registry.dart`,
  `very_good_analysis` lint config live, PR CI workflow live.
- **Scope out:** no real module (Water/Medicine/Prayer) — the registry
  list stays empty. No module-specific DB tables, only the common ones
  (`app_settings`, `modules`, `notification_ledger`, `achievements`). No
  working PIN lock (the guard exists as a stub, per `folder-structure.md`).
- **Feature demo checklist:** launch → language picker → pick English →
  module-select screen (three toggles, all off) → continue with none
  enabled → dashboard shows the "Enable a module" empty state → Settings →
  toggle theme through light/dark/system, confirm live update → switch
  language to Bangla, confirm all visible strings change immediately.
- **Rollback:** unmet DoD leaves `dev` at the pre-run state (docs only,
  bare scaffold) — nothing to ship yet, but nothing broken either.

## Run 06 — Core infrastructure

- **Entry criteria:** Run 05 merged to `dev`.
- **Scope in:** Drift database with the common tables only
  (`app_settings`, `notification_ledger`, `achievements` — schema only for
  the latter two), migration scaffolding from schema v1, a settings
  repository backing theme/locale (replacing Run 05's in-memory seam —
  theme/language now survive app restart), the `AppException`/`Result<T>`
  error taxonomy + a top-level error widget/zone guard, a leveled logger
  with a rotating on-disk log file, and an injected-clock
  (`package:clock`) + DST-safe local-day bucketing helper every later
  run's streak/schedule logic depends on.
- **Scope out:** no module-specific DB tables (`modules` table itself
  also deferred — arrives with Run 13's enable/disable feature, not
  needed until then). No notifications, no PIN logic, no feature UI.
- **Feature demo checklist:** set theme to Dark and language to Bangla in
  Settings → force-quit the app (not just background it) → relaunch →
  confirm it reopens in Dark/Bangla, proving the DB-backed settings
  survived restart, not just in-memory state.
- **Rollback:** unmet DoD leaves `dev` at Run 05's state.

## Run 07 — Water module (full vertical slice)

- **Entry criteria:** Run 06 merged to `dev`.
- **Scope in:** full `domain/data/presentation` slice per
  `feature-breakdown.md` — goal history (D-01), entries, streak/goal-
  resolution use cases, quick-add, unit toggle, stats, optional interval
  reminders, `WaterModule` registered.
- **Scope out:** Medicine/Prayer untouched. Water's own reminder
  notifications ship without the full cross-module N-day window tuning
  (`notifications.md`) — they're low-volume enough to work correctly in
  isolation; the shared tuning pass happens in Run 12 once real
  multi-module volume exists to tune against.
- **Feature demo checklist:** enable Water, set a 2000ml goal → tap
  quick-add 250ml three times, ring shows 750/2000 → add a backdated
  custom entry for earlier today, total updates → open Stats, confirm
  streak/30-day view → change the goal mid-day, confirm today's ring
  recalculates but a seeded past completed day's streak status doesn't
  retroactively change (FR-W-04) → switch to fl oz, confirm display
  converts, stored data doesn't.
- **Rollback:** unmet DoD leaves `dev` at Run 06's state.

## Run 08 — Medicine module: domain & data

- **Entry criteria:** Run 07 merged (first proof the plugin pattern
  produces a real module; Run 08 begins the second).
- **Scope in:** `Medicine`/`MedicineSchedule` (`RepeatRule` sealed union)/
  `MedicineDose`/`MedicineStockEvent` entities, repository + Drift tables,
  D-13's materialization job, D-03's every-other-day anchoring (incl. the
  DST test case), D-05's grace-window state machine, D-04's stock
  deduction/undo. **No UI.**
- **Scope out:** no medicine screens, no OS notification scheduling yet
  (Run 09) — this run is verified through tests, not a manual UI demo.
- **Feature demo checklist (test-suite-based, no UI exists yet):**
  `repeat_rule_every_n_days_test.dart`, `mark_dose_done_test.dart`, and
  `medicine_stock_events_test.dart` (`testing.md` suites 3-5) all green,
  plus a throwaway script demonstrating the materialization job produces
  30 correctly-timed days of dose rows for a sample schedule.
- **Rollback:** unmet DoD leaves `dev` at Run 07's state (Water still
  fully functional).

## Run 09 — Medicine module: presentation & notifications

- **Entry criteria:** Run 08 merged.
- **Scope in:** medicine screens (list/detail/new/edit/schedule create-
  edit/dose detail/stats), `flutter_local_notifications` integration
  (exact-alarm scheduling, Doze mode, Done/Snooze/Skip → background
  isolate → DB write → ledger update), low-stock banner, `MedicineModule`
  registered.
- **Scope out:** the OEM battery-killer guidance screen and full
  cross-module notification-window tuning deferred to Run 12 — Medicine's
  notifications must work correctly in isolation first.
- **Feature demo checklist:** add a medicine, fixed-daily 8am/8pm →
  today's dose list shows both slots → mark 8am Done, stock decrements (if
  tracked) → background the app, wait for the 8pm notification → tap
  Snooze from the shade, confirm it re-fires ~10 min later → tap Done from
  the notification with the app fully closed → reopen the app, confirm the
  dose already shows Done.
- **Rollback:** unmet DoD leaves `dev` at Run 08's state.

## Run 10 — Prayer module: domain & data

- **Entry criteria:** Run 09 merged (Medicine complete end to end).
- **Scope in:** `PrayerSettings`/`PrayerRecord`/`PrayerQadhaCounter`
  entities, `adhan_dart` integration, calculation-method + Asr-method
  resolution, Jumu'ah toggle logic, Qadha auto-increment/floor logic,
  manual-city/GPS location resolution, materialization reusing D-13's
  pattern. **No UI.**
- **Scope out:** no prayer screens, no notification scheduling (Run 11).
- **Feature demo checklist (test-suite-based):**
  `prayer_time_golden_values_test.dart` green against ≥3 calculation
  methods, `qadha_counter_test.dart` green, plus a throwaway comparison of
  `adhan_dart`'s computed times against a real published timetable for a
  known city/date, within ±1 minute tolerance.
- **Rollback:** unmet DoD leaves `dev` at Run 09's state.

## Run 11 — Prayer module: presentation & notifications

- **Entry criteria:** Run 10 merged.
- **Scope in:** prayer screens (checklist/detail/qadha/settings/stats),
  notification integration **reusing Run 09's shared Done/Snooze/Skip
  component** (the concrete validation of `architecture.md`'s reuse
  claim), `PrayerModule` registered.
- **Scope out:** OEM guidance screen and full cross-module window tuning
  still deferred to Run 12, which now has real two-module volume to tune
  against.
- **Feature demo checklist:** enable Prayer, confirm locale-appropriate
  defaults pre-filled (Karachi method, Hanafi Asr for `bn`) → mark Fajr
  Prayed, streak shows partial progress → let a prayer's window lapse
  unmarked, confirm its Qadha counter increments by 1 → toggle "observes
  Jumu'ah" on a Friday, confirm only that day's Dhuhr label changes to
  Jumu'ah.
- **Rollback:** unmet DoD leaves `dev` at Run 10's state.

## Run 12 — Notification system hardening (cross-module)

- **Entry criteria:** Runs 09 and 11 both merged — real multi-module
  notification volume now exists to tune the shared window against.
- **Scope in:** boot-receiver manifest config verified end-to-end (reboot
  test), the N=3-day sliding window + conveyor-belt top-up tuned and
  tested across Medicine + Prayer simultaneously, OEM battery-killer
  guidance screen, battery-optimization-exemption request flow, deep-link
  tap-through verified for both modules.
- **Scope out:** Water's reminders join the shared window only if testing
  shows real volume needs it — `notifications.md`'s own worst-case
  calculation already included them, so this is mostly verification, not
  new design.
- **Feature demo checklist:** schedule dense notifications across both
  modules (e.g. 3 medicines × 3 doses/day + 6 prayers) → reboot the test
  device/emulator, confirm all still-pending notifications re-fire without
  opening the app → force-idle the device (Doze simulation), confirm
  exact-alarm delivery still occurs → open the new guidance screen from
  Settings, confirm it renders.
- **Rollback:** unmet DoD leaves `dev` at Run 11's state — a lower-risk
  rollback than most, since this run is additive tuning, not a rewrite;
  Medicine/Prayer notifications still work individually either way.

## Run 13 — Dashboard, module enable/disable, PIN lock

- **Entry criteria:** all three modules (07/09/11) merged and individually
  functional.
- **Scope in:** full dashboard aggregation, Settings → Modules
  enable/disable with data preserved, PIN lock (set/change, lockout
  backoff, optional biometric layer, `FLAG_SECURE` toggle), forgot-PIN
  full-reset flow.
- **Scope out:** local export/import and Google Drive backup remain
  v1.1+, not built here.
- **Feature demo checklist:** dashboard shows all three modules' live
  summaries at once → disable Medicine from Settings, confirm it
  disappears from nav/dashboard without deleting its data → re-enable it,
  confirm history intact → set a PIN, background/reopen the app, confirm
  the lock screen appears → fail 4 attempts, confirm the 5-second backoff
  → enter the correct PIN, confirm unlock → enable biometric, confirm it
  unlocks without PIN entry → tap "Forgot PIN," confirm the full-reset
  warning appears before anything is touched.
- **Rollback:** unmet DoD leaves `dev` at the pre-Run-13 state — three
  working modules, no aggregation/PIN yet, still a shippable state.

## Run 14 — Polish, accessibility, localization QA, store prep

- **Entry criteria:** Run 13 merged — the full v1.0 feature set exists.
- **Scope in:** accessibility pass (the three densest screens named in
  `../strategies/accessibility.md`), localization QA (pseudo-locale pass,
  Bangla numeral/line-height verification), performance pass against
  NFR-01-03 on reference devices, store listing assets + privacy policy +
  data-safety forms (`../product/release-plan.md`), the full device test
  matrix for notification reliability (NFR-07-09).
- **Scope out:** no new features — this run verifies and polishes what
  Runs 05-13 built. A bug found here that needs new logic gets its own
  small follow-up branch rather than silently expanding this run.
- **Feature demo checklist:** manual NFR checklist run against the
  reference device classes → TalkBack/VoiceOver pass on the "logging a
  dose" flow → 200% text-scale check on Dashboard/Medicine home/a stats
  screen → pseudo-locale build shows no un-wrapped hard-coded strings →
  store screenshots captured in both languages.
- **Rollback:** this run is the release-candidate gate itself. Unmet DoD
  means v1.0 simply isn't tagged yet — `main` stays at the last
  successfully-tagged v0.x milestone, itself shippable by the same rule
  applied one run earlier.
