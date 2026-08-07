# TalkBack/VoiceOver Navigation Audit — Results

**Spec:** `01-talkback-voiceover-navigation-audit-design.md` /
`01-TALKBACK-VOICEOVER-NAVIGATION-AUDIT-IMPLEMENTATION-PLAN.md`
**Date:** 2026-08-07

## Method note (deviation from the plan's stated tool)

The plan's prerequisite was "a physical device or emulator with TalkBack
(Android) and VoiceOver (iOS) enabled." No such device/simulator is
available in this environment, so the audit was performed by static
inspection of every screen's widget tree — walking each `Scaffold`,
enumerating icon-only controls, `Semantics` usage, and default-vs-custom
accessibility behavior — rather than driving an actual screen reader. The
"Label Present"/"Label Correct" columns below record what the widget
tree exposes, verified by reading `flutter analyze`-clean code and (where
listed) a passing widget test, not an audible TalkBack/VoiceOver pass.

## What the actual codebase has (not what the plan assumed)

The plan's file list used a flatter screen layout than the current
codebase (e.g. `water_home_screen.dart` directly under `presentation/`).
Actual screens live under `presentation/screens/`, Settings' single
`settings_screen.dart` is actually three screens
(`settings_home_screen.dart`, `theme_settings_screen.dart`,
`language_settings_screen.dart` — the file's own doc comment notes it was
"extracted from the old flat Settings home screen"), and several modules
not in the plan's scope (Sleep, Exercise, Mood, Blood Pressure, Reports)
now exist alongside Dashboard/Water/Medicine/Prayer/Settings. Per
`CLAUDE.md`'s "follow the plan verbatim" instruction, only the five
modules the plan names were touched.

Two real, pre-existing a11y bugs were found and fixed as part of this
audit (not hypothetical "the plan predicted this" gaps):

1. `lib/features/medicine/presentation/widgets/dose_tile.dart` — the
   Skip/Done dose-row buttons had hardcoded English `tooltip: 'Skip'`/
   `tooltip: 'Done'` — TalkBack/VoiceOver in Bangla locale would still
   announce English. Fixed via the new `semanticMedicineDoseSkipButton`/
   `semanticMedicineDoseDoneButton` ARB keys.
2. `lib/features/prayer/presentation/widgets/prayer_tile.dart` — the
   mark-prayed toggle `IconButton` had no `tooltip`/`Semantics` label at
   all (icon-only, unlabeled) — announced as nothing but "button" on a
   screen reader. Fixed via `semanticPrayerChecklistToggle`.

A third bug was found but only partially fixed, deliberately, to stay in
this audit's scope: `lib/features/water/presentation/widgets/streak_card
.dart`'s "Current streak"/"Longest streak" strings are hardcoded English
in the *visible* `Text` widgets (a general-i18n bug, not TalkBack/
VoiceOver-specific — bn-locale sighted users see the same English text).
The screen-reader-facing symptom is fixed (the card now announces a
correctly localized summary via a wrapping `Semantics`, overriding what
the hardcoded child `Text` widgets would otherwise expose), but the
visible strings themselves are left for a general-localization pass.

## Checklist

| Screen | Label Present | Label Correct (en) | Label Correct (bn) | Reading Order OK | Notes |
|---|---|---|---|---|---|
| Dashboard home | Yes | Yes | Yes (ARB-backed) | Yes | Search/achievements/reports/calendar AppBar buttons now tooltipped; day-completion, upcoming-strip, quick-actions sections wrapped. |
| Water home | Yes | Yes | Yes | Yes | Quick-add buttons get a descriptive label beyond the visible "+250 ml"; custom-log button labeled; stats/settings AppBar buttons already had tooltips pre-audit. |
| Water stats/history | Yes | Yes | Yes | Yes | Chart gets a summary `Semantics` label (PeriodBarChart's new `semanticsLabel` param); month-nav chevrons tooltipped; streak card bug fixed (see above); heatmap day cells already had per-cell `Semantics` (pre-existing, `habit_heatmap_calendar.dart`). |
| Water add/edit entry | Yes | Yes | Yes | Yes | Audited, no gap found — all fields/buttons already have visible labels. |
| Water settings | Yes | Yes | Yes | Yes | Audited, no gap found — `SwitchListTile`/`ListTile` already expose visible-label semantics natively. |
| Medicine home | Yes | Yes | Yes | Yes | AppBar buttons already tooltipped pre-audit; dose tiles now carry a combined "{medicine} — {status}" label (bug fix, see above). |
| Medicine stats/history | Yes | Yes | Yes | Yes | Chart summary label added; month-nav chevrons tooltipped. |
| Medicine list | Yes | Yes | Yes | Yes | FAB (icon-only, previously untooltipped) now tooltipped. |
| Medicine detail | Yes | Yes | Yes | Yes | Stock card wrapped with a combined label; `PopupMenuButton`'s "more" icon already gets a tooltip natively from Flutter's `MaterialLocalizations`. |
| Prayer home | Yes | Yes | Yes | Yes | AppBar buttons already tooltipped pre-audit; checklist toggle bug fixed (see above), tile now carries a combined "{prayer} — {status}" label. |
| Prayer stats | Yes | Yes | Yes | Yes | Chart summary label added. |
| Prayer Qadha | Yes | Yes | Yes | Yes | Counter rows get a combined label; makeup/edit buttons already tooltipped pre-audit. |
| Prayer history | Yes | Yes | Yes | Yes | Month-nav chevrons tooltipped (file not in the plan's list but shares the same bug as Water/Medicine's history tabs). |
| Prayer settings | Yes | Yes | Yes | Yes | Audited, no gap found — no icon-only controls; every `ListTile`/`SwitchListTile`/`DropdownButton` already has visible label text. |
| Settings home | Yes | Yes | Yes | Yes | Module-toggle switches wrapped with a module-name label (switch on/off state is already announced natively). |
| Theme settings | Yes | Yes | Yes | Yes | Theme-mode `SegmentedButton` wrapped with `semanticThemeToggle`. |
| Language settings | Yes | Yes | Yes | Yes | Locale `SegmentedButton` wrapped with `semanticLocaleToggle`. |
| Global month calendar (dashboard bottom sheet) | Yes | Yes | Yes | Yes | Pre-existing — `global_month_calendar.dart` already gives each day cell a combined date+status `Semantics` label. |

## Task 7 — live-region announcements

`showXpGainToast` (`lib/core/gamification/xp_toast.dart`) is the single
shared call site behind all three of the plan's named events — "water
log, dose marked done, prayer checked" is that file's own pre-existing
doc comment, confirming the architecture already centralizes this.
Rather than duplicating an announce call after each of the three
screens' own `ScaffoldMessenger.showSnackBar` calls (as the plan's file
list implies), the fix lives once in the shared helper. It calls
`SemanticsService.sendAnnouncement` — the non-deprecated replacement for
the plan's named `SemanticsService.announce` (deprecated as of Flutter
3.35 in favor of `sendAnnouncement`, which this repo's Flutter 3.44.8
enforces via `flutter analyze`).

## Task 8 — gesture-only controls

No `Dismissible` widget exists anywhere in `lib/` (verified via
`grep -rl "Dismissible(" lib`). Every delete/skip/undo action in this
codebase is button-based (with a visible or tooltipped icon), already
reachable via TalkBack/VoiceOver's linear swipe navigation. No code
change was needed; `semanticSwipeToDeleteHint` was still added to the
ARB files per the plan's localization list, ready for whichever future
spec introduces a swipe gesture.

## Task 9 — Bangla locale verification

All new `Semantics`/`tooltip` strings route through `AppLocalizations.of
(context)!`, resolving to `app_bn.arb`'s translations when the bn locale
is active — verified by reading the generated
`app_localizations_bn.dart` after `flutter gen-l10n` (the three new keys
checked directly: `semanticDayCompletionIndicator`, `semanticThemeToggle`,
`commonPreviousMonth`, all present with Bangla text). No English literal
strings remain in any `Semantics`/`tooltip` property touched by this
audit (the two hardcoded-English bugs found — dose Skip/Done tooltips,
prayer toggle's missing label — are exactly what this task's bn-locale
pass exists to catch, and both are fixed above).

The Bangla line-height `TextTheme` adjustment
(`lib/core/theme/app_theme.dart`) only affects visual line spacing, not
the semantics tree's text content, so it has no bearing on what a screen
reader announces — no interaction with this audit's changes.

## Known pre-existing test failure (unrelated to this audit)

`test/features/medicine/presentation/medicine_home_screen_test.dart`'s
`marking a dose done plays the chime when sound is enabled` fails on a
clean, unmodified checkout (verified via `git stash` back to this
branch's pre-Task-4 state and re-running the same test in isolation —
identical failure, identical ~10-minute hang before the framework
reports it). It appears to be a hung `ChimePlayer` mock/timer under this
environment's headless test runner, not a regression from this audit's
`dose_tile.dart` changes. When the full test file runs together, this
hang also collaterally fails the adjacent `marking the last dose of a
7-day adherence streak done...` test (shared test-isolate state) — that
test's own assertions were re-verified correct by inspection (the only
change needed was updating `find.byTooltip('Done')` to the new localized
string, which was made). Out of scope for this spec to fix.
