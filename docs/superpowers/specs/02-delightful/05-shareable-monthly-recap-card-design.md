# Shareable Monthly Recap Card

**Date:** 2026-07-23
**Status:** Draft — pending review

## Problem

The data half of this feature is already fully solved:
`AggregateReportUseCase.execute({modules, period: ReportPeriod.month,
periodAnchor})` (`lib/core/reports/aggregate_report_usecase.dart:39-61`)
already returns a `List<ModuleReport>` — a `typedef` record
(`aggregate_report_usecase.dart:22-28`) carrying `displayName`,
`accentColor`, chart `points`, and `longestStreak` per module, already
skipping any module with zero data in the period (the "hasData" check,
`aggregate_report_usecase.dart:48-51`) rather than rendering a misleading
zero. `longestStreak` itself comes from the shared `longestStreak()`
helper (`day_status_streaks.dart:7-20`). `ReportsScreen`
(`lib/features/reports/presentation/screens/reports_screen.dart`) already
renders exactly this for `ReportPeriod.month` — the recap card's data
source is "call the same use case with the same period, one month
anchor," nothing new to compute.

**Two things this feature actually needs are both genuinely absent
today**, checked directly rather than assumed:

1. **Image capture.** `grep -rn "RenderRepaintBoundary\|toImage("` across
   `lib/` returns nothing — no widget-to-image capability exists anywhere
   in the app yet. `home_widget` (already a dependency, used by
   `lib/core/widgets/widget_refresh_helper.dart`) is unrelated — it pushes
   structured JSON to a native home-screen widget via `HomeWidget
   .saveWidgetData`, it does not rasterize a Flutter widget into a PNG.
   `RenderRepaintBoundary.toImage()` (Flutter's own native capture
   primitive — wrap the card widget in a `RepaintBoundary`, grab its
   `RenderRepaintBoundary` via a `GlobalKey`, call `.toImage(pixelRatio:
   ...)`, then `.toByteData(format: ImageByteFormat.png)`) is the correct,
   dependency-free approach — confirmed nothing already installed does
   this job.
2. **Share sheet.** **Already solved, already a dependency.**
   `share_plus: ^13.2.1` is in `pubspec.yaml` and already used twice:
   `lib/core/backup/local_file_backup_target.dart:17` (`SharePlus.instance
   .share(ShareParams(files: [XFile(exportFile.path)]))`) and
   `lib/features/settings/presentation/screens/data_settings_screen.dart
   :149` (log-file sharing, same call shape). The recap card reuses this
   exact API with a PNG file instead of a JSON/log file — **no new
   dependency for sharing.**

**File lifecycle precedent already exists too:**
`data_settings_screen.dart:46-51` writes its export JSON to
`(await getTemporaryDirectory())`, hands it straight to `LocalFileBackupTarget
().upload(file)`, and never explicitly deletes it afterward — the OS-managed
temp directory is the app's existing (and only) precedent for this kind
of ephemeral share file. The recap card follows the same pattern rather
than inventing a cleanup routine this app doesn't otherwise have.

## Design

### Rendering pipeline

New `lib/features/reports/presentation/widgets/monthly_recap_card.dart` —
the visual card itself, a fixed-aspect (e.g. 1080×1920, a share-sheet-
friendly portrait ratio) `Widget` built from a `List<ModuleReport>` plus a
month label, laid out as: app name/icon header, one row per module
(`accentColor` dot + `displayName` + its headline number — water's `value`
totals as a percent-of-goal-equivalent bucket count, prayer/medicine as
`longestStreak` days), and a subtle background gradient seeded from the
first enabled module's `accentColor` (falls back to the theme's seed teal
if the list is empty, though an empty list never reaches this widget —
see below). No per-module custom template in v1, matching the original
draft's non-goal.

New `lib/features/reports/presentation/widgets/recap_card_capture.dart` —
the capture plumbing, kept separate from the visual widget so the widget
itself stays a plain, previewable `Widget`:

```dart
/// Wraps [child] in a `RepaintBoundary` keyed by [_boundaryKey] and
/// exposes [capturePng] to rasterize it. `pixelRatio: 3` for share-quality
/// output regardless of the rendering device's actual density.
class RecapCardCapture extends StatelessWidget {
  const RecapCardCapture({required this.child, super.key});
  final Widget child;

  static final _boundaryKey = GlobalKey();

  /// Renders the wrapped widget to PNG bytes. Must be called after the
  /// first frame the boundary is part of (post-`WidgetsBinding
  /// .instance.addPostFrameCallback`, or from a button's `onPressed`,
  /// which always runs after layout).
  static Future<Uint8List> capturePng({double pixelRatio = 3}) async {
    final boundary = _boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: _boundaryKey, child: child);
}
```

### Share/save action

New `lib/features/reports/presentation/recap_share_usecase.dart`:

```dart
/// Renders the current month's recap and hands it to the OS share sheet
/// (which already includes "save to Photos"/"save to Files" on both
/// platforms — same precedent `LocalFileBackupTarget.upload` already
/// relies on, so no separate gallery-save code path is needed).
Future<void> shareMonthlyRecap({
  required List<ModuleReport> reports,
  required LocalDate monthAnchor,
}) async {
  final pngBytes = await RecapCardCapture.capturePng();
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, 'habit_tracker_recap.png'));
  await file.writeAsBytes(pngBytes);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  // No explicit delete — same precedent as data_settings_screen.dart's
  // export file: the OS-managed temp directory is left to reclaim it.
}
```

### Entry point

A `Share my month` button/icon on `ReportsScreen`
(`reports_screen.dart:48-60`'s `AppBar.actions`), enabled only when
`_period == ReportPeriod.month` (the recap is month-only in v1, per the
original draft's non-goal — the button is simply absent/disabled for week/
year). Tapping it: builds an **off-screen** `RecapCardCapture(child:
MonthlyRecapCard(reports: reportsAsync.value!, monthAnchor: _anchor))`
inside an `Overlay` entry positioned off-screen (or a zero-opacity
`Positioned` within the existing tree) so it lays out and paints without
being visible to the user, waits one frame, calls `capturePng()`, then
`shareMonthlyRecap(...)`. This "render invisibly, capture, then discard"
pattern is the standard way to use `RenderRepaintBoundary` for a widget
that isn't part of the normal visible layout — flagged here explicitly
since it's the one non-obvious part of an otherwise-boring pipeline.

If `reports` is empty (no module has data for the anchored month —
`AggregateReportUseCase` already produces this), the button is disabled
rather than generating a blank card — reuses the same `hasData` judgment
the use case already makes, no new empty-state logic to write.

### l10n keys (both `app_en.arb`/`app_bn.arb`)

- `reportsShareMonthButton` — "Share my month" (AppBar action tooltip/label)
- `reportsShareMonthFailed` — "Couldn't create your recap card" (shown via
  the existing plain-`ScaffoldMessenger` snackbar convention, same as
  `dataExportFailed` at `data_settings_screen.dart:56`, if capture/share
  throws)
- `recapCardMonthLabel` — "{month} recap" (placeholder `month`, `String` —
  e.g. "July recap"), the card's own header text
- `recapCardLongestStreak` — "{days}-day streak" (placeholder `days`,
  `int`) — reuses the same wording pattern as the existing
  `reportsLongestStreak` key but shortened for the card's tighter layout

## Out of scope

- **Historical recap browsing (past months beyond the current Reports
  anchor).** v1 only ever recaps whatever month `ReportsScreen`'s own
  `_anchor` is currently showing when the user taps Share — no separate
  "pick a past month to recap" UI. Matches the original draft's non-goal.
- **Per-module custom card layouts.** One shared template pulling
  whichever modules have data — no Water-specific vs. Prayer-specific
  card variant.
- **Weekly/yearly recap variants.** Button is disabled outside
  `ReportPeriod.month`; extending to year (naturally pairing with a future
  seasonal-theme item per the original draft) is a follow-up, not this
  spec.
- **A display name or any other PII on the card.** The app has no user-
  name concept anywhere today (`app_settings` has no name/profile field) —
  the card stays anonymous by construction, not by an explicit privacy
  decision requiring new UI.
- **Direct gallery-save without the share sheet.** Both platforms' share
  sheets already expose "Save Image"/"Save to Photos" — a second, separate
  save-to-gallery code path (and the platform permissions that would need)
  is redundant given `SharePlus`'s existing coverage, same reasoning
  `LocalFileBackupTarget`'s own doc comment already gives for reusing one
  path for both "share" and "save."
- **Explicit temp-file cleanup/rotation.** Follows the app's one existing
  precedent (`data_settings_screen.dart`'s export file) of leaving it to
  the OS-managed temp directory; a recap PNG is small (a few hundred KB)
  and infrequent (once a month at most), so this isn't a storage-growth
  risk worth a new cleanup routine.

## Global Constraints

- New files: `lib/features/reports/presentation/widgets/monthly_recap_card
  .dart`, `recap_card_capture.dart`, `lib/features/reports/presentation/
  recap_share_usecase.dart`.
- **No new dependency.** Image capture uses Flutter SDK
  (`RenderRepaintBoundary`/`dart:ui`'s `Image`/`ImageByteFormat`); sharing
  reuses the already-present `share_plus: ^13.2.1`; temp-file writing
  reuses the already-present `path_provider`.
- No change to `AggregateReportUseCase`, `day_status_streaks.dart`, or any
  Reports data logic — this is a rendering/export layer only, consuming
  `AggregateReportUseCase.execute(...)`'s existing return shape as-is.
- Render entirely on-device; the use case must never perform a network
  call — consistent with the app's offline-first/no-cloud-upload
  positioning the original draft grounds this feature in.
- Capture resolution: `pixelRatio: 3` fixed, not user-configurable in v1.
