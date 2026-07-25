# Implementation Plan: 08 Audio Cue Alternative for Notification Actions

## Overview

- **Spec:** Audio Cue Alternative for Notification Actions
- **Complexity:** S
- **Estimated effort:** 1 day
- **Dependencies:** Standalone. Depends on existing `notification_action_handler.dart` (it exists).
- **Prerequisites:** Decision on bundled audio assets vs. platform system sounds.

---

## Implementation Tasks

### Task 1: Source or create audio assets

**Files to create/modify:**
- `assets/audio/earcon_done.mp3` (new)
- `assets/audio/earcon_snooze.mp3` (new)
- `assets/audio/earcon_skip.mp3` (new)
- `pubspec.yaml` (modify — register asset path)

**Detailed changes:**
- Bundle three short audio files (each under 50KB):
  - `earcon_done.mp3` — ascending positive tone.
  - `earcon_snooze.mp3` — neutral tone.
  - `earcon_skip.mp3` — lower/descending tone.
- Register the `assets/audio/` directory in `pubspec.yaml` under `flutter: assets:`.
- Alternative: use platform system sound APIs (`SystemSound.play(SystemSound.click)` on Android, `AudioServices.playSystemSound` on iOS) to avoid bundling assets entirely. This is the preferred approach if the tones are sufficiently distinguishable.

**Integration:** Assets are consumed by the audio playback service.

### Task 2: Create audio cue service

**Files to create/modify:**
- `lib/core/notifications/audio_cue_service.dart` (new)

**Detailed changes:**
- Create `AudioCueService` with:
  - `Future<void> playEarcon(NotificationActionType action)` — plays the appropriate sound for Done/Snooze/Skip.
  - Uses `just_audio` or `audioplayers` package (add to `pubspec.yaml`) OR use Flutter's built-in `rootBundle.load()` + `AudioPlayer` for asset playback.
  - Queue mechanism: if an earcon is already playing, queue the next one (don't overlap).
  - Platform check: on Android background isolate, audio playback may be restricted — fall back to playing only when the app is foregrounded.
  - Respect OS DND/silent mode — defer to the platform's audio session settings.
- Make it a singleton or injectable service that `notification_action_handler.dart` calls.

**Integration:** `AudioCueService` is called from `handleNotificationAction()` after each action is processed.

### Task 3: Hook into notification action handler

**Files to create/modify:**
- `lib/core/notifications/notification_action_handler.dart` (modify)

**Detailed changes:**
- After each `case` branch (Done/Skip/Snooze) in `handleNotificationAction()`, add:
  ```dart
  await AudioCueService.instance.playEarcon(actionType);
  ```
- Place the call after the ledger update and dispatch, before `planAndApplyNotifications`.
- For the background isolate path (`database == null`), verify that audio playback works; if not, defer the earcon to foreground.

**Integration:** Additive change to existing handler — no modification to existing Done/Skip/Snooze logic.

### Task 4: Handle background isolate constraints

**Files to create/modify:**
- `lib/core/notifications/audio_cue_service.dart` (modify)

**Detailed changes:**
- On Android, background isolate audio playback may be restricted by the OS.
- Add a check: if running in a background isolate (no foreground `WidgetsBinding`), either:
  - Attempt playback and silently fail if it doesn't work, OR
  - Skip the earcon and rely on the OS's own notification sound.
- On iOS, background audio from notification extensions is more permissive — test and verify.

**Integration:** Platform-specific handling within the service.

### Task 5: Add optional Settings toggle

**Files to create/modify:**
- `lib/features/settings/domain/entities/app_settings.dart` (modify)
- `lib/features/settings/presentation/settings_screen.dart` (modify)
- `lib/core/l10n/app_en.arb` (modify)
- `lib/core/l10n/app_bn.arb` (modify)

**Detailed changes:**
- Add `bool audioCuesEnabled` to `AppSettings` (default: `true`).
- Add `SwitchListTile` in Settings under the existing Sound section.
- Label: `settingsAudioCuesLabel`, description: `settingsAudioCuesDescription`.
- `AudioCueService` checks this setting before playing.

**Integration:** Follows existing settings persistence pattern.

### Task 6: Add ARB keys

**Files to create/modify:**
- `lib/core/l10n/app_en.arb` (modify)
- `lib/core/l10n/app_bn.arb` (modify)

**Detailed changes:**
- Add: `settingsAudioCuesLabel`, `settingsAudioCuesDescription`.

**Integration:** Standard `gen_l10n` flow.

---

## Performance Considerations

- **Caching strategy:** Audio assets are loaded from the bundle on demand (not cached in memory between plays).
- **Lazy loading:** Audio player instances are created per-play or as a singleton with reset between plays.
- **Memory efficiency:** Short audio files (<50KB each) loaded into memory briefly for playback.

---

## Testing

- `test/core/notifications/audio_cue_test.dart`:
  - Mock the audio playback API and verify the correct earcon is triggered for each action (Done, Snooze, Skip).
  - Verify earcon fires from both foreground and background handler paths.
  - Verify rapid successive actions queue audio sequentially (no overlap).
- `test/core/notifications/notification_action_handler_test.dart` — assert `AudioCueService.playEarcon()` is called for each action type.
- Manual verification on physical iOS and Android devices, foreground and background, with DND mode on/off.

---

## Localization

New ARB keys:
```
settingsAudioCuesLabel
settingsAudioCuesDescription
```

---

## Edge Cases

1. **Background isolate audio playback** — may be restricted on Android; fall back to foreground playback.
2. **OS Do Not Disturb** — app should not bypass system sound settings; defer to platform.
3. **Audio asset bundle size** — three short files under 50KB each; prefer system sounds if distinguishable.
4. **Rapid successive actions** — queue audio playback, don't overlap concurrent calls.
5. **Foreground vs. background consistency** — same earcon must sound identical in both contexts.
