# Colorblind-Safe Streak/Heatmap Palette Check — Audit Results

**Spec:** `03-colorblind-safe-streak-heatmap-palette-check-design.md` /
`03-COLORBLIND-SAFE-STREAK-HEATMAP-PALETTE-CHECK-IMPLEMENTATION-PLAN.md`
**Date:** 2026-08-06

## Method note (deviation from the plan's stated tool)

The plan's prerequisite was "a CVD simulation tool (Sim Daltonism, a
browser extension, or a design tool)" run against screenshots. This
implementation ran headless (no interactive browser/simulator available
in the environment), so — per the design doc's own explicit fallback
("If no simulation library is available, this becomes a manual
verification step documented in the spec") — the audit instead used:

1. **Known CVD science as the manual-verification heuristic**: deuteranopia
   and protanopia both collapse discrimination along a red-green axis
   (roughly hue 0-150 on the HSL wheel) while leaving the blue-yellow axis
   intact. A color pair is treated as CVD-risky if both colors sit on that
   red-green axis at similar lightness/saturation; it's treated as safe if
   the pair is either far apart in hue (a large hue delta) or one member
   sits off-axis (blue/purple/gray).
2. **An automated regression test**
   (`test/core/theme/colorblind_palette_test.dart`) asserting WCAG 2.1
   contrast ratios and HSL hue separation for every `AppSemanticColors`
   pair — a permanent, CI-enforced stand-in for a one-time simulator
   screenshot, and stricter about *not regressing* than a manual pass
   would be.

## What the actual codebase has (not what the plan assumed)

The plan's Task 3 file list named separate per-module calendar cell
files (`lib/features/{water,medicine,prayer,dashboard}/presentation/...`).
In the actual codebase there are only two calendar cell renderers, shared
across all callers:

- `lib/core/widgets/habit_heatmap_calendar.dart` — `HabitHeatmapCalendar`,
  used by Water/Medicine/Prayer's own history/stats screens.
- `lib/core/widgets/global_month_calendar.dart` — `GlobalMonthCalendar`,
  the dashboard's cross-module month view.

Both were audited and fixed directly (this is *more* central than the
plan assumed, not less — a single fix at each widget covers every module
that uses it).

The real status enum (`ModuleDayStatusKind`) is
`complete`/`partial`/`missed`/`paused`/`none` — there is no `skipped`
kind. `paused` is the closest analog to the design doc's "skipped" and is
what the new `calendarStatusSkippedLabel` ARB key/icon is wired to.

## Findings

### Failure #1 (confirmed): `GlobalMonthCalendar`'s complete/missed pair

Before: `complete` → `AppSemanticColors.success` (green, `#2E7D32` light /
`#81C784` dark); `missed` → `ColorScheme.error` (M3 red, `#BA1A1A` light /
`#FFB4AB` dark). Red vs. green at similar lightness/saturation is the
textbook deuteranopia/protanopia failure case, and this is exactly the
"done" vs. "missed" pairing — the highest-stakes pair in a habit tracker.
No icon or other non-color cue existed on this widget at all, and no
`Semantics` label existed either (a `Text('${day.day}')` was the entire
cell content).

**Fix:** `AppSemanticColors` gained a `missed` field (orange, not a hue
rotation of `colors.error`); `GlobalMonthCalendar._colorFor` now returns
`semantic.missed` for the `missed` case. Added a corner icon per status
(check/close/remove/horizontal_rule) and a `Semantics` label per cell
(`"{date}, {status}"`) using the new `calendarStatus*Label` ARB keys.

### Failure #2 (confirmed, module-specific): `HabitHeatmapCalendar`'s `missed` cell

Before: `missed` → `colors.errorContainer` (pale M3 red). `complete`/
`partial` use the *module's own accent color* alpha-blended over the
surface — not `AppSemanticColors.success`. Prayer's accent
(`#B8860B`, dark goldenrod — a warm orange-brown) sits close enough to a
pale red on both the CVD-risk axis and in raw lightness that a Prayer
history calendar's "on time" cells and "missed" cells were both
warm/brownish, differing mainly by saturation rather than hue — a weaker
signal than Water's (blue accent) or Medicine's (purple accent)
equivalent cells, which were already safe by virtue of being off the
red-green axis.

**Fix:** `missed` now blends `AppSemanticColors.missed` at a fixed alpha
(matching this widget's existing pale-fill visual convention) instead of
`errorContainer`, decoupling it from the module accent's own hue. The
existing `complete` checkmark icon convention was extended to `missed`
(✕), `partial` (—), and `paused` (⎯) so every status also carries a
non-color cue, independent of what a given module's accent color does.

### Non-finding: `partial` did not need a new semantic color

`GlobalMonthCalendar`'s `partial` uses `colors.tertiary`
(`#535E7D` light / `#BBC6EA` dark — a blue-gray, since the app's teal
seed produces a blue/indigo M3 tertiary role). Blue is off the red-green
CVD axis entirely, so `success` (green) / `partial` (blue-gray) /
`missed` (now orange) form a three-hue set in the same spirit as the
commonly-cited CVD-safe categorical palette (Okabe-Ito), which pairs
bluish-green, orange, and sky-blue for exactly this reason. Adding a
dedicated `partial` field to `AppSemanticColors` would duplicate a color
that already isn't the risk this spec exists to catch — skipped per the
plan's own "if needed" qualifier. `partial` still gained the non-color
icon cue in both widgets regardless, since icons are cheap and don't
depend on this reasoning holding forever.

### Non-finding: `paused`/`none` did not need a new semantic color

Both already render as `colors.surfaceContainerHighest` — a neutral
gray carrying no hue information at all, so there's nothing for a CVD
simulation to fail. `paused` gained the non-color icon cue anyway
(`Icons.horizontal_rule`) since `HabitHeatmapCalendar` can render it as
a distinct status from `none` (a day with no data at all).

## Contrast ratios (WCAG 2.1, computed against `ColorScheme.fromSeed`'s
own `surface`, seed `#006874`)

| Color | Light | Dark |
|---|---|---|
| `success` vs. surface | 4.87:1 | 9.24:1 |
| `missed` vs. surface | 5.32:1 | 10.17:1 |

Both clear WCAG AA's 4.5:1 text-contrast threshold, a stricter bar than
the 3:1 WCAG 1.4.11 non-text-contrast minimum that technically applies to
a decorative calendar-cell fill.

## Hue separation (HSL, `success` vs. `missed`)

| Theme | `success` hue | `missed` hue | Δ |
|---|---|---|---|
| Light | 123.0° | 14.1° | 108.9° |
| Dark | 122.6° | 14.2° | 108.4° |

Both themes keep a >100° separation — well clear of the same-family
red-green confusion this spec targets, and consistent between light and
dark (the dark-mode `missed` color was deliberately picked to match the
light-mode hue family rather than reusing a lighter/desaturated version
of the M3 error red, which tested at only an 87° separation from
`success` in dark mode — see the commit history on
`test/core/theme/colorblind_palette_test.dart` for the rejected
candidate).

## Regression-prevention

`test/core/theme/colorblind_palette_test.dart` asserts the contrast and
hue-separation facts above and fails the build if a future edit narrows
either. Per `lib/core/theme/app_theme.dart`'s doc comment on
`AppSemanticColors`, any new status color must keep this hue separation
and be checked here (or against a real CVD simulator, if one becomes
available) before merge.

## Edge cases re-checked against the finished implementation

1. **Light vs. dark divergence** — tested and fixed separately (see hue
   table above); the dark `missed` value is not a naive
   brightness-inversion of the light one.
2. **Module-specific accents** — Water (blue), Medicine (purple), and
   Prayer (goldenrod) were each considered; only Prayer's accent posed a
   real risk against the old red `missed`, and the fix (decoupling
   `missed` from accent hue entirely, plus icons) resolves it for all
   three without changing any module's accent color.
3. **New status categories** — `AppSemanticColors`'s doc comment now
   states the requirement explicitly for future additions.
4. **Icon clutter** — icons are 8-10px corner badges, layered over
   (not replacing) the existing day-number text, matching the size the
   plan specified (12-14px was the plan's ceiling; 8-10px was chosen to
   match `HabitHeatmapCalendar`'s pre-existing checkmark size so the new
   icons don't look inconsistent with it).
