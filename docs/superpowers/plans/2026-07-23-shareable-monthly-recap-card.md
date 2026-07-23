# Shareable Monthly Recap Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user render the current month's cross-module Reports data
as a shareable PNG card and hand it to the OS share sheet, per
`docs/superpowers/specs/02-delightful/05-shareable-monthly-recap-card-design.md`.

**Architecture:** `AggregateReportUseCase.execute(period:
ReportPeriod.month, ...)` (unchanged) already produces the
`List<ModuleReport>` the card needs. A new `MonthlyRecapCard` widget
renders that data as a fixed 1080×1920 portrait layout; a separate
`RecapCardCapture` wraps it in a `RepaintBoundary` and exposes
`capturePng()` (`RenderRepaintBoundary.toImage()` — Flutter SDK, no new
dependency); `recap_share_usecase.dart`'s `shareMonthlyRecap` writes the
PNG to the OS temp directory and hands it to the already-used
`share_plus` API. `ReportsScreen` gains a "Share my month" `AppBar`
action, enabled only in `ReportPeriod.month` with non-empty data, that
renders the card off-screen, captures it, and shares it.

**Tech Stack:** Flutter SDK (`RenderRepaintBoundary`/`dart:ui`), existing
`share_plus: ^13.2.1` and `path_provider: ^2.1.6` — no new dependency.
`gen_l10n`, `flutter_test`.

## Global Constraints

- New files only: `lib/features/reports/presentation/widgets/
  monthly_recap_card.dart`, `recap_card_capture.dart`,
  `lib/features/reports/presentation/recap_share_usecase.dart`.
- **No new dependency.** Image capture uses Flutter SDK
  (`RenderRepaintBoundary`/`dart:ui`'s `Image`/`ImageByteFormat`);
  sharing reuses `share_plus`; temp-file writing reuses `path_provider`.
- No change to `AggregateReportUseCase`, `day_status_streaks.dart`, or
  any Reports data logic — this is a rendering/export layer only,
  consuming `AggregateReportUseCase.execute(...)`'s existing
  `ModuleReport` shape (`moduleId`, `displayName`, `accentColor`,
  `points`, `longestStreak`) as-is.
- **Deliberate simplification beyond the source spec's literal
  wording:** the spec's "Rendering pipeline" section describes "water's
  `value` totals as a percent-of-goal-equivalent bucket count, prayer/
  medicine as `longestStreak` days" as the per-module headline number.
  `ModuleReport` has no goal/percent field today (only `points` and
  `longestStreak`), and the Global Constraints forbid touching
  `AggregateReportUseCase` to add one. `ReportsScreen` itself
  (`reports_screen.dart:101-105`) already shows `longestStreak`
  uniformly for every module with no Water special-case — this plan's
  card follows that same existing precedent rather than inventing a new
  per-module metric that would need new data.
- Render entirely on-device; no network call anywhere in this feature.
- Capture resolution: `pixelRatio: 3` fixed, not user-configurable.
- No explicit temp-file cleanup/rotation — same precedent as
  `data_settings_screen.dart`'s own export file (leaves it to the
  OS-managed temp directory).
- **Honesty about what is/isn't unit-testable:** `RecapCardCapture
  .capturePng()`'s use of `RenderRepaintBoundary.toImage()` genuinely
  works under `flutter test` (the same mechanism `matchesGoldenFile`
  itself relies on) and gets a real, non-faked widget test (Task 2). The
  full render-off-screen → capture → write-to-disk → hand-to-share-sheet
  pipeline (`recap_share_usecase.dart` wired from `ReportsScreen`) is
  tested at the seam level with injected test doubles for
  `path_provider`/`share_plus` (Task 3, mirroring `PinSettingsScreen`'s
  existing `biometricAvailable` test-seam precedent) — the actual OS
  share sheet appearing is a real device/simulator concern, out of scope
  for an automated test, and Task 4 says so explicitly rather than
  faking it.
- Every new l10n key goes in **both** `lib/core/l10n/app_en.arb` and
  `lib/core/l10n/app_bn.arb`; run `flutter gen-l10n` after each ARB edit
  and before running any test that references the changed getter.
- Per this repo's CLAUDE.md spec-implementation workflow: one commit per
  task, run only that task's own test file (never the full `flutter
  test` suite mid-task), pipe `build_runner`/`gen-l10n`/`test` output
  through `| tail -10`.

---

### Task 1: The visual recap card widget

**Files:**
- Create: `lib/features/reports/presentation/widgets/monthly_recap_card.dart`
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Test: `test/features/reports/presentation/widgets/monthly_recap_card_test.dart`

**Interfaces:**
- Consumes: `ModuleReport` (`core/reports/aggregate_report_usecase.dart`,
  pre-existing).
- Produces: `class MonthlyRecapCard extends StatelessWidget
  ({required List<ModuleReport> reports, required LocalDate
  monthAnchor})` — consumed by Task 2's capture wrapper and Task 4's
  `ReportsScreen` wiring.

- [ ] **Step 1: Add l10n keys to both arb files**

In `lib/core/l10n/app_en.arb`, insert after the `"reportsLongestStreak"`
block (immediately before `"achievementsTitle"`) — find this exact
anchor text:

```json
  "reportsLongestStreak": "Longest streak: {days} days",
  "@reportsLongestStreak": {
    "description": "A module's longest-streak record on the reports screen.",
    "placeholders": {"days": {"type": "int"}}
  },
  "achievementsTitle": "Achievements",
```

Replace it with:

```json
  "reportsLongestStreak": "Longest streak: {days} days",
  "@reportsLongestStreak": {
    "description": "A module's longest-streak record on the reports screen.",
    "placeholders": {"days": {"type": "int"}}
  },
  "recapCardMonthLabel": "{month} recap",
  "@recapCardMonthLabel": {
    "description": "The shareable monthly recap card's own header text, e.g. \"July recap\".",
    "placeholders": {"month": {"type": "String"}}
  },
  "recapCardLongestStreak": "{days}-day streak",
  "@recapCardLongestStreak": {
    "description": "A module's headline number on the recap card — a shortened form of reportsLongestStreak for the card's tighter layout.",
    "placeholders": {"days": {"type": "int"}}
  },
  "achievementsTitle": "Achievements",
```

In `lib/core/l10n/app_bn.arb`, insert after the `"reportsLongestStreak"`
line (immediately before `"achievementsTitle"`) — find this exact anchor
text:

```json
  "reportsLongestStreak": "দীর্ঘতম স্ট্রিক: {days} দিন",
  "achievementsTitle": "অর্জন",
```

Replace it with:

```json
  "reportsLongestStreak": "দীর্ঘতম স্ট্রিক: {days} দিন",
  "recapCardMonthLabel": "{month} রিক্যাপ",
  "recapCardLongestStreak": "{days} দিনের স্ট্রিক",
  "achievementsTitle": "অর্জন",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors.

- [ ] **Step 3: Write the failing widget test**

Create `test/features/reports/presentation/widgets/monthly_recap_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/reports/presentation/widgets/monthly_recap_card.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required List<ModuleReport> reports,
    required LocalDate monthAnchor,
  }) async {
    // The card is a fixed 1080x1920 portrait layout — resize the test
    // surface so it lays out without overflowing the default ~800x600
    // test viewport.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MonthlyRecapCard(reports: reports, monthAnchor: monthAnchor),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders one row per module with its display name and longest-streak '
    'headline',
    (tester) async {
      const reports = [
        (
          moduleId: 'water',
          displayName: 'Water',
          accentColor: Color(0xFF1565C0),
          points: <BarChartPoint>[],
          longestStreak: 12,
        ),
        (
          moduleId: 'prayer',
          displayName: 'Prayer',
          accentColor: Color(0xFFB8860B),
          points: <BarChartPoint>[],
          longestStreak: 30,
        ),
      ];

      await pumpCard(
        tester,
        reports: reports,
        monthAnchor: const LocalDate(2026, 7, 1),
      );

      expect(find.text('July recap'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Prayer'), findsOneWidget);
      expect(find.text('12-day streak'), findsOneWidget);
      expect(find.text('30-day streak'), findsOneWidget);
    },
  );

  testWidgets('renders the header even with an empty module list', (
    tester,
  ) async {
    await pumpCard(
      tester,
      reports: const [],
      monthAnchor: const LocalDate(2026, 3, 1),
    );

    expect(find.text('March recap'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/reports/presentation/widgets/monthly_recap_card_test.dart | tail -10`
Expected: FAIL to compile — `monthly_recap_card.dart` doesn't exist yet.

- [ ] **Step 5: Write the implementation**

Create `lib/features/reports/presentation/widgets/monthly_recap_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:intl/intl.dart';

/// The visual recap card itself — a fixed 1080x1920 portrait share
/// image, laid out from a month's already-computed `List<ModuleReport>`
/// (`docs/superpowers/specs/02-delightful/
/// 05-shareable-monthly-recap-card-design.md`). A plain, previewable
/// `Widget` — capture plumbing lives separately in
/// `recap_card_capture.dart`.
class MonthlyRecapCard extends StatelessWidget {
  /// Creates the recap card for [reports] (already filtered to modules
  /// with data by `AggregateReportUseCase`), anchored at [monthAnchor].
  const MonthlyRecapCard({
    required this.reports,
    required this.monthAnchor,
    super.key,
  });

  /// One entry per module with data this month.
  final List<ModuleReport> reports;

  /// Any day within the recapped month.
  final LocalDate monthAnchor;

  static const _width = 1080.0;
  static const _height = 1920.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Falls back to the ambient theme's primary color when there's
    // nothing to seed the gradient from — an empty `reports` list never
    // actually reaches this widget in practice (`ReportsScreen` disables
    // the share button first), but the widget itself stays correct
    // standalone regardless.
    final seedColor = reports.isEmpty
        ? Theme.of(context).colorScheme.primary
        : reports.first.accentColor;
    final monthName = DateFormat.MMMM().format(
      DateTime(monthAnchor.year, monthAnchor.month),
    );

    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            seedColor.withValues(alpha: 0.85),
            seedColor.withValues(alpha: 0.35),
          ],
        ),
      ),
      padding: const EdgeInsets.all(64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.self_improvement,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  l10n.recapCardMonthLabel(monthName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 64),
          for (final report in reports)
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: report.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                          ),
                        ),
                        Text(
                          l10n.recapCardLongestStreak(report.longestStreak),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/reports/presentation/widgets/monthly_recap_card_test.dart | tail -10`
Expected: PASS (2 tests).

- [ ] **Step 7: Analyze and format**

Run: `flutter analyze lib/features/reports/presentation/widgets/monthly_recap_card.dart | tail -10`
Run: `dart format lib/features/reports/presentation/widgets/monthly_recap_card.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/reports/presentation/widgets/monthly_recap_card.dart \
  lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  test/features/reports/presentation/widgets/monthly_recap_card_test.dart
git commit -m "feat(reports): add the monthly recap card widget"
```

---

### Task 2: Capture plumbing (`RecapCardCapture`)

**Files:**
- Create: `lib/features/reports/presentation/widgets/recap_card_capture.dart`
- Test: `test/features/reports/presentation/widgets/recap_card_capture_test.dart`

**Interfaces:**
- Produces: `class RecapCardCapture extends StatelessWidget ({required
  Widget child})` with `static Future<Uint8List> capturePng({double
  pixelRatio = 3})` — consumed by Task 3's `shareMonthlyRecap` and
  Task 4's `ReportsScreen` wiring.

- [ ] **Step 1: Write the failing test**

Create `test/features/reports/presentation/widgets/recap_card_capture_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/reports/presentation/widgets/recap_card_capture.dart';

void main() {
  testWidgets(
    'capturePng renders the wrapped widget to real PNG bytes — this is a '
    'genuine RenderRepaintBoundary.toImage() call, the same mechanism '
    'matchesGoldenFile itself relies on, not a stub',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecapCardCapture(
            child: SizedBox(
              width: 100,
              height: 100,
              child: ColoredBox(color: Colors.red),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bytes = await RecapCardCapture.capturePng(pixelRatio: 1);

      expect(bytes, isNotEmpty);
      // The 8-byte PNG file signature — proves this is real,
      // correctly-encoded image data without depending on decoding the
      // pixels themselves.
      expect(bytes.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reports/presentation/widgets/recap_card_capture_test.dart | tail -10`
Expected: FAIL to compile — `recap_card_capture.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reports/presentation/widgets/recap_card_capture.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Wraps [child] in a `RepaintBoundary` keyed by [_boundaryKey] and
/// exposes [capturePng] to rasterize it. `pixelRatio: 3` for
/// share-quality output regardless of the rendering device's actual
/// density (`docs/superpowers/specs/02-delightful/
/// 05-shareable-monthly-recap-card-design.md`). No existing capability
/// in this app does this job — `grep -rn "RenderRepaintBoundary\|
/// toImage(" lib/` returns nothing prior to this widget.
class RecapCardCapture extends StatelessWidget {
  /// Wraps [child] for capture — typically a `MonthlyRecapCard`.
  const RecapCardCapture({required this.child, super.key});

  /// The widget to capture.
  final Widget child;

  static final _boundaryKey = GlobalKey();

  /// Renders the wrapped widget to PNG bytes. Must be called after the
  /// first frame the boundary is part of (post-`WidgetsBinding.instance
  /// .addPostFrameCallback`, or from a button's `onPressed`, which
  /// always runs after layout).
  static Future<Uint8List> capturePng({double pixelRatio = 3}) async {
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: _boundaryKey, child: child);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reports/presentation/widgets/recap_card_capture_test.dart | tail -10`
Expected: PASS (1 test).

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/features/reports/presentation/widgets/recap_card_capture.dart | tail -10`
Run: `dart format lib/features/reports/presentation/widgets/recap_card_capture.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/reports/presentation/widgets/recap_card_capture.dart \
  test/features/reports/presentation/widgets/recap_card_capture_test.dart
git commit -m "feat(reports): add RecapCardCapture (RenderRepaintBoundary PNG export)"
```

---

### Task 3: Share/save use case (`shareMonthlyRecap`)

**Files:**
- Create: `lib/features/reports/presentation/recap_share_usecase.dart`
- Test: `test/features/reports/presentation/recap_share_usecase_test.dart`

**Interfaces:**
- Consumes: `RecapCardCapture.capturePng` (Task 2), `ModuleReport`
  (pre-existing).
- Produces: `Future<void> shareMonthlyRecap({required List<ModuleReport>
  reports, required LocalDate monthAnchor, Future<Uint8List>
  Function({double pixelRatio}) capturePng, Future<Directory>
  Function() getTemporaryDirectory, Future<void> Function(ShareParams)
  share})` — consumed by Task 4's `ReportsScreen` wiring.

- [ ] **Step 1: Write the failing test**

Create `test/features/reports/presentation/recap_share_usecase_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/reports/presentation/recap_share_usecase.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

void main() {
  test(
    'writes the captured PNG bytes to a temp file named after the month '
    'and hands it to the share sheet',
    () async {
      Directory? tempDir;
      ShareParams? capturedParams;

      await shareMonthlyRecap(
        reports: const <ModuleReport>[],
        monthAnchor: const LocalDate(2026, 7, 15),
        capturePng: ({pixelRatio = 3}) async => Uint8List.fromList([1, 2, 3]),
        getTemporaryDirectory: () async {
          tempDir = await Directory.systemTemp.createTemp(
            'recap_share_test_',
          );
          return tempDir!;
        },
        share: (params) async => capturedParams = params,
      );

      expect(capturedParams, isNotNull);
      final file = File(capturedParams!.files!.single.path);
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), [1, 2, 3]);
      expect(p.basename(file.path), 'habit_tracker_recap_2026_07.png');

      await tempDir?.delete(recursive: true);
    },
  );

  test('the default capturePng/getTemporaryDirectory/share arguments '
      'exist and type-check against the real APIs', () {
    // Compile-time check only — asserting `shareMonthlyRecap` is
    // callable with zero optional arguments, i.e. its defaults
    // (`RecapCardCapture.capturePng`, `path_provider`'s
    // `getTemporaryDirectory`, `SharePlus.instance.share`) all
    // type-check against the seam signatures. This intentionally never
    // calls the tear-off (that would hit the real platform channels) —
    // it exists purely so a future signature drift on either side fails
    // to compile here rather than only at real app runtime.
    expect(shareMonthlyRecap, isA<Function>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reports/presentation/recap_share_usecase_test.dart | tail -10`
Expected: FAIL to compile — `recap_share_usecase.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/features/reports/presentation/recap_share_usecase.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/reports/presentation/widgets/recap_card_capture.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:share_plus/share_plus.dart';

/// Renders the current month's recap (already painted, off-screen, onto
/// a `RecapCardCapture`'s `RepaintBoundary` by the caller — see
/// `ReportsScreen`'s share button) and hands it to the OS share sheet,
/// which already includes "Save to Photos"/"Save to Files" on both
/// platforms — same precedent `LocalFileBackupTarget.upload` already
/// relies on, so no separate gallery-save code path is needed
/// (`docs/superpowers/specs/02-delightful/
/// 05-shareable-monthly-recap-card-design.md`).
///
/// [capturePng]/[getTemporaryDirectory]/[share] are test-only seams —
/// the real platform channels behind `path_provider`/`share_plus` aren't
/// exercised under `flutter test`, same precedent as `PinSettingsScreen`
/// 's `biometricAvailable` seam
/// (`docs/superpowers/plans/2026-07-21-pin-lock-toggles-fix.md`).
Future<void> shareMonthlyRecap({
  // Never read in this function's own body — kept required so a caller
  // can't call this without having already rendered the off-screen
  // `MonthlyRecapCard(reports: reports, ...)` this function assumes
  // exists; self-documents the precondition rather than silently
  // trusting it.
  required List<ModuleReport> reports,
  required LocalDate monthAnchor,
  Future<Uint8List> Function({double pixelRatio}) capturePng =
      RecapCardCapture.capturePng,
  Future<Directory> Function() getTemporaryDirectory =
      path_provider.getTemporaryDirectory,
  Future<void> Function(ShareParams params) share = _defaultShare,
}) async {
  final pngBytes = await capturePng(pixelRatio: 3);
  final dir = await getTemporaryDirectory();
  final fileName =
      'habit_tracker_recap_${monthAnchor.year}_'
      '${monthAnchor.month.toString().padLeft(2, '0')}.png';
  final file = File(p.join(dir.path, fileName));
  await file.writeAsBytes(pngBytes);
  // No explicit delete — same precedent as `data_settings_screen.dart`'s
  // export file: the OS-managed temp directory is left to reclaim it.
  await share(ShareParams(files: [XFile(file.path)]));
}

Future<void> _defaultShare(ShareParams params) async {
  await SharePlus.instance.share(params);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reports/presentation/recap_share_usecase_test.dart | tail -10`
Expected: PASS (2 tests).

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/features/reports/presentation/recap_share_usecase.dart | tail -10`
Run: `dart format lib/features/reports/presentation/recap_share_usecase.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/reports/presentation/recap_share_usecase.dart \
  test/features/reports/presentation/recap_share_usecase_test.dart
git commit -m "feat(reports): add shareMonthlyRecap (writes the PNG, hands it to share_plus)"
```

---

### Task 4: Wire the "Share my month" button into `ReportsScreen`

**Files:**
- Modify: `lib/features/reports/presentation/screens/reports_screen.dart`
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Test: `test/features/reports/presentation/reports_screen_test.dart`

**Interfaces:**
- Consumes: `MonthlyRecapCard`/`RecapCardCapture` (Tasks 1-2),
  `shareMonthlyRecap` (Task 3).

- [ ] **Step 1: Add l10n keys to both arb files**

In `lib/core/l10n/app_en.arb`, insert after the `"reportsEmptyState"`
block (immediately before `"reportsLongestStreak"`) — find this exact
anchor text:

```json
  "reportsEmptyState": "No data for this period",
  "@reportsEmptyState": {"description": "Shown when no module has data for the selected report period."},
  "reportsLongestStreak": "Longest streak: {days} days",
```

Replace it with:

```json
  "reportsEmptyState": "No data for this period",
  "@reportsEmptyState": {"description": "Shown when no module has data for the selected report period."},
  "reportsShareMonthButton": "Share my month",
  "@reportsShareMonthButton": {
    "description": "AppBar action tooltip: share the current month as a recap card. Only enabled while viewing the month period with data."
  },
  "reportsShareMonthFailed": "Couldn't create your recap card",
  "@reportsShareMonthFailed": {
    "description": "Snackbar shown if rendering/sharing the recap card throws."
  },
  "reportsLongestStreak": "Longest streak: {days} days",
```

In `lib/core/l10n/app_bn.arb`, insert after the `"reportsEmptyState"`
line (immediately before `"reportsLongestStreak"`) — find this exact
anchor text:

```json
  "reportsEmptyState": "এই সময়ের জন্য কোনো তথ্য নেই",
  "reportsLongestStreak": "দীর্ঘতম স্ট্রিক: {days} দিন",
```

Replace it with:

```json
  "reportsEmptyState": "এই সময়ের জন্য কোনো তথ্য নেই",
  "reportsShareMonthButton": "আমার মাস শেয়ার করুন",
  "reportsShareMonthFailed": "আপনার রিক্যাপ কার্ড তৈরি করা যায়নি",
  "reportsLongestStreak": "দীর্ঘতম স্ট্রিক: {days} দিন",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors.

- [ ] **Step 3: Write the failing test**

Add to `test/features/reports/presentation/reports_screen_test.dart`, a
new `Fake` module with data (right after `_EmptyModule`) and a new test:

```dart
class _DataModule extends Fake implements HabitModule {
  @override
  String get id => 'water';
  @override
  ModuleMetadata get metadata => const ModuleMetadata(
    displayName: 'Water',
    icon: Icons.water_drop,
    accentColor: Colors.blue,
  );
  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async {
    final result = <LocalDate, ModuleDayStatus>{};
    var day = range.start;
    while (day.compareTo(range.end) <= 0) {
      result[day] = const ModuleDayStatus(
        kind: ModuleDayStatusKind.complete,
        value: 1,
      );
      day = day.addDays(1);
    }
    return result;
  }
}
```

And inside `main()`, after the existing test:

```dart
  testWidgets(
    'the share-month button is disabled for week/year, and enabled once '
    "switched to month with a module that has this period's data",
    (tester) async {
      await withClock(Clock.fixed(DateTime.utc(2026, 7, 15)), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitModulesProvider.overrideWith((ref) => [_DataModule()]),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ReportsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Default period is week -> disabled.
        expect(
          tester
              .widget<IconButton>(find.byTooltip('Share my month'))
              .onPressed,
          isNull,
        );

        await tester.tap(find.text('Month'));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<IconButton>(find.byTooltip('Share my month'))
              .onPressed,
          isNotNull,
        );
      });
    },
  );
```

Add the missing import at the top of the file:

```dart
import 'package:habit_tracker/core/modules/module_registry.dart';
```

(`habit_module.dart`, `date_range.dart`, `local_date.dart` are already
imported by this file for `_EmptyModule`.)

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/reports/presentation/reports_screen_test.dart | tail -10`
Expected: FAIL — no widget with tooltip `'Share my month'` exists yet.

- [ ] **Step 5: Wire the button into `ReportsScreen`**

In `lib/features/reports/presentation/screens/reports_screen.dart`, add
the new imports:

```dart
import 'dart:async';

import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/reports/presentation/recap_share_usecase.dart';
import 'package:habit_tracker/features/reports/presentation/widgets/monthly_recap_card.dart';
import 'package:habit_tracker/features/reports/presentation/widgets/recap_card_capture.dart';
```

(`app_localizations.dart` is already imported; only `dart:async` and the
three new recap files are genuinely new.)

Add a new method to `_ReportsScreenState`, right after `_shiftPeriod`:

```dart
  Future<void> _shareMonth(List<ModuleReport> reports) async {
    final overlayState = Overlay.of(context);
    final completer = Completer<void>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      // Renders off-screen (far outside the visible viewport) so it
      // lays out and paints without ever being shown to the user — the
      // standard way to use `RenderRepaintBoundary` for a widget that
      // isn't part of the normal visible layout (design doc, "Entry
      // point").
      builder: (context) => Positioned(
        left: -9999,
        top: 0,
        child: Material(
          child: RecapCardCapture(
            child: MonthlyRecapCard(reports: reports, monthAnchor: _anchor),
          ),
        ),
      ),
    );
    overlayState.insert(entry);
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    await completer.future;
    try {
      await shareMonthlyRecap(reports: reports, monthAnchor: _anchor);
    } on Object {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reportsShareMonthFailed)),
        );
      }
    } finally {
      entry.remove();
    }
  }
```

Change the `AppBar.actions` list from:

```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftPeriod(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shiftPeriod(1),
          ),
        ],
```

to:

```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: l10n.reportsShareMonthButton,
            onPressed:
                _period == ReportPeriod.month &&
                    (reportsAsync.value?.isNotEmpty ?? false)
                ? () => unawaited(_shareMonth(reportsAsync.value!))
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftPeriod(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shiftPeriod(1),
          ),
        ],
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/reports/presentation/reports_screen_test.dart | tail -10`
Expected: PASS (2 tests).

- [ ] **Step 7: Analyze and format**

Run: `flutter analyze lib/features/reports/presentation/screens/reports_screen.dart | tail -10`
Run: `dart format lib/features/reports/presentation/screens/reports_screen.dart`
Expected: `No issues found!`

- [ ] **Step 8: Full sweep**

Run: `flutter analyze | tail -10`
Expected: `No issues found!`

Run: `dart format --output=none --set-exit-if-changed . | tail -10`
Expected: exits 0.

- [ ] **Step 9: Manual verification (not automatable)**

Run the app on a simulator/device (`flutter run`), open Reports, switch
to Month, tap "Share my month," and confirm the OS share sheet appears
with a real recap PNG attached, and that "Save Image" from the share
sheet produces a legible card. This is the one part of this feature that
is genuinely a real-device/platform-channel concern — Task 2 already
covers the actual pixel-capture mechanism with a real automated test,
and Task 3 covers `shareMonthlyRecap`'s own file-write/share-call glue
at the seam level; nothing further here is faked, this step is simply
where automated coverage runs out.

- [ ] **Step 10: Commit**

```bash
git add lib/features/reports/presentation/screens/reports_screen.dart \
  lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  test/features/reports/presentation/reports_screen_test.dart
git commit -m "feat(reports): wire the Share my month button into ReportsScreen"
```

---

## After all tasks

Per this repo's CLAUDE.md spec-implementation workflow: once every task
above is committed, open a PR for the spec with the design summary in the
description (including a note that Task 4's Step 9 manual check must be
run once before merge, since it's the one part of this feature no
automated test covers), then run a code review against the finished PR
(comment → fix → commit cycle, up to 5 rounds), then stop and wait for
the user's own review and merge.
