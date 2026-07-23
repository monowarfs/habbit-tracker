# Streak-Save Celebration Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give streak-milestone achievement unlocks (7/30/100-day streaks)
a brief, skippable celebration overlay — distinct from the plain snackbar
every other achievement still gets — per `docs/superpowers/specs/
02-delightful/02-streak-save-celebration-animation-design.md`.

**Architecture:** A pure `isStreakMilestoneKey(String key)` helper
(`key.contains('_streak_')`) distinguishes the 8 real streak keys from
the 5 non-streak keys across Water/Medicine/Prayer — no new
`AchievementDefinition` field, no DB column. A new `OverlayEntry`-based
`showStreakCelebration` (900ms in / 700ms hold / 400ms out,
`Curves.elasticOut` scale + fade + a cheap `CustomPainter` confetti
burst, `MediaQuery.disableAnimations`-aware) is inserted as one extra
branch in each of the three existing achievement-diff-then-snackbar call
sites — no new call site, no change to `AchievementEngine`/
`AchievementRepository`.

**Tech Stack:** Flutter SDK only (`OverlayEntry`/`AnimationController`/
`CustomPainter`/`MediaQuery`) — no new dependency. `package:clock`,
`flutter_test`.

## Global Constraints

- New files only: `lib/core/achievements/achievement_kind.dart`
  (`isStreakMilestoneKey`), `lib/core/widgets/streak_celebration_overlay
  .dart` (`showStreakCelebration`).
- No new dependency. In particular, **no `package:collection`** — it is
  only a *transitive* dependency in this repo (`pubspec.lock` shows
  `dependency: transitive`, not declared in `pubspec.yaml`), so
  `firstWhereOrNull` is not available without violating "no new
  dependency" and would also trip `very_good_analysis`'s
  `depend_on_referenced_packages` lint. Every task below finds the first
  streak key with a plain `for` loop instead.
- Each of the three home screens (`water_home_screen.dart`,
  `medicine_home_screen.dart`, `prayer_home_screen.dart`) gets a small
  addition at its existing achievement-diff call site — no change to
  `AchievementEngine`/`AchievementRepository`, no change to what
  `achievements` stores or how `AchievementRepository.upsertProgress`
  decides `unlockedAt`.
- Overlay total duration budget: ≤2 seconds auto-dismiss, tap-anywhere
  dismisses immediately.
- `MediaQuery.of(context).disableAnimations` must be honored: when set,
  skip straight to a static badge-and-title flash (~600ms, no motion)
  instead of the animated version (`docs/superpowers/specs/
  07-accessibility/07-reduce-motion-respect-design.md`'s standing rule).
- Medicine's site keeps its existing `wasUndone` gate — an undone dose
  shows no celebration, same as it shows no achievement snackbar today.
- Per this repo's CLAUDE.md spec-implementation workflow: one commit per
  task, run only that task's own test file (never the full `flutter
  test` suite mid-task), pipe `build_runner`/`test` output through
  `| tail -10`.
- No l10n keys needed — the overlay reuses `localizedAchievementTitle`,
  the same lookup the achievement snackbar already calls.

---

### Task 1: `isStreakMilestoneKey` helper

**Files:**
- Create: `lib/core/achievements/achievement_kind.dart`
- Test: `test/core/achievements/achievement_kind_test.dart`

**Interfaces:**
- Produces: `bool isStreakMilestoneKey(String key)` — consumed by Tasks
  3-5's three wiring sites.

- [ ] **Step 1: Write the failing test**

Create `test/core/achievements/achievement_kind_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_kind.dart';

void main() {
  // Every real streak-milestone key across all three modules today
  // (`WaterModule`/`MedicineModule`/`PrayerModule.achievementDefinitions`
  // — grepped for the source design doc, re-verified directly against
  // the current `lib/features/*/*.dart` definitions while writing this
  // plan).
  const streakKeys = [
    'water_streak_7',
    'water_streak_30',
    'water_streak_100',
    'medicine_adherence_streak_7',
    'medicine_adherence_streak_30',
    'prayer_streak_7',
    'prayer_streak_30',
    'prayer_streak_100',
  ];

  // Every real non-streak key today.
  const nonStreakKeys = [
    'water_first_log',
    'water_perfect_week',
    'medicine_first_dose',
    'prayer_first_log',
    'prayer_perfect_week',
  ];

  for (final key in streakKeys) {
    test('$key is a streak milestone', () {
      expect(isStreakMilestoneKey(key), isTrue);
    });
  }

  for (final key in nonStreakKeys) {
    test('$key is not a streak milestone', () {
      expect(isStreakMilestoneKey(key), isFalse);
    });
  }

  test('a key with no _streak_ substring at all is never a match', () {
    expect(isStreakMilestoneKey('totally_unrelated_key'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/achievements/achievement_kind_test.dart | tail -10`
Expected: FAIL to compile — `achievement_kind.dart` doesn't exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/achievements/achievement_kind.dart`:

```dart
/// True for a key like `water_streak_7`/`medicine_adherence_streak_30` —
/// every streak-milestone achievement across all three modules follows
/// this naming convention (`docs/superpowers/specs/02-delightful/
/// 02-streak-save-celebration-animation-design.md`). A module adding a
/// future streak key must keep using `_streak_` in it, same as today's 8
/// keys already do.
bool isStreakMilestoneKey(String key) => key.contains('_streak_');
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/achievements/achievement_kind_test.dart | tail -10`
Expected: `+14: All tests passed!`

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/core/achievements/achievement_kind.dart | tail -10`
Run: `dart format lib/core/achievements/achievement_kind.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/achievements/achievement_kind.dart \
  test/core/achievements/achievement_kind_test.dart
git commit -m "feat(achievements): add isStreakMilestoneKey"
```

---

### Task 2: The celebration overlay widget

**Files:**
- Create: `lib/core/widgets/streak_celebration_overlay.dart`
- Test: `test/core/widgets/streak_celebration_overlay_test.dart`

**Interfaces:**
- Produces: `Future<void> showStreakCelebration(BuildContext context,
  {required String title, required Color accentColor, required IconData
  icon})` — consumed by Tasks 3-5's three wiring sites.

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/streak_celebration_overlay_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/widgets/streak_celebration_overlay.dart';

void main() {
  Future<void> pumpTrigger(
    WidgetTester tester, {
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => unawaited(
                  showStreakCelebration(
                    context,
                    title: '7-Day Streak',
                    accentColor: Colors.blue,
                    icon: Icons.local_fire_department,
                  ),
                ),
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the title and auto-dismisses within the 2s budget', (
    tester,
  ) async {
    await pumpTrigger(tester);
    await tester.tap(find.text('trigger'));
    await tester.pump();

    expect(find.text('7-Day Streak'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();

    expect(find.text('7-Day Streak'), findsNothing);
  });

  testWidgets('tapping anywhere on the overlay dismisses it immediately', (
    tester,
  ) async {
    await pumpTrigger(tester);
    await tester.tap(find.text('trigger'));
    await tester.pump();
    expect(find.text('7-Day Streak'), findsOneWidget);

    await tester.tap(find.text('7-Day Streak'));
    await tester.pumpAndSettle();

    expect(find.text('7-Day Streak'), findsNothing);
  });

  testWidgets(
    'disableAnimations shows a static flash with no motion and dismisses '
    'well under the full animated budget',
    (tester) async {
      await pumpTrigger(tester, disableAnimations: true);
      await tester.tap(find.text('trigger'));
      await tester.pump();
      expect(find.text('7-Day Streak'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();

      expect(find.text('7-Day Streak'), findsNothing);
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/streak_celebration_overlay_test.dart | tail -10`
Expected: FAIL to compile — `streak_celebration_overlay.dart` doesn't
exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/core/widgets/streak_celebration_overlay.dart`:

```dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Shows a brief (900ms in, 700ms hold, 400ms out; 2000ms total),
/// skippable celebration over the current screen using an
/// [OverlayEntry] — not a route/dialog, so it never blocks input to the
/// screen underneath and never appears in the back-stack. Tapping
/// anywhere on the overlay dismisses it immediately, same as its
/// auto-dismiss (`docs/superpowers/specs/02-delightful/
/// 02-streak-save-celebration-animation-design.md`).
///
/// Respects `MediaQuery.of(context).disableAnimations`
/// (`docs/superpowers/specs/07-accessibility/07-reduce-motion-respect
/// -design.md`'s standing rule): when set, skips straight to a static
/// badge-and-title flash for ~600ms with no motion, rather than the
/// animated version.
Future<void> showStreakCelebration(
  BuildContext context, {
  required String title,
  required Color accentColor,
  required IconData icon,
}) async {
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  final overlayState = Overlay.of(context);
  final completer = Completer<void>();
  void dismiss() {
    if (!completer.isCompleted) completer.complete();
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _StreakCelebrationOverlay(
      title: title,
      accentColor: accentColor,
      icon: icon,
      reduceMotion: reduceMotion,
      onTapDismiss: dismiss,
    ),
  );
  overlayState.insert(entry);

  final autoDismissAfter = reduceMotion
      ? const Duration(milliseconds: 600)
      : const Duration(milliseconds: 2000);
  unawaited(Future.delayed(autoDismissAfter, dismiss));

  await completer.future;
  entry.remove();
}

class _StreakCelebrationOverlay extends StatefulWidget {
  const _StreakCelebrationOverlay({
    required this.title,
    required this.accentColor,
    required this.icon,
    required this.reduceMotion,
    required this.onTapDismiss,
  });

  final String title;
  final Color accentColor;
  final IconData icon;
  final bool reduceMotion;
  final VoidCallback onTapDismiss;

  @override
  State<_StreakCelebrationOverlay> createState() =>
      _StreakCelebrationOverlayState();
}

class _StreakCelebrationOverlayState extends State<_StreakCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    // Weights approximate the 900ms-in/700ms-hold/400ms-out timeline
    // over the controller's 2000ms total.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 900,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 700),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 400),
    ]).animate(_controller);
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 1600),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 400),
    ]).animate(_controller);
    if (!widget.reduceMotion) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTapDismiss,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.35),
          child: Center(
            child: widget.reduceMotion
                ? _badge(opacity: 1, scale: 1)
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) =>
                        _badge(opacity: _fade.value, scale: _scale.value),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _badge({required double opacity, required double scale}) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: 220,
          height: 220,
          child: CustomPaint(
            painter: _ConfettiBurstPainter(color: widget.accentColor),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: widget.accentColor.withValues(
                      alpha: 0.15,
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A cheap confetti-burst approximation: a dozen short colored line
/// segments radiating outward from the center, fixed-seed for
/// deterministic (if unrealistic) rendering — no particle-physics
/// simulation, no images decoded, nothing GPU-heavier than the existing
/// chart widgets already in the app (`period_bar_chart.dart`'s
/// `fl_chart` usage).
class _ConfettiBurstPainter extends CustomPainter {
  _ConfettiBurstPainter({required this.color});

  final Color color;
  static final _random = Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * pi + _random.nextDouble() * 0.2;
      final innerRadius = size.shortestSide * 0.32;
      final outerRadius = size.shortestSide * 0.48;
      final direction = Offset(cos(angle), sin(angle));
      canvas.drawLine(
        center + direction * innerRadius,
        center + direction * outerRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiBurstPainter oldDelegate) =>
      oldDelegate.color != color;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/streak_celebration_overlay_test.dart | tail -10`
Expected: `+3: All tests passed!`

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/core/widgets/streak_celebration_overlay.dart | tail -10`
Run: `dart format lib/core/widgets/streak_celebration_overlay.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/streak_celebration_overlay.dart \
  test/core/widgets/streak_celebration_overlay_test.dart
git commit -m "feat(widgets): add the streak-save celebration overlay"
```

---

### Task 3: Wire Water's home screen

**Files:**
- Modify: `lib/features/water/presentation/screens/water_home_screen.dart:154-192`
- Test: `test/features/water/presentation/water_home_screen_test.dart`

**Interfaces:**
- Consumes: `isStreakMilestoneKey` (Task 1), `showStreakCelebration`
  (Task 2).

- [ ] **Step 1: Write the failing test**

Add to `test/features/water/presentation/water_home_screen_test.dart`,
new imports alongside the existing ones:

```dart
import 'package:habit_tracker/features/water/presentation/widgets/quick_add_button.dart';
```

(`clock`/`Clock`/`withClock` are already imported by this file.) Then add
a new `testWidgets` at the end of `main()`, before the closing `}`:

```dart
  testWidgets(
    'quick-adding water that completes a 7-day streak shows the streak '
    'celebration before the achievement snackbar',
    (tester) async {
      final today = DateTime.utc(2026, 6, 7, 9);
      final repo = WaterRepositoryImpl(db);
      // An explicit goal with an `effectiveFrom` well before the 7-day
      // window — otherwise the repository's own lazy goal-seeding would
      // stamp `effectiveFrom` as "now" the first time it's read, which
      // would clip `_currentWaterStreak`'s own earliest-day bound to
      // today and cap the achievable streak at 1.
      await repo.setGoal(2000, effectiveFrom: DateTime.utc(2026, 5, 25));
      // `water_first_log`/`water_perfect_week` would otherwise unlock in
      // the very same diff as `water_streak_7` (a fresh account's first
      // week is trivially both a first log and a perfect week) — pre-seed
      // both as already-unlocked so the test's own diff isolates
      // `water_streak_7` as the sole newly-unlocked achievement.
      final achievementRepo = AchievementRepository(db);
      await achievementRepo.upsertProgress(
        moduleId: 'water',
        key: 'water_first_log',
        current: 1,
        target: 1,
        now: DateTime.utc(2026, 5, 26),
      );
      await achievementRepo.upsertProgress(
        moduleId: 'water',
        key: 'water_perfect_week',
        current: 1,
        target: 1,
        now: DateTime.utc(2026, 5, 26),
      );

      await withClock(Clock.fixed(today), () async {
        // 6 fully-complete prior days.
        for (var i = 1; i <= 6; i++) {
          await repo.addEntry(
            amountMl: 2000,
            loggedAt: today.subtract(Duration(days: i)),
            source: WaterEntrySource.custom,
          );
        }
        // Today: 1750ml already logged, 250ml short of the goal.
        await repo.addEntry(
          amountMl: 1750,
          loggedAt: today,
          source: WaterEntrySource.custom,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: WaterHomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Taps the default 250ml quick-add button, completing today's
        // goal and — with 6 prior complete days and both non-streak
        // achievements pre-unlocked — the 7-day streak.
        await tester.tap(find.byType(QuickAddButton).first);
        await tester.pump();

        // The celebration overlay appears first.
        expect(find.text('Hydration Habit'), findsOneWidget);
        // The achievement snackbar hasn't appeared yet — it waits for
        // the overlay's own future to resolve first.
        expect(
          find.text('Achievement unlocked: Hydration Habit'),
          findsNothing,
        );

        // Let the overlay auto-dismiss, then the snackbar follows.
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pumpAndSettle();

        expect(
          find.text('Achievement unlocked: Hydration Habit'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      });
    },
  );
```

Also add the `AchievementRepository` import to the top of the file:

```dart
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/water/presentation/water_home_screen_test.dart | tail -10`
Expected: FAIL — the celebration text `'Hydration Habit'` never appears
(no celebration is wired up yet), only the achievement snackbar fires.

- [ ] **Step 3: Wire the celebration into `_logQuickAddAndCelebrate`**

In `lib/features/water/presentation/screens/water_home_screen.dart`, add
the two new imports:

```dart
import 'package:habit_tracker/core/achievements/achievement_kind.dart';
import 'package:habit_tracker/core/widgets/streak_celebration_overlay.dart';
```

Change:

```dart
  await ref.read(waterControllerProvider.notifier).logQuickAdd(amountMl);

  final after = await repository.watchByModule('water').first;
  final newlyUnlocked = after.where(
    (r) => r.unlockedAt != null && !unlockedBefore.contains(r.key),
  );
  if (newlyUnlocked.isEmpty || !context.mounted) return;
  final module = ref
      .read(habitModulesProvider)
      .firstWhere((m) => m.id == 'water');
  final definition = module.achievementDefinitions.firstWhere(
    (d) => d.key == newlyUnlocked.first.key,
  );
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        l10n.achievementUnlockedSnackbar(
          localizedAchievementTitle(l10n, definition.titleKey),
        ),
      ),
    ),
  );
}
```

to:

```dart
  await ref.read(waterControllerProvider.notifier).logQuickAdd(amountMl);

  final after = await repository.watchByModule('water').first;
  final newlyUnlocked = after.where(
    (r) => r.unlockedAt != null && !unlockedBefore.contains(r.key),
  );
  if (newlyUnlocked.isEmpty || !context.mounted) return;
  final module = ref
      .read(habitModulesProvider)
      .firstWhere((m) => m.id == 'water');

  String? streakKey;
  for (final row in newlyUnlocked) {
    if (isStreakMilestoneKey(row.key)) {
      streakKey = row.key;
      break;
    }
  }
  if (streakKey != null && context.mounted) {
    final streakDefinition = module.achievementDefinitions.firstWhere(
      (d) => d.key == streakKey,
    );
    final celebrationL10n = AppLocalizations.of(context)!;
    await showStreakCelebration(
      context,
      title: localizedAchievementTitle(celebrationL10n, streakDefinition.titleKey),
      accentColor: module.metadata.accentColor,
      icon: module.metadata.icon,
    );
  }
  if (!context.mounted) return;

  final definition = module.achievementDefinitions.firstWhere(
    (d) => d.key == newlyUnlocked.first.key,
  );
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        l10n.achievementUnlockedSnackbar(
          localizedAchievementTitle(l10n, definition.titleKey),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/water/presentation/water_home_screen_test.dart | tail -10`
Expected: PASS — all pre-existing tests plus the new one.

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/features/water/presentation/screens/water_home_screen.dart | tail -10`
Run: `dart format lib/features/water/presentation/screens/water_home_screen.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/water/presentation/screens/water_home_screen.dart \
  test/features/water/presentation/water_home_screen_test.dart
git commit -m "feat(water): show the streak celebration before the achievement snackbar"
```

---

### Task 4: Wire Medicine's home screen

**Files:**
- Modify: `lib/features/medicine/presentation/screens/medicine_home_screen.dart:99-153`
- Test: `test/features/medicine/presentation/medicine_home_screen_test.dart`

**Interfaces:**
- Consumes: `isStreakMilestoneKey` (Task 1), `showStreakCelebration`
  (Task 2).

- [ ] **Step 1: Write the failing test**

Add to `test/features/medicine/presentation/medicine_home_screen_test.dart`,
new imports (the file does not yet import `medicine_dose.dart` at all —
`MedicineDose`/`MedicineDoseStatus` are new to this file):

```dart
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
```

Then add a new `testWidgets` at the end of `main()`:

```dart
  testWidgets(
    'marking the last dose of a 7-day adherence streak done shows the '
    'streak celebration before the achievement snackbar',
    (tester) async {
      final repo = MedicineRepositoryImpl(db);
      final medicineResult = await repo.createMedicine(
        name: 'Aspirin',
        stockEnabled: false,
      );
      final medicine = (medicineResult as Success<Medicine>).value;
      final scheduleResult = await repo.createSchedule(
        medicineId: medicine.id,
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        startDate: const LocalDate(2026, 5, 20),
      );
      final schedule = (scheduleResult as Success<MedicineSchedule>).value;

      // `medicine_first_dose` would otherwise unlock in the very same
      // diff as `medicine_adherence_streak_7` (a fresh account's first
      // taken dose is trivially both) — pre-seed it as already-unlocked
      // so the test's own diff isolates the streak achievement.
      final achievementRepo = AchievementRepository(db);
      await achievementRepo.upsertProgress(
        moduleId: 'medicine',
        key: 'medicine_first_dose',
        current: 1,
        target: 1,
        now: DateTime.utc(2026, 5, 21),
      );

      final today = DateTime.utc(2026, 6, 1, 8, 15);
      // 6 prior fully-taken days, inserted directly (bypassing
      // materialization/timing) — the same precedent
      // `medicine_module.dart`'s own `importData` uses for `restoreDose`.
      for (var i = 1; i <= 6; i++) {
        final day = today.subtract(Duration(days: i));
        await repo.restoreDose(
          MedicineDose(
            id: '',
            medicineId: medicine.id,
            scheduleId: schedule.id,
            scheduledFor: DateTime.utc(day.year, day.month, day.day, 8),
            storedStatus: MedicineDoseStatus.done,
            graceWindowMinutes: 30,
            statusChangedAt: DateTime.utc(day.year, day.month, day.day, 8, 5),
            stockDeltaApplied: 0,
          ),
        );
      }

      await withClock(Clock.fixed(today), () async {
        // Materializes today's dose (still upcoming) without disturbing
        // the 6 already-seeded prior days (gap-filler semantics).
        await repo.materializeDoses(today);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MedicineHomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Done'));
        await tester.pump();
        // Let the undo snackbar's enter animation finish, then time out
        // (commit) — same technique as `undo_snackbar_test.dart`'s own
        // "letting the snackbar time out" case, for the default 4s
        // duration `showUndoSnackbar` uses here.
        await tester.pump(const Duration(milliseconds: 750));
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // The celebration overlay appears first.
        expect(find.text('On Schedule'), findsOneWidget);
        expect(
          find.text('Achievement unlocked: On Schedule'),
          findsNothing,
        );

        // Let the overlay auto-dismiss, then the snackbar follows.
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pumpAndSettle();

        expect(find.text('Achievement unlocked: On Schedule'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      });
    },
  );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medicine/presentation/medicine_home_screen_test.dart | tail -10`
Expected: FAIL — `'On Schedule'` (the celebration) never appears.

- [ ] **Step 3: Wire the celebration into `_markDoneAndCelebrate`**

In `lib/features/medicine/presentation/screens/medicine_home_screen.dart`,
add the two new imports:

```dart
import 'package:habit_tracker/core/achievements/achievement_kind.dart';
import 'package:habit_tracker/core/widgets/streak_celebration_overlay.dart';
```

Change:

```dart
  if (wasUndone || !context.mounted) return;

  final after = await repository.watchByModule('medicine').first;
  final newlyUnlocked = after.where(
    (r) => r.unlockedAt != null && !unlockedBefore.contains(r.key),
  );
  if (newlyUnlocked.isEmpty || !context.mounted) return;
  final module = ref
      .read(habitModulesProvider)
      .firstWhere((m) => m.id == 'medicine');
  final definition = module.achievementDefinitions.firstWhere(
    (d) => d.key == newlyUnlocked.first.key,
  );
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        l10n.achievementUnlockedSnackbar(
          localizedAchievementTitle(l10n, definition.titleKey),
        ),
      ),
    ),
  );
}
```

to:

```dart
  if (wasUndone || !context.mounted) return;

  final after = await repository.watchByModule('medicine').first;
  final newlyUnlocked = after.where(
    (r) => r.unlockedAt != null && !unlockedBefore.contains(r.key),
  );
  if (newlyUnlocked.isEmpty || !context.mounted) return;
  final module = ref
      .read(habitModulesProvider)
      .firstWhere((m) => m.id == 'medicine');

  String? streakKey;
  for (final row in newlyUnlocked) {
    if (isStreakMilestoneKey(row.key)) {
      streakKey = row.key;
      break;
    }
  }
  if (streakKey != null && context.mounted) {
    final streakDefinition = module.achievementDefinitions.firstWhere(
      (d) => d.key == streakKey,
    );
    final celebrationL10n = AppLocalizations.of(context)!;
    await showStreakCelebration(
      context,
      title: localizedAchievementTitle(celebrationL10n, streakDefinition.titleKey),
      accentColor: module.metadata.accentColor,
      icon: module.metadata.icon,
    );
  }
  if (!context.mounted) return;

  final definition = module.achievementDefinitions.firstWhere(
    (d) => d.key == newlyUnlocked.first.key,
  );
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        l10n.achievementUnlockedSnackbar(
          localizedAchievementTitle(l10n, definition.titleKey),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medicine/presentation/medicine_home_screen_test.dart | tail -10`
Expected: PASS — all pre-existing tests plus the new one.

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/features/medicine/presentation/screens/medicine_home_screen.dart | tail -10`
Run: `dart format lib/features/medicine/presentation/screens/medicine_home_screen.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/medicine/presentation/screens/medicine_home_screen.dart \
  test/features/medicine/presentation/medicine_home_screen_test.dart
git commit -m "feat(medicine): show the streak celebration before the achievement snackbar"
```

---

### Task 5: Wire Prayer's home screen

**Files:**
- Modify: `lib/features/prayer/presentation/screens/prayer_home_screen.dart:89-131`
- Test: `test/features/prayer/presentation/prayer_home_screen_test.dart`

**Interfaces:**
- Consumes: `isStreakMilestoneKey` (Task 1), `showStreakCelebration`
  (Task 2).

- [ ] **Step 1: Write the failing test**

The existing `test/features/prayer/presentation/prayer_home_screen_test
.dart` mocks `PrayerRepository` directly, which only stands in for the
screen's own `todaysPrayerViewsProvider` data — the achievement-diff
path reads through `habitModulesProvider`, which always constructs a
real `PrayerRepositoryImpl(db)` off `databaseProvider`
(`module_registry.dart`'s `buildHabitModules`), independent of that
mock. This new test therefore follows the real-database convention
`water_home_screen_test.dart`/`medicine_home_screen_test.dart` already
use instead, added as its own top-level `main()` alongside — actually,
add it as a new file to avoid mixing the two conventions in one file:

Create `test/features/prayer/presentation/prayer_streak_celebration_test.dart`:

```dart
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_home_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets(
    'marking the last prayer of a 7-day streak prayed shows the streak '
    'celebration before the achievement snackbar',
    (tester) async {
      final repo = PrayerRepositoryImpl(db);

      // `prayer_first_log`/`prayer_perfect_week` would otherwise unlock
      // in the very same diff as `prayer_streak_7` — pre-seed both as
      // already-unlocked so the test's own diff isolates the streak
      // achievement (same reasoning as Water's/Medicine's equivalent
      // tests in this plan).
      final achievementRepo = AchievementRepository(db);
      await achievementRepo.upsertProgress(
        moduleId: 'prayer',
        key: 'prayer_first_log',
        current: 1,
        target: 1,
        now: DateTime.utc(2026, 5, 26),
      );
      await achievementRepo.upsertProgress(
        moduleId: 'prayer',
        key: 'prayer_perfect_week',
        current: 1,
        target: 1,
        now: DateTime.utc(2026, 5, 26),
      );

      final today = const LocalDate(2026, 6, 7);
      // 6 prior fully-prayed days, inserted directly via `restoreRecord`
      // (the same precedent `prayer_module.dart`'s own `importData`
      // uses) — bypasses solar-time materialization entirely, since
      // `effectivePrayerStatus` returns a non-`upcoming` `storedStatus`
      // unconditionally, without checking `scheduledFor` against `now`.
      for (var i = 1; i <= 6; i++) {
        final day = today.addDays(-i);
        for (final name in PrayerName.values) {
          await repo.restoreRecord(
            PrayerRecord(
              id: '',
              prayerDate: day,
              prayerName: name,
              scheduledFor: DateTime.utc(day.year, day.month, day.day, 6),
              storedStatus: PrayerStatus.prayed,
              statusChangedAt: DateTime.utc(
                day.year,
                day.month,
                day.day,
                6,
                5,
              ),
            ),
          );
        }
      }

      // Today: Fajr/Asr/Maghrib/Isha already prayed, Dhuhr still
      // upcoming — this is the one toggled via the UI below. `now` sits
      // inside Dhuhr's own due window (after its own `scheduledFor`,
      // before Asr's, which is Dhuhr's cutoff) — the other prayers being
      // marked prayed "ahead of their own scheduled time" is harmless
      // here since `effectivePrayerStatus` never validates that.
      await repo.restoreRecord(
        PrayerRecord(
          id: '',
          prayerDate: today,
          prayerName: PrayerName.fajr,
          scheduledFor: DateTime.utc(2026, 6, 7, 5),
          storedStatus: PrayerStatus.prayed,
          statusChangedAt: DateTime.utc(2026, 6, 7, 5, 5),
        ),
      );
      await repo.restoreRecord(
        PrayerRecord(
          id: '',
          prayerDate: today,
          prayerName: PrayerName.dhuhr,
          scheduledFor: DateTime.utc(2026, 6, 7, 12),
          storedStatus: PrayerStatus.upcoming,
        ),
      );
      await repo.restoreRecord(
        PrayerRecord(
          id: '',
          prayerDate: today,
          prayerName: PrayerName.asr,
          scheduledFor: DateTime.utc(2026, 6, 7, 15, 30),
          storedStatus: PrayerStatus.prayed,
          statusChangedAt: DateTime.utc(2026, 6, 7, 15, 35),
        ),
      );
      await repo.restoreRecord(
        PrayerRecord(
          id: '',
          prayerDate: today,
          prayerName: PrayerName.maghrib,
          scheduledFor: DateTime.utc(2026, 6, 7, 18),
          storedStatus: PrayerStatus.prayed,
          statusChangedAt: DateTime.utc(2026, 6, 7, 18, 5),
        ),
      );
      await repo.restoreRecord(
        PrayerRecord(
          id: '',
          prayerDate: today,
          prayerName: PrayerName.isha,
          scheduledFor: DateTime.utc(2026, 6, 7, 19, 30),
          storedStatus: PrayerStatus.prayed,
          statusChangedAt: DateTime.utc(2026, 6, 7, 19, 35),
        ),
      );

      await withClock(Clock.fixed(DateTime.utc(2026, 6, 7, 13)), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: PrayerHomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // `PrayerTile`'s "Prayed" toggle is the tile's trailing
        // `IconButton` (`onPressed: onToggle`), not a tap on the tile
        // itself (`prayer_tile.dart:66-77`) — Dhuhr is the only
        // not-yet-prayed record among today's five, so its
        // `radio_button_unchecked` icon is unique in the tree.
        await tester.tap(find.byIcon(Icons.radio_button_unchecked));
        await tester.pump();

        // The celebration overlay appears first.
        expect(find.text('Consistent Worship'), findsOneWidget);
        expect(
          find.text('Achievement unlocked: Consistent Worship'),
          findsNothing,
        );

        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pumpAndSettle();

        expect(
          find.text('Achievement unlocked: Consistent Worship'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      });
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/prayer/presentation/prayer_streak_celebration_test.dart | tail -10`
Expected: FAIL — `'Consistent Worship'` (the celebration) never appears.

- [ ] **Step 3: Wire the celebration into `_togglePrayedAndCelebrate`**

In `lib/features/prayer/presentation/screens/prayer_home_screen.dart`,
add the two new imports:

```dart
import 'package:habit_tracker/core/achievements/achievement_kind.dart';
import 'package:habit_tracker/core/widgets/streak_celebration_overlay.dart';
```

Change:

```dart
  await ref
      .read(prayerControllerProvider.notifier)
      .togglePrayed(recordId, currentlyPrayed: currentlyPrayed);

  final after = await repository.watchByModule('prayer').first;
  final newlyUnlocked = after.where(
    (r) => r.unlockedAt != null && !unlockedBefore.contains(r.key),
  );
  if (newlyUnlocked.isEmpty || !context.mounted) return;
  final module = ref
      .read(habitModulesProvider)
      .firstWhere((m) => m.id == 'prayer');
  final definition = module.achievementDefinitions.firstWhere(
    (d) => d.key == newlyUnlocked.first.key,
  );
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        l10n.achievementUnlockedSnackbar(
          localizedAchievementTitle(l10n, definition.titleKey),
        ),
      ),
    ),
  );
}
```

to:

```dart
  await ref
      .read(prayerControllerProvider.notifier)
      .togglePrayed(recordId, currentlyPrayed: currentlyPrayed);

  final after = await repository.watchByModule('prayer').first;
  final newlyUnlocked = after.where(
    (r) => r.unlockedAt != null && !unlockedBefore.contains(r.key),
  );
  if (newlyUnlocked.isEmpty || !context.mounted) return;
  final module = ref
      .read(habitModulesProvider)
      .firstWhere((m) => m.id == 'prayer');

  String? streakKey;
  for (final row in newlyUnlocked) {
    if (isStreakMilestoneKey(row.key)) {
      streakKey = row.key;
      break;
    }
  }
  if (streakKey != null && context.mounted) {
    final streakDefinition = module.achievementDefinitions.firstWhere(
      (d) => d.key == streakKey,
    );
    final celebrationL10n = AppLocalizations.of(context)!;
    await showStreakCelebration(
      context,
      title: localizedAchievementTitle(celebrationL10n, streakDefinition.titleKey),
      accentColor: module.metadata.accentColor,
      icon: module.metadata.icon,
    );
  }
  if (!context.mounted) return;

  final definition = module.achievementDefinitions.firstWhere(
    (d) => d.key == newlyUnlocked.first.key,
  );
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        l10n.achievementUnlockedSnackbar(
          localizedAchievementTitle(l10n, definition.titleKey),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/prayer/presentation/prayer_streak_celebration_test.dart | tail -10`
Expected: PASS.

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/features/prayer/presentation/screens/prayer_home_screen.dart | tail -10`
Run: `dart format lib/features/prayer/presentation/screens/prayer_home_screen.dart`
Expected: `No issues found!`

- [ ] **Step 6: Full sweep**

Run: `flutter analyze | tail -10`
Expected: `No issues found!`

Run: `dart format --output=none --set-exit-if-changed . | tail -10`
Expected: exits 0.

- [ ] **Step 7: Commit**

```bash
git add lib/features/prayer/presentation/screens/prayer_home_screen.dart \
  test/features/prayer/presentation/prayer_streak_celebration_test.dart
git commit -m "feat(prayer): show the streak celebration before the achievement snackbar"
```

---

## After all tasks

Per this repo's CLAUDE.md spec-implementation workflow: once every task
above is committed, open a PR for the spec with the design summary in the
description, then run a code review against the finished PR (comment →
fix → commit cycle, up to 5 rounds), then stop and wait for the user's
own review and merge.
