# In-App "What's New" Changelog on Update

**Date:** 2026-07-21
**Status:** Draft — pending review

## Problem

Feature Atlas gap analysis (Must Have, complexity S, inspired by TickTick):
when a user updates the app and a new module/badge/feature appears with no
explanation, it reads as broken rather than intentional. There is currently
no in-app mechanism that tells a user what changed after an update — the
About screen shows only the current version number, with no history and no
automatic "here's what's new" surface.

## Codebase findings

- **`package_info_plus: ^10.2.1`** is already a direct dependency
  (`pubspec.yaml:34`) and already used twice: `about_screen.dart:19-24`
  (`PackageInfo.fromPlatform().version` in a `FutureBuilder`) and
  `data_settings_screen.dart:37-44` (export metadata). **No new dependency
  needed.**
- Current app version: `pubspec.yaml:7` → `version: 1.0.0+1`.
- `lib/main.dart` already has the exact idiom this feature needs: a
  `ConsumerStatefulWidget` (`_HabitTrackerAppState`) whose `initState`
  schedules a one-time `addPostFrameCallback` (currently used for
  `widget.initialDeepLink` navigation, lines 88-94). The changelog check
  slots in as a second, similar one-time post-frame action — not a new
  pattern.
- `AppSettings` (`lib/features/settings/domain/entities/app_settings.dart`)
  is a `@freezed` sealed class; `SettingsRepositoryImpl`
  (`lib/features/settings/data/repositories/settings_repository_impl.dart`)
  is the no-DAO, one-caller repository pattern every settings field
  already follows — most recently `biometricEnabled`/
  `screenPrivacyEnabled`, added this session
  (`docs/superpowers/specs/2026-07-21-pin-lock-toggles-fix-design.md`) via
  a `schemaVersion` bump and an `if (from < N)` migration block
  (`app_database.dart:54-84`, currently at version `3`, with an explicit
  "seam" comment inviting the next bump).
- `AppSettings.onboardingCompletedAt` is a precedent for a settings field
  that is **deliberately excluded** from backup export/import
  (`core/backup/export_orchestrator.dart:39-47`'s `_appSettingsToJson`
  omits it) because it's device-local launch state, not user preference
  data. `lastSeenAppVersion` is the same shape of field and should follow
  the same exclusion.
- `SettingsHomeScreen` (`lib/features/settings/presentation/screens/
  settings_home_screen.dart`) routes to `AboutScreen` via
  `context.push('/settings/about')` (`AppRoutes.settingsAbout`,
  `app_router.dart:64`). `AboutScreen` is a plain `StatelessWidget` with a
  `ListView` of `ListTile`s (version, licenses, privacy policy) — a
  natural place to append one more `ListTile`.
- Precedent for a bundled JSON asset already exists
  (`lib/features/prayer/data/prayer_cities_loader.dart` loads
  `assets/data/prayer_cities.json` via `rootBundle.loadString`), but for a
  short, hand-written, developer-authored list (one entry per release) a
  bundled JSON asset adds an async load + parse + assets-list entry for no
  benefit over a plain Dart `const` list that ships in the binary and is
  type-checked at compile time. This spec uses a `const` list — see
  Design.
- `pub_semver` is only a *transitive* dependency (present in
  `pubspec.lock`, not `pubspec.yaml`) — not safe to import directly
  without declaring it. Comparing `"1.10.0"` vs `"1.9.0"` needs numeric,
  not lexical, comparison, so this spec uses a ~5-line manual dotted-
  integer comparator instead of adding a real dependency for it.

## Design

**No new dependency.** `package_info_plus` is already installed and
already used for exactly this purpose (reading `PackageInfo.version`) in
two other files.

### Changelog data — a `const` Dart list, not a JSON asset

`lib/core/changelog/changelog_entry.dart`:

```dart
/// One release's changelog entry. Plain (not `@freezed`) — no `copyWith`/
/// serialization ever needed, it's a compile-time literal, not a value
/// flowing through repositories.
class ChangelogEntry {
  const ChangelogEntry({required this.version, required this.highlights});

  /// Semantic version this entry describes, e.g. `'1.1.0'` — matches
  /// `PackageInfo.version` (the part before `+buildNumber`).
  final String version;

  /// Bullet points shown for this release. Localized: each string is an
  /// `AppLocalizations` getter name resolved at display time (same
  /// indirection every other static/enum-backed UI string in this repo
  /// uses), not raw English baked into the const list.
  final List<String Function(AppLocalizations)> highlights;
}
```

`lib/core/changelog/changelog_data.dart`: `const List<ChangelogEntry>
kChangelogEntries = [...]`, newest-first, one entry appended by hand each
release (developer-authored alongside the version bump in `pubspec.yaml`
— not generated, not remote-fetched, per this being an offline-first app
with no backend).

A small manual comparator, `lib/core/changelog/version_compare.dart`:
`int compareVersions(String a, String b)` — splits on `.`, parses each
dotted segment as `int`, compares component-wise (falls back to `0` on a
malformed segment rather than throwing — a corrupt/missing version string
must never crash startup). Used to filter `kChangelogEntries` to those
newer than `lastSeenAppVersion`.

### New settings field: `lastSeenAppVersion`

Follows the `biometricEnabled`/`screenPrivacyEnabled` precedent exactly:

- `AppSettingsTable` (`lib/core/database/tables/app_settings_table.dart`)
  gains `TextColumn get lastSeenAppVersion => text().nullable()();` — null
  means "never recorded" (fresh install, or upgraded from a build that
  predates this feature).
- `schemaVersion` → `4`; `app_database.dart`'s `onUpgrade` gets an
  `if (from < 4) { await m.addColumn(appSettingsTable,
  appSettingsTable.lastSeenAppVersion); }` block, following the exact
  `if (from < 3)` precedent immediately above it.
- `AppSettings` domain entity gains `String? lastSeenAppVersion`.
- `SettingsRepository` gains `Future<Result<void>>
  updateLastSeenAppVersion(String version)`; `SettingsRepositoryImpl`
  implements it with the same one-line `_update(AppSettingsTableCompanion
  (lastSeenAppVersion: Value(version)))` pattern every other setter uses.
- **Not included in backup export/import** — same reasoning as
  `onboardingCompletedAt` (device-local launch bookkeeping, not user
  preference data users would expect a restore to carry over). No changes
  needed to `export_orchestrator.dart`/`import_orchestrator.dart`.

### Startup check — `main.dart`

Reuses the existing `_HabitTrackerAppState.initState()` one-time
post-frame idiom (the `widget.initialDeepLink` handling right above it,
`main.dart:88-94`) rather than inventing a second mechanism:

```dart
if (widget.initialDeepLink == null) {
  WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowWhatsNew());
}
```

`_maybeShowWhatsNew()`:
1. Reads `PackageInfo.fromPlatform().version` and the first value of
   `ref.read(appSettingsProvider.future)`.
2. If `lastSeenAppVersion == null` (fresh install): silently persist the
   current version via `updateLastSeenAppVersion` and return — nothing to
   announce to a brand-new user.
3. Else if `compareVersions(currentVersion, lastSeenAppVersion) > 0`:
   filter `kChangelogEntries` to versions `> lastSeenAppVersion`, and — if
   the filtered list is non-empty — show the changelog bottom sheet
   (below), then persist the new `lastSeenAppVersion` once it's dismissed.
4. Else (same version, e.g. a hot-restart or a build-number-only bump):
   no-op.

**Deep-link precedence.** If `widget.initialDeepLink` is set (a
notification tap cold-started the app), the changelog check is skipped
entirely for that launch — no dialog stacked on top of deep-link
navigation — and, importantly, `lastSeenAppVersion` is **not** updated in
that branch either, so the very next normal launch (no deep link) picks
the check back up instead of silently losing the announcement.

### The bottom sheet — one widget, two call sites

`lib/core/changelog/presentation/whats_new_sheet.dart`: a
`showModalBottomSheet` helper taking a `List<ChangelogEntry>` and
rendering version headers + bullet highlights, `l10n`-driven title/close
button. Two callers, same widget, different input list:

1. **Auto-shown on update** (`main.dart`, above) — passed only the
   entries newer than `lastSeenAppVersion`.
2. **About screen's "View what's new" entry** — a new `ListTile` appended
   to `AboutScreen`'s existing `ListView` (`about_screen.dart`, after the
   licenses tile), passed the **full** `kChangelogEntries` list
   unfiltered — a persistent, manually-triggerable history, independent
   of what's already been seen.

No new route/`AppRoutes` constant, no `GoRouter` wiring — a bottom sheet
is presented from a `BuildContext` the same way `showLicensePage` already
is in the same file, keeping this consistent with the existing screen and
avoiding a needless route for a dismissible sheet.

### Localization

New `app_en.arb`/`app_bn.arb` keys (both locales, per every other feature
in this repo): a sheet title (e.g. `whatsNewTitle`), a close/dismiss
label, and the About screen's new tile label (e.g.
`aboutWhatsNew`/`aboutChangelog`). Highlight bullet strings are also
`AppLocalizations` getters (one per changelog entry per release), not
inline literals in `changelog_data.dart` — kept consistent with how every
other user-facing string in the app is sourced.

## Out of scope

- Any remote/backend-fetched changelog — this is an offline-first app
  with no backend; the changelog is a compile-time asset shipped in the
  binary, authored by hand alongside each version bump.
- Per-module "new" badges/pills on the bottom nav or dashboard (e.g. a
  dot on the Prayer tab the first time it appears after an update) — a
  plausible follow-on but a separate, larger design (needs its own
  "seen" state per module/feature, not just per app-version) not
  requested here.
- A settings toggle to opt out of the auto-shown sheet — TickTick and
  peers don't offer this either; the sheet is dismissible and only ever
  shows once per version.
- Retroactively backfilling changelog entries for versions before this
  feature ships (`1.0.0`) — `kChangelogEntries` starts from the release
  that ships this feature.
- Rich content (images/GIFs) in changelog entries — text bullets only,
  matching the About screen's existing plain-text style.

## Global Constraints

- No new `pubspec.yaml` dependency — `package_info_plus` is already
  present and already used for version reads.
- New DB column: `last_seen_app_version` (nullable text) on
  `app_settings`.
- `schemaVersion` → `4`, migrated via `m.addColumn`, following the
  `if (from < 3)` precedent immediately above the new `if (from < 4)`
  block.
- `lastSeenAppVersion` is excluded from backup export/import, same as
  `onboardingCompletedAt`.
- Changelog content lives in a bundled `const` Dart list
  (`lib/core/changelog/changelog_data.dart`), never fetched over the
  network.
- The auto-shown sheet is skipped (and `lastSeenAppVersion` left
  unchanged) on any launch where `initialDeepLink` is set, so it reliably
  surfaces on the next deep-link-free launch instead of being silently
  lost.
- A fresh install (`lastSeenAppVersion == null`) never shows the sheet —
  it only silently seeds the current version.
