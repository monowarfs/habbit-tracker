# Gentle No-Guilt Missed-Dose Copy Pass

**Category:** Delightful · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — implementation-ready

## Problem

This is a content audit, not a code feature — no state machine, no
screen, no route changes. The persona work (Rafiq: "slowly rebuild
prayer consistency without a judgmental or preachy app tone"; Qadha
tracking "without guilt-tripping UI copy") names a real risk, but the
actual codebase surface it applies to is small and **already mostly
neutral**. Grepping both `lib/core/l10n/app_en.arb` and
`lib/core/l10n/app_bn.arb` for every key whose value matches `missed`,
`skip(ped)`, `overdue`, or `qadha` turns up exactly 8 user-facing string
keys (plus 2 dev-only `@`-description comments, which don't ship). Most
of the wording is already fine — Finch's own bar ("neutral information,
not a scolding") is largely met by the text alone. **The real guilt
signal in this codebase is carried by color, not words, and only in one
of the two modules that has a "missed" concept:**

- `lib/features/medicine/presentation/widgets/dose_tile.dart:57-60` —
  `MedicineDoseStatus.missed` renders with `theme.colorScheme.error`
  (Material's error/red role), while `MedicineDoseStatus.skipped`
  (line 61-64) uses the neutral `theme.colorScheme.outline`. The same
  status kind gets a CircleAvatar background at `alpha: 0.15` of that
  error color (line 74) plus an error-colored `Icons.medication` icon
  (line 75) — a visibly "alarmed" red badge next to the word "Missed".
- `lib/core/widgets/habit_heatmap_calendar.dart:79-81` — the **shared**
  heatmap widget used by Water/Medicine/Prayer's history/stats screens
  renders `ModuleDayStatusKind.missed` days with `colors.errorContainer`
  (comment on line 80: "matches PrayerHistoryScreen's existing choice"),
  so Prayer's missed-day cells get the same red-family treatment even
  though Prayer's own tile-level rendering doesn't otherwise use red.
- By contrast, `lib/features/prayer/presentation/widgets/prayer_tile.dart:66-78`
  renders a missed prayer as a bare `Icons.cancel_outlined` with **no**
  color override (`color: null` for the non-prayed branch) — Prayer's
  own tile is already neutral; the heatmap calendar is the one place
  that pulls it back toward red.

There is also one **non-localized** hardcoded string directly in the
missed-dose surface: `lib/features/medicine/presentation/screens/
medicine_detail_screen.dart:109-113` builds
`'Last 30 days: $takenPct% taken (${stats.missed} missed, ${stats.skipped}
skipped)'` and `'No dose history yet'` as raw Dart string literals — not
ARB keys, not translated, not audited by any existing copy pass. Worth
folding into this pass since it's the exact category this spec covers,
even though it wasn't caught by the `.arb` grep.

One more data point worth citing rather than ignoring: **Bangla is
already gentler than English in one case**, which argues for matching
English *to* Bangla rather than the reverse. See row 7 below.

## Design — the actual audit

All 8 real keys, current value, and proposed rewrite. Every "no change"
row is a deliberate finding, not an omission — padding this table with
invented problems would defeat the point of an audit.

| # | Key (both files) | Current EN | Current BN | Where rendered / colored | Verdict | Proposed EN | Proposed BN |
|---|---|---|---|---|---|---|---|
| 1 | `medicineDoseStatusMissed` | "Missed" | "মিস হয়েছে" | `dose_tile.dart:57-60`, `theme.colorScheme.error` (red icon + badge) | **Guilt signal — color, not word.** "Missed" alone is standard, neutral habit-app vocabulary (Finch itself uses it). The problem is pairing it with the error/red role, which visually reads as "you did something wrong." | Keep text ("Missed"). Code change (not an ARB change): switch the color mapping from `theme.colorScheme.error` to `theme.colorScheme.outline` — the same neutral treatment already used for `skipped` two lines below. No new key needed. | Keep text ("মিস হয়েছে"). Same color fix. |
| 2 | `medicineDoseStatusSkipped` | "Skipped" | "এড়িয়ে যাওয়া হয়েছে" | `dose_tile.dart:61-64`, `theme.colorScheme.outline` (neutral) | **Already correct** — neutral word, neutral color. Reference point for row 1's fix. | No change. | No change. |
| 3 | `medicineStatsMissedDosesLabel` | "Missed doses" | "মিস হওয়া ডোজ" | `medicine_stats_screen.dart:101`, plain section header, no color | **Fine as-is** — a factual list-section label describing aggregate data, not addressed at the user in the second person. Finch itself still uses "missed" in stats/history contexts; the guilt vector is tone-in-context (exclamation marks, red, "you failed"), which this has none of. | No change. | No change. |
| 4 | `medicineStatsNoMissedDoses` | "None — great adherence!" | "কোনোটি নেই — দুর্দান্ত!" | `medicine_stats_screen.dart:107` | **Already good** — positive framing on the zero-missed case, exactly the kind of copy Finch's tone aims for. | No change. | No change. |
| 5 | `heatmapCellMissedSemantics` | "{date}, missed, {value}" | "{date}, মিস হয়েছে, {value}" | `habit_heatmap_calendar.dart:112`, screen-reader-only `Semantics` label | **Low priority** — never visible to sighted users, purely a factual accessibility label. Still worth minor softening for parity with row 1's tone if this pass is touching the file anyway, but not a blocker. | Optional: "{date}, not completed, {value}" — softer without losing information. | Optional matching bn tweak: "{date}, সম্পন্ন হয়নি, {value}" |
| 6 | `prayerStatusMissed` | "Missed" | "কাজা হয়েছে" | `prayer_tile.dart:96`, `Icons.cancel_outlined`, **no color override** (neutral already); also rendered via the shared heatmap (`errorContainer`, see row 8) | **Split verdict.** The tile itself is already neutral. But the Bangla translation isn't a literal translation of "Missed" at all — কাজা হয়েছে means "became Qadha" / "is now due as make-up," a reframe toward the actionable next step rather than a verdict on the user. This is *more* aligned with Finch's tone than the English original. | Reword EN to match BN's already-better framing: **"Due for Qadha"** instead of bare "Missed" — turns a verdict into an actionable status, consistent with the module's own Qadha-counter mechanism. | No change — BN is already the model to copy from. |
| 7 | `prayerQadhaCountLabel` | "{count} owed" | "{count}টি বাকি" | `prayer_qadha_screen.dart:26`, subtitle on each Qadha counter row | **Real asymmetry, EN is the worse one.** "Owed" frames the counter as a debt/obligation the user is behind on. BN's "বাকি" means "remaining" — informational, no debt framing at all. Same finding as row 6: Bangla already meets Finch's bar; English doesn't. | **"{count} remaining"** — matches BN's neutral framing, still literally accurate (it's a to-make-up count), drops the "owed" connotation. | No change. |
| 8 | *(not an ARB key)* `stats.missed`/`stats.skipped` inline string, `medicine_detail_screen.dart:109-113` | `'Last 30 days: $takenPct% taken (${stats.missed} missed, ${stats.skipped} skipped)'`, `'No dose history yet'` | *(doesn't exist — not localized at all)* | Plain `Text(...)` in a `Card`, no color | **Out of scope for i18n infra, but in scope for this pass's wording**, and flagged because it's a real gap this audit's own grep methodology (ARB-only) would otherwise miss entirely. | Extract to new keys `medicineDetailStatsSummary`/`medicineDetailNoHistory` (see below), rewording "missed" → "not taken" for internal consistency with row 1's fix. | Add BN translations for the first time. |

New/changed l10n keys this pass adds (both `app_en.arb`/`app_bn.arb`):

- `prayerStatusMissedDue` — replaces the *meaning* carried by
  `prayerStatusMissed` for display purposes only (EN: "Due for Qadha";
  BN unchanged, reuse `prayerStatusMissed`'s existing BN value). Keeping
  the old key name would be misleading once the EN text no longer says
  "Missed" — rename the key so it isn't silently stale.
- `prayerQadhaCountLabel` — value changed in place (EN only: `"{count}
  owed"` → `"{count} remaining"`), same key, same placeholder.
- `medicineDetailStatsSummary` — new, params `{pct}`, `{missed}`,
  `{skipped}`: EN `"Last 30 days: {pct}% taken ({missed} not taken,
  {skipped} skipped)"`.
- `medicineDetailNoHistory` — new, no params: EN `"No dose history yet"`.

## Out of scope

- **Onboarding/empty-state copy unrelated to missed/skipped/Qadha**
  (e.g. generic "get started" strings) — outside this pass's semantic
  category by design, per the atlas item's own non-goal.
- **Notification title/body text for missed doses/prayers.** Grepping
  `medicine_module.dart`/`prayer_module.dart` for scheduled notification
  content found no "missed"/"overdue" wording in what's actually sent —
  the only dose-reminder body found is `'Time for your dose'`
  (`medicine_module.dart:162`), which is neutral and pre-dated this
  pass. Nothing to change there.
- **A written house-style guideline doc.** The high-level draft floated
  this; this rewrite treats the table above as the guideline (every
  future "missed"-adjacent string can be checked against rows 1/6/7 as
  precedent) rather than adding a new doc file to maintain.
- **Re-deriving the Medicine/Prayer state machines.** Nothing here
  touches `effectiveDoseStatus`/`effectivePrayerStatus`/
  `sweepMissedPrayers` — copy and one color mapping only.
- **A native Bangla speaker's full-app review.** This pass is scoped to
  the 8 keys above; a broader bilingual tone review of the whole app is
  a separate, larger effort not bounded by this spec.

## Global Constraints

- No new dependency, no schema migration — this is ARB text edits plus
  one Dart-level color-mapping change (`dose_tile.dart`) and two new
  ARB-string extractions replacing hardcoded literals
  (`medicine_detail_screen.dart`).
- Renaming `prayerStatusMissed` usages to `prayerStatusMissedDue` touches
  exactly 2 call sites found by grep: `prayer_tile.dart:96` and
  `prayer_history_screen.dart:157`. Both are simple `l10n.` getter swaps.
- The `dose_tile.dart` color change (row 1) is a one-line diff
  (`theme.colorScheme.error` → `theme.colorScheme.outline`) with no
  semantic-color-extension change needed — `AppSemanticColors` already
  isn't used for this state, so no new theme token is introduced.
- Run `flutter gen-l10n` after editing the ARB files (per CLAUDE.md's
  standard command list) — not part of this pass's own execution here,
  but required before the app builds against the renamed/new keys.
