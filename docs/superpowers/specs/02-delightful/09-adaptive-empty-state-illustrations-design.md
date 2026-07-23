# Adaptive Empty-State Illustrations Per Module

**Category:** Delightful · **Atlas complexity:** S · **Retention impact:** Low-Medium
**Date:** 2026-07-23
**Status:** Draft — pending review

## Problem

Each module's primary screen already renders a first-run empty state, but
it's a single `Center(child: Text(...))` per module — no icon, no color,
no illustration, just a plain string:

- **Water** — `WaterHomeScreen` (`lib/features/water/presentation/screens/
  water_home_screen.dart:132-135`): when `_visibleEntries(progress.entries)
  .isEmpty`, renders `Padding(child: Text(l10n.waterHomeEmptyLogs))` inline
  in the log list (not even a full-screen state — this is "no entries
  logged today yet," always reachable since goal/quick-add UI renders
  above it regardless).
- **Medicine** — two separate empty states, both plain text: `medicine_
  home_screen.dart:56` (`Center(child: Text(l10n.medicineHomeEmpty))`,
  "No doses scheduled for today") and `medicine_list_screen.dart:81-88`
  (`medicineListEmpty`/`medicineListArchivedEmpty`, "No medicines yet" —
  the actual first-run-before-any-data state, since a brand-new install
  has zero `Medicine` rows and therefore zero doses to schedule).
- **Prayer** — `prayer_home_screen.dart:55-56`:
  `Center(child: Text(l10n.prayerHomeEmpty))`, "No prayers scheduled for
  today."

None of these three use an icon, illustration, or module accent color —
just `Theme.of(context)`'s default text color on the default background.
Each module already has a distinct accent (`ModuleAccents.water`
`0xFF1565C0`, `.medicine` `0xFF5E35B1`, `.prayer` `0xFFB8860B` — `lib/core/
theme/app_theme.dart:11-22`), but nothing on these screens references it
today — `ModuleAccents` is currently only consumed by dashboard tiles/nav
icons per its own doc comment. `flutter_svg` is **not** a dependency
(checked `pubspec.yaml` — only `fl_chart`, no SVG/vector-asset package of
any kind), and there is no `assets/illustrations/` directory — `pubspec
.yaml`'s only registered asset is `assets/data/prayer_cities.json` plus
the launcher-icon/splash images consumed by `flutter_launcher_icons`/
`flutter_native_splash` config, not by app code.

The genuine first-run empty state per module (the one worth illustrating)
is: Water — no entries logged today (`waterHomeEmptyLogs`); Medicine — no
medicines added at all (`medicineListEmpty`, not `medicineHomeEmpty`,
which fires equally for "you have medicines but none are due today" — a
returning-user state, not first-run); Prayer — `prayerHomeEmpty` (a
brand-new install has no `prayer_records` for today until the module's
own materialization runs, which happens on first Prayer-tab open).

## Design

**Recommendation: `CustomPainter`-drawn vector illustrations, not bundled
SVG/PNG assets.** Zero new dependency (no `flutter_svg`), zero new asset
pipeline (no `assets/illustrations/*.svg` to source/license/maintain),
zero app-size cost, and trivial to theme — a `CustomPainter` takes
`ModuleAccents.water`/`.medicine`/`.prayer` directly as a `Color`
constructor argument, painted with plain `Canvas` primitives (circles,
rounded rects, arcs — a water-drop, a pill-and-calendar glyph, a
crescent-and-mat glyph are all well within 15-30 lines of `Canvas` calls
each). A licensed illustration set would need per-module recoloring
anyway (SVG tinting in Flutter means either pre-baked per-accent-color
assets, multiplying the asset count by 3, or `ColorFilter.mode` tinting
that only works for single-color art) — the `CustomPainter` route gets
that "already in module accent color" property for free since it paints
with the color directly, and needs no `flutter_svg` runtime SVG parser
at all.

**New file: `lib/core/widgets/module_empty_state.dart`**

```dart
/// Shared empty-state widget for a module's primary screen — an icon-sized
/// vector illustration in [accentColor] above a message line. Replaces the
/// bare `Center(child: Text(...))` each module renders today.
class ModuleEmptyState extends StatelessWidget {
  const ModuleEmptyState({
    super.key,
    required this.painter,
    required this.message,
    required this.accentColor,
  });

  /// Module-specific illustration, e.g. [WaterDropPainter.new].
  final CustomPainter Function(Color color) painter;
  final String message;
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

**Three new painters, one file each** (kept alongside the widget, not
inside each module — they're generic vector art, not module-domain
logic): `lib/core/widgets/illustrations/water_drop_painter.dart` (a
single teardrop path + a smaller highlight circle), `.../pill_calendar_
painter.dart` (a rounded-rect calendar outline + a capsule shape
overlapping its corner), `.../crescent_mat_painter.dart` (a crescent arc
via `Path.arcTo` + a small rounded-rect "mat" beneath it). Each
constructor takes the single `Color` to paint with — no gradient, no
per-theme variant beyond that one color, so light/dark mode is already
handled: the same illustration on `accentColor` reads fine on both
`ColorScheme.fromSeed` backgrounds since `ModuleAccents` colors are fixed
(not scheme-derived), same as today's dashboard tiles.

**Call-site changes** (swap the `Text`-only branch for `ModuleEmptyState`,
no change to the surrounding `if`/`else` structure):

- `water_home_screen.dart:132-135` → `ModuleEmptyState(painter:
  WaterDropPainter.new, message: l10n.waterHomeEmptyLogs, accentColor:
  ModuleAccents.water)`, still inside the existing log-list `Padding`
  slot (this one stays inline, not full-screen, since goal/quick-add UI
  renders above it either way).
- `medicine_list_screen.dart:81-88` → same swap for `medicineListEmpty`/
  `medicineListArchivedEmpty` with `PillCalendarPainter.new` and
  `ModuleAccents.medicine`. `medicine_home_screen.dart:56`
  (`medicineHomeEmpty`, the "nothing due today" case) is explicitly left
  as plain `Text` — see Out of scope.
- `prayer_home_screen.dart:55-56` → `CrescentMatPainter.new` +
  `ModuleAccents.prayer` for `prayerHomeEmpty`.

No new l10n keys — the existing `waterHomeEmptyLogs`/`medicineListEmpty`/
`medicineListArchivedEmpty`/`prayerHomeEmpty` strings are reused verbatim
in both `app_en.arb`/`app_bn.arb`.

## Out of scope

- **`medicineHomeEmpty`** ("no doses scheduled for today") — a returning-
  user state (you have medicines, just none due today), not first-run;
  illustrating it the same way would misrepresent "empty" as "nothing to
  do here ever," which is wrong for that specific message. Stays plain
  `Text`.
- **Animated illustrations.** Static `CustomPainter` output only — an
  `AnimationController`-driven variant is a materially larger scope
  (frame-by-frame path interpolation or a `Tween` on painted geometry)
  for a first-run screen a user sees once.
- **Dashboard/Settings/Reports empty states** (`emptyDashboardMessage`,
  `reportsEmptyState`) — out of scope; those aren't per-module and don't
  have an accent color to apply.
- **Secondary empty states** (Water/Medicine stats history-empty,
  `waterStatsHistoryEmpty`) — only each module's single primary-screen
  first-run state gets the illustration treatment.
- **Bangla-specific art variants.** The illustrations are purely visual
  (shapes, no embedded text/glyphs), so `app_en.arb`/`app_bn.arb` only
  ever affect the message line below the art, never the painter.
- **A bundled SVG/PNG asset pipeline.** Explicitly rejected above in favor
  of `CustomPainter` — revisit only if a future illustration needs detail
  genuinely beyond what `Canvas` primitives can express tastefully.

## Global Constraints

- No new dependency. `flutter_svg` is not added — confirmed absent from
  `pubspec.yaml`'s `dependencies:` block today, and this design keeps it
  that way.
- No new assets, no `pubspec.yaml` `assets:` entry — every illustration is
  drawn code, not a bundled file.
- No l10n changes — all three call sites reuse existing arb keys.
- No schema/migration/settings changes — purely `presentation/` layer.
- New files: `lib/core/widgets/module_empty_state.dart`,
  `lib/core/widgets/illustrations/water_drop_painter.dart`,
  `lib/core/widgets/illustrations/pill_calendar_painter.dart`,
  `lib/core/widgets/illustrations/crescent_mat_painter.dart`.
- Modified files: `water_home_screen.dart`, `medicine_list_screen.dart`,
  `prayer_home_screen.dart` (one `Text` → `ModuleEmptyState` swap each,
  no structural change to surrounding widgets).
