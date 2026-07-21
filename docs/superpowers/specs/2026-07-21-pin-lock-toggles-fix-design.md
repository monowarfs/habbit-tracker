# PIN Lock: Fix Biometric/Screen-Privacy Toggles + Test Coverage

**Date:** 2026-07-21
**Status:** Approved

## Problem

An audit of the PIN lock feature (`docs/strategies/security.md`,
`docs/superpowers/specs/2026-07-19-settings-security-design.md`) found the
core flow (router `/lock` redirect, PIN hashing/storage, backoff, re-lock
on resume) is genuinely complete — but two of `PinSettingsScreen`'s
toggles are non-functional stubs, and there is zero test coverage on the
lock UI itself:

1. **Biometric toggle** (`pin_settings_screen.dart:82-87`) — hardcoded
   `value: false`, `onChanged: (_) {}`. Meanwhile `LockScreen._tryBiometric`
   unconditionally attempts biometric auth whenever the hardware supports
   it, so biometric unlock is actually always-on with no way to opt out,
   and the Settings switch is decorative.
2. **Screen-privacy toggle** (`pin_settings_screen.dart:89-100`) —
   hardcoded `value: false`, never persisted. Toggling it calls
   `ScreenPrivacyService` in the moment but forgets on next visit to the
   screen and never re-applies on cold start.
3. **No test exercises** the `/lock` redirect gate, `LockScreen`,
   `PinSetScreen`, or `PinSettingsScreen`. The `pinLockControllerProvider`
   overrides in `app_router_test.dart`/`widget_test.dart` are plumbing
   only (PIN never gets enabled in either test, so the redirect branch
   never runs).

## Design

**Both toggles become real, persisted `AppSettings` fields**, following
the exact pattern `pinEnabled`/`pinLockTimeoutSeconds` already establish
(a boolean column on `app_settings`, a repository update method, wired
into the settings stream everything else already reads from).

- `AppSettings.biometricEnabled` (`bool`, DB default `true`) — default
  `true` because that's the app's current de-facto behavior (biometric
  always attempted when hardware supports it); this feature makes that
  behavior *visible and opt-out-able*, not a new default.
- `AppSettings.screenPrivacyEnabled` (`bool`, DB default `false`) —
  default `false`, per `docs/strategies/security.md`'s "Default: off,
  opt-in from Settings" for this feature.

**Biometric gating** — `LockScreen._tryBiometric()` reads
`biometricEnabled` from `appSettingsProvider` before calling
`BiometricService.isAvailable()`; `false` skips the biometric prompt
entirely and goes straight to PIN entry. No change to `BiometricService`
itself (already correctly falls back to PIN on any failure).

**Screen-privacy application — single source of truth, not two call
sites.** Currently the Settings toggle calls `ScreenPrivacyService`
directly, which only takes effect for the rest of that in-memory session
and never re-applies on cold start. Instead: `PinSettingsScreen`'s toggle
only persists the setting (`updateScreenPrivacyEnabled`); a new
`ref.listen` in `HabitTrackerApp` (`main.dart`) watches
`appSettingsProvider` and calls `ScreenPrivacyService().enable()`/
`.disable()` whenever `screenPrivacyEnabled` changes — this fires once on
cold start with whatever value was persisted (correctly re-applying
`FLAG_SECURE` etc. after every app launch) and again on every toggle,
with no duplicate/conflicting call sites.

**Disabling PIN clears both gated prefs.** Both toggles are only shown
in Settings while `pinEnabled` is true (existing `if (pinEnabled) ...`
wrapper) — per `docs/strategies/security.md`, biometric unlock requires a
PIN to already be set, and screen-privacy is "only offered when PIN lock
is also enabled." Today, if a user disables PIN, both flags silently
survive in the DB even though the UI to see/change them disappears.
`PinLockController.disablePin()` now also resets
`biometricEnabled` to `true` and `screenPrivacyEnabled` to `false` — each
reverting to its own fresh-install default, so re-enabling PIN later
starts from a clean slate rather than silently re-arming a stale
preference. See Global Constraints for the exact values.

**Schema migration** — `schemaVersion` bumps to `3`; `onUpgrade`'s
existing `if (from < N)` seam (already anticipated by a comment at
`app_database.dart:70-72`) gets an `if (from < 3)` block adding the two
new columns via `m.addColumn(...)`, matching the `if (from < 2)`
precedent for the Medicine/Prayer tables.

**Backup export/import** — `AppSettings` gains two `required` fields, so
`export_orchestrator.dart`'s `_appSettingsToJson` and
`import_orchestrator.dart`'s `AppSettings(...)` construction both need
the two new keys. Import reads them with a `?? true`/`?? false` fallback
so restoring an *older* export (missing these keys) doesn't crash — it
falls back to the same defaults a fresh install gets.

**Test coverage** — three additions:
1. A shared `test/support/test_secure_storage.dart` `InMemorySecureStorage`
   (promoted out of `pin_lock_controller_test.dart`'s existing private
   `_InMemoryStorage`, which moves to import the shared one instead — no
   behavior change, just de-duplication ahead of reuse in the two new
   test files below).
2. `test/core/router/app_router_test.dart` gains a second test: with a
   PIN actually set and the app backgrounded past its timeout, navigating
   redirects to `/lock`; entering the correct PIN via `LockScreen`
   returns to the original destination.
3. New `test/core/security/lock_screen_test.dart`: wrong PIN shows the
   error message and doesn't unlock; correct PIN unlocks.
4. New `test/features/settings/presentation/screens/pin_settings_screen_test.dart`:
   toggling biometric/screen-privacy actually calls the repository's
   update methods and the switch reflects the persisted value on rebuild
   — a regression test for the exact bug being fixed.

## Out of scope

- `changePin()` being unused by the UI (the "Change PIN" flow uses
  `setPin()` directly, skipping old-PIN verification) — a real
  finding from the same audit, but a separate, larger UX change (needs
  an old-PIN-prompt step before `PinSetScreen`) not requested for this
  round.
- Any change to `BiometricService`, `ScreenPrivacyService`,
  `PinLockService`, or the hashing/backoff logic — all already correct
  per the audit.
- iOS-specific screen-privacy behavior verification (app-switcher blur)
  — requires a real device/manual check, not something this change can
  verify in CI.

## Global Constraints

- New DB columns: `biometric_enabled` (bool, default `true`),
  `screen_privacy_enabled` (bool, default `false`) on `app_settings`.
- `schemaVersion` → `3`, migrated via `m.addColumn`.
- `PinLockController.disablePin()` resets `biometricEnabled` → `true`
  (its normal default) and `screenPrivacyEnabled` → `false` (its normal
  default) — i.e. both toggles revert to fresh-install defaults, not to
  whatever the user last set, so re-enabling PIN later starts from a
  clean slate rather than silently re-arming a stale preference.
- `ScreenPrivacyService` is applied from exactly one call site
  (`main.dart`'s `ref.listen`), never from `PinSettingsScreen` directly.
- Import of an older backup (missing the two new JSON keys) must not
  crash — fallback to the same defaults as a fresh install.
