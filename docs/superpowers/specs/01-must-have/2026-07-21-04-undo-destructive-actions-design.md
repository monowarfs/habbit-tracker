# Undo for Destructive Actions

**Date:** 2026-07-21
**Status:** Draft — pending review

## Problem

The Feature Atlas gap-analysis flags a Gmail-style "Undo" snackbar for
delete / mark-done-by-mistake as Must Have, Complexity S, and claims the
`deleted_at` soft-delete columns it would depend on already exist.

**That premise checks out, but only partially matters.** `deleted_at`
(nullable `int`, "null = not deleted") is already a real, actively-used
column — every read path filters `t.deletedAt.isNull()` — on every table a
user can actually delete a row from: `water_goals`, `water_logs`,
`medicines`, `medicine_schedules`, `medicine_doses`,
`medicine_stock_events`, and `prayer_records` (also on `achievements` and
`notification_ledger`, neither of which is user-facing). It's absent from
`water_settings`, `prayer_settings`, `prayer_qadha_counters`, and
`app_settings` — but those are singleton/settings rows nobody ever
"deletes," so that's expected, not a gap. **So: the schema dependency is
already satisfied everywhere it needs to be. The actual gap is entirely in
the UI/presentation layer** — no screen shows an undo affordance, and one
whole reversal code path already exists but is dead code:

- **Water — delete a log entry.** `WaterLogTile`'s trash icon
  (`lib/features/water/presentation/widgets/water_log_tile.dart`) calls
  `WaterController.deleteEntry` (`water_controller.dart:67`) straight
  through to `WaterRepositoryImpl.deleteEntry`
  (`water_repository_impl.dart:189`), which sets `deletedAt` immediately —
  no confirmation dialog, no undo, nothing. One tap, gone.
- **Medicine — "mark done by mistake," the scenario the atlas names
  explicitly.** `DoseTile.onDone` in `medicine_home_screen.dart:62-64`
  calls straight through to `MedicineController.markDoseDone`
  (`medicine_controller.dart:82`), which writes `status: 'done'`
  immediately. There *is* already an `undoDose` reversal
  (`medicine_controller.dart:105-108` →
  `medicine_repository_impl.dart:455`) that resets a dose back to
  `upcoming` and reverses whatever stock delta was applied — but grepping
  `lib/features/medicine/presentation/` for `undoDose` turns up exactly
  one hit: the method definition itself. **It has zero callers.** Same
  gap for `DoseTile.onSkip` → `markDoseSkipped`
  (`medicine_controller.dart:97`) — instant commit, no undo, and
  `undoDose` resets to `upcoming` regardless of whether the prior state
  was `done` or `skipped`, so it already covers both.
- **Prayer — no delete UI exists at all.** The only "undo-able" action is
  the existing prayed/un-prayed toggle (`PrayerTile` → `togglePrayed` →
  `markPrayed`/`unmarkPrayed`), which is already a free, instant, fully
  symmetric undo (tap again) — see Out of scope.

**Existing SnackBar convention** (found identically in
`data_settings_screen.dart:85-99`, `water_home_screen.dart:138-149`,
`medicine_home_screen.dart:102-110`, `prayer_home_screen.dart:110-118`):
plain `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:
Text(...)))`, no action button, used today only for the "Achievement
unlocked" toast. The new undo snackbar should look and feel like that one
plus a `SnackBarAction`, not invent a new visual language.

## Design

**One generic, dependency-free helper — `lib/core/widgets/undo_snackbar.dart`:**

```dart
/// Shows a Gmail-style Undo snackbar. If the user taps Undo, [onUndo]
/// runs and [onCommit] never does; otherwise (timeout, swipe-dismiss,
/// navigating away) [onCommit] runs once the snackbar closes.
Future<void> showUndoSnackbar(
  BuildContext context, {
  required String message,
  required String undoLabel,
  required FutureOr<void> Function() onCommit,
  VoidCallback? onUndo,
  Duration duration = const Duration(seconds: 4),
}) async {
  final reason = await ScaffoldMessenger.of(context)
      .showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          action: SnackBarAction(label: undoLabel, onPressed: () {}),
        ),
      )
      .closed;
  if (reason == SnackBarClosedReason.action) {
    onUndo?.call();
  } else {
    await onCommit();
  }
}
```

No `Timer`, no new package: `SnackBar`'s own `duration` and the
`ScaffoldFeatureController.closed` future's `SnackBarClosedReason`
*already* distinguish "user tapped the action" from "it just went away" —
that's the whole undo-window mechanism, for free, from the SDK.

The two real call sites use this one function in two different modes,
picked by which is the smaller diff for that module — this is the
"before committing for real (**or** reversing a soft-delete)" the atlas
description gestures at; it's the same helper either way, just which
argument does the work:

1. **Water delete — defer-commit mode** (Water has no existing reversal
   method, so don't add one). `WaterHomeScreen` becomes a
   `ConsumerStatefulWidget` holding a small `Set<String> _pendingDeleteIds`.
   Tapping the trash icon adds the entry's id to that set (`setState`,
   filtered out of the rendered list immediately — optimistic hide, zero
   DB write yet) and calls `showUndoSnackbar(..., onCommit: () =>
   controller.deleteEntry(id), onUndo: () => setState(() =>
   _pendingDeleteIds.remove(id)))`. The real soft-delete only happens
   inside `onCommit`, i.e. only if Undo isn't tapped. Tapping Undo never
   touches the repository at all.
2. **Medicine dose done/skip — optimistic-then-reverse mode** (Medicine
   already has the reversal). The write happens exactly as it does today
   — immediately, unchanged, so achievement evaluation (which already
   runs inline inside `markDoseDone`/`markDoseSkipped`) keeps firing at
   the same point it always has. `DoseTile.onDone`/`onSkip` additionally
   call `showUndoSnackbar(..., onCommit: () {}, onUndo: () =>
   controller.undoDose(doseId))` right after. `onCommit` is a no-op —
   the "commit" already happened; Undo is what does work here, giving
   `undoDose` its first real caller.

**Sequencing with the achievement-unlock snackbar.** Medicine's
`_markDoneAndCelebrate` already shows a snackbar when a dose newly
unlocks an achievement. Two snackbars can't usefully show at once on the
same `ScaffoldMessenger` — show the undo snackbar first; only show the
achievement-unlock snackbar after the undo snackbar's own `.closed`
resolves *and* the dose wasn't undone (skip it if it was — the user just
said "that didn't happen"). Exact sequencing is an implementation
detail, flagged here so it isn't a surprise mid-PR.

**Known, accepted limitation:** the achievement engine
(`core/achievements/achievement_engine.dart`) has no revoke path — it
only ever unlocks forward. If a dose-done unlocks an achievement and the
user then taps Undo, the achievement stays unlocked. Not fixing that
here; out of scope for an S-sized change, and matches how most apps with
this pattern behave (the celebratory moment already happened).

## Destructive actions covered

1. Water — delete a logged entry (`WaterLogTile`'s trash icon).
2. Medicine — mark a dose done (`DoseTile.onDone`), the atlas's named
   "mark done by mistake" scenario.
3. Medicine — mark a dose skipped (`DoseTile.onSkip`) — same
   `undoDose` reversal, same treatment, effectively free once (2) exists.

## Out of scope

- **Prayer's mark-prayed toggle.** Already an instant, cost-free,
  symmetric undo — tapping the tile again calls `unmarkPrayed`. Layering
  a snackbar on top of an already-reversible toggle is redundant chrome,
  not a gap.
- **Medicine's `archiveMedicine`/`restoreMedicine`.** Not wired to any
  UI button at all today — no archive or delete affordance exists in
  `medicine_list_screen.dart` or `medicine_detail_screen.dart`. Needs its
  own "add the button" change before undo is even a question.
- **Bulk wipes** (`WaterRepository.wipeAll`/Medicine's/Prayer's
  equivalents, used by import's replace-semantics). Already a deliberate,
  explicit, low-frequency action gated inside the Settings import flow —
  not a stray-tap risk this pattern is meant to catch.
- **Notification-action reversals** (`onNotificationAction`'s Done/Skip,
  Prayer's `markMissedBySkip` from a Skip notification). These fire from
  a background isolate with no `BuildContext` to attach a snackbar to;
  only the in-app tile taps listed above are in scope.
- **Achievement-unlock revocation on undo** — see Known limitation above.
- **A generic "wrap every write in undo" framework.** Only the 3 call
  sites above exist today; building a blanket abstraction for
  hypothetical future ones is exactly the over-engineering this size
  budget rules out. Add a 4th call site the same two-line way if/when one
  shows up (e.g. if Prayer ever grows a record-delete feature).

## Global Constraints

- New file: `lib/core/widgets/undo_snackbar.dart`, exporting
  `showUndoSnackbar(...)` per the signature above. No new dependency —
  built entirely on `SnackBar`/`SnackBarAction`/
  `ScaffoldFeatureController.closed`/`SnackBarClosedReason`, all
  already-imported Flutter SDK.
- **No schema migration, no new DB columns.** `deleted_at` already exists
  and is already filtered-on everywhere a user-facing delete needs it.
- `WaterHomeScreen` changes from `ConsumerWidget` to
  `ConsumerStatefulWidget` (adds one `Set<String> _pendingDeleteIds`
  field used only to filter the rendered list). No new repository method
  on `WaterRepository` — undo never reaches the DB.
- `MedicineHomeScreen` stays a `ConsumerWidget` — no optimistic-hide
  needed there, since the write is unchanged (still immediate).
  `DoseTile.onDone`/`onSkip` call sites gain a trailing
  `showUndoSnackbar(...)` wired to the pre-existing
  `MedicineController.undoDose`.
- New l10n keys (both `app_en.arb`/`app_bn.arb`): `commonUndo` ("Undo" —
  shared across both call sites), `waterEntryDeletedSnackbar` ("Entry
  deleted"), `medicineDoseUndoSnackbar` ("Dose updated").
- Undo window: 4 seconds, the function's default `Duration` parameter —
  not a user-configurable setting.
