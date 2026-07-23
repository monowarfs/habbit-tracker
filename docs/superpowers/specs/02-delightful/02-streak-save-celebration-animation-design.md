# Streak-Save Celebration Animation

**Date:** 2026-07-23
**Status:** Draft — pending review

## Problem

Run 15's exit criteria (`docs/product/roadmap.md:29`) fixed the house
style: "badge unlock shows a snackbar not a modal." Today **every**
achievement — streak milestone or not — gets exactly the same treatment,
found identically at three call sites:

- `lib/features/water/presentation/screens/water_home_screen.dart:186`
- `lib/features/prayer/presentation/screens/prayer_home_screen.dart:125`
- `lib/features/medicine/presentation/screens/medicine_home_screen.dart:147`
  (inside `_markDoneAndCelebrate`, `medicine_home_screen.dart:99-153`)

Each computes an `unlockedBefore`/`after` diff against
`AchievementRepository.watchByModule(moduleId)` right after the module's
own write commits, then — if anything newly unlocked —
`ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n
.achievementUnlockedSnackbar(...))))`. This is exactly the "evaluated from
each module's own write path" hook CLAUDE.md documents, and it's the
**only** trigger point that exists — there's no separate detection logic
to hook into.

**Streak-length achievements are already identifiable by key, no new
metadata needed.** Grepping every `AchievementDefinition(key: '...')`
across the three modules:

```
water_streak_7, water_streak_30, water_streak_100
medicine_adherence_streak_7, medicine_adherence_streak_30
prayer_streak_7, prayer_streak_30, prayer_streak_100
```

versus the non-streak keys (`water_first_log`, `water_perfect_week`,
`medicine_first_dose`, `prayer_first_log`, `prayer_perfect_week`) — every
streak-milestone key contains the literal substring `_streak_`, and no
non-streak key does. That substring check is the entire "distinction ...
between streak milestone and other achievement types" the original draft
flagged as an open question — no new field on `AchievementDefinition` or
column on `achievements` needed.

**Reduce-motion is already a named cross-cutting requirement, not
something this spec invents:** `docs/superpowers/specs/07-accessibility/
07-reduce-motion-respect-design.md` explicitly calls out that "neither the
current codebase nor the atlas's Delightful/Gamification categories have
shipped streak-save ... animations yet," and pre-establishes the rule this
feature must follow: check `MediaQuery.of(context).disableAnimations` and
substitute an instant state change when it's set. This spec is the first
concrete consumer of that standing rule.

**No animation/confetti package is a dependency** (`pubspec.yaml` has no
`confetti`, `lottie`, or similar — checked directly). Budget-hardware
constraint (Nusrat's persona) plus "no new dependency for what a few lines
can do" both point at pure Flutter `AnimationController`/`CustomPainter`,
not a package.

## Design

### Detecting "this unlock is a streak milestone"

New helper, `lib/core/achievements/achievement_kind.dart`:

```dart
/// True for a key like `water_streak_7`/`medicine_adherence_streak_30` —
/// every streak-milestone achievement across all three modules follows
/// this naming convention (checked against every current
/// `AchievementDefinition.key`; see design doc for the grep results this
/// relies on). A module adding a future streak key must keep using
/// `_streak_` in it, same as today's 8 keys already do.
bool isStreakMilestoneKey(String key) => key.contains('_streak_');
```

### The animation

New `lib/core/widgets/streak_celebration_overlay.dart`:

```dart
/// Shows a brief (900ms in, 700ms hold, 400ms out), skippable celebration
/// over the current screen using an `OverlayEntry` — not a route/dialog,
/// so it never blocks input to the screen underneath and never appears in
/// the back-stack. Tapping anywhere on the overlay dismisses it
/// immediately, same as its auto-dismiss.
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
});
```

Implementation shape: an `OverlayEntry` holding a `Center` with a scaling
+ fading icon (`ScaleTransition`/`FadeTransition` driven by one
`AnimationController`, `Curves.elasticOut` for a bit of "pop") in
`accentColor`, plus the achievement title beneath it, and a lightweight
`CustomPainter` drawing a dozen short colored line segments radiating
outward and fading (a cheap confetti-burst approximation — a handful of
`Path`/`Paint` draws per frame, no particle-physics simulation, no images
decoded). All driven by one `AnimationController` on a single
`Ticker` — nothing GPU-heavier than the existing chart widgets already in
the app (`period_bar_chart.dart`'s `fl_chart` usage sets the bar for
"acceptable animation cost on Nusrat's phone").

### Wiring into the three existing call sites

Each site's existing diff-then-snackbar block gets one extra branch,
**sequenced the same way the undo-snackbar spec already established for
Medicine** (`docs/superpowers/specs/01-must-have/2026-07-21-04-undo
-destructive-actions-design.md`'s "two things can't usefully show at once"
precedent) — the celebration overlay plays first (it's non-blocking, so
this is really "first" not "instead of," see below), then the achievement
snackbar follows once the overlay's future resolves, exactly as the undo
snackbar's `.closed` gates the achievement snackbar today:

```dart
// water_home_screen.dart / prayer_home_screen.dart / medicine_home_screen.dart
final newlyUnlockedKeys = newlyUnlocked.map((r) => r.key);
final streakKey = newlyUnlockedKeys.firstWhereOrNull(isStreakMilestoneKey);
if (streakKey != null && context.mounted) {
  final definition = module.achievementDefinitions
      .firstWhere((d) => d.key == streakKey);
  await showStreakCelebration(
    context,
    title: localizedAchievementTitle(l10n, definition.titleKey),
    accentColor: module.metadata.accentColor,
    icon: module.metadata.icon,
  );
}
if (!context.mounted) return;
// existing achievement-unlock snackbar unchanged, still fires for this
// (and every other) newly-unlocked achievement.
```

Medicine's site additionally already gates on `wasUndone` — the
celebration slots in after that check, same place the achievement
snackbar already sits (`medicine_home_screen.dart:130-152`), so an undone
dose still shows no celebration, consistent with "the achievement stays
unlocked but nothing new is celebrated" not applying here (undo already
skips the achievement snackbar entirely today).

Module accent color: `ModuleMetadata.accentColor`
(`lib/core/modules/habit_module.dart`, already defined per-module, already
read at all three snackbar call sites via `module.metadata` — no new
plumbing).

### l10n keys (both `app_en.arb`/`app_bn.arb`)

None needed for the overlay's own copy — it reuses
`localizedAchievementTitle(l10n, definition.titleKey)`, the same lookup
the achievement snackbar already calls. No new user-facing string exists
that isn't already localized.

## Out of scope

- **Sound.** Explicitly deferred by the original draft (a separate item).
- **Per-module bespoke animation art.** One shared animation shape,
  recolored via `accentColor` — no bespoke Water/Medicine/Prayer variants.
- **Intensity scaling by milestone size** (7 vs. 30 vs. 100 days getting a
  bigger animation). Same animation regardless of which streak threshold
  fired — a v2 nice-to-have, not required for this to land.
- **A settings toggle specifically for this animation.** The existing OS-
  level `MediaQuery.disableAnimations` reduce-motion signal is the only
  suppression path in this spec — a bespoke in-app toggle duplicates a
  signal the OS already provides and the accessibility spec already
  requires honoring; add one later only if user feedback asks for
  something OS-independent.
- **Revoking/replaying a celebration.** If the app is backgrounded mid-
  animation and the achievement diff is re-computed on next resume, the
  celebration simply doesn't replay (the diff no longer shows it as
  "newly" unlocked) — same behavior the achievement snackbar already has
  today, not a new gap this spec introduces.

## Global Constraints

- New files: `lib/core/achievements/achievement_kind.dart`
  (`isStreakMilestoneKey`), `lib/core/widgets/streak_celebration_overlay
  .dart` (`showStreakCelebration`).
- No new dependency — built on `OverlayEntry`/`AnimationController`/
  `CustomPainter`/`MediaQuery.disableAnimations`, all Flutter SDK.
- Each of the three home screens (`water_home_screen.dart`, `prayer_home
  _screen.dart`, `medicine_home_screen.dart`) gets a small addition at its
  existing achievement-diff call site — no new call site, no change to
  `AchievementEngine`/`AchievementRepository`.
- Must not change what `achievements` stores or how `AchievementRepository
  .upsertProgress` decides `unlockedAt` — purely a presentation-layer
  addition riding the existing unlock event.
- Overlay total duration budget: ≤2 seconds auto-dismiss, tap-anywhere
  dismisses immediately — matches the "brief, skippable" goal and the
  app's established non-nagging tone.
