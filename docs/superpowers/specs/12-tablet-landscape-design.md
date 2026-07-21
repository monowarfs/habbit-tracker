# Tablet / Landscape Layout Pass — Phase 1 (Responsive Shell + Two Screens)

**Date:** 2026-07-21
**Status:** Draft — pending review

## Problem

The Feature Atlas gap-analysis (Must Have, complexity M) flags: "current
shell assumes phone portrait." A codebase check confirms this literally —
there is no `MediaQuery.sizeOf`/`LayoutBuilder`/`NavigationRail`/breakpoint
logic anywhere under `lib/` (grepped for all four; zero hits). Specifically:

1. **`lib/core/router/app_router.dart`** builds one `StatefulShellRoute`
   with `AppScaffold` as its shell — no width-based branching at all.
2. **`lib/core/widgets/app_scaffold.dart`** always renders
   `Scaffold(bottomNavigationBar: NavigationBar(...))`, regardless of
   screen width. Material 3's own guidance is bottom `NavigationBar` on
   compact (phone) widths but `NavigationRail` from medium width (≥600dp)
   up — this is the single change that affects every screen in the app,
   since every screen sits inside this one shell. (The file also carries
   a stale `// ponytail:` comment about hardcoded tabs "until Run 06+" —
   module_registry has had real entries since Run 06; the comment is
   about tab iteration, not the nav-widget-type gap this spec addresses,
   so it's left alone here.)
3. Sampled screens confirm the shell gap is the *only* structural
   problem, not a symptom of pervasive fixed-width code — most screens
   (`DashboardScreen`, `WaterHomeScreen`, `WaterStatsScreen`, etc.) are
   already `ListView`/`Column` stacks with no hardcoded widths, so they
   reflow vertically without crashing or clipping on a wider screen. But
   two are visibly *worse*, not just "extra whitespace," on a tablet:
   - **`DashboardScreen`** (`lib/features/dashboard/presentation/screens/dashboard_screen.dart`)
     — `ListView(padding: EdgeInsets.all(16))` stretches every child to
     full screen width. On a ~1024dp-wide tablet landscape, the
     `_QuickActionsRow`'s `Wrap` spreads its buttons across nearly the
     full width with large dead gaps between them, and each module's
     `dashboardSummary(ref)` card (a bounded-content card, not designed
     for near-1000dp width) stretches sparse and thin.
   - **`WaterStatsScreen`** (`lib/features/water/presentation/screens/water_stats_screen.dart`)
     — its Stats tab puts `PeriodBarChart` (`lib/core/widgets/charts/period_bar_chart.dart`,
     fixed `height: 200`, 12px-wide bars) inside the same full-width
     `ListView`. `fl_chart`'s `BarChart` fills whatever width it's given,
     so on a tablet the same handful of 12px bars spread across ~1000dp
     with huge gaps — this is the worst-looking case since it's a data
     visualization, and this exact widget is shared by Medicine's stats
     screen too (per `CLAUDE.md`), so the same distortion already exists
     there.
4. No tablet-specific platform config exists to build on or worry about
   breaking: `pubspec.yaml` has no responsive-layout package;
   `android/app/src/main/AndroidManifest.xml`'s `configChanges` is the
   unmodified Flutter template default (not a tablet customization);
   `ios/Runner/Info.plist` already declares full portrait+landscape
   orientation support for iPad (`UISupportedInterfaceOrientations~ipad`)
   — also the unmodified Flutter template default. Rotation/landscape is
   already OS-permitted on both platforms; nothing here is about
   *enabling* landscape, only about *reflowing* content once the OS is
   already free to present it at tablet width.

## Design

**Phased, minimal-viable scope** — this is a cross-cutting M-complexity
feature; the goal of this round is the one shared choke point plus the
two screens confirmed broken above, not a screen-by-screen redesign.

### Phase 1 — shared responsive breakpoint helper (the leverage point)

New `lib/core/widgets/responsive_breakpoints.dart`:

```dart
/// Material 3's compact/medium width boundary (`m3.material.io/foundations
/// /layout/applying-layout/window-size-classes`) — below this, phone-style
/// bottom nav; at or above it, side nav.
const double kTabletBreakpointWidth = 600;

/// True once [context]'s width reaches the medium size class.
bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kTabletBreakpointWidth;
```

`MediaQuery.sizeOf` (not `MediaQuery.of(context).size`) so the widget only
rebuilds on width/height changes, not unrelated `MediaQuery` churn
(padding, text scale, etc.) — Flutter's own documented reason the
`sizeOf`/`paddingOf`/etc. family exists.

Same file also exports `MaxContentWidth`, a tiny wrapper:

```dart
/// Caps content at a comfortable reading/card width on wide screens,
/// centered; a no-op below the cap (ConstrainedBox only clips when the
/// incoming width exceeds [maxWidth], so this is safe to wrap
/// unconditionally — no [isWideLayout] gating needed).
class MaxContentWidth extends StatelessWidget {
  const MaxContentWidth({required this.child, this.maxWidth = 840, super.key});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
```

840dp is M3's expanded-class threshold and a common reading-width cap;
picked so it's a genuine no-op on every phone width in the codebase's
existing test viewports and only engages on tablet-class widths.

### Phase 2 — `AppScaffold` nav switch (highest-leverage single edit)

`lib/core/widgets/app_scaffold.dart`'s existing `destinations` list is
already just icon/selectedIcon/label data per tab — keep that list as the
single source of truth and derive both nav widget types from it, instead
of duplicating tab metadata:

- width `< kTabletBreakpointWidth` (today's only path): unchanged —
  `Scaffold(bottomNavigationBar: NavigationBar(destinations: ...))`.
- width `>= kTabletBreakpointWidth`: `Scaffold(body: Row(children: [
  NavigationRail(destinations: ..., selectedIndex: ..., onDestinationSelected: ...),
  const VerticalDivider(width: 1), Expanded(child: navigationShell) ]))`
  — no `bottomNavigationBar`.

This is the one change that touches every screen in the app for free,
since every screen already lives inside this shell.

### Phase 3 — the two confirmed-broken screens

- **`DashboardScreen`**: wrap the existing `ListView`'s content in
  `MaxContentWidth` (the `ListView` itself stays — just gains an outer
  constraint). Stops the `Wrap`/summary cards from stretching sparse on
  wide screens; no new grid or two-pane layout.
- **`WaterStatsScreen`**: same treatment — wrap both tabs' `ListView`
  content in `MaxContentWidth`. Caps `PeriodBarChart` at a sane width so
  bars stop spreading across a near-1000dp chart. (Medicine's stats
  screen reuses the same `PeriodBarChart` widget per `CLAUDE.md` and will
  visibly have the same problem — explicitly deferred, see below, since
  it wasn't part of the sampled/confirmed set and this round stays to
  the two screens actually inspected.)

### Explicitly deferred (not this round)

- **Every other screen** (Medicine/Prayer home, stats, detail, list,
  add-form; Settings' screens; achievement gallery; reports screen) —
  already reflows acceptably via existing `Column`/`ListView` vertical
  stacking; nothing sampled there showed a broken layout, only extra
  side whitespace at most. Revisit case-by-case if a specific screen is
  flagged as bad in practice, starting with Medicine's stats screen
  (same `PeriodBarChart` widget as Water's, noted above) as the most
  likely next candidate.
- **Two-pane / master-detail layouts** (e.g. a list + detail side by
  side on wide screens, for Water/Medicine history or Prayer's Qadha
  screen) — a real tablet UX improvement, but a separate, larger design
  than "don't look broken."
- **`NavigationDrawer`** for the expanded/desktop size class (≥840dp) —
  M3 allows `NavigationRail` alone to scale further; only worth adding if
  desktop/large-tablet support becomes an explicit target.
- **Orientation-specific (not just width-based) logic** — this spec is
  purely about reflowing by available width, mirroring how
  `isWideLayout` is computed; a phone rotated to landscape that's still
  narrower than 600dp keeps today's bottom-nav behavior, which is
  correct per M3 guidance (it's about size class, not orientation).
- **Golden-image tablet screenshot test suite** — one widget test is
  enough for v1 (see Global Constraints).

## Out of scope

- Any change to phone-portrait visuals or behavior — widths below
  `kTabletBreakpointWidth` must render byte-identical to today.
- Enabling landscape/rotation itself — already OS-permitted on both
  platforms per the Info.plist/AndroidManifest check above; nothing to
  change there.
- Any new dependency — `NavigationRail`, `MediaQuery.sizeOf`, and
  `ConstrainedBox`/`Align` are all existing Flutter SDK widgets, no
  `flutter pub add`.
- Medicine's and Prayer's own screens, Settings screens, Reports,
  Achievement gallery — explicitly deferred above.
- Foldables/hinge-aware layout (`display_features`) — a further-out
  concern than "tablet landscape," not raised by the gap-analysis entry.

## Global Constraints

- One breakpoint constant, defined once: `kTabletBreakpointWidth = 600`
  in `lib/core/widgets/responsive_breakpoints.dart`. No other file
  hardcodes a width threshold.
- Width checks use `MediaQuery.sizeOf(context)`, never
  `MediaQuery.of(context).size`.
- `AppScaffold`'s per-tab icon/selectedIcon/label data is defined once
  and mapped to both `NavigationDestination` (phone) and
  `NavigationRailDestination` (tablet) — no duplicated tab list.
- `MaxContentWidth`'s default cap is 840dp; only `DashboardScreen` and
  `WaterStatsScreen` adopt it this round.
- New widget test (`test/core/widgets/app_scaffold_test.dart` or
  colocated with the existing router test) asserting: at width 400,
  `NavigationBar` is present and `NavigationRail` is absent; at width
  800, the reverse.
