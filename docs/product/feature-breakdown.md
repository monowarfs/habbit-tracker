# Feature Breakdown

**Assumption:** run numbering (05-13) is proposed here, not given in the
input brief — see `user-stories.md` header and `roadmap.md` for the
proposed run/module mapping. Every unit below is small enough to be one PR
/ one focused implementation session, per module's `domain/data/
presentation` split (see CLAUDE.md architecture rules).

---

## Run 05 — App shell & common foundation

- Project structure: `lib/core/`, `lib/features/<feature>/` scaffolding,
  Riverpod provider setup, GoRouter root config with the `/lock` redirect
  guard stub (no PIN logic yet, just the guard shape).
- Theme: Material 3 ColorScheme, System/Light/Dark switching.
- Localization scaffold: ARB files for `en` and `bn`, `intl` codegen
  wired into build, lint/CI check for hard-coded strings (NFR-15).
- Onboarding flow shell: language select → module select → dashboard,
  with each module's setup step stubbed as "coming in Run 06/07/09."
- Module-plugin contract (interface only): the shared contract each
  feature module implements (registers its own routes, its own dashboard
  summary widget, its own settings entry, its own notification channel) —
  built once, concretely informed by Water's real implementation in Run
  06, not speculatively designed in the abstract first.

## Run 06 — Water module (full vertical slice)

- Domain: `WaterGoal`, `WaterEntry` entities (Freezed), goal-vs-actual
  calculation logic, streak calculation logic — all pure Dart, zero
  Flutter imports, unit-testable in isolation.
- Data: repository + Isar/Drift schema for goals and entries.
- Presentation: `/water`, `/water/add`, `/water/entry/:id/edit`,
  `/water/stats`, `/water/settings`, quick-add widget, progress ring
  widget, unit toggle (ml/fl oz, D-01).
- Notification: optional interval reminders (FR-W-10), off by default.
- Dashboard integration via the Run 05 plugin contract.

## Run 07 — Medicine module: domain & data

- Domain: `Medicine`, `Schedule` (with frequency pattern variants: fixed-
  times, every-N-days, weekday-set, PRN), `DoseInstance`, stock-tracking
  logic, grace-window/missed-dose state machine, every-other-day
  anchoring logic (D-03) — all pure Dart, unit-tested against the DST-
  transition edge case called out in US-M-02.
- Data: repository + schema for medicines, schedules, dose instances,
  stock ledger.
- Dose-instance generation service: flattens overlapping schedules into
  one deduplicated daily list (D-02/FR-M-02), including the collision-
  warning surfaced at schedule-creation time.

## Run 08 — Medicine module: presentation & notifications

- Screens: `/medicine`, `/medicine/list`, `/medicine/:id`, `/medicine/
  new`, `/medicine/:id/edit`, schedule create/edit screens, `/medicine/
  dose/:doseId`, `/medicine/:id/stats`.
- Notification integration: scheduled exact alarms per dose instance,
  Done/Snooze/Skip actions wired to the domain layer's state-change
  handlers (must work with app killed — this is the shared notification-
  action component also used by Prayer in Run 10).
- Low-stock banner + single-fire threshold notification (FR-M-04).

## Run 09 — Prayer module: domain & data

- Prayer time calculation engine: wraps a standard astronomical
  calculation (method table from D-06), exposes calculation method +
  Asr juristic method as pure inputs, locale-based default resolution.
- Domain: daily prayer status state machine (Upcoming/Due/Prayed/Missed),
  Qadha counter logic (auto-increment at cutoff, floor at 0, D-08),
  Jumu'ah toggle logic (D-07) affecting only Friday's Dhuhr label/bucket.
- Data: repository + schema for daily prayer records and Qadha counters.
- Location/timezone handling: device location → coordinates → timezone,
  manual-city fallback storage and resolution order (D-09).

## Run 10 — Prayer module: presentation & notifications

- Screens: `/prayer`, `/prayer/:name/:date`, `/prayer/qadha`, `/prayer/
  settings`, `/prayer/stats`.
- Notification integration: reuses the Run 08 notification-action
  component (Done/Snooze/Skip) rather than rebuilding it — this reuse is
  the concrete validation that the Run 05 plugin contract's shared
  notification piece was designed at the right level of abstraction.
- Permission explainer screen for location (shown before OS prompt,
  D-09).

## Run 11 — Notification system hardening (cross-module)

- Boot receiver: re-registers all pending notifications (medicine +
  prayer) after device reboot (FR-C-08/NFR-09).
- Exact-alarm scheduling audit across the device test matrix (NFR-07/08):
  verify delivery on stock Android, Samsung, Xiaomi, OnePlus, iOS.
- Snooze-limit enforcement (max 3, FR-M-07/FR-P-08 shared logic).
- Deep-link wiring: notification-body-tap → correct detail route
  (FR-C-09), verified through the `/lock` guard when PIN is enabled.

## Run 12 — Dashboard, module enable/disable, PIN lock

- Dashboard: aggregates each enabled module's summary widget via the
  plugin contract (FR-C-03).
- Settings → Modules: enable/disable per module without deleting
  underlying data (FR-C-10), re-run of that module's onboarding setup
  step if enabling for the first time.
- PIN lock: set/change PIN, re-lock timeout options, `/lock` guard made
  fully functional (was stubbed in Run 05), forgot-PIN reset explainer.

## Run 13 — Polish, accessibility, localization QA, store prep

- Accessibility pass: TalkBack/VoiceOver manual verification of all core
  flows (NFR-11), touch-target audit (NFR-12), text-scaling test at 200%
  (NFR-13), contrast audit (NFR-14).
- Localization QA: full `en`/`bn` string audit, Bangla numeral rendering
  check (NFR-16).
- Performance pass against NFR-01/02/03 on reference devices.
- Store prep: privacy policy (offline app — see `roadmap.md` release
  checklist), data-safety form answers, iOS permission usage strings
  (location, notifications), app store screenshots/listing copy.

---

## Deferred / not in v1.0 scope (tracked for roadmap, not built)

- Local export/import (file-based backup) — candidate for v1.1, not a
  Run 05-13 unit; flagged here so it isn't accidentally half-built during
  the plugin-contract work in Run 05.
- Cloud sync, Google Drive backup, family profiles, any fourth module —
  see `prd.md` Non-Goals and `roadmap.md` v1.1+ candidates.
