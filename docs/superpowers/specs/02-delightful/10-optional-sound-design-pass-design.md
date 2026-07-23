# Sound Design Pass, Optional Off by Default

**Category:** Delightful · **Atlas complexity:** S · **Retention impact:** Low-Medium
**Date:** 2026-07-23
**Status:** Draft — implementation-ready

## Problem

`grep -n "audioplayers\|just_audio\|audio" pubspec.yaml` finds nothing —
this app has never played audio outside `flutter_local_notifications`'
own OS-level notification sound (`lib/core/notifications/
notification_service.dart`, the one file that imports that plugin). A
genuinely new dependency is required; there is no existing in-app audio
capability to reuse (rung 5 of the ladder — new dependency — is
unavoidable here, not a shortcut being skipped).

**Package choice: `audioplayers`, not `just_audio`.** `just_audio` is
built for streaming/playlists/background audio sessions with queue
management — none of which this feature needs. `audioplayers` is the
smaller, simpler API for exactly this shape of need (play one short
bundled local asset, fire-and-forget, no queue) and — the deciding
factor for the silent-mode requirement below — exposes an `AudioContext`
API that directly maps to the platform knobs this feature needs:
`AudioContextIOS(category: AVAudioSessionCategory.ambient)` (the iOS
category that **respects** the ring/silent switch and Do Not Disturb,
as opposed to `.playback`, which overrides both) and
`AudioContextAndroid(audioFocus: AndroidAudioFocus.none, contentType:
AndroidContentType.sonification)`. `just_audio` can be configured
similarly but is heavier machinery for a one-shot chime.

**Exact call site.** CLAUDE.md and the reference undo spec both point at
the same place: `MedicineController.markDoseDone`
(`lib/features/medicine/presentation/providers/medicine_controller.dart:
82-94`) is the write path, but it is called from **two** contexts —
the UI (`_markDoneAndCelebrate` in `lib/features/medicine/presentation/
screens/medicine_home_screen.dart:99-129`) **and** a background isolate
with no `BuildContext`/audio session
(`lib/features/medicine/medicine_module.dart:205,229` call
`_repository.markDoseDone` directly from `onNotificationAction`, per
CLAUDE.md's note that this runs "from the foreground or a fresh
background isolate"). Playing a sound inside the controller or
repository would therefore sometimes fire from a headless isolate with
no valid audio output path. **The chime must hook into the UI-only call
site**, `_markDoneAndCelebrate`, right after line 114's
`await controller.markDoseDone(doseId);` succeeds — the same point
where that function already decides whether to show the undo snackbar
and the achievement-unlock snackbar, so it's one more sibling side
effect at an already-established "the dose was just marked done, react
to it" point, not a new one.

## Design

**New dependency (`pubspec.yaml`):** `audioplayers: ^6.x` (latest at
implementation time) under the existing alphabetical dependency block
(between `adhan_dart` and `clock`, matching the file's current
alphabetical ordering).

**New asset:** `assets/sounds/dose_done_chime.mp3` — one short
(<1s), soft, non-jarring chime, bundled locally (no network fetch).
Register in `pubspec.yaml`'s `flutter.assets` list alongside the
existing `assets/data/prayer_cities.json` entry:
```yaml
assets:
  - assets/data/prayer_cities.json
  - assets/sounds/dose_done_chime.mp3
```

**New file — `lib/core/audio/chime_player.dart`** (mirrors
`notification_service.dart`'s role as "the one file that imports the
plugin directly"):

```dart
/// Plays the short, local completion chime — silent-mode-respecting by
/// construction (see [_context]), fire-and-forget, no queueing. The one
/// file in the app that imports `package:audioplayers`.
class ChimePlayer {
  ChimePlayer._();
  static final ChimePlayer instance = ChimePlayer._();

  final AudioPlayer _player = AudioPlayer();

  static const _context = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    android: AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notificationEvent,
    ),
  );

  /// No-ops silently on playback failure (e.g. unsupported codec on an
  /// emulator) — a missed chime is never worth surfacing as an error to
  /// the user or the logger's normal error channel.
  Future<void> playDoseDoneChime() async {
    await _player.setAudioContext(_context);
    unawaited(_player.play(AssetSource('sounds/dose_done_chime.mp3')));
  }
}
```

**Call site** — `medicine_home_screen.dart`'s `_markDoneAndCelebrate`,
right after the existing `await controller.markDoseDone(doseId);` at
line 114, gated on the new settings field:

```dart
await controller.markDoseDone(doseId);
if (ref.read(appSettingsProvider).value?.soundEnabled ?? false) {
  unawaited(ChimePlayer.instance.playDoseDoneChime());
}
```
(`unawaited` — the chime must never block or delay the undo/achievement
snackbar sequencing that already follows on the next lines.)

**Settings — new `AppSettings` field, following the existing boolean-
toggle pattern (`biometricEnabled`/`screenPrivacyEnabled`):**

- `lib/core/database/tables/app_settings_table.dart`: `BoolColumn get
  soundEnabled => boolean().withDefault(const Constant(false))();` —
  default `false`, matching the atlas item's "off by default" goal and
  `screenPrivacyEnabled`'s existing off-by-default precedent.
- Migration: `schemaVersion` 7 → 8 (or 9 if item 6's spec is implemented
  first and already claimed 8 — coordinate at implementation time),
  `if (from < N) { await m.addColumn(appSettingsTable,
  appSettingsTable.soundEnabled); }`.
- `AppSettings` entity/Freezed union: add `bool soundEnabled` field
  (required, not nullable — it always has a default).
- `SettingsRepository`/`SettingsRepositoryImpl`: add
  `Future<Result<void>> updateSoundEnabled({required bool enabled})`,
  a one-line `_update(AppSettingsTableCompanion(soundEnabled:
  Value(enabled)))`, the same shape as `updateBiometricEnabled`
  (`settings_repository_impl.dart:81-83`).

**Settings UI — `lib/features/settings/presentation/screens/
settings_home_screen.dart`:** a single `SwitchListTile` is the right
size here (a lone boolean needs no dedicated sub-screen, unlike Quiet
Hours' multi-field settings group). Insert a new section between the
existing Notifications group (ends at line 66) and Security
(`_SectionHeader` at line 68):

```dart
const Divider(),
_SectionHeader(l10n.settingsSound),
SwitchListTile(
  secondary: const Icon(Icons.volume_up_outlined),
  title: Text(l10n.settingsSoundToggle),
  value: ref.watch(appSettingsProvider).value?.soundEnabled ?? false,
  onChanged: (value) => ref
      .read(settingsControllerProvider.notifier)
      .updateSoundEnabled(enabled: value),
),
```

**New l10n keys (both `app_en.arb`/`app_bn.arb`):** `settingsSound`
("Sound"), `settingsSoundToggle` ("Play a chime when a dose is marked
done").

## Out of scope

- **Water quick-add / Prayer checklist-toggle chimes.** CLAUDE.md and
  this spec's own instructions scope this to Medicine's dose-done only;
  the atlas draft's "optionally too" for Water/Prayer is explicitly
  deferred. `ChimePlayer.playDoseDoneChime()` is named for the one call
  site it has today — a generic `play(SoundId)` API is not built until
  a second call site actually exists (YAGNI; same reasoning the undo
  spec used for its "4th call site" note).
- **Per-module distinct sounds / a sound "theme" echoing per-module
  accent colors.** One universal chime, one asset, one settings toggle.
- **Custom sound packs or user-selectable sounds.** One well-chosen
  default only, per the original draft's own non-goal.
- **A per-module (vs. global) toggle.** One global `soundEnabled` flag.
  If Medicine-only vs. Water-only granularity is ever wanted, it's an
  additive field later — not building it speculatively now.
- **Explicit runtime detection/override of Android's ringer-mode
  quirk.** Android's `STREAM_MUSIC`/media playback is not muted by the
  ring/notification silent switch the way `STREAM_RING`/
  `STREAM_NOTIFICATION` are — this is a known platform gotcha, distinct
  from iOS where `.ambient` reliably respects the physical silent
  switch. `AndroidContentType.sonification` +
  `usageType: notificationEvent` steers the platform toward treating
  this like a notification-adjacent sound (more likely to honor Do Not
  Disturb) rather than a media stream, but this spec does **not** add
  a manual `AudioManager.getRingerMode()` check — verifying and, if
  needed, hardening this is flagged as a follow-up once the feature is
  in testers' hands on real Android devices, not solved speculatively
  here.
- **Sounds on notification actions (Done/Snooze/Skip tapped from the
  notification tray itself).** Those fire the same
  `onNotificationAction` background-isolate path this spec's Problem
  section already ruled out as an audio call site — no headless-isolate
  audio session is attempted.

## Global Constraints

- **New dependency:** `audioplayers` (not previously in `pubspec.yaml` —
  confirmed by grep). No other new package.
- **New asset:** `assets/sounds/dose_done_chime.mp3`, registered in
  `pubspec.yaml`'s `flutter.assets`.
- **Schema migration required:** `AppSettingsTable` gains `soundEnabled`
  (`BoolColumn`, default `false`). Bump `schemaVersion` and add the
  matching `if (from < N)` block in `app_database.dart`'s
  `MigrationStrategy.onUpgrade`, per the existing pattern (most recently
  `if (from < 7)` for per-weekday reminder overrides). Run
  `dart run build_runner build --delete-conflicting-outputs` after the
  table/entity change, and `flutter gen-l10n` after the ARB additions.
- **Default is off** (`soundEnabled: false`) — no behavior change for
  any existing user until they opt in via the new Settings toggle.
- `ChimePlayer` is the only new file importing `package:audioplayers`,
  mirroring `notification_service.dart`'s "one file owns the plugin"
  convention already established for `flutter_local_notifications`.
- No change to `core/notifications/` at all — the OS notification sound
  and this in-app chime are fully independent; nothing here touches
  `notification_service.dart`'s channel setup.
