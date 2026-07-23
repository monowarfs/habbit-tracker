# "Why This Matters" Micro-Education Cards

**Category:** Delightful · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — implementation-ready

## Problem

The app already has one working example of exactly this pattern, just
not generalized: `lib/core/changelog/presentation/whats_new_sheet.dart`
(`showWhatsNewSheet`) shows a **modal** bottom sheet the first time the
app is opened after an update, gated by comparing
`AppSettings.lastSeenAppVersion` against the running version
(`lib/main.dart:147-161`, using `lib/core/changelog/version_compare.dart`).
That's the right *mechanism* precedent (a persisted "have we shown this
already" flag on the settings singleton, checked once at a natural
moment) but the wrong *presentation* precedent for this item — a modal
sheet is exactly the "onboarding friction" this atlas item explicitly
wants to avoid; it needs to be inline and non-blocking instead.

Grepping `lib/core` and `lib/features` for `hasSeen`, `firstOpen`,
`onboardingComplete`, and `dismissed` found:

- `AppSettingsTable.onboardingCompletedAt`
  (`lib/core/database/tables/app_settings_table.dart:57`, nullable
  `IntColumn`, UTC epoch millis, "null = onboarding not yet completed")
  and `AppSettingsTable.lastSeenAppVersion` (line 62, nullable
  `TextColumn`) — **the only two "one-time flag" columns that exist
  today**, both living directly on the `app_settings` singleton row,
  both following the same convention: null/absent = not yet shown,
  non-null = shown (with a timestamp or version marker).
- No generic per-module or per-screen flag table, no `shared_preferences`
  dependency anywhere (`grep shared_preferences pubspec.yaml` — no hit),
  no existing "dismissed hints" concept at all beyond those two columns.

**Decision: extend `AppSettingsTable` with new nullable epoch-millis
columns, one per curated card, following the exact
`onboardingCompletedAt` convention — not a new table, not
`shared_preferences`.**

- **Why not a new table:** the atlas item itself calls for "a small,
  curated set" (2-4 cards, not dozens) — a generic `dismissed_hints(id
  TEXT PRIMARY KEY, dismissed_at INTEGER)` key-value table is the kind
  of speculative generality this app's own precedent argues against:
  every other one-off UI flag it has ever needed (`onboardingCompletedAt`,
  `lastSeenAppVersion`) got its own named column, not a row in a generic
  table, and a handful of cards fits the same shape.
- **Why not `shared_preferences`:** it would be a genuinely new
  dependency (confirmed absent from `pubspec.yaml`) introducing a
  *second, competing* persistence mechanism for what is otherwise
  indistinguishable from the settings the app already keeps in Drift.
  Concretely, it would lose the free reactive rebuild the Drift column
  gets for nothing: `SettingsRepositoryImpl.watchSettings()`
  (`settings_repository_impl.dart:30-35`) already streams the singleton
  row via `query.watchSingle()`, so a new `AppSettings` field shows up
  in every existing `ref.watch(appSettingsProvider)` consumer
  automatically. A `shared_preferences` flag would need its own
  provider, its own read-on-init wiring, and still wouldn't compose with
  `restoreSettings` (the import/restore path,
  `settings_repository.dart:50`) the way a DB column does for free. Not
  a defensible exception for 2-4 booleans-with-timestamps.

## Design

**Schema — `lib/core/database/tables/app_settings_table.dart`:** add one
nullable `IntColumn` per curated card, same doc-comment convention as
`onboardingCompletedAt`:

```dart
/// UTC epoch millis; null = the Water hydration-science card hasn't
/// been shown yet.
IntColumn get waterHydrationHintSeenAt => integer().nullable()();

/// UTC epoch millis; null = the Prayer Qadha-context card hasn't been
/// shown yet.
IntColumn get prayerQadhaHintSeenAt => integer().nullable()();
```

Migration (`lib/core/database/app_database.dart`): bump
`schemaVersion` from 7 to 8, add a matching `if (from < 8)` block next to
the existing `if (from < 7)` (per-weekday reminder overrides) —
```dart
if (from < 8) {
  await m.addColumn(appSettingsTable, appSettingsTable.waterHydrationHintSeenAt);
  await m.addColumn(appSettingsTable, appSettingsTable.prayerQadhaHintSeenAt);
}
```

**Domain (`app_settings.dart`/its Freezed union):** add
`DateTime? waterHydrationHintSeenAt` and `DateTime? prayerQadhaHintSeenAt`
fields, same nullable-`DateTime`-from-epoch-millis mapping
`_toDomain`/`toDb` already does for `onboardingCompletedAt`
(`settings_repository_impl.dart:159-163`).

**Repository (`SettingsRepository`/`SettingsRepositoryImpl`):** add
```dart
Future<Result<void>> markWaterHydrationHintSeen();
Future<Result<void>> markPrayerQadhaHintSeen();
```
each a one-line `_update(AppSettingsTableCompanion(waterHydrationHintSeenAt:
Value(clock.now().millisecondsSinceEpoch)))`, following the exact
`updateLastSeenAppVersion` one-liner pattern
(`settings_repository_impl.dart:91-93`).

**Widget — new file `lib/core/widgets/dismissible_hint_card.dart`:**
one small reusable `Card` (not `MaterialBanner` — the app has no
existing `MaterialBanner` usage anywhere; `Card` is the idiom already
established for standalone content blocks, e.g. `medicine_detail_screen
.dart:105`), close icon following `whats_new_sheet.dart:46-49`'s
`IconButton(icon: const Icon(Icons.close))` convention:

```dart
/// A one-line, dismissible, non-modal educational card — shown at most
/// once per [onDismiss] call, per the "why this matters" pattern.
/// Caller owns whether to render it at all (checked against the
/// relevant `*HintSeenAt` field being null).
class DismissibleHintCard extends StatelessWidget {
  const DismissibleHintCard({
    required this.message,
    required this.onDismiss,
    super.key,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.lightbulb_outline),
      title: Text(message),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onDismiss,
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      ),
    ),
  );
}
```

**Call sites** — inserted as the first child of the existing screen's
body, conditionally on the flag being null:

1. **Water** — `WaterSettingsScreen` (`lib/features/water/presentation/
   screens/water_settings_screen.dart:14`, the module's actual daily-goal
   screen; there's no separate "goal screen" file). Insert
   `if (settings.waterHydrationHintSeenAt == null) DismissibleHintCard(
   message: l10n.waterHydrationHintCard, onDismiss: () =>
   controller.markWaterHydrationHintSeen())` above the existing goal-
   preset chips (before the widget currently at line ~43).
2. **Prayer** — `PrayerQadhaScreen` (`lib/features/prayer/presentation/
   screens/prayer_qadha_screen.dart:19-22`, a `ListView`). Insert the
   card as the first item in that `ListView`'s `children`, before the
   `for (final counter in counters)` loop.

Both screens are `ConsumerWidget` today (not `ConsumerStatefulWidget`) —
no state-class change needed since visibility is driven entirely by the
already-streamed `AppSettings`, not local widget state.

**l10n keys (both `app_en.arb`/`app_bn.arb`), naming matching the
existing `moduleScreenPurpose` key-naming convention:**

- `waterHydrationHintCard` — EN: "Water helps regulate temperature,
  joints, and energy — most adults need roughly 2-3 liters a day,
  more if it's hot or you're active." BN: equivalent one-liner.
- `prayerQadhaHintCard` — EN: "Qadha lets you make up a missed prayer
  later — it's a normal part of practice, not a separate obligation on
  top of your regular five." BN: equivalent one-liner.
- (Curated list capped at these 2 for v1 — see Open questions in the
  prior draft; Medicine's low-stock screen is a plausible 3rd but is
  deliberately deferred, see Out of scope.)

## Out of scope

- **Medicine's stock/low-stock screen card.** A 3rd plausible moment,
  but adding it means picking accurate, reviewed medical-adherence
  copy — a content-accuracy bar this spec isn't resourced to clear right
  now. Add a 3rd `*HintSeenAt` column the same two-line way if/when
  copy is ready; the mechanism already generalizes.
- **A "replay tips" Settings control.** Per the original draft's own
  non-goal: one-time is truly one-time for v1. No UI is built for
  resetting the flags (a developer could still do it by hand via a DB
  reset during testing).
- **Personalized/dynamic card content.** Static curated strings only,
  no logic branching on user data.
- **Reusing `whats_new_sheet.dart`'s modal presentation.** Deliberately
  not reused — that pattern is right for "here's what changed" (a
  bigger, multi-item announcement) but wrong for a single-sentence,
  low-friction aside; the new `DismissibleHintCard` is intentionally a
  different, lighter-weight widget.
- **A generic N-flag table for arbitrary future hints.** Two hardcoded
  columns for two curated cards is the matching size for "a small,
  curated set" — building a scalable hint-registry table now would be
  solving a problem this atlas item doesn't have yet (see Design's
  "why not a new table").

## Global Constraints

- No new dependency — `Card`/`ListTile`/`IconButton` are all
  already-used Flutter SDK widgets; no `shared_preferences` addition
  (see Problem for why that was considered and rejected).
- **Schema migration required:** `schemaVersion` 7 → 8,
  `AppSettingsTable` gains `waterHydrationHintSeenAt`/
  `prayerQadhaHintSeenAt` (both nullable `IntColumn`, no default —
  matches `onboardingCompletedAt`'s existing nullable-no-default shape).
  **Coordinate with `11-personalized-dashboard-greeting-design.md`
  (`displayName`) and `12-seasonal-theme-accents-design.md`
  (`seasonalAccentsEnabled`)** — all three independently target
  `schemaVersion` 8; whichever of these three ships last must check
  `app_database.dart`'s actual current version and fold its `addColumn`
  into the existing `if (from < 8)` block rather than bumping to 9.
  Run `dart run build_runner build --delete-conflicting-outputs` after
  the table change (Drift codegen), and `flutter gen-l10n` after the
  ARB additions, per CLAUDE.md's standard commands.
- `SettingsRepository.restoreSettings` (the import/replace path,
  `settings_repository.dart:50`) intentionally does **not** restore
  these two new fields — same treatment as `onboardingCompletedAt`,
  which the interface's own doc comment already excludes from that
  method's scope (PIN hash/salt are the only example given today, but
  the same "don't carry one-time UI state across a restore" reasoning
  applies here: a fresh import shouldn't silently suppress a card the
  new installation hasn't actually shown yet).
- New l10n keys: `waterHydrationHintCard`, `prayerQadhaHintCard` (both
  `app_en.arb`/`app_bn.arb`), plus reuse of
  `MaterialLocalizations.of(context).closeButtonTooltip` for the
  dismiss button's tooltip — no new key needed there, it's an existing
  Flutter SDK localization.
