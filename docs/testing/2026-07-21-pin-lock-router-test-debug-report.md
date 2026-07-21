# PIN Lock Router-Test Debugging Report

**Date:** 2026-07-21

## What was being debugged

`test/core/router/app_router_test.dart` gained a new test this session: `'a
locked app redirects to /lock; wrong PIN shows an error and stays locked;
the correct PIN unlocks back to the dashboard'`. Getting it to a reliable
pass surfaced two separate problems.

## Confirmed and fixed: biometric-provider race in `LockScreen`

**Bug:** `lib/core/security/lock_screen.dart`'s `_tryBiometric()` read
`ref.read(appSettingsProvider).value?.biometricEnabled ?? true` — a
snapshot of whatever the settings stream provider currently has cached.
On the very first frame after redirecting to `/lock`, that stream may not
have delivered its first value yet (`AsyncLoading`, `.value == null`), so
the `?? true` fallback silently defaulted to "attempt biometric" —
regardless of what the DB row (or the user's real preference) actually
says, because the *provider's cache* hadn't caught up to the *DB write*
yet. This is a real race, not just a test artifact: on a genuinely slow
cold start it could show a biometric prompt for a split second even with
biometric disabled.

Under `flutter test` in this sandbox specifically, hitting that branch
means calling the real (unmocked) `local_auth` platform channel, which
hangs indefinitely here rather than throwing `MissingPluginException` —
explaining why this test's hangs were intermittent (a timing race, not a
deterministic failure) and why it correlated with `biometricEnabled`
defaulting to `true` in this session's Task 2 work.

**Fix applied:** `_tryBiometric()` now does
`await ref.read(appSettingsProvider.future)` instead of reading `.value`
— waits for the real current settings value instead of guessing. Also
added a `mounted` check right after that await, since the widget can be
disposed during it.

```dart
final settings = await ref.read(appSettingsProvider.future);
if (!mounted || !settings.biometricEnabled) return;
```

**Verification:** rerunning the test after this fix no longer hangs (was
previously observed hanging for up to ~38 minutes on some runs). This
part is confirmed solved.

## Unresolved: `LockScreen` not found after the fix

With the hang fixed, the test still fails — deterministically, fast (no
hang), same as an earlier pre-fix run:

```
Expected: exactly one matching candidate
  Actual: _TypeWidgetFinder:<Found 0 widgets with type "LockScreen": []>
```

More importantly: **the file's other, older, previously-working test**
(`'bottom nav switches between the 5 tab branches'`) **now also fails**,
at its very first assertion:

```
Expected: exactly one matching candidate
  Actual: _AncestorWidgetFinder:<Found 0 widgets with type "AppBar" that
  are ancestors of widgets with text "Dashboard": []>
```

That test uses `FakePinLockService` (always unlocked) — it never touches
the lock/redirect path at all. Both tests failing at their *first* screen
assertion, immediately after the initial pump, points at something
broader than the lock-flow logic: neither test can currently get a normal
`DashboardScreen` (or `LockScreen`) to render its `Scaffold`/`AppBar` at
all under this exact test harness.

### What was ruled out by static code review (not by running tests)

Per instruction, the rest of this investigation was done by reading code,
not by executing `flutter test` again (this sandbox's `flutter_tester`
process has repeatedly hung for 10+ minutes on both widget-pumping code
*and*, in one run, on plain pre-widget-tree async DB/service calls with
no rendering involved at all — see "Environment note" below — so further
test runs here aren't a reliable diagnostic signal right now).

Checked and ruled out:
- **`GoRouter`/redirect logic** (`lib/core/router/app_router.dart`): the
  top-level `redirect` callback, `PinLockController.isCurrentlyLocked()`
  (`lib/core/security/pin_lock_controller.dart`), and `computeIsLocked()`
  were traced by hand against the test's exact sequence of writes
  (`setPin` → `writeLastBackgroundedAt` → `updateBiometricEnabled`) and
  logically should compute `isCurrentlyLocked() == true` given
  `pinLockTimeoutSeconds` defaults to `0`
  (`lib/core/database/tables/app_settings_table.dart:29`). No bug found
  here.
- **Generated-code staleness**: confirmed `lib/core/database/app_database
  .g.dart` (and the other touched files' `.g.dart` companions) are newer
  than their source files and do contain the new `biometricEnabled`/
  `screenPrivacyEnabled` columns — not a stale-codegen issue.
- **`go_router` version behavior**: `^17.3.0`, a version where top-level
  async `redirect` on the initial location is well-established, standard
  behavior — not a known-version quirk.
- **l10n string mismatch**: `l10n.navDashboard` is `"Dashboard"` in
  `app_en.arb` — matches the test's literal string.

### Leading (unconfirmed) hypothesis

`DashboardScreen` (`lib/features/dashboard/presentation/screens/
dashboard_screen.dart`) — the Run 15 additions — call into all three
modules' `dayStatus()`/`nextUpcoming(ref)`/`quickActions(ref)` against
whatever's in the test's fresh, empty in-memory DB (no goals, no
medicines, no prayer settings configured). A hand-read of Water's
implementations (`lib/features/water/water_module.dart`) shows defensive
null-handling throughout (`.value ?? default`, early-return on `null`),
so no obvious synchronous-throw was found there — but Medicine's and
Prayer's equivalents, and the exact interaction between
`_DayCompletionIndicator`'s `FutureBuilder` and `pumpAndSettle()`'s
settle-detection, were not exhaustively hand-traced the same way. This
remains a **hypothesis, not a confirmed root cause** — static reading
cannot substitute for actually observing whether something throws during
a real build (Flutter renders an `ErrorWidget` in place of a failed
subtree rather than always propagating the exception somewhere a static
reader would see it).

### Recommended next step

Run `flutter test test/core/router/app_router_test.dart` in a normal
(non-sandboxed) environment where `flutter_tester` doesn't intermittently
hang, and inspect the actual rendered widget tree on failure (e.g.
`tester.allWidgets`, `find.byType(ErrorWidget)`, `tester.takeException()`)
to see what's actually on screen instead of `Dashboard`/`LockScreen`. If
it turns out to be the `DashboardScreen` hypothesis above, the fix is
almost certainly making the Run 15 dashboard widgets tolerant of a
completely fresh/empty database (likely already true for Water; worth
checking Medicine/Prayer the same way) rather than anything in the PIN
lock feature itself.

## Environment note

Separately from the above: one debug run
(`test/_debug_lock_widget_test.dart`, a scratch file, since deleted) hung
for the full 10-minute `flutter test` internal timeout *before printing
anything* — including a `print()` placed before `pumpWidget` was even
called, i.e. during plain `await controller.setPin(...)` / secure-storage
/ Drift calls with no widget tree, no rendering, and no platform channel
involved. This matches the same class of intermittent hang documented
earlier this session for `dart:ui`'s `toImage()` and `local_auth`'s
platform channel — this sandbox's `flutter_tester` process appears to
hang unpredictably on a broader range of async Dart execution than just
plugin/rendering calls, which is why repeated `flutter test` runs here
are not a fully reliable signal and further diagnosis of the `LockScreen`
issue should happen in a non-sandboxed environment.

## Status

- Biometric-provider race in `LockScreen`: **fixed and confirmed**
  (`lib/core/security/lock_screen.dart`).
- `LockScreen`/`DashboardScreen` not rendering under test: **not yet
  root-caused** — static review narrowed it to a `DashboardScreen`
  hypothesis but could not confirm without running the test in a stable
  environment.
- Cleanup done: removed the temporary debug `print()` from
  `test/core/router/app_router_test.dart`; deleted the scratch files
  `test/_debug_lock_test.dart` and `test/_debug_lock_widget_test.dart`.
