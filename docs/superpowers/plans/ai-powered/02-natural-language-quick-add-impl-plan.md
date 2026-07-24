# Natural-Language Quick-Add — Implementation Plan

**Spec:** [Natural-Language Quick-Add Design](./02-natural-language-quick-add-design.md)
**Run:** TBD
**Estimated effort:** M (8 tasks)
**Dependencies:** Water module (existing), `LogWaterEntryUseCase`, `WaterUnit` setting, `quick_add_button.dart` widget

## Pre-requisites
- Water module is complete (domain/data/presentation, Run 05+)
- `LogWaterEntryUseCase` accepts `amountMl`, `source`, `loggedAt`
- `WaterUnit` enum exists (`ml` / `flOz`) and is readable from settings
- Freezed + codegen pipeline works
- No new packages needed (regex-based parser)

---

## Tasks

### Task 1: Create `ParsedWaterEntry` Freezed entity
**Effort:** S
**Files to create:**
- `lib/features/water/domain/entities/parsed_water_entry.dart`

**Files to modify:** (none)

**Description:**
Create the `ParsedWaterEntry` Freezed sealed class:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'parsed_water_entry.freezed.dart';

@freezed
sealed class ParsedWaterEntry with _$ParsedWaterEntry {
  const factory ParsedWaterEntry({
    int? amountMl,
    DateTime? loggedAt,
    required String confidence,
    required String rawText,
  }) = _ParsedWaterEntry;
}
```

Run `dart run build_runner build --delete-conflicting-outputs`.

**Acceptance criteria:**
- `parsed_water_entry.freezed.dart` is generated
- File compiles without errors

**Test:** No dedicated test — verified by compilation and downstream use case tests.

---

### Task 2: Implement `ParseWaterQuickAddUseCase` with all parser rules
**Effort:** M
**Files to create:**
- `lib/features/water/domain/usecases/parse_water_quick_add.dart`

**Files to modify:** (none)

**Description:**
Implement a pure, synchronous, regex-based parser. No I/O, no DB, no clock dependency.

**Parser rules (in priority order):**

1. **Number extraction** — regex: `r'(\d+(?:[.,]\d+)?)\s*'` to capture numeric values. Handles: `2`, `2.5`, `2,5` (European decimal), `500`.

2. **Unit synonyms** (case-insensitive):
   - `ml` / `mL` / `milliliter` / `milliliters` / `mil` → multiply by 1
   - `l` / `L` / `liter` / `liters` / `litre` / `litres` → multiply by 1000
   - `cup` / `cups` → multiply by 240
   - `glass` / `glasses` → multiply by 250
   - `oz` / `fl oz` / `fluid ounce` / `fluid ounces` → multiply by 29.5735
   - No unit found → assume `ml`

3. **Unit scaling for `WaterUnit` display** — if user's `WaterUnit` is `flOz`, interpret bare numbers as fl oz and convert to ml (`* 29.5735`, rounded).

4. **Time phrase extraction** (case-insensitive):
   - `just now` / `now` / `right now` → `now`
   - `(\d+)\s*(min|minute|minutes)\s*ago` → `now - N minutes`
   - `(\d+)\s*(hr|hour|hours)\s*ago` → `now - N hours`
   - `(\d+)\s*(day|days)\s*ago` → `now - N days`
   - `at\s*(\d{1,2}):?(\d{2})?\s*(am|pm)?` → parse as today's time (or yesterday if in future)
   - No time phrase → default to `now`

5. **Confidence scoring:**
   - `high`: both amount and time phrase found, unambiguous
   - `medium`: amount found, time defaulted to "now"
   - `low`: amount ambiguous (multiple numbers with no unit) or no amount found

**Acceptance criteria:**
- Returns correct `amountMl` and `loggedAt` for all rule combinations
- Confidence is correctly classified
- `now` parameter is used consistently (no `DateTime.now()` calls)

**Test:** See Task 3.

---

### Task 3: Write unit tests for parser (all edge cases)
**Effort:** M
**Files to create:**
- `test/features/water/domain/usecases/parse_water_quick_add_test.dart`

**Files to modify:** (none)

**Description:**
Comprehensive unit tests for `ParseWaterQuickAddUseCase`:

| Input | Expected amountMl | Expected loggedAt | Confidence |
|-------|-------------------|-------------------|------------|
| `"2 glasses just now"` | 500 | now | high |
| `"500ml at 3pm"` | 500 | today 15:00 | high |
| `"1 cup"` | 240 | now | medium |
| `"2L"` | 2000 | now | medium |
| `"300ml 20 minutes ago"` | 300 | now - 20min | high |
| `"just now"` | null | now | low |
| `"abc"` | null | null | low |
| `"2,5 glasses"` | 625 | now | medium |
| `"8 oz"` | 237 | now | medium |
| `"1 liter 2 hours ago"` | 1000 | now - 2h | high |

Also test `WaterUnit.flOz` setting: bare number `"8"` → interprets as fl oz → converts to ~237ml.

**Acceptance criteria:**
- `flutter test test/features/water/domain/usecases/parse_water_quick_add_test.dart` passes
- All edge cases covered

**Test:** `flutter test test/features/water/domain/usecases/parse_water_quick_add_test.dart`

---

### Task 4: Create `NaturalLanguageQuickAdd` widget
**Effort:** M
**Files to create:**
- `lib/features/water/presentation/widgets/natural_language_quick_add.dart`

**Files to modify:** (none)

**Description:**
A `ConsumerStatefulWidget` that provides:
- A `TextField` with hint text "e.g. '2 glasses just now'"
- Debounced parsing (~300ms) on every keystroke via a `Timer`
- A preview `Card` below the text field showing:
  - Parsed amount and time (e.g. "Log 500ml at 3:00 PM")
  - Confidence indicator (green check for high, yellow warning for medium/low)
  - "Edit" button (switches to the existing custom amount form)
  - "Log" button (calls controller to log the entry)

Widget structure:
```dart
Column([
  TextField(hintText: localizedHint),
  if (parsed != null && parsed.amountMl != null)
    Card([
      ListTile(
        leading: Icon(Icons.water_drop),
        title: Text("Log ${formatAmount(parsed.amountMl)} at ${formatTime(parsed.loggedAt)}"),
        subtitle: Text(parsed.confidence == 'high' ? localizedParsed : localizedWarning),
      ),
      Row([
        TextButton("Edit", onPressed: ...),
        FilledButton("Log", onPressed: ...),
      ]),
    ]),
])
```

**Acceptance criteria:**
- Typing triggers a preview after debounce
- Empty field shows no preview
- "Log" button calls the controller method
- "Edit" button switches to custom form
- Low confidence shows warning text
- Strings are localized

**Test:** See Task 7.

---

### Task 5: Wire widget into `quick_add_button.dart` and controller
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/water/presentation/widgets/quick_add_button.dart`
- `lib/features/water/presentation/water_controller.dart` (or equivalent provider)

**Description:**
1. In `quick_add_button.dart`, add `NaturalLanguageQuickAdd` below the existing button row (inside a `Column` or `Column`-like widget).
2. In the water controller/provider, add a method:
   ```dart
   Future<void> logFromParsedText(String input) async {
     final parsed = _parser.execute(input, now: clock.now());
     if (parsed.amountMl == null || parsed.amountMl! <= 0) return;
     await _logWaterEntry.execute(
       amountMl: parsed.amountMl!,
       source: WaterEntrySource.quick,
       loggedAt: parsed.loggedAt ?? clock.now(),
     );
   }
   ```
3. Pass this method down to the `NaturalLanguageQuickAdd` widget.

**Acceptance criteria:**
- Existing button grid still works (no regression)
- New text field appears below buttons
- Typing + "Log" logs an entry via `LogWaterEntryUseCase`

**Test:** Manual verification: type a phrase, tap Log, confirm entry appears in water logs.

---

### Task 6: Add localization strings
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**Description:**
Add ARB keys for all new strings (see Localization Keys below). Run `flutter gen-l10n` after.

**Acceptance criteria:**
- All new keys are present in both `app_en.arb` and `app_bn.arb`
- `flutter gen-l10n` succeeds without errors
- Strings are accessible via `AppLocalizations`

**Test:** Compile check after `flutter gen-l10n`.

---

### Task 7: Widget tests for preview/confirm UX
**Effort:** S
**Files to create:**
- `test/features/water/presentation/widgets/natural_language_quick_add_test.dart`

**Files to modify:** (none)

**Description:**
Widget tests:
- Typing text triggers preview card to appear
- Empty field shows no preview
- "Log" button calls the controller's `logFromParsedText`
- "Edit" button triggers a callback (switches to custom form)
- Low-confidence parse shows warning text
- High-confidence parse shows "Parsed" label

**Acceptance criteria:**
- `flutter test test/features/water/presentation/widgets/natural_language_quick_add_test.dart` passes

**Test:** `flutter test test/features/water/presentation/widgets/natural_language_quick_add_test.dart`

---

### Task 8: Manual testing with real user input
**Effort:** S
**Files to create:** (none)
**Files to modify:** (none)

**Description:**
Manual verification checklist:
1. Open Water quick-add screen
2. Type "2 glasses just now" — verify preview shows 500ml, tap Log, confirm entry
3. Type "500ml at 3pm" — verify time is parsed correctly
4. Type "just now" — verify no amount, warning shown
5. Type "abc" — verify "Couldn't understand that" message
6. Verify flOz unit setting: type "8" — verify it interprets as fl oz
7. Verify "Edit" button switches to custom form
8. Verify no regression: existing button grid still works
9. Verify both en and bn locales show correct strings

**Acceptance criteria:**
- All checklist items pass
- No crashes or data corruption

**Test:** Manual QA — no automated test file.

---

## Schema Migration

**None.** Parsed values map directly to `LogWaterEntryUseCase` inputs (`amountMl`, `loggedAt`) which are already persisted in the existing `water_logs` table.

---

## Localization Keys

| Key | en | bn |
|-----|----|----|
| `waterQuickAddHintText` | e.g. 2 glasses just now | যেমন ২ গ্লাস এইমাত্র |
| `waterQuickAddPreviewTitle` | Log {amount} at {time} | {amount} {time} তে লগ করুন |
| `waterQuickAddConfirmButton` | Log | লগ |
| `waterQuickAddEditButton` | Edit | সম্পাদনা |
| `waterQuickAddUnparsedMessage` | Couldn't understand that — try a number and unit | বোঝা যায়নি — একটি সংখ্যা এবং একক দিন |
| `waterQuickAddConfidenceWarning` | Check this looks right | দেখুন এটি সঠিক কিনা |

---

## Risk Notes

- **No new packages.** This is a regex/rule-based parser — no cloud API, no ML model. If a more capable tokenizer is wanted later, that's a deliberate future call.
- **Bangla support deferred.** The parser handles English phrasing only in v1. Bangla number words/units are a follow-up spec. The bn ARB strings cover the UI chrome, not the parser input.
- **Debounce timing.** 300ms debounce on keystroke parsing is a reasonable default. Too fast causes lag on long inputs; too slow feels unresponsive. Tune if needed.
- **European decimal.** The regex handles both `2.5` and `2,5` (comma as decimal separator). This covers locales that use `,` for decimals.
- **`WaterUnit.flOz` interaction.** When the user's unit setting is flOz, bare numbers are interpreted as fl oz and converted to ml internally. The display in the preview card should show the value in the user's preferred unit.
- **No replacement for existing flow.** This is an additional entry point. The button grid remains the default/primary path.
