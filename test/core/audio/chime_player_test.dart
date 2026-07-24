import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/audio/chime_player.dart';
import 'package:mocktail/mocktail.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  late _MockAudioPlayer player;

  setUpAll(() {
    registerFallbackValue(AssetSource('sounds/dose_done_chime.mp3'));
    registerFallbackValue(AudioContext());
  });

  setUp(() {
    player = _MockAudioPlayer();
    when(() => player.setAudioContext(any())).thenAnswer((_) async {});
    when(() => player.play(any())).thenAnswer((_) async {});
  });

  test(
    'sets the silent-mode-respecting audio context, then plays the '
    'bundled asset',
    () async {
      final chime = ChimePlayer(player: player);

      await chime.playDoseDoneChime();

      verify(() => player.setAudioContext(any())).called(1);
      final played = verify(() => player.play(captureAny())).captured.single;
      expect(played, isA<AssetSource>());
      expect((played as AssetSource).path, 'sounds/dose_done_chime.mp3');
    },
  );

  test('swallows a playback failure without throwing', () async {
    when(() => player.setAudioContext(any())).thenThrow(Exception('boom'));
    final chime = ChimePlayer(player: player);

    await expectLater(chime.playDoseDoneChime(), completes);
  });
}
