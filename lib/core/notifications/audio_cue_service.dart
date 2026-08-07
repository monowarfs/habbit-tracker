import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';

/// Plays a short earcon confirming a Done/Snooze/Skip notification action
/// (`docs/superpowers/specs/07-accessibility/
/// 08-AUDIO-CUE-ALTERNATIVE-NOTIFICATION-ACTIONS-IMPLEMENTATION-PLAN.md`)
/// — a non-visual confirmation for a user who acts on a notification
/// without looking at the screen. Mirrors `core/audio/chime_player.dart`'s
/// "one file owns this AudioPlayer" convention and its silent-failure
/// policy (a missed earcon is never worth surfacing as an error), extended
/// with a serial play queue so rapid Done/Snooze/Skip taps never overlap.
class AudioCueService {
  /// Creates a service. [player] is a test seam — [instance], the one
  /// production call site, always uses a real [AudioPlayer].
  AudioCueService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  /// The app's single real audio-cue service.
  static final AudioCueService instance = AudioCueService();

  final AudioPlayer _player;
  Future<void> _queue = Future<void>.value();

  /// `.ambient` (iOS) respects the ring/silent switch and Do Not Disturb,
  /// unlike `.playback`, which overrides both — same reasoning as
  /// `ChimePlayer`'s context, and required by this spec's "app should
  /// not bypass system sound settings" edge case.
  static final _context = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notificationEvent,
    ),
  );

  static const _assetPaths = {
    NotificationActionType.done: 'audio/earcon_done.mp3',
    NotificationActionType.snooze: 'audio/earcon_snooze.mp3',
    NotificationActionType.skip: 'audio/earcon_skip.mp3',
  };

  /// Plays the earcon for [action]. Chained behind any earcon already
  /// queued so rapid successive actions play one after another instead of
  /// overlapping.
  Future<void> playEarcon(NotificationActionType action) {
    final next = _queue.then((_) => _playNow(action));
    _queue = next;
    return next;
  }

  Future<void> _playNow(NotificationActionType action) async {
    final path = _assetPaths[action];
    if (path == null) return;
    try {
      await _player.setAudioContext(_context);
      await _player.play(AssetSource(path));
      // ponytail: the earcons are fixed, short (<=250ms) synthesized
      // tones, so a flat delay stands in for "playback finished" instead
      // of listening on `onPlayerComplete` — cheap to test (no stream
      // mocking) and correct for every asset this service ships today.
      // Swap to `onPlayerComplete` if a longer/variable-length earcon is
      // ever added.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } on Object {
      // Deliberately silent — see the class doc comment.
    }
  }
}
