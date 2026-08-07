import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/features/mood/domain/entities/mood_log.dart';
import 'package:habit_tracker/features/mood/domain/usecases/log_mood_use_case.dart';
import 'package:habit_tracker/features/mood/presentation/providers/mood_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mood_controller.g.dart';

/// Mutation surface for the Mood module — a pure command controller (see
/// `SleepController`'s doc comment for why `keepAlive: true` is required
/// here too).
@Riverpod(keepAlive: true)
class MoodController extends _$MoodController {
  @override
  void build() {}

  Future<String> _activeProfileId() =>
      ref.read(activeProfileProvider.future).then((p) => p.id);

  /// Logs a quick check-in. Returns the [Result] so a caller can show
  /// the specific validation message on failure rather than a generic
  /// one — see Blood Pressure's review round for why this shape (not a
  /// plain `bool`) is the right one.
  Future<Result<MoodLog>> logMood(int moodValue, {String? notes}) async {
    final profileId = await _activeProfileId();
    final repository = ref.read(moodRepositoryProvider);
    final result = await LogMoodUseCase(repository).execute(
      moodValue: moodValue,
      profileId: profileId,
      notes: notes,
    );
    if (result case Failure(:final error)) {
      logException(error);
      return result;
    }
    await ref
        .read(achievementEngineProvider)
        .evaluate('mood', profileId: profileId);
    return result;
  }

  /// Deletes a check-in.
  Future<bool> deleteLog(String id) async {
    final profileId = await _activeProfileId();
    final result = await ref
        .read(moodRepositoryProvider)
        .deleteLog(id, profileId: profileId);
    if (result case Failure(:final error)) {
      logException(error);
      return false;
    }
    return true;
  }
}
