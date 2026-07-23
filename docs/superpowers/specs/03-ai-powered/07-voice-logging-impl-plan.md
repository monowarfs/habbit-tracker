# Voice Logging (On-Device Speech-to-Text) — Implementation Plan

**Spec:** [07-voice-logging-design.md](./07-voice-logging-design.md)
**Run:** TBD
**Estimated effort:** L (17 tasks, several M-sized, new feature module from scratch)
**Estimated duration:** 2–3 focused sessions
**Dependencies:** Natural-language quick-add parser (item 02) for intent/parameter extraction reuse; `speech_to_text` package evaluation for on-device STT

## Pre-requisites

- Flutter SDK `^3.12.2` installed and `flutter pub get` working
- Natural-language quick-add parser (item 02) built and working — voice logging is a thin input-method layer on top of the same parsing logic
- `speech_to_text` package evaluated and confirmed for on-device-only operation on both iOS and Android
- Microphone permission handling pattern reviewed (follows existing notification permission explainer pattern in `core/notifications/permission_explainer_screen.dart`)
- Drift database at schema version 7 (no schema changes needed for this spec)

## Tasks

### Task 1: Add `speech_to_text` dependency
**Effort:** S
**Files to modify:** `pubspec.yaml`
**Description:** Add `speech_to_text: ^7.0.0` (or latest stable) to `pubspec.yaml`. Run `flutter pub get`. This package wraps iOS `SFSpeechRecognizer` and Android `SpeechRecognizer` — both on-device only, no cloud fallback. Permission handling is built into the package via `SpeechToText.initialize()` and `SpeechToText.listen()`.
**Acceptance criteria:** `flutter pub get` completes without errors; `speech_to_text` appears in `pubspec.lock`.
**Test:** N/A (dependency addition only)

### Task 2: Create domain entities
**Effort:** S
**Files to create:**
- `lib/features/voice/domain/entities/voice_command.dart`
- `lib/features/voice/domain/entities/parsed_intent.dart`
**Description:** Create the `VoiceCommand` freezed entity (rawText, transcript, parsedAction, moduleId, confidence) and the `VoiceAction` enum (quickAdd, markDone, markSkipped, unknown). Create the internal `ParsedIntent` class (moduleId, action, parameters map, confidence) used by the use case but not exported.
**Acceptance criteria:** Freezed code generation succeeds; entities compile without errors.
**Test:** N/A (data classes only — tested via use case tests)

### Task 3: Create `InterpretVoiceCommandUseCase`
**Effort:** M
**Files to create:** `lib/features/voice/domain/usecases/interpret_voice_command.dart`
**Description:** Pure use case: takes raw transcribed text + confidence, returns a `VoiceCommand` with matched intent/parameters. Pattern-matching rules (all regex, case-insensitive):
- **Water quick-add**: `"log N ml/glass/cup/glasses of water"`, `"water N"`, `"drank N"` → moduleId: 'water', action: quickAdd
- **Medicine done**: `"mark ... dose ... taken"`, `"took [medicine name]"`, `"medicine done"` → moduleId: 'medicine', action: markDone
- **Medicine skip**: `"skip ... dose"` → moduleId: 'medicine', action: markSkipped
- **Prayer done**: `"prayed [prayer name]"`, `"[prayer name] done"` → moduleId: 'prayer', action: markDone
- **Prayer skip**: `"missed [prayer name]"`, `"skip [prayer name]"` → moduleId: 'prayer', action: markSkipped
- Fallback: `VoiceAction.unknown`. STT confidence passed through unchanged; module/action matching confidence is 1.0 if regex matches, 0.0 otherwise.
**Acceptance criteria:** All regex patterns match correctly; edge cases (empty string, multiple keywords, mixed languages) handled gracefully; falls back to unknown for unrecognized input.
**Test:** `test/features/voice/domain/usecases/interpret_voice_command_test.dart` — test all regex patterns, edge cases, unknown fallback, empty string, multiple keyword matches.

### Task 4: Create `VoiceState` freezed model
**Effort:** S
**Files to create:** `lib/features/voice/presentation/providers/voice_state.dart`
**Description:** Freezed union for controller state: `idle`, `listening`, `parsed(VoiceCommand)`, `applying`, `success(String message)`, `error(String message)`.
**Acceptance criteria:** Freezed code generation succeeds; all states compile.
**Test:** N/A (tested via controller tests)

### Task 5: Create `VoiceController`
**Effort:** M
**Files to create:** `lib/features/voice/presentation/providers/voice_controller.dart`
**Description:** `@riverpod` controller managing the full voice flow:
- `startListening()`: initializes STT, begins recording, transitions to `listening`
- `onTranscript(text, confidence)`: runs `InterpretVoiceCommandUseCase`, transitions to `parsed` or `error`
- `confirmCommand()`: runs `ApplyVoiceCommandUseCase`, transitions to `applying` → `success`
- `cancel()`: transitions back to `idle`
Handles STT lifecycle (init, listen, cancel, dispose).
**Acceptance criteria:** State transitions follow: idle → listening → parsed → applying → success; error state reachable; cancel returns to idle.
**Test:** `test/features/voice/presentation/providers/voice_controller_test.dart` — mock STT, test all state transitions, error handling, cancel flow.

### Task 6: Create `VoicePermissionHandler`
**Effort:** S
**Files to create:** `lib/features/voice/presentation/voice_permission_handler.dart`
**Description:** Handles microphone permission flow:
1. Check current status
2. If denied permanently → show rationale dialog ("Voice logging requires microphone access to convert your speech to text. Audio is processed entirely on-device and never leaves your phone."), then open app settings
3. If not determined → request, then show rationale if needed
4. If granted → return true
Pattern follows `core/notifications/permission_explainer_screen.dart`.
**Acceptance criteria:** Returns true when permission granted; opens settings when permanently denied; shows rationale dialog.
**Test:** N/A (permission flow — tested via integration/manual)

### Task 7: Create `VoiceMicButton` widget
**Effort:** S
**Files to create:** `lib/features/voice/presentation/widgets/voice_mic_button.dart`
**Description:** Reusable `IconButton` or `ActionChip` showing a mic icon. On tap: checks permission via `VoicePermissionHandler`, then opens `VoiceCommandSheet`. Shows a small recording indicator when active. Tooltip: "Voice logging".
**Acceptance criteria:** Renders mic icon; taps check permission then open bottom sheet; recording indicator visible when listening.
**Test:** N/A (simple widget — tested as part of dashboard tests)

### Task 8: Create `VoiceCommandSheet` widget
**Effort:** M
**Files to create:** `lib/features/voice/presentation/widgets/voice_command_sheet.dart`
**Description:** `ModalBottomSheet` showing four states:
1. **Listening**: Animated mic icon, "Listening..." text
2. **Parsed**: Transcript text, parsed intent summary ("Water quick-add: 500ml"), Confirm / Cancel buttons
3. **Applying/success**: Spinner → checkmark → auto-dismiss
4. **Error**: Error message + Retry button
**Acceptance criteria:** All four states render correctly; confirm/cancel buttons wired to controller; permission denied state handled.
**Test:** `test/features/voice/presentation/widgets/voice_command_sheet_test.dart` — renders correct UI per state, confirm/cancel buttons work, permission denied state.

### Task 9: Add `logFromVoiceCommand` to `HabitModule` contract
**Effort:** S
**Files to modify:** `lib/core/modules/habit_module.dart`
**Description:** Add `Future<void> logFromVoiceCommand(VoiceCommand command)` method to the `HabitModule` plugin contract. Default implementation returns `Future.value()` (no-op for modules that don't support voice).
**Acceptance criteria:** Contract compiles; existing modules unaffected (default no-op).
**Test:** N/A (contract change — tested via module implementations)

### Task 10: Implement `logFromVoiceCommand` in Water/Medicine/Prayer modules
**Effort:** M
**Files to modify:**
- `lib/features/water/water_module.dart`
- `lib/features/medicine/medicine_module.dart`
- `lib/features/prayer/prayer_module.dart`
**Description:** Each module implements `logFromVoiceCommand` by routing to the appropriate internal method:
- Water: calls `waterRepository.logEntry(...)` with parsed amount/unit
- Medicine: calls `medicineRepository.markDoseStatus(...)` with matched dose and action (done/skipped)
- Prayer: calls `prayerRepository.logPrayer(...)` with matched prayer name and status
**Acceptance criteria:** Each module correctly interprets VoiceCommand and calls the right repository method; unknown actions are no-ops.
**Test:** Covered by `apply_voice_command_test.dart` (Task 11)

### Task 11: Create `ApplyVoiceCommandUseCase`
**Effort:** M
**Files to create:** `lib/features/voice/domain/usecases/apply_voice_command.dart`
**Description:** Wires a confirmed `VoiceCommand` to the appropriate module's action handler. Takes `List<HabitModule>`, matches by `moduleId`, and calls `module.logFromVoiceCommand(command)`. Handles all VoiceAction types; unknown action returns early.
**Acceptance criteria:** Routes commands to correct module; handles unknown action gracefully; no side effects on misroute.
**Test:** `test/features/voice/domain/usecases/apply_voice_command_test.dart` — routes VoiceCommand to correct module, handles unknown action, handles missing module.

### Task 12: Wire mic button into dashboard
**Effort:** S
**Files to modify:** `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
**Description:** Add `VoiceMicButton` to `_QuickActionsRow` as a global mic button (voice logging is cross-module by nature, so a single entry point is less noisy than a mic button per module). Place it as the first or last item in the quick-actions row.
**Acceptance criteria:** Mic button visible on dashboard; tapping opens voice command sheet; no regression in existing quick actions.
**Test:** N/A (integration — manual verification)

### Task 13: Add L10n strings (en/bn)
**Effort:** S
**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`
**Description:** Add all voice-related localization keys (see Localization Keys section below). Run `flutter gen-l10n` after adding.
**Acceptance criteria:** All new keys present in both ARB files; `flutter gen-l10n` generates without errors.
**Test:** N/A (localization only)

### Task 14: Write unit tests for intent matching
**Effort:** M
**Files to create:** `test/features/voice/domain/usecases/interpret_voice_command_test.dart`
**Description:** Test `InterpretVoiceCommandUseCase` regex patterns: water quick-add (all unit variants), medicine done/skip, prayer done/skip, unknown fallback, empty string, multiple keyword matches, mixed language input. All tests are pure — no mocks needed.
**Acceptance criteria:** All test cases pass; edge cases covered.
**Test:** `test/features/voice/domain/usecases/interpret_voice_command_test.dart`

### Task 15: Write unit tests for controller state transitions
**Effort:** M
**Files to create:** `test/features/voice/presentation/providers/voice_controller_test.dart`
**Description:** Test `VoiceController` state machine: idle → listening → parsed → applying → success; error handling (STT failure, unknown command); cancel flow returns to idle. Mock STT and module repositories.
**Acceptance criteria:** All state transitions verified; error paths tested.
**Test:** `test/features/voice/presentation/providers/voice_controller_test.dart`

### Task 16: Write widget tests for voice sheet
**Effort:** S
**Files to create:** `test/features/voice/presentation/widgets/voice_command_sheet_test.dart`
**Description:** Test `VoiceCommandSheet` renders correct UI per state (listening, parsed, applying, success, error); confirm/cancel buttons wired correctly; permission denied state renders.
**Acceptance criteria:** All widget states render; button taps trigger correct callbacks.
**Test:** `test/features/voice/presentation/widgets/voice_command_sheet_test.dart`

### Task 17: Run `build_runner build`, verify no analysis errors
**Effort:** S
**Files to modify:** (none — verification step)
**Description:** Run `dart run build_runner build --delete-conflicting-outputs` to generate all `*.g.dart` files. Run `flutter analyze` to verify no lint or analysis errors. Run `dart format --output=none --set-exit-if-changed .` to verify formatting.
**Acceptance criteria:** All generated files produced; zero analysis errors; formatting clean.
**Test:** `flutter analyze` passes; `dart format` clean.

## Schema Migration

**None.** This feature does not add any new database tables or columns. All data flows through existing module repositories.

## Localization Keys

**English (`app_en.arb`):**
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

**Bangla (`app_bn.arb`):** Corresponding Bangla translations for all keys above.

## Risk Notes

1. **On-device STT language coverage:** `speech_to_text` wraps platform-native engines (SFSpeechRecognizer on iOS, SpeechRecognizer on Android). On-device language coverage varies — English is well-supported on both platforms, but Bangla on-device support may be limited on older Android devices. Test on target devices early.
2. **Natural-language parser dependency:** This spec assumes item 02 (natural-language quick-add parser) is built first. If it isn't, the regex patterns in `InterpretVoiceCommandUseCase` are self-contained, but the design intent is to reuse item 02's patterns for Water. Coordinate sequencing.
3. **Confidence threshold:** The chosen STT package may not expose per-result confidence scores. If so, the `confidence` field defaults to 1.0 and the confirm step is always shown (safer UX). Design around this uncertainty.
4. **Module action wiring:** `ApplyVoiceCommandUseCase` calls `module.logFromVoiceCommand()` which requires access to internal module repositories. The recommended approach (adding the method to `HabitModule` contract) keeps encapsulation clean but means every module must implement it — even as a no-op.
5. **Audio permission UX:** iOS is stricter about microphone permission timing — the permission dialog must be triggered by a user gesture (the mic button tap). Never request permission on app startup.
