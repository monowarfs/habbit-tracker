# Natural-Language Quick-Add

**Category:** AI-Powered · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Water's quick-add today is a grid of preset-amount buttons plus a custom
amount form — fast for the common case, but a power user who wants to log
"2 glasses just now" or "500ml at 3pm" still has to tap through a button
and, for anything not on the grid or not "now", a separate time picker.
TickTick's free-text quick-add parsing is the benchmark: typing a sentence
and having the app extract the structured fields is meaningfully faster
than multi-step form entry once a user trusts it. This is a convenience
upgrade for an existing flow, not a new capability.

## Goals
- Let a user type (or, later, speak) a short phrase like "2 glasses just
  now" or "300ml 20 minutes ago" and have Water parse an amount and a
  timestamp from it.
- Fall back gracefully (and visibly) to the existing manual custom-amount
  form when the parser can't confidently extract both fields.
- Keep the existing button-grid quick-add as the default/primary path —
  this is an additional entry point, not a replacement.

## Non-goals / out of scope
- No natural-language understanding model, no cloud NLU API — this is
  explicitly a small rule-based/regex-style parser.
- No support for arbitrary free-form logging across all three modules in
  this pass; Water is the natural first target since its log entries are
  a single number, unlike Medicine's schedule complexity or Prayer's fixed
  checklist.
- No voice input in this spec (see the separate voice-logging feature).
- Not attempting to parse every phrasing users might try — a bounded
  vocabulary (numbers + units + a handful of relative-time phrases) with
  a clear "couldn't understand that" fallback is the target, not 100%
  coverage.

## Proposed approach (high-level)
A small on-device parser (a handful of regex/token-matching rules, not a
model) extracts two things from a typed string: a quantity+unit token
(numbers, "glass"/"glasses", "ml", "cup", respecting the existing
Water unit setting) and an optional relative-time phrase ("just now",
"an hour ago", "at 3pm"). The parsed result maps onto the same inputs
`LogWaterEntryUseCase` already validates (amount > 0, no future
timestamp), so the parser's only job is producing those two values —
all the existing validation and persistence logic downstream is reused
unchanged. The UI surface is a text field alongside (or replacing, on
user preference) the quick-add button row, with a preview of the parsed
amount/time shown before confirming, so a misparse is caught before it's
logged rather than silently logging the wrong thing.

## Dependencies & prerequisites
- No new packages required if the parser stays regex/rule-based; if a
  more capable tokenizer is wanted later, that's a deliberate call to
  make in the implementation round, not assumed here.
- Localization: the parser needs bn-language number words/units handled
  too, or an explicit decision to ship en-only first and treat bn as a
  follow-up given the existing en/bn localization commitment.

## Open questions for the implementation round
- Does the parser need to handle Bangla phrasing at launch, or is an
  English-only v1 acceptable given the effort/localization tradeoff?
- What's the exact fallback UX when parsing fails partially (e.g. amount
  found, time not) — assume "now" for a missing time, or force the user
  to clarify?
- Should this live as a Water-only feature permanently, or is the parser
  designed generically enough that Medicine's "log as taken" flow could
  reuse it later?
- Where does the preview/confirm step live — inline in the text field's
  own widget, or a lightweight bottom sheet?

## Effort & sequencing notes
Complexity M — the parsing logic itself is small, but building a
trustworthy preview/confirm UX (so a misparse doesn't silently log wrong
data) is the part that takes real design and testing effort. Fine to
sequence independently of other AI-powered items; no shared dependencies.

---

## Implementation Plan (Low-Level)

### Schema Changes

**None.** Parsed values map directly to `LogWaterEntryUseCase` inputs (`amountMl`, `loggedAt`) which are already persisted in the existing `water_logs` table. No new tables, columns, or migrations needed.

### Domain Entities

**File:** `lib/features/water/domain/entities/parsed_water_entry.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'parsed_water_entry.freezed.dart';

/// The result of parsing a natural-language water quick-add string.
@freezed
sealed class ParsedWaterEntry with _$ParsedWaterEntry {
  /// Creates a parsed water entry.
  const factory ParsedWaterEntry({
    /// Parsed amount in ml (canonical unit). null if parser couldn't
    /// extract a quantity.
    int? amountMl,

    /// Parsed timestamp. null if parser couldn't extract a time and the
    /// caller should default to "now".
    DateTime? loggedAt,

    /// Confidence: 'high' (both fields parsed, unambiguous),
    /// 'medium' (one field parsed, other defaulted), 'low' (ambiguous
    /// or partial parse — show preview but flag uncertainty).
    required String confidence,

    /// The original user-typed text, for display in the preview card.
    required String rawText,
  }) = _ParsedWaterEntry;
}
```

### Parser Rules

**File:** `lib/features/water/domain/usecases/parse_water_quick_add.dart`

A pure, synchronous, regex-based parser. No I/O, no DB, no clock dependency — fully unit-testable with deterministic inputs.

```dart
import 'package:habit_tracker/features/water/domain/entities/parsed_water_entry.dart';

/// Rule-based parser that extracts a water amount and optional timestamp
/// from a short free-text string. Pure — no dependencies beyond regex.
class ParseWaterQuickAddUseCase {
  const ParseWaterQuickAddUseCase();

  /// Parses [input] into a [ParsedWaterEntry].
  ///
  /// [now] is injected for testability (the real call site passes
  /// `clock.now()`).
  ParsedWaterEntry execute(String input, {required DateTime now}) { ... }
}
```

**Parser rules (in priority order):**

1. **Number extraction** — regex: `r'(\d+(?:[.,]\d+)?)\s*'` to capture numeric values. Handles: `2`, `2.5`, `2,5` (European decimal), `500`.

2. **Unit synonyms** (case-insensitive, fuzzy):
   - `ml` / `mL` / `milliliter` / `milliliters` / `mil` → multiply by 1
   - `l` / `L` / `liter` / `liters` / `litre` / `litres` → multiply by 1000
   - `cup` / `cups` → multiply by 240 (standard US cup)
   - `glass` / `glasses` → multiply by 250 (app default, matches first quick-add button)
   - `oz` / `fl oz` / `fluid ounce` / `fluid ounces` → multiply by 29.5735
   - No unit found → assume `ml` (the canonical unit)

3. **Unit scaling for `waterUnit` display** — if the user's `WaterUnit` is `flOz`, interpret bare numbers as fl oz and convert to ml (`* 29.5735`, rounded). This respects D-01.

4. **Time phrase extraction** — regex patterns (case-insensitive):
   - `just now` / `now` / `right now` → `now`
   - `(\d+)\s*(min|minute|minutes)\s*ago` → `now - N minutes`
   - `(\d+)\s*(hr|hour|hours)\s*ago` → `now - N hours`
   - `(\d+)\s*(day|days)\s*ago` → `now - N days`
   - `at\s*(\d{1,2}):?(\d{2})?\s*(am|pm)?` → parse as today's time (or yesterday if the time is in the future)
   - No time phrase → default to `now`

5. **Confidence scoring:**
   - `high`: both amount and time phrase found, unambiguous
   - `medium`: amount found, time defaulted to "now" (no time phrase)
   - `low`: amount ambiguous (multiple numbers with no unit to disambiguate) or no amount found

### Data Layer

**No changes.** The parsed result maps to `LogWaterEntryUseCase.execute()` which already handles validation and persistence through `WaterRepositoryImpl`.

**Modify:** `lib/features/water/domain/repositories/water_repository.dart` — no change needed; `addEntry` already accepts the values the parser produces.

### Presentation Layer

**Modify:** `lib/features/water/presentation/widgets/quick_add_button.dart` — add an optional text field below (or beside) the existing button row. When the user types, the parser runs on every keystroke (debounced ~300ms) and shows a preview card.

**New file:** `lib/features/water/presentation/widgets/natural_language_quick_add.dart`

```dart
/// A text field + preview card for natural-language water quick-add.
///
/// Shows below the existing quick-add button row. When the user types a
/// phrase like "2 glasses just now", a preview card shows the parsed
/// amount and time with a "Log" confirmation button.
class NaturalLanguageQuickAdd extends ConsumerStatefulWidget {
  const NaturalLanguageQuickAdd({super.key});
  // ...
}
```

**Widget structure:**
```
Column([
  TextField(hintText: "e.g. '2 glasses just now'"),
  if (parsed != null && parsed.amountMl != null)
    Card([
      ListTile(
        leading: Icon(Icons.water_drop),
        title: Text("Log ${formatAmount(parsed.amountMl)} at ${formatTime(parsed.loggedAt)}"),
        subtitle: Text(parsed.confidence == 'high' ? "Parsed" : "Check this looks right"),
      ),
      Row([
        TextButton("Edit", onPressed: /* switch to custom form */),
        FilledButton("Log", onPressed: /* call LogWaterEntryUseCase */),
      ]),
    ]),
])
```

**Modify:** `lib/features/water/presentation/water_controller.dart` (or equivalent provider) — add a method:
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

### Localization

**Modify:** `lib/core/l10n/app_en.arb` and `app_bn.arb` — add keys for:
- `waterQuickAddHintText` — "e.g. 2 glasses just now"
- `waterQuickAddPreviewTitle` — "Log {amount} at {time}"
- `waterQuickAddConfirmButton` — "Log"
- `waterQuickAddEditButton` — "Edit"
- `waterQuickAddUnparsedMessage` — "Couldn't understand that — try a number and unit"
- `waterQuickAddConfidenceWarning` — "Check this looks right"

### Testing Strategy

| Test file | What it covers |
|-----------|---------------|
| `test/features/water/domain/usecases/parse_water_quick_add_test.dart` | Extensive unit tests: "2 glasses just now" → 500ml, "500ml at 3pm" → 500ml @ 15:00, "1 cup" → 240ml, "2L" → 2000ml, "300ml 20 minutes ago" → 300ml @ now-20min, "just now" → 0ml (no amount, low confidence), "abc" → no parse, "2,5 glasses" → 625ml (European decimal), fl_oz unit setting converts correctly, Bangla number words not yet supported (returns low confidence or empty). |
| `test/features/water/presentation/widgets/natural_language_quick_add_test.dart` | Widget tests: typing triggers preview, empty field shows no preview, "Log" button calls controller, "Edit" button switches to custom form, low-confidence shows warning text. |

### File Paths

**Create:**
- `lib/features/water/domain/entities/parsed_water_entry.dart`
- `lib/features/water/domain/entities/parsed_water_entry.freezed.dart` (generated)
- `lib/features/water/domain/usecases/parse_water_quick_add.dart`
- `lib/features/water/presentation/widgets/natural_language_quick_add.dart`
- `test/features/water/domain/usecases/parse_water_quick_add_test.dart`
- `test/features/water/presentation/widgets/natural_language_quick_add_test.dart`

**Modify:**
- `lib/features/water/presentation/widgets/quick_add_button.dart` — add text field below buttons
- `lib/features/water/presentation/water_controller.dart` (or equivalent) — add `logFromParsedText`
- `lib/core/l10n/app_en.arb` — new strings
- `lib/core/l10n/app_bn.arb` — new strings

### Sequencing

| Task | Depends on | Effort |
|------|-----------|--------|
| T1: Create `ParsedWaterEntry` Freezed entity | None | S |
| T2: Implement `ParseWaterQuickAddUseCase` with all parser rules | T1 | M |
| T3: Write unit tests for parser (all edge cases) | T2 | M |
| T4: Create `NaturalLanguageQuickAdd` widget (text field + preview card) | T1 | M |
| T5: Wire widget into `quick_add_button.dart` and controller | T4 | S |
| T6: Add localization strings | None | S |
| T7: Widget tests for preview/confirm UX | T4, T5 | S |
| T8: Manual testing with real user input | T5, T6, T7 | S |

**Critical path:** T1 → T2 → T4 → T5 → T8
