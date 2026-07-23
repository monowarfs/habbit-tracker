# Voice Logging (On-Device Speech-to-Text)

**Category:** AI-Powered · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Logging today always requires navigating to a module's screen and
tapping through a UI, even for the simplest action ("I took my morning
dose"). Apple Health's voice-entry pattern shows that a short spoken
command can meaningfully lower the friction of routine logging,
particularly for accessibility (users with limited dexterity or vision)
and for quick hands-busy moments (cooking, driving). Since this app
already has a natural-language quick-add parser planned for Water (item
02), voice logging is a thin input-method layer on top of the same
parsing/action-matching logic rather than a separate feature built from
scratch.

## Goals
- Let a user speak a short command ("mark my morning dose taken", "log 2
  glasses of water") and have the app recognize the intended module and
  action.
- Keep all speech recognition on-device — no audio ever leaves the
  device, consistent with the app's offline/no-account trust story.
- Serve as both an accessibility win and a convenience shortcut,
  reachable from wherever quick actions already live (e.g. the
  dashboard's quick-actions strip from Run 15).

## Non-goals / out of scope
- No cloud speech-to-text service of any kind — only on-device engines.
- No open-ended conversational assistant — a bounded set of recognized
  command phrases/intents, not general voice control of the whole app.
- No always-listening/background voice activation — this is an
  explicit, user-initiated action (e.g. holding a mic button), not
  passive listening.

## Proposed approach (high-level)
A speech-to-text package that runs its recognition entirely on-device
converts spoken audio to text locally; that text is then handed to the
same rule-based intent/parameter extraction the natural-language
quick-add feature already builds (item 02) — the module/action-matching
step (e.g. "morning dose" → MedicineModule's relevant dose, "taken" →
the Done action) plus its parsing for Water's amount/time phrases. This
keeps voice logging a thin front-end on top of existing text-parsing
logic and each module's already-existing action-handling paths (the same
`onNotificationAction`-style Done/Snooze/Skip handling Medicine and Water
already implement for notification actions), rather than a parallel
logging pipeline. The UI surface is a mic-trigger control with a visible
transcript-and-confirm step before any action is actually applied, so a
misrecognition is caught before data is logged.

## Dependencies & prerequisites
- An on-device speech-to-text package (e.g. the `speech_to_text` plugin
  family) — a new dependency, evaluated specifically for on-device-only
  operation, not one that silently phones home to a cloud recognition
  service.
- Microphone permission handling (iOS/Android), including a clear
  permission-rationale moment consistent with how notification
  permissions are already explained in this app.
- The natural-language quick-add parser (item 02) as the intent/parameter
  extraction layer this feature reuses, if built in that order.

## Open questions for the implementation round
- Which on-device STT package best covers both English and Bangla given
  the app's existing en/bn localization commitment — on-device engine
  language coverage varies significantly by platform and package.
- What's the bounded vocabulary/command grammar — a fixed phrase list, or
  a looser pattern grammar reusing item 02's parser across all modules
  (not just Water)?
- Does this need its own dedicated screen/entry point, or does it hang
  off the dashboard's existing quick-actions strip?
- How is a low-confidence transcription handled — always show the
  confirm step, or only when recognition confidence is below a threshold
  (if the chosen package even exposes one)?

## Effort & sequencing notes
Complexity M — the speech-to-text integration itself is a fairly
standard plugin wiring, but the intent-matching layer's quality (and
therefore user trust in the feature) depends heavily on the natural-
language quick-add parser from item 02 being solid first. Sequencing
this after item 02 avoids duplicating parsing logic.

---

## Implementation Plan (Low-Level)

### 1. New dependency: `speech_to_text`

**File:** `pubspec.yaml` (modify)

Add `speech_to_text: ^7.0.0` (or latest stable). This package provides
on-device STT with no cloud fallback — it wraps iOS `SFSpeechRecognizer`
and Android `SpeechRecognizer`, both on-device only. After adding:
```
flutter pub get
```

No other new package dependencies needed. Permission handling is
built into the package via `SpeechToText.initialize()` and
`SpeechToText.listen()`.

### 2. Domain entities

#### `VoiceCommand` entity

**File to create:** `lib/features/voice/domain/entities/voice_command.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'voice_command.freezed.dart';

/// Parsed voice input from on-device STT, before confirmation.
@freezed
class VoiceCommand with _$VoiceCommand {
  const factory VoiceCommand({
    required String rawText,        // original transcribed text from STT
    required String transcript,     // cleaned/normalized version for matching
    required VoiceAction parsedAction, // matched intent
    required String moduleId,       // target module id ('water', 'medicine', 'prayer')
    required double confidence,     // STT confidence 0.0–1.0
  }) = _VoiceCommand;
}

/// Recognized intent from voice text parsing.
enum VoiceAction {
  quickAdd,       // log an amount (e.g. "log 2 glasses of water")
  markDone,       // mark a dose/prayer done (e.g. "mark morning dose taken")
  markSkipped,    // skip an item (e.g. "skip Asr today")
  unknown,        // no matching intent found
}
```

#### `ParsedIntent` (internal to use case, not exported)

**File to create:** `lib/features/voice/domain/entities/parsed_intent.dart`

```dart
/// Intermediate parse result — module match + action match + extracted
/// parameters. Not a public entity; used internally by the use case.
class ParsedIntent {
  const ParsedIntent({
    required this.moduleId,
    required this.action,
    required this.parameters,
    required this.confidence,
  });
  final String moduleId;
  final VoiceAction action;
  final Map<String, String> parameters; // e.g. {'amount': '500', 'unit': 'ml'}
  final double confidence;
}
```

### 3. Use cases

#### `InterpretVoiceCommandUseCase` (pure)

**File to create:** `lib/features/voice/domain/usecases/interpret_voice_command.dart`

```dart
/// Pure use case: takes raw transcribed text, returns a [VoiceCommand]
/// with matched intent/parameters. No side effects — the confirmation
/// step in the UI gates the actual logging.
class InterpretVoiceCommandUseCase {
  const InterpretVoiceCommandUseCase();

  /// Parses [transcribedText] into a [VoiceCommand].
  ///
  /// Pattern matching order:
  /// 1. Check for water keywords → WaterModule quick-add
  /// 2. Check for medicine keywords → MedicineModule mark done/skip
  /// 3. Check for prayer keywords → PrayerModule mark done/skip
  /// 4. Fall back to [VoiceAction.unknown]
  VoiceCommand execute({
    required String transcribedText,
    required double confidence,
  }) { ... }
}
```

**Pattern-matching rules** (all regex-based, case-insensitive):

- **Water quick-add**: Matches patterns like `"log N ml/glass/cup/glasses of water"`,
  `"water N"`, `"drank N"`. Extracts amount and unit into `parameters['amount']`
  and `parameters['unit']`. Maps to `moduleId: 'water'`, `action: VoiceAction.quickAdd`.
- **Medicine done**: Matches `"mark ... dose ... taken"`, `"took [medicine name]"`,
  `"medicine done"`. Maps to `moduleId: 'medicine'`, `action: VoiceAction.markDone`.
- **Medicine skip**: Matches `"skip ... dose"`. Maps to `moduleId: 'medicine'`,
  `action: VoiceAction.markSkipped`.
- **Prayer done**: Matches `"prayed [prayer name]"`, `"[prayer name] done"`,
  `"marked [prayer name] taken"`. Maps to `moduleId: 'prayer'`, `action: VoiceAction.markDone`.
- **Prayer skip**: Matches `"missed [prayer name]"`, `"skip [prayer name]"`.
  Maps to `moduleId: 'prayer'`, `action: VoiceAction.markSkipped`.

Confidence from STT is passed through unchanged; module/action matching
confidence is 1.0 if a regex matches, 0.0 if fallback to unknown.

#### `ApplyVoiceCommandUseCase` (wiring to module actions)

**File to create:** `lib/features/voice/domain/usecases/apply_voice_command.dart`

```dart
/// Wires a confirmed [VoiceCommand] to the appropriate module's action
/// handler. Not pure — touches module repositories.
class ApplyVoiceCommandUseCase {
  const ApplyVoiceCommandUseCase({required this.modules});
  final List<HabitModule> modules;

  /// Executes the confirmed [command] against the matched module.
  ///
  /// - `VoiceAction.quickAdd` on Water → calls waterRepository to log entry
  /// - `VoiceAction.markDone` on Medicine → calls medicineRepository to mark dose done
  /// - `VoiceAction.markDone` on Prayer → calls prayerRepository to log record
  /// - `VoiceAction.markSkipped` → equivalent skip action per module
  /// - `VoiceAction.unknown` → no-op, returns early
  Future<void> execute(VoiceCommand command) async { ... }
}
```

### 4. Permission handling

**File to create:** `lib/features/voice/presentation/voice_permission_handler.dart`

Handles `permission_handler` flow for microphone access:

```dart
/// Checks and requests microphone permission with a rationale dialog.
/// Returns true if permission is granted.
Future<bool> ensureMicrophonePermission(BuildContext context) async {
  // 1. Check current status
  // 2. If denied permanently → show rationale dialog explaining why mic is needed,
  //    then open app settings
  // 3. If not determined → request, then show rationale if needed
  // 4. If granted → return true
}
```

Pattern follows the existing notification permission explainer in
`core/notifications/permission_explainer_screen.dart`. The rationale
dialog should explain: "Voice logging requires microphone access to
convert your speech to text. Audio is processed entirely on-device and
never leaves your phone."

### 5. Presentation layer

#### Voice controller (state management)

**File to create:** `lib/features/voice/presentation/providers/voice_controller.dart`

```dart
@riverpod
class VoiceController extends _$VoiceController {
  @override
  VoiceState build() => const VoiceState.idle();

  /// Starts listening — initializes STT, begins recording.
  Future<void> startListening() async { ... }

  /// STT produces a result — runs InterpretVoiceCommandUseCase.
  void onTranscript(String text, double confidence) { ... }

  /// User confirms the parsed command — runs ApplyVoiceCommandUseCase.
  Future<void> confirmCommand() async { ... }

  /// User dismisses/cancels.
  void cancel() { ... }
}
```

**File to create:** `lib/features/voice/presentation/providers/voice_state.dart`

```dart
@freezed
class VoiceState with _$VoiceState {
  const factory VoiceState.idle() = Idle;
  const factory VoiceState.listening() = Listening;
  const factory VoiceState.parsed(VoiceCommand command) = Parsed;
  const factory VoiceState.applying() = Applying;
  const factory VoiceState.success(String message) = Success;
  const factory VoiceState.error(String message) = Error;
}
```

#### Voice bottom sheet (main UI surface)

**File to create:** `lib/features/voice/presentation/widgets/voice_command_sheet.dart`

A `ModalBottomSheet` showing:
1. **Listening state**: Animated mic icon, "Listening..." text
2. **Parsed state**: Shows transcript text, parsed intent summary
   ("Water quick-add: 500ml"), Confirm / Cancel buttons
3. **Applying/success state**: Spinner → checkmark → auto-dismiss
4. **Error state**: Error message + Retry button

#### Mic button widget

**File to create:** `lib/features/voice/presentation/widgets/voice_mic_button.dart`

A reusable `IconButton` or `ActionChip` that:
- Shows a mic icon
- On tap: checks permission → opens `VoiceCommandSheet`
- Shows a small recording indicator when active

### 6. Integration points

#### Dashboard quick-actions

**File to modify:** `lib/features/water/water_module.dart`

In `quickActions(ref)`, add a mic button (using `VoiceMicButton`)
alongside the existing quick-add chip. The mic button appears as the
last item in the quick-actions row.

**File to modify:** `lib/features/medicine/medicine_module.dart`

Same — add a mic button to `quickActions(ref)`.

**File to modify:** `lib/features/prayer/prayer_module.dart`

Same — add a mic button to `quickActions(ref)`.

**Alternatively** (simpler, less invasive): Add the mic button directly
in `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
inside `_QuickActionsRow`, as a single global mic button that appears
before the per-module chips when voice logging is enabled. This avoids
modifying every module.

**Recommended approach:** Global mic button in `_QuickActionsRow` since
voice logging is cross-module by nature and a single entry point is
less noisy than a mic button per module.

#### Module action wiring

Each module's repository already supports the actions voice needs:
- Water: `WaterRepositoryImpl.logEntry(...)` — already called by quick-add
- Medicine: `MedicineRepositoryImpl.markDoseStatus(...)` — already called by notification action handler
- Prayer: `PrayerRepositoryImpl.logPrayer(...)` — already called by checklist toggle

`ApplyVoiceCommandUseCase` calls these directly (it takes
`List<HabitModule>` and matches by `moduleId`, then casts to call the
relevant repository method). Since the repository is internal to each
module, the use case needs access to the repositories. Two options:
1. Add a `logFromVoiceCommand(VoiceCommand)` method to `HabitModule`
   (cleanest, keeps encapsulation). **Recommended.**
2. Have the use case take the repositories directly (breaks encapsulation).

**Recommended:** Add `Future<void> logFromVoiceCommand(VoiceCommand command)` to `HabitModule` contract. Each module implements it by routing to the appropriate internal method.

### 7. L10n strings

**Files to modify:** `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`

New keys:
```json
"voiceListening": "Listening...",
"voiceConfirm": "Confirm",
"voiceCancel": "Cancel",
"voiceRetry": "Retry",
"voicePermissionTitle": "Microphone Access",
"voicePermissionBody": "Voice logging requires microphone access to convert your speech to text. Audio is processed entirely on-device and never leaves your phone.",
"voiceErrorNoMatch": "Sorry, I didn't understand that. Try again.",
"voiceErrorSTTFailed": "Speech recognition failed. Please try again.",
"voiceSuccessWater": "Logged {amount}ml of water",
"voiceSuccessMedicine": "Marked dose as {action}",
"voiceSuccessPrayer": "Logged prayer: {name}",
"voiceMicTooltip": "Voice logging"
```

### 8. Testing strategy

| Test file | What it covers | Type |
|-----------|---------------|------|
| `test/features/voice/domain/usecases/interpret_voice_command_test.dart` | Regex intent matching: water patterns, medicine patterns, prayer patterns, unknown fallback, edge cases (empty string, multiple keywords, mixed languages) | Unit |
| `test/features/voice/domain/usecases/apply_voice_command_test.dart` | Routes VoiceCommand to correct module's log method, handles unknown action gracefully | Unit |
| `test/features/voice/presentation/providers/voice_controller_test.dart` | State transitions: idle → listening → parsed → applying → success, error handling, cancel flow | Unit (mock STT) |
| `test/features/voice/presentation/widgets/voice_command_sheet_test.dart` | Widget renders correct UI per state, confirm/cancel buttons work, permission denied state | Widget |

**Mock strategy:** Create `MockSpeechToText` for integration tests.
`InterpretVoiceCommandUseCase` is pure and needs no mocks.
`ApplyVoiceCommandUseCase` depends on module repositories — mock those.

### 9. Complete file list

**Files to create (10):**
- `lib/features/voice/domain/entities/voice_command.dart`
- `lib/features/voice/domain/entities/parsed_intent.dart`
- `lib/features/voice/domain/usecases/interpret_voice_command.dart`
- `lib/features/voice/domain/usecases/apply_voice_command.dart`
- `lib/features/voice/presentation/providers/voice_controller.dart`
- `lib/features/voice/presentation/providers/voice_state.dart`
- `lib/features/voice/presentation/widgets/voice_command_sheet.dart`
- `lib/features/voice/presentation/widgets/voice_mic_button.dart`
- `lib/features/voice/presentation/voice_permission_handler.dart`
- `lib/features/voice/voice_module.dart` (optional — if voice gets its own module entry, or inline into dashboard)

**Files to modify (5):**
- `pubspec.yaml` — add `speech_to_text` dependency
- `lib/core/modules/habit_module.dart` — add `logFromVoiceCommand(VoiceCommand)` method to contract
- `lib/features/water/water_module.dart` — implement `logFromVoiceCommand`
- `lib/features/medicine/medicine_module.dart` — implement `logFromVoiceCommand`
- `lib/features/prayer/prayer_module.dart` — implement `logFromVoiceCommand`
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` — add `VoiceMicButton` to `_QuickActionsRow`
- `lib/core/l10n/app_en.arb` — add voice-related strings
- `lib/core/l10n/app_bn.arb` — add Bangla voice-related strings

**Test files to create (4):**
- `test/features/voice/domain/usecases/interpret_voice_command_test.dart`
- `test/features/voice/domain/usecases/apply_voice_command_test.dart`
- `test/features/voice/presentation/providers/voice_controller_test.dart`
- `test/features/voice/presentation/widgets/voice_command_sheet_test.dart`

### 10. Sequencing and effort estimates

| # | Task | Depends on | Effort |
|---|------|-----------|--------|
| 1 | Add `speech_to_text` to `pubspec.yaml`, run `flutter pub get` | — | S |
| 2 | Create `VoiceCommand` and `ParsedIntent` entities | — | S |
| 3 | Create `InterpretVoiceCommandUseCase` with regex rules | 2 | M |
| 4 | Create `VoiceState` freezed model | — | S |
| 5 | Create `VoiceController` with STT integration | 1, 3, 4 | M |
| 6 | Create `VoicePermissionHandler` | — | S |
| 7 | Create `VoiceMicButton` widget | 5, 6 | S |
| 8 | Create `VoiceCommandSheet` widget | 4 | M |
| 9 | Add `logFromVoiceCommand` to `HabitModule` contract | 2 | S |
| 10 | Implement `logFromVoiceCommand` in Water/Medicine/Prayer modules | 9 | M |
| 11 | Create `ApplyVoiceCommandUseCase` | 10 | M |
| 12 | Wire mic button into dashboard `_QuickActionsRow` | 7 | S |
| 13 | Add L10n strings (en/bn) | — | S |
| 14 | Write unit tests for intent matching | 3 | M |
| 15 | Write unit tests for controller state transitions | 5 | M |
| 16 | Write widget tests for voice sheet | 8 | S |
| 17 | Run `build_runner build`, verify no analysis errors | all | S |

**Total effort: L** (17 tasks, several M-sized, new feature module from scratch)
**Estimated duration: 2–3 focused sessions**
