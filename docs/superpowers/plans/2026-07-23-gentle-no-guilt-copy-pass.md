# Gentle No-Guilt Missed-Dose Copy Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the app's one real guilt signal (a red/error color on
Medicine's missed-dose tile) and fix the three specific wording spots the
audit in `docs/superpowers/specs/02-delightful/03-gentle-no-guilt-missed-
dose-copy-pass-design.md` identified as not meeting Finch's "neutral
information, not a scolding" bar — no state-machine or screen changes,
this is a content/color audit with four concrete fixes.

**Architecture:** One Dart color-mapping one-liner in `dose_tile.dart`;
one ARB key rename (`prayerStatusMissed` → `prayerStatusMissedDue`) with
its two call sites updated; one ARB value-only edit
(`prayerQadhaCountLabel` EN text); two new ARB keys replacing a hardcoded,
never-localized string pair in `medicine_detail_screen.dart`. No schema
migration, no new dependency, no new widget.

**Tech Stack:** Flutter/Dart, `gen_l10n`, `flutter_test`.

## Global Constraints

- No new dependency, no schema migration.
- Every new/changed key goes in **both** `lib/core/l10n/app_en.arb` and
  `lib/core/l10n/app_bn.arb`; run `flutter gen-l10n` after each ARB edit
  and before running any test that references the changed getter.
- Per this repo's CLAUDE.md spec-implementation workflow: one commit per
  task, run only that task's own test file (never the full `flutter
  test` suite mid-task), pipe `build_runner`/`test`/`gen-l10n` output
  through `| tail -10`.
- `heatmapCellMissedSemantics` (screen-reader-only, `habit_heatmap_
  calendar.dart:112`) and the heatmap's shared `colors.errorContainer`
  missed-day cell color (`habit_heatmap_calendar.dart:79-81`) are
  deliberately **not** touched by this pass — the source spec marks the
  semantics label "optional"/low-priority (never seen by sighted users)
  and scopes the color fix to `dose_tile.dart` only (its own Global
  Constraints: "one Dart-level color-mapping change (dose_tile.dart)").
  Re-coloring the shared heatmap would also affect Water/Prayer's
  `complete`/`partial` rendering, which is out of this pass's scope.
- Notification title/body text is out of scope — already audited by the
  source spec and found neutral (`medicine_module.dart:162`'s `'Time for
  your dose'`).

---

### Task 1: Fix the missed-dose color signal (`dose_tile.dart`)

**Files:**
- Modify: `lib/features/medicine/presentation/widgets/dose_tile.dart:57-60`
- Test: `test/features/medicine/presentation/medicine_home_screen_test.dart`

**Interfaces:**
- Consumes: `MedicineDoseStatus.missed` (existing enum value, unchanged),
  `theme.colorScheme.outline`/`theme.colorScheme.error` (Material 3
  `ColorScheme`, no new token).
- Produces: nothing consumed by later tasks in this plan — this task is
  self-contained.

- [ ] **Step 1: Write the failing test**

Add a new test to `test/features/medicine/presentation/
medicine_home_screen_test.dart`, right after the existing `'overdue
(missed) dose is visually distinct'` test (which only asserts the text
exists, not its color):

```dart
  testWidgets(
    'missed dose uses the neutral outline color, not the error/red role '
    '(no guilt-tripping color signal)',
    (tester) async {
      final repo = MedicineRepositoryImpl(db);
      final medicine = await repo.createMedicine(
        name: 'Ibuprofen',
        stockEnabled: false,
      );
      await repo.createSchedule(
        medicineId: (medicine as Success<Medicine>).value.id,
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        startDate: const LocalDate(2026, 6, 1),
      );
      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
        await repo.materializeDoses(clock.now());
      });

      // Now well past the grace window -> missed.
      final now = DateTime.utc(2026, 6, 1, 10);
      await _pumpMedicineHome(tester, db, now: now);

      final missedLabel = tester.widget<Text>(find.text('Missed'));
      final theme = Theme.of(tester.element(find.text('Missed')));
      expect(missedLabel.style?.color, theme.colorScheme.outline);
      expect(missedLabel.style?.color, isNot(theme.colorScheme.error));

      await disposeTree(tester);
    },
  );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medicine/presentation/medicine_home_screen_test.dart | tail -10`
Expected: FAIL — `missedLabel.style?.color` currently equals
`theme.colorScheme.error`, not `theme.colorScheme.outline`.

- [ ] **Step 3: Write minimal implementation**

In `lib/features/medicine/presentation/widgets/dose_tile.dart`, change:

```dart
      MedicineDoseStatus.missed => (
        l10n.medicineDoseStatusMissed,
        theme.colorScheme.error,
      ),
```

to:

```dart
      MedicineDoseStatus.missed => (
        l10n.medicineDoseStatusMissed,
        // ponytail: `missed` gets the same neutral treatment as
        // `skipped` two lines below — the guilt signal this app's copy
        // pass found was carried by color (error/red = "you did
        // something wrong"), not by the word "Missed" itself
        // (docs/superpowers/specs/02-delightful/
        // 03-gentle-no-guilt-missed-dose-copy-pass-design.md).
        theme.colorScheme.outline,
      ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medicine/presentation/medicine_home_screen_test.dart | tail -10`
Expected: `+4: All tests passed!` (the 3 pre-existing tests plus this one).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medicine/presentation/widgets/dose_tile.dart \
  test/features/medicine/presentation/medicine_home_screen_test.dart
git commit -m "fix(medicine): drop the error/red color from the missed-dose tile"
```

---

### Task 2: Reframe Prayer's missed status as an actionable Qadha status

**Files:**
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Modify: `lib/features/prayer/presentation/widgets/prayer_tile.dart:96`
- Modify: `lib/features/prayer/presentation/screens/prayer_history_screen.dart:157`
- Test: `test/core/l10n/copy_pass_test.dart` (new file)

**Interfaces:**
- Produces: `AppLocalizations.prayerStatusMissedDue` (EN: "Due for
  Qadha", BN: reuses the old `prayerStatusMissed` BN value verbatim) —
  consumed by `prayer_tile.dart`'s and `prayer_history_screen.dart`'s
  `_statusLabel` switch expressions in this same task.
- The old key `prayerStatusMissed` is removed from both ARB files (grep
  confirms its only two call sites are the two files modified here —
  no other reference exists anywhere in `lib/` or `test/`).

- [ ] **Step 1: Write the failing test**

`test/core/l10n/` doesn't exist yet — create the directory, then create
`test/core/l10n/copy_pass_test.dart`:

```bash
mkdir -p test/core/l10n
```

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

void main() {
  test(
    'prayerStatusMissedDue reframes English away from a bare "Missed" '
    'verdict, matching the already-neutral Bangla framing '
    '(docs/superpowers/specs/02-delightful/'
    '03-gentle-no-guilt-missed-dose-copy-pass-design.md, row 6)',
    () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(en.prayerStatusMissedDue, 'Due for Qadha');

      final bn = await AppLocalizations.delegate.load(const Locale('bn'));
      // Bangla is unchanged — it already read "became Qadha"/"due as
      // make-up", not a literal "Missed".
      expect(bn.prayerStatusMissedDue, 'কাজা হয়েছে');
    },
  );

  test(
    'prayerQadhaCountLabel drops the "owed"/debt framing in English, '
    'matching Bangla\'s already-neutral "remaining" framing (row 7)',
    () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(en.prayerQadhaCountLabel(3), '3 remaining');

      final bn = await AppLocalizations.delegate.load(const Locale('bn'));
      expect(bn.prayerQadhaCountLabel(3), '3টি বাকি');
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/l10n/copy_pass_test.dart | tail -10`
Expected: FAIL to compile — `prayerStatusMissedDue` doesn't exist yet
(only `prayerStatusMissed` does), and `prayerQadhaCountLabel(3)` still
returns `'3 owed'`.

- [ ] **Step 3: Rename the key in both ARB files**

In `lib/core/l10n/app_en.arb`, change:

```json
  "prayerStatusMissed": "Missed",
  "@prayerStatusMissed": {"description": "Label for a prayer past its cutoff, unactioned."},
```

to:

```json
  "prayerStatusMissedDue": "Due for Qadha",
  "@prayerStatusMissedDue": {"description": "Label for a prayer past its cutoff, unactioned — phrased as an actionable next step (make it up via Qadha) rather than a verdict."},
```

In `lib/core/l10n/app_bn.arb`, change:

```json
  "prayerStatusMissed": "কাজা হয়েছে",
```

to:

```json
  "prayerStatusMissedDue": "কাজা হয়েছে",
```

(Bangla's value is unchanged — only the key name moves, since Bangla
already met the tone bar; see the spec's row 6.)

- [ ] **Step 4: Update the two call sites**

In `lib/features/prayer/presentation/widgets/prayer_tile.dart`, change:

```dart
        PrayerStatus.missed => l10n.prayerStatusMissed,
```

to:

```dart
        PrayerStatus.missed => l10n.prayerStatusMissedDue,
```

In `lib/features/prayer/presentation/screens/prayer_history_screen.dart`,
change:

```dart
        PrayerStatus.missed => l10n.prayerStatusMissed,
```

to:

```dart
        PrayerStatus.missed => l10n.prayerStatusMissedDue,
```

- [ ] **Step 5: Change the Qadha count label's English value in place**

In `lib/core/l10n/app_en.arb`, change:

```json
  "prayerQadhaCountLabel": "{count} owed",
  "@prayerQadhaCountLabel": {
    "description": "Current Qadha balance for one prayer.",
    "placeholders": {"count": {"type": "int"}}
  },
```

to:

```json
  "prayerQadhaCountLabel": "{count} remaining",
  "@prayerQadhaCountLabel": {
    "description": "Current Qadha balance for one prayer — phrased as a neutral remaining-count, not a debt owed.",
    "placeholders": {"count": {"type": "int"}}
  },
```

`lib/core/l10n/app_bn.arb`'s `"prayerQadhaCountLabel": "{count}টি বাকি"`
is unchanged — it already means "remaining", not "owed" (the spec's row
7 finding). No key rename here (same key, same placeholder, only the
English string's wording changes), so no other call site needs editing
— `prayer_qadha_screen.dart:26`'s
`Text(l10n.prayerQadhaCountLabel(counter.count))` keeps working as-is.

- [ ] **Step 6: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors; `prayerStatusMissed` getter disappears,
`prayerStatusMissedDue` getter appears, `prayerQadhaCountLabel`'s
generated EN string updates.

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/core/l10n/copy_pass_test.dart | tail -10`
Expected: `+2: All tests passed!`

- [ ] **Step 8: Analyze**

Run: `flutter analyze lib/features/prayer/presentation/widgets/prayer_tile.dart lib/features/prayer/presentation/screens/prayer_history_screen.dart | tail -10`
Expected: `No issues found!` (confirms no other file still references the
now-deleted `prayerStatusMissed` getter).

- [ ] **Step 9: Commit**

```bash
git add lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  lib/features/prayer/presentation/widgets/prayer_tile.dart \
  lib/features/prayer/presentation/screens/prayer_history_screen.dart \
  test/core/l10n/copy_pass_test.dart
git commit -m "feat(prayer): reframe missed-prayer/Qadha copy away from guilt framing"
```

---

### Task 3: Extract and localize Medicine detail's hardcoded stats string

**Files:**
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Modify: `lib/features/medicine/presentation/screens/medicine_detail_screen.dart:105-117`
- Test: `test/core/l10n/copy_pass_test.dart`

**Interfaces:**
- Consumes: nothing new from Task 2 (same file, additive test).
- Produces: `AppLocalizations.medicineDetailStatsSummary(int pct, int
  missed, int skipped)` — gen-l10n generates **positional** parameters
  in the order placeholders first appear in the message string (matching
  the existing precedent at `app_localizations_en.dart:154`'s
  `heatmapCellMissedSemantics(String date, String value)`, not named
  parameters) — and `AppLocalizations.medicineDetailNoHistory`, consumed
  only by `medicine_detail_screen.dart` in this same task.

- [ ] **Step 1: Write the failing test**

Add to `test/core/l10n/copy_pass_test.dart`, inside `main()`, after the
existing two `test(...)` blocks:

```dart
  test(
    'medicineDetailStatsSummary/medicineDetailNoHistory are localized and '
    'say "not taken" instead of "missed" — matching row 1\'s finding that '
    '"missed"-adjacent-but-red-badged wording should read neutrally '
    '(row 8, the one hardcoded-string gap the ARB grep itself missed)',
    () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        en.medicineDetailStatsSummary(80, 1, 1),
        'Last 30 days: 80% taken (1 not taken, 1 skipped)',
      );
      expect(en.medicineDetailNoHistory, 'No dose history yet');

      final bn = await AppLocalizations.delegate.load(const Locale('bn'));
      // Just needs to exist and be non-empty — exact Bangla wording is
      // this task's own translation, not pinned to a specific string in
      // this English-authored test.
      expect(bn.medicineDetailStatsSummary(80, 1, 1), isNotEmpty);
      expect(bn.medicineDetailNoHistory, isNotEmpty);
    },
  );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/l10n/copy_pass_test.dart | tail -10`
Expected: FAIL to compile — `medicineDetailStatsSummary`/
`medicineDetailNoHistory` don't exist yet.

- [ ] **Step 3: Add the ARB keys**

In `lib/core/l10n/app_en.arb`, insert after the
`"medicineDetailRefillButton"` block (immediately before
`"medicineStatsTitle"`) — find this exact anchor text:

```json
  "medicineDetailRefillButton": "Refill",
  "@medicineDetailRefillButton": {
    "description": "Opens the add-stock dialog."
  },
  "medicineStatsTitle": "Medicine stats",
```

Replace it with:

```json
  "medicineDetailRefillButton": "Refill",
  "@medicineDetailRefillButton": {
    "description": "Opens the add-stock dialog."
  },
  "medicineDetailStatsSummary": "Last 30 days: {pct}% taken ({missed} not taken, {skipped} skipped)",
  "@medicineDetailStatsSummary": {
    "description": "30-day adherence summary on the medicine detail screen. 'not taken' (not 'missed') keeps this consistent with dose_tile.dart's neutral wording (row 1 of the copy-pass audit).",
    "placeholders": {
      "pct": {"type": "int"},
      "missed": {"type": "int"},
      "skipped": {"type": "int"}
    }
  },
  "medicineDetailNoHistory": "No dose history yet",
  "@medicineDetailNoHistory": {
    "description": "Shown instead of the stats summary when there is no dose history in the last 30 days."
  },
  "medicineStatsTitle": "Medicine stats",
```

In `lib/core/l10n/app_bn.arb`, insert after the
`"medicineDetailRefillButton"` line (immediately before
`"medicineStatsTitle"`) — find this exact anchor text:

```json
  "medicineDetailRefillButton": "পুনরায় পূরণ",
  "medicineStatsTitle": "ওষুধের পরিসংখ্যান",
```

Replace it with:

```json
  "medicineDetailRefillButton": "পুনরায় পূরণ",
  "medicineDetailStatsSummary": "গত ৩০ দিন: {pct}% নেওয়া হয়েছে ({missed}টি নেওয়া হয়নি, {skipped}টি এড়িয়ে যাওয়া হয়েছে)",
  "medicineDetailNoHistory": "এখনো কোনো ডোজের ইতিহাস নেই",
  "medicineStatsTitle": "ওষুধের পরিসংখ্যান",
```

- [ ] **Step 4: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors.

- [ ] **Step 5: Wire the new keys into the screen**

In `lib/features/medicine/presentation/screens/medicine_detail_screen.dart`,
change:

```dart
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      stats.total == 0
                          ? 'No dose history yet'
                          : 'Last 30 days: $takenPct% taken '
                                '(${stats.missed} missed, '
                                '${stats.skipped} skipped)',
                    ),
                  ),
                );
```

to:

```dart
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      stats.total == 0
                          ? l10n.medicineDetailNoHistory
                          : l10n.medicineDetailStatsSummary(
                              takenPct,
                              stats.missed,
                              stats.skipped,
                            ),
                    ),
                  ),
                );
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/core/l10n/copy_pass_test.dart | tail -10`
Expected: `+3: All tests passed!` (Task 2's two tests plus this one).

- [ ] **Step 7: Analyze and format**

Run: `flutter analyze lib/features/medicine/presentation/screens/medicine_detail_screen.dart | tail -10`
Run: `dart format lib/features/medicine/presentation/screens/medicine_detail_screen.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  lib/features/medicine/presentation/screens/medicine_detail_screen.dart \
  test/core/l10n/copy_pass_test.dart
git commit -m "feat(medicine): localize the detail screen's hardcoded stats string"
```

---

## After all tasks

Per this repo's CLAUDE.md spec-implementation workflow: once every task
above is committed, open a PR for the spec with the audit summary in the
description, then run a code review against the finished PR (comment →
fix → commit cycle, up to 5 rounds), then stop and wait for the user's
own review and merge.
