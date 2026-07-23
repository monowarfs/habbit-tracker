# Adaptive Empty-State Illustrations Per Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace each module's bare `Center(child: Text(...))` first-run
empty state with a small `CustomPainter`-drawn illustration in that
module's own accent color, per `docs/superpowers/specs/02-delightful/
09-adaptive-empty-state-illustrations-design.md`.

**Architecture:** Three new `CustomPainter` classes (one glyph each:
water drop, pill+calendar, crescent+mat), each taking a single `Color`
constructor argument and painting with plain `Canvas` primitives — no
new dependency, no bundled asset. One shared `ModuleEmptyState` widget
(icon-sized illustration + message, centered) wraps whichever painter a
call site passes in. Three call-site swaps (Water's inline "no entries
today," Medicine's "no medicines yet," Prayer's "no prayers today") each
replace a `Text`-only branch with `ModuleEmptyState`, reusing the
existing l10n string and each module's existing `ModuleAccents` color.

**Tech Stack:** Flutter/Dart (`dart:ui` `Canvas`/`Path`/`RRect`
primitives only), `flutter_test`.

## Global Constraints

- No new dependency — `flutter_svg` stays absent from `pubspec.yaml`.
- No new assets, no `pubspec.yaml` `assets:` entry — every illustration
  is drawn code.
- No l10n changes — all three call sites reuse their existing arb keys
  (`waterHomeEmptyLogs`, `medicineListEmpty`/`medicineListArchivedEmpty`,
  `prayerHomeEmpty`) verbatim.
- No schema/migration/settings changes — presentation layer only.
- `medicineHomeEmpty` ("no doses scheduled for today," Medicine's
  *returning-user* empty state) stays plain `Text` — out of scope, per
  the source spec's own distinction between first-run and
  nothing-due-today.
- New files: `lib/core/widgets/module_empty_state.dart`,
  `lib/core/widgets/illustrations/water_drop_painter.dart`,
  `lib/core/widgets/illustrations/pill_calendar_painter.dart`,
  `lib/core/widgets/illustrations/crescent_mat_painter.dart`.
- Each painter's public API is `const XxxPainter(Color color)` with a
  public `color` getter (not just a private field) — later tasks' widget
  tests read `painter.color` directly off the `CustomPaint.painter`
  instance to confirm the right module accent reached the canvas.

---

### Task 1: The three illustration painters

**Files:**
- Create: `lib/core/widgets/illustrations/water_drop_painter.dart`
- Create: `lib/core/widgets/illustrations/pill_calendar_painter.dart`
- Create: `lib/core/widgets/illustrations/crescent_mat_painter.dart`
- Test: `test/core/widgets/illustrations/illustration_painters_test.dart`

**Interfaces:**
- Produces: `class WaterDropPainter extends CustomPainter { const
  WaterDropPainter(this.color); final Color color; }` (and identically
  shaped `PillCalendarPainter`/`CrescentMatPainter`) — consumed by Task
  2's `ModuleEmptyState` and Tasks 3-5's call sites.

- [ ] **Step 1: Write the failing test**

`test/core/widgets/illustrations/` doesn't exist yet — create the
directory, then create the test file:

```bash
mkdir -p test/core/widgets/illustrations
```

Create `test/core/widgets/illustrations/illustration_painters_test.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/widgets/illustrations/crescent_mat_painter.dart';
import 'package:habit_tracker/core/widgets/illustrations/pill_calendar_painter.dart';
import 'package:habit_tracker/core/widgets/illustrations/water_drop_painter.dart';

/// Paints [painter] onto a real (disposed-immediately) `dart:ui` canvas —
/// the cheapest way to assert "this paint() call doesn't throw" without a
/// full widget pump, since `flutter_test`'s tester embedder provides a
/// real `dart:ui` regardless of `test()` vs `testWidgets()`.
void _paintOnRealCanvas(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  recorder.endRecording().dispose();
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('WaterDropPainter', () {
    test('paints without throwing at the empty-state illustration size', () {
      expect(
        () => _paintOnRealCanvas(
          const WaterDropPainter(Colors.blue),
          const Size(96, 96),
        ),
        returnsNormally,
      );
    });

    test('stores the color it was constructed with', () {
      const painter = WaterDropPainter(Colors.blue);
      expect(painter.color, Colors.blue);
    });

    test('shouldRepaint is true only when the color actually changes', () {
      const a = WaterDropPainter(Colors.blue);
      const b = WaterDropPainter(Colors.blue);
      const c = WaterDropPainter(Colors.red);
      expect(a.shouldRepaint(b), isFalse);
      expect(a.shouldRepaint(c), isTrue);
    });
  });

  group('PillCalendarPainter', () {
    test('paints without throwing at the empty-state illustration size', () {
      expect(
        () => _paintOnRealCanvas(
          const PillCalendarPainter(Colors.deepPurple),
          const Size(96, 96),
        ),
        returnsNormally,
      );
    });

    test('stores the color it was constructed with', () {
      const painter = PillCalendarPainter(Colors.deepPurple);
      expect(painter.color, Colors.deepPurple);
    });

    test('shouldRepaint is true only when the color actually changes', () {
      const a = PillCalendarPainter(Colors.deepPurple);
      const b = PillCalendarPainter(Colors.deepPurple);
      const c = PillCalendarPainter(Colors.teal);
      expect(a.shouldRepaint(b), isFalse);
      expect(a.shouldRepaint(c), isTrue);
    });
  });

  group('CrescentMatPainter', () {
    test('paints without throwing at the empty-state illustration size', () {
      expect(
        () => _paintOnRealCanvas(
          const CrescentMatPainter(Colors.amber),
          const Size(96, 96),
        ),
        returnsNormally,
      );
    });

    test('stores the color it was constructed with', () {
      const painter = CrescentMatPainter(Colors.amber);
      expect(painter.color, Colors.amber);
    });

    test('shouldRepaint is true only when the color actually changes', () {
      const a = CrescentMatPainter(Colors.amber);
      const b = CrescentMatPainter(Colors.amber);
      const c = CrescentMatPainter(Colors.blue);
      expect(a.shouldRepaint(b), isFalse);
      expect(a.shouldRepaint(c), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/illustrations/illustration_painters_test.dart | tail -10`
Expected: FAIL to compile — none of the three painter files exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/widgets/illustrations/water_drop_painter.dart`:

```dart
import 'package:flutter/material.dart';

/// A single water-drop glyph, painted in [color] — Water's empty-state
/// illustration (`docs/superpowers/specs/02-delightful/
/// 09-adaptive-empty-state-illustrations-design.md`).
class WaterDropPainter extends CustomPainter {
  /// Creates a water-drop painter using [color].
  const WaterDropPainter(this.color);

  /// The color the drop (and its highlight) is painted with — always one
  /// of `ModuleAccents`' fixed colors at call sites, never scheme-derived.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Teardrop: a pointed top narrowing into a rounded bulb, drawn as one
    // closed path (two cubic beziers for the sides, an arc for the
    // rounded bottom).
    final path = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..cubicTo(w * 0.82, h * 0.42, w * 0.82, h * 0.55, w * 0.82, h * 0.60)
      ..arcToPoint(
        Offset(w * 0.18, h * 0.60),
        radius: Radius.circular(w * 0.34),
        clockwise: true,
      )
      ..cubicTo(w * 0.18, h * 0.55, w * 0.18, h * 0.42, w * 0.5, h * 0.08)
      ..close();
    canvas.drawPath(path, fill);

    // Highlight: a small lighter circle near the top-left of the bulb —
    // reads on both light/dark backgrounds since it's relative to [color],
    // not the theme.
    final highlight = Paint()..color = color.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(w * 0.38, h * 0.5), w * 0.08, highlight);
  }

  @override
  bool shouldRepaint(covariant WaterDropPainter oldDelegate) =>
      oldDelegate.color != color;
}
```

Create `lib/core/widgets/illustrations/pill_calendar_painter.dart`:

```dart
import 'package:flutter/material.dart';

/// A rounded-rect calendar outline with a capsule overlapping its corner,
/// painted in [color] — Medicine's empty-state illustration
/// (`docs/superpowers/specs/02-delightful/
/// 09-adaptive-empty-state-illustrations-design.md`).
class PillCalendarPainter extends CustomPainter {
  /// Creates a pill-and-calendar painter using [color].
  const PillCalendarPainter(this.color);

  /// The color every shape is painted with.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05;
    final fill = Paint()..color = color;

    // Calendar body: a rounded rectangle outline.
    final calendarRect = Rect.fromLTWH(w * 0.1, h * 0.22, w * 0.8, h * 0.68);
    canvas.drawRRect(
      RRect.fromRectAndRadius(calendarRect, Radius.circular(w * 0.08)),
      stroke,
    );

    // Two "binding" tabs at the top.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.25, h * 0.1, w * 0.08, h * 0.18),
        Radius.circular(w * 0.04),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.67, h * 0.1, w * 0.08, h * 0.18),
        Radius.circular(w * 0.04),
      ),
      fill,
    );

    // Capsule glyph, rotated and overlapping the bottom-right corner.
    final capsule = Rect.fromCenter(
      center: Offset(w * 0.66, h * 0.66),
      width: w * 0.4,
      height: h * 0.2,
    );
    canvas
      ..save()
      ..translate(capsule.center.dx, capsule.center.dy)
      ..rotate(-0.5)
      ..translate(-capsule.center.dx, -capsule.center.dy)
      ..drawRRect(
        RRect.fromRectAndRadius(capsule, Radius.circular(h * 0.1)),
        fill,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(covariant PillCalendarPainter oldDelegate) =>
      oldDelegate.color != color;
}
```

Create `lib/core/widgets/illustrations/crescent_mat_painter.dart`:

```dart
import 'package:flutter/material.dart';

/// A crescent above a small prayer mat, painted in [color] — Prayer's
/// empty-state illustration (`docs/superpowers/specs/02-delightful/
/// 09-adaptive-empty-state-illustrations-design.md`).
class CrescentMatPainter extends CustomPainter {
  /// Creates a crescent-and-mat painter using [color].
  const CrescentMatPainter(this.color);

  /// The color every shape is painted with.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;

    // Crescent: a full circle minus an offset circle (even-odd path
    // difference) — a plain Canvas-primitive way to draw an arc-shaped
    // crescent without manual trigonometry.
    final outer = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(w * 0.5, h * 0.36), radius: w * 0.26),
      );
    final inner = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(w * 0.61, h * 0.3), radius: w * 0.22),
      );
    final crescent = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(crescent, fill);

    // Prayer mat: a small rounded rectangle beneath the crescent.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.2, h * 0.72, w * 0.6, h * 0.16),
        Radius.circular(w * 0.04),
      ),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant CrescentMatPainter oldDelegate) =>
      oldDelegate.color != color;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/illustrations/illustration_painters_test.dart | tail -10`
Expected: `+9: All tests passed!`

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/core/widgets/illustrations/ | tail -10`
Run: `dart format lib/core/widgets/illustrations/`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/illustrations/water_drop_painter.dart \
  lib/core/widgets/illustrations/pill_calendar_painter.dart \
  lib/core/widgets/illustrations/crescent_mat_painter.dart \
  test/core/widgets/illustrations/illustration_painters_test.dart
git commit -m "feat(widgets): add per-module empty-state illustration painters"
```

---

### Task 2: Shared `ModuleEmptyState` widget

**Files:**
- Create: `lib/core/widgets/module_empty_state.dart`
- Test: `test/core/widgets/module_empty_state_test.dart`

**Interfaces:**
- Consumes: `WaterDropPainter`/`PillCalendarPainter`/`CrescentMatPainter`
  from Task 1 (used only in this task's own test, as illustrative
  painters — the widget itself is painter-agnostic).
- Produces: `class ModuleEmptyState extends StatelessWidget {
  const ModuleEmptyState({required CustomPainter Function(Color) painter,
  required String message, required Color accentColor}); }` — consumed
  by Tasks 3-5's call sites.

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/module_empty_state_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/widgets/illustrations/water_drop_painter.dart';
import 'package:habit_tracker/core/widgets/module_empty_state.dart';

void main() {
  testWidgets(
    'renders the message below a CustomPaint built from the given painter '
    'and accent color',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModuleEmptyState(
              painter: WaterDropPainter.new,
              message: 'No entries yet today',
              accentColor: Colors.blue,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No entries yet today'), findsOneWidget);

      final customPaint = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .firstWhere((w) => w.painter is WaterDropPainter);
      final painter = customPaint.painter! as WaterDropPainter;
      expect(painter.color, Colors.blue);
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/module_empty_state_test.dart | tail -10`
Expected: FAIL to compile — `lib/core/widgets/module_empty_state.dart`
doesn't exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/widgets/module_empty_state.dart`:

```dart
import 'package:flutter/material.dart';

/// Shared empty-state widget for a module's primary screen — an
/// icon-sized vector illustration in [accentColor] above a message line.
/// Replaces the bare `Center(child: Text(...))` each module's first-run
/// empty state rendered before this
/// (`docs/superpowers/specs/02-delightful/
/// 09-adaptive-empty-state-illustrations-design.md`).
class ModuleEmptyState extends StatelessWidget {
  /// Creates a module empty state painting [painter] (applied to
  /// [accentColor]) above [message].
  const ModuleEmptyState({
    super.key,
    required this.painter,
    required this.message,
    required this.accentColor,
  });

  /// Module-specific illustration constructor, e.g.
  /// `WaterDropPainter.new`.
  final CustomPainter Function(Color color) painter;

  /// The existing l10n empty-state string for this module — reused
  /// verbatim, not a new key.
  final String message;

  /// The module's `ModuleAccents` color the illustration is painted with.
  final Color accentColor;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(painter: painter(accentColor)),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/module_empty_state_test.dart | tail -10`
Expected: `+1: All tests passed!`

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/core/widgets/module_empty_state.dart | tail -10`
Run: `dart format lib/core/widgets/module_empty_state.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/module_empty_state.dart \
  test/core/widgets/module_empty_state_test.dart
git commit -m "feat(widgets): add the shared ModuleEmptyState widget"
```

---

### Task 3: Wire Water's "no entries today" empty state

**Files:**
- Modify: `lib/features/water/presentation/screens/water_home_screen.dart:1-19,132-135`
- Test: `test/features/water/presentation/water_home_screen_test.dart`

**Interfaces:**
- Consumes: `ModuleEmptyState`, `WaterDropPainter` (Tasks 1-2),
  `ModuleAccents.water` (`lib/core/theme/app_theme.dart`, pre-existing).

- [ ] **Step 1: Write the failing test**

Add a new test to `test/features/water/presentation/
water_home_screen_test.dart`, right after the existing `'empty state: no
entries yet today'` test:

```dart
  testWidgets(
    "empty state's illustration is painted in Water's own accent color",
    (tester) async {
      final now = DateTime.utc(2026, 6, 1, 8);
      await _pumpWaterHome(tester, db, now: now);

      final customPaint = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .firstWhere((w) => w.painter is WaterDropPainter);
      final painter = customPaint.painter! as WaterDropPainter;
      expect(painter.color, ModuleAccents.water);

      await disposeTree(tester);
    },
  );
```

Add the two new imports at the top of the same file (alongside the
existing `habit_tracker/...` imports):

```dart
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/widgets/illustrations/water_drop_painter.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/water/presentation/water_home_screen_test.dart | tail -10`
Expected: FAIL — no `CustomPaint` with a `WaterDropPainter` exists on the
empty-state screen yet (`firstWhere` throws `StateError: No element`).

- [ ] **Step 3: Write minimal implementation**

In `lib/features/water/presentation/screens/water_home_screen.dart`, add
the two new imports (alphabetically ordered among the existing
`habit_tracker/...` imports):

```dart
import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/widgets/illustrations/water_drop_painter.dart';
import 'package:habit_tracker/core/widgets/module_empty_state.dart';
import 'package:habit_tracker/core/widgets/undo_snackbar.dart';
```

Change:

```dart
                if (_visibleEntries(progress.entries).isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(l10n.waterHomeEmptyLogs),
                  )
                else
```

to:

```dart
                if (_visibleEntries(progress.entries).isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: ModuleEmptyState(
                      painter: WaterDropPainter.new,
                      message: l10n.waterHomeEmptyLogs,
                      accentColor: ModuleAccents.water,
                    ),
                  )
                else
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/water/presentation/water_home_screen_test.dart | tail -10`
Expected: PASS, all tests in the file (including the pre-existing 3)
green.

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/features/water/presentation/screens/water_home_screen.dart | tail -10`
Run: `dart format lib/features/water/presentation/screens/water_home_screen.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/water/presentation/screens/water_home_screen.dart \
  test/features/water/presentation/water_home_screen_test.dart
git commit -m "feat(water): illustrate the no-entries-today empty state"
```

---

### Task 4: Wire Medicine's "no medicines yet" empty state

**Files:**
- Modify: `lib/features/medicine/presentation/screens/medicine_list_screen.dart`
- Test: `test/features/medicine/presentation/medicine_list_screen_test.dart` (new)

**Interfaces:**
- Consumes: `ModuleEmptyState`, `PillCalendarPainter` (Tasks 1-2),
  `ModuleAccents.medicine`.

- [ ] **Step 1: Write the failing test**

Create `test/features/medicine/presentation/medicine_list_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/widgets/illustrations/pill_calendar_painter.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_list_screen.dart';

Future<void> _pumpMedicineList(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MedicineListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('empty active tab: shows the message and its illustration '
      "in Medicine's own accent color", (tester) async {
    await _pumpMedicineList(tester, db);

    expect(find.text('No medicines yet'), findsOneWidget);
    final customPaint = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .firstWhere((w) => w.painter is PillCalendarPainter);
    final painter = customPaint.painter! as PillCalendarPainter;
    expect(painter.color, ModuleAccents.medicine);

    await disposeTree(tester);
  });

  testWidgets('populated active tab: the empty-state message no longer '
      'shows', (tester) async {
    final repo = MedicineRepositoryImpl(db);
    await repo.createMedicine(name: 'Amoxicillin', stockEnabled: false);

    await _pumpMedicineList(tester, db);

    // Only assert the text, not "no PillCalendarPainter anywhere" — the
    // Archived tab's own `_MedicineListView` may also be built by
    // `TabBarView` even off-screen, and it's still legitimately empty
    // (nothing was archived), so it would still paint its own
    // illustration. That's correct behavior, not something to assert
    // against here.
    expect(find.text('No medicines yet'), findsNothing);

    await disposeTree(tester);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medicine/presentation/medicine_list_screen_test.dart | tail -10`
Expected: FAIL — no `CustomPaint` with a `PillCalendarPainter` exists on
the screen yet (`firstWhere` throws `StateError: No element`).

- [ ] **Step 3: Write minimal implementation**

In `lib/features/medicine/presentation/screens/medicine_list_screen.dart`,
add the new imports (alongside the existing `habit_tracker/...` import):

```dart
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/widgets/illustrations/pill_calendar_painter.dart';
import 'package:habit_tracker/core/widgets/module_empty_state.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
```

Change:

```dart
    if (filtered.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Text(
          archivedOnly
              ? l10n.medicineListArchivedEmpty
              : l10n.medicineListEmpty,
        ),
      );
    }
```

to:

```dart
    if (filtered.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return ModuleEmptyState(
        painter: PillCalendarPainter.new,
        message: archivedOnly
            ? l10n.medicineListArchivedEmpty
            : l10n.medicineListEmpty,
        accentColor: ModuleAccents.medicine,
      );
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medicine/presentation/medicine_list_screen_test.dart | tail -10`
Expected: `+2: All tests passed!`

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/features/medicine/presentation/screens/medicine_list_screen.dart | tail -10`
Run: `dart format lib/features/medicine/presentation/screens/medicine_list_screen.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/medicine/presentation/screens/medicine_list_screen.dart \
  test/features/medicine/presentation/medicine_list_screen_test.dart
git commit -m "feat(medicine): illustrate the no-medicines-yet empty state"
```

---

### Task 5: Wire Prayer's "no prayers today" empty state

**Files:**
- Modify: `lib/features/prayer/presentation/screens/prayer_home_screen.dart`
- Test: `test/features/prayer/presentation/prayer_home_screen_test.dart`

**Interfaces:**
- Consumes: `ModuleEmptyState`, `CrescentMatPainter` (Tasks 1-2),
  `ModuleAccents.prayer`.

- [ ] **Step 1: Write the failing test**

Add a new test to `test/features/prayer/presentation/
prayer_home_screen_test.dart`, right after the existing `'shows the
empty state when there are no records today'` test:

```dart
  testWidgets(
    "empty state's illustration is painted in Prayer's own accent color",
    (tester) async {
      when(
        () => repo.watchRecordsForDay(any()),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        () => repo.watchSettings(),
      ).thenAnswer((_) => Stream.value(settings));

      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 6)), () async {
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();
      });

      final customPaint = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .firstWhere((w) => w.painter is CrescentMatPainter);
      final painter = customPaint.painter! as CrescentMatPainter;
      expect(painter.color, ModuleAccents.prayer);
    },
  );
```

Add the two new imports at the top of the same file (alongside the
existing `habit_tracker/...` imports):

```dart
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/widgets/illustrations/crescent_mat_painter.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/prayer/presentation/prayer_home_screen_test.dart | tail -10`
Expected: FAIL — no `CustomPaint` with a `CrescentMatPainter` exists on
the screen yet (`firstWhere` throws `StateError: No element`).

- [ ] **Step 3: Write minimal implementation**

In `lib/features/prayer/presentation/screens/prayer_home_screen.dart`,
add the new imports (alongside the existing `habit_tracker/...` imports):

```dart
import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/widgets/illustrations/crescent_mat_painter.dart';
import 'package:habit_tracker/core/widgets/module_empty_state.dart';
import 'package:habit_tracker/core/widgets/note_editor_sheet.dart';
```

Change:

```dart
      body: views == null
          ? const Center(child: CircularProgressIndicator())
          : views.isEmpty
          ? Center(child: Text(l10n.prayerHomeEmpty))
          : ListView.builder(
```

to:

```dart
      body: views == null
          ? const Center(child: CircularProgressIndicator())
          : views.isEmpty
          ? ModuleEmptyState(
              painter: CrescentMatPainter.new,
              message: l10n.prayerHomeEmpty,
              accentColor: ModuleAccents.prayer,
            )
          : ListView.builder(
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/prayer/presentation/prayer_home_screen_test.dart | tail -10`
Expected: PASS, all tests in the file green.

- [ ] **Step 5: Analyze, format, and full sweep**

Run: `flutter analyze lib/features/prayer/presentation/screens/prayer_home_screen.dart | tail -10`
Run: `dart format lib/features/prayer/presentation/screens/prayer_home_screen.dart`
Expected: `No issues found!`

Run: `flutter analyze | tail -10`
Expected: `No issues found!` — confirms no stray unused import across all
five touched files.

- [ ] **Step 6: Commit**

```bash
git add lib/features/prayer/presentation/screens/prayer_home_screen.dart \
  test/features/prayer/presentation/prayer_home_screen_test.dart
git commit -m "feat(prayer): illustrate the no-prayers-today empty state"
```

---

## After all tasks

Per this repo's CLAUDE.md spec-implementation workflow: once every task
above is committed, open a PR for the spec with the design summary in the
description, then run a code review against the finished PR (comment →
fix → commit cycle, up to 5 rounds), then stop and wait for the user's
own review and merge.
