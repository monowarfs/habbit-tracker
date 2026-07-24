import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Plays the short, local dose-done completion chime
/// (`docs/superpowers/specs/02-delightful/
/// 10-optional-sound-design-pass-design.md`) — the one file in the app
/// that imports `package:audioplayers`, mirroring
/// `notification_service.dart`'s "one file owns the plugin" convention.
class ChimePlayer {
  /// Creates a chime player. [player] is a test seam — [instance], the
  /// one production call site should always use, never passes one and
  /// owns its own real [AudioPlayer].
  ChimePlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  /// The app's single real chime player.
  static final ChimePlayer instance = ChimePlayer();

  final AudioPlayer _player;

  /// `.ambient` (iOS) respects the ring/silent switch and Do Not
  /// Disturb, unlike `.playback`, which overrides both.
  /// `AndroidAudioFocus.none` + `sonification`/`notificationEvent`
  /// steers Android away from treating this like ordinary media
  /// playback (see the spec's "Out of scope" note on Android's
  /// `STREAM_MUSIC` ringer-mode quirk — not fully solved here, flagged
  /// as a follow-up once this is in testers' hands on real devices).
  static final _context = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    android: AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notificationEvent,
    ),
  );

  /// Plays the bundled chime — fire-and-forget, no queueing. Swallows
  /// any playback failure (e.g. an unsupported codec on an emulator)
  /// without throwing: a missed chime is never worth surfacing as an
  /// error to the user or the logger's normal error channel.
  Future<void> playDoseDoneChime() async {
    try {
      await _player.setAudioContext(_context);
      unawaited(_player.play(AssetSource('sounds/dose_done_chime.mp3')));
    } on Object {
      // Deliberately silent — see the doc comment above.
    }
  }
}
