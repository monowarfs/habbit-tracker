import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/notifications/audio_cue_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  late _MockAudioPlayer player;

  setUpAll(() {
    registerFallbackValue(AssetSource('audio/earcon_done.mp3'));
    registerFallbackValue(AudioContext());
  });

  setUp(() {
    player = _MockAudioPlayer();
    when(() => player.setAudioContext(any())).thenAnswer((_) async {});
    when(() => player.play(any())).thenAnswer((_) async {});
  });

  test('plays the done earcon for a done action', () async {
    final service = AudioCueService(player: player);

    await service.playEarcon(NotificationActionType.done);

    final played = verify(() => player.play(captureAny())).captured.single;
    expect((played as AssetSource).path, 'audio/earcon_done.mp3');
  });

  test('plays the snooze earcon for a snooze action', () async {
    final service = AudioCueService(player: player);

    await service.playEarcon(NotificationActionType.snooze);

    final played = verify(() => player.play(captureAny())).captured.single;
    expect((played as AssetSource).path, 'audio/earcon_snooze.mp3');
  });

  test('plays the skip earcon for a skip action', () async {
    final service = AudioCueService(player: player);

    await service.playEarcon(NotificationActionType.skip);

    final played = verify(() => player.play(captureAny())).captured.single;
    expect((played as AssetSource).path, 'audio/earcon_skip.mp3');
  });

  test('swallows a playback failure without throwing', () async {
    when(() => player.setAudioContext(any())).thenThrow(Exception('boom'));
    final service = AudioCueService(player: player);

    await expectLater(
      service.playEarcon(NotificationActionType.done),
      completes,
    );
  });

  test('queues rapid successive calls instead of overlapping', () async {
    final service = AudioCueService(player: player);

    final first = service.playEarcon(NotificationActionType.done);
    final second = service.playEarcon(NotificationActionType.skip);

    await Future.wait([first, second]);

    final played = verify(() => player.play(captureAny())).captured;
    expect(played, hasLength(2));
    expect((played[0] as AssetSource).path, 'audio/earcon_done.mp3');
    expect((played[1] as AssetSource).path, 'audio/earcon_skip.mp3');
  });
}
