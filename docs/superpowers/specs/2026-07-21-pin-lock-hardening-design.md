# PIN Lock Hardening: Close the Remaining Real Gaps

**Date:** 2026-07-21
**Status:** Draft — pending review

> **Correction to source artifact.** The Feature Atlas gap-analysis item this
> spec was requested against ("Biometric / PIN app lock ... the last privacy
> gap") describes a stale premise: PIN lock is not a stub. It is a complete,
> working feature — PBKDF2-HMAC-SHA256 hashing (`pin_hash.dart`),
> `flutter_secure_storage`-backed credentials and lockout bookkeeping
> (`pin_lock_service.dart`), a real GoRouter `/lock` redirect gate
> (`app_router.dart`), exponential backoff (`backoff.dart`, tested), and
> optional biometric unlock (`biometric_service.dart`). Two toggle bugs
> (biometric/screen-privacy enable-disable) were already found and fixed
> this session — see `docs/superpowers/specs/2026-07-21-pin-lock-toggles-
> fix-design.md`. This spec re-audits the *current* code (post-fix) against
> "real, production-grade app lock" expectations and specs only what's
> still actually missing.

## Problem

Four genuine gaps remain, none of them the artifact's claimed one:

1. **"Change PIN" never checks the current PIN.** `PinLockController
   .changePin(oldPin, newPin)` exists and is unit-tested
   (`pin_lock_controller_test.dart`), but has **zero call sites in
   `lib/`** — confirmed by grep. `PinSettingsScreen`'s "Change PIN" tile
   (`pin_settings_screen.dart:47-51`) just does
   `context.push('/settings/pin/set')`, the exact same route as first-time
   enable, and `PinSetScreen._onDigit` (`pin_set_screen.dart:51`)
   unconditionally calls `setPin()` — which overwrites the stored
   credentials with no verification step at all. Anyone with the app
   already unlocked (e.g. a phone handed to someone else mid-session, or
   grabbed during a brief lapse) can silently replace the PIN without
   proving they know the old one. This was already flagged and explicitly
   deferred in the prior session's spec ("Out of scope" list) — it's a
   real finding, not a new one.

2. **"Forgot PIN" is a one-tap, zero-friction full data wipe reachable
   directly from the lock screen.** `LockScreen` always renders a "Forgot
   PIN" `TextButton` (`lock_screen.dart:137-140`), even while backoff is
   active, requiring no correct PIN and no biometric. It pushes straight
   to `LockResetScreen`, whose only gate is a single `FilledButton`
   (`lock_reset_screen.dart:30-43`) — no re-typed confirmation phrase, no
   delay, no secondary check. `docs/strategies/security.md`'s "Forgot
   PIN — full data reset, not a soft recovery" section justifies *why*
   there's no soft-recovery identity check (no account, nothing to verify
   against) — but doesn't address the different adversary this exposes:
   someone with a stolen/borrowed locked device who **can't** guess the
   PIN can still destroy the owner's data in two taps. That's an
   availability/integrity gap, distinct from (and not addressed by) the
   confidentiality problem PIN lock solves.

3. **`ScreenPrivacyService` has no test coverage and no seam to add
   any.** Unlike `BiometricService`/`PinLockService`, which both take an
   injectable dependency specifically so tests can fake the platform
   channel, `ScreenPrivacyService.enable()`/`disable()` call the static
   `ScreenProtector.*` methods directly (`screen_privacy_service.dart:9-
   18`). There is no `test/core/security/screen_privacy_service_test.dart`
   and structurally can't be one without refactoring first — so the
   `main.dart` `ref.listen` wiring that calls it on cold start and every
   settings toggle (added in the prior session's fix) is entirely
   unverified outside manual QA.

4. **Debug cruft left in the test suite from the prior session.**
   `test/core/router/app_router_test.dart:124-130` has a committed (in
   `0cea8ae`) `print('DEBUG isCurrentlyLocked=... ')` block wrapped in
   `// ignore: avoid_print` — diagnostic scaffolding for the toggle fix
   that was never cleaned up, now permanently in the suite. Separately,
   `test/_debug_lock_test.dart` is an **untracked** scratch file
   (`git status` shows `??`) with the same pattern (raw `print`s of locked
   state) sitting in the working tree — never committed, but present
   right now and would run under `flutter test`.

**Confirmed non-gaps** (checked against the artifact's suggested
questions, explicitly *not* proposed as work):

- **No hard lockout/wipe-after-N-attempts** beyond the doubling-capped-
  at-5-minutes backoff — `security.md` already states this is an accepted
  trade-off for a local, account-free app (uninstall/reinstall resets the
  counter anyway, and also wipes data). Consistent, not an oversight.
- **PIN length is a hardcoded 4 digits** in three places (`lock_screen
  .dart`, `pin_settings_screen.dart`'s `_CurrentPinPrompt`, `pin_set_
  screen.dart`) with no settings option. `security.md` explicitly reasons
  about "a 4-digit PIN's inherently small keyspace (10,000
  possibilities)" as the documented threat model — this is a stated
  design choice, not a gap.
- **Lock-timeout coverage of backgrounding paths** (notification tray,
  app switcher, phone-lock button) — all route through Flutter's
  `AppLifecycleState.paused`, which `main.dart`'s `didChangeAppLifecycleState`
  already hooks (`recordBackgrounded()`). No missing trigger found.
- **iOS app-switcher blur** is handled natively by `screen_protector`'s
  `protectDataLeakageOn()` (resigns-active blur is internal to the
  plugin) — no Flutter-side `AppLifecycleState.inactive` handling needed.

## Design

**1. Require the old PIN before accepting a new one.** Reuse the
`_CurrentPinPrompt` bottom sheet already built for the disable flow
(`pin_settings_screen.dart:112-119`): "Change PIN" first shows it and
calls `pinLockController.verify(oldPin)`; only on success does it
navigate to `PinSetScreen`, passing the verified `oldPin` through (e.g.
`context.push('/settings/pin/set', extra: oldPin)`). `PinSetScreen`
accepts an optional `oldPin` constructor param: when present, the final
step calls `changePin(oldPin, newPin)` instead of `setPin(newPin)` (both
already exist; this wires the dead `changePin` up for the first time).
First-time enable (`oldPin == null`) is unaffected — still calls
`setPin()` directly, no prompt.

**2. Add friction to "Forgot PIN," keep the no-soft-recovery policy
unchanged.** `LockResetScreen` gets a required typed-confirmation step —
a `TextField` where the destructive button only enables once the user
types the exact word shown in `lockResetConfirm` (or a dedicated short
phrase), the same pattern most "delete my account"-class flows use. This
is not a security control against a determined attacker (there's still
no identity to check, per FR-C-04) — it's a deliberate speed bump against
a bystander with an unlocked-enough device tapping through two buttons
in three seconds, and against fat-fingering it as the legitimate owner.
No change to the underlying `resetAllData()`/`wipeAllAppData()` behavior
or the FR-C-04 "full reset, no soft recovery" policy itself.

**3. Give `ScreenPrivacyService` the same injectable seam as its
siblings**, then add the missing test. Wrap the two `ScreenProtector`
static calls behind an injected function pair (constructor params
defaulting to the real calls, mirroring `BiometricService`'s
`LocalAuthentication? localAuth` pattern) so a test can inject fakes and
assert `enable()`/`disable()` call through correctly. Add
`test/core/security/screen_privacy_service_test.dart` (unit-level: the
service calls through) and extend the existing `main.dart` widget test
coverage to assert the `ref.listen` fires the injected fake on cold start
and on a settings toggle — closing the "just wired, never verified" gap.

**4. Test hygiene.** Delete `test/_debug_lock_test.dart` (untracked,
never should have lived past the debugging session it was written for).
Strip the `print('DEBUG ...')` block from `app_router_test.dart:124-130`
— the assertions immediately below it already cover what it was printed
to sanity-check.

## Open Questions

- Item 2's typed-confirmation friction is a UX speed bump, not an access
  control — is that the right bar, or does "last privacy gap" framing
  warrant something stronger (e.g. also requiring a successful biometric
  check before the reset screen is even reachable, on devices that have
  one enrolled)? That would still not stop a PIN-and-biometric-less
  attacker, but raises the bar further for a device where biometrics are
  set up.
- `main.dart`'s `recordBackgrounded()` call is `unawaited()`
  (`main.dart:114`). In the (very narrow) case of a near-instantaneous
  background→resume cycle faster than a `flutter_secure_storage` write
  completes, `isCurrentlyLocked()` could read a stale or still-null
  `lastBackgroundedAt` on the immediate next check. Real, but likely
  unobservable in practice (disk-backed secure storage writes are not
  that slow relative to any human-driven resume). Worth an `await` fix,
  or accepted as noise?
- Item 1's `extra:`-based old-PIN handoff between routes keeps the old
  PIN in memory (as a plain `String`) slightly longer than `verify()`'s
  own internal handling does. Acceptable (same as every other in-flight
  PIN string already handled by `PinKeypad`/`_entered` state), or should
  `PinSetScreen` instead re-verify itself rather than trust a
  caller-supplied "already verified" old PIN?
