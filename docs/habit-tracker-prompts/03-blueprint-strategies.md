# 03 — CROSS-CUTTING STRATEGIES (documentation only — NO code)

**Inputs:** `00-project-context.md`, `docs/technical/*`
**Outputs:** files under `docs/strategies/`

## 1. `notifications.md` — the highest-risk subsystem; be thorough
- flutter_local_notifications capabilities and limits on Android 13+ / iOS
  (exact-alarm permission, POST_NOTIFICATIONS runtime permission, iOS 64
  pending-notification limit — verify current numbers against the package
  docs, don't guess)
- **Scheduling window strategy** to live under the iOS pending limit:
  e.g. materialize only the next N days of reminders and re-plan on app open
  / a periodic Android worker / after each notification fires. Specify N and
  the re-planning triggers.
- Reboot handling (Android BOOT_COMPLETED re-scheduling)
- Action buttons (Done/Snooze/Skip) → background isolate handler → DB write
  → ledger update. Define exactly what Snooze does (duration, re-schedule
  semantics, does it affect streaks?)
- Doze/App Standby / OEM battery killers (relevant to Android devices common
  in Bangladesh — Xiaomi/Realme/Vivo aggressive task killing): mitigation and
  honest limits; in-app guidance screen for users
- Deep links from notification tap to the right screen

## 2. `prayer-times.md`
- Offline calculation: recommend a Dart library (verify it exists and is
  maintained on pub.dev — e.g. an adhan Dart port; if unverifiable, specify
  implementing the standard astronomical algorithm and cite which calculation
  methods to support: Karachi, MWL, ISNA, Umm al-Qura at minimum, Karachi as
  the sensible default for Bangladesh)
- Location WITHOUT internet: manual city list + manual lat/long entry;
  optional GPS one-shot. No network geocoding dependency.
- Madhab (Asr) setting, Hijri date display, midnight/qiyam not in scope v1

## 3. `localization.md`
ARB workflow, pluralization in Bangla, Bangla digit rendering policy,
date/number formatting via intl, pseudo-locale testing, how a new language
is added (checklist), font choice for Bangla (verify Noto Serif/Sans Bengali
availability via google_fonts or bundled).

## 4. `theme.md`
Material 3 tokens, seed color, dark/light/system switching, per-module accent
colors from the module contract, typography scale incl. Bangla script
line-height needs.

## 5. `security.md`
PIN lock: store only a salted hash (specify algorithm and where the salt
lives), lockout backoff after failed attempts, biometric unlock as optional
convenience layered over PIN, screen privacy (FLAG_SECURE optional toggle),
threat model honesty: local DB is not encrypted in v1 — state this and the
future option (DB-level encryption), what "forgot PIN" does (data wipe vs.
nothing — decide and justify).

## 6. `backup-import-export.md`
- JSON export: versioned envelope `{schemaVersion, exportedAt, appVersion,
  modules: {...}}`; per-module export handlers via the module contract
- Import: validation, schemaVersion migration path, merge vs. replace
  semantics (recommend replace-with-confirmation for v1; document why merge
  is deferred)
- Future Google Drive backup: exactly which seams exist today (export
  produces a single file; a future `BackupTarget` interface uploads it) —
  design the interface, don't implement

## 7. `error-handling-logging.md`
Failure taxonomy (sealed Result/AppException types), what users see vs. what
is logged, logger setup with redaction rules (never log medicine names or
health data at info level), in-app "share logs" for support, no crash
reporting SaaS in v1 (offline promise) — document the tradeoff.

## 8. `performance.md`
Cold-start budget, lazy module initialization, chart data pre-aggregation
strategy for yearly views (query raw vs. maintain daily rollup rows —
compare, recommend), build_runner hygiene, image/asset policy.

## 9. `testing.md`
Test pyramid for this app: domain unit tests (streak math, repeat-rule
expansion, prayer time golden values against known published timetables),
repository tests on temp DB, widget tests for each screen's key states,
one integration smoke test. Name the 10 highest-value test suites explicitly.
Time-dependent logic MUST use an injected clock — no `DateTime.now()` in
domain code.

## 10. `accessibility.md`
Semantics labels, touch targets ≥48dp, text scaling to 200% without overflow
on the three densest screens (name them), color-contrast checks in both
themes, screen-reader flows for logging a dose.

## 11. `analytics-future.md`
Ship NO analytics in v1. Define a no-op `AnalyticsService` interface with
typed events so instrumentation points exist. List the consent/privacy work
required before ever enabling it.

## 12. `future-expansion.md`
Step-by-step recipe: "How to add a new module" using the plugin contract,
proven against two paper examples (Sleep, Blood Pressure — one boolean-ish
habit, one measurement habit; they stress the contract differently).

Append all decisions to `decisions.md`.
