import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/recalibration/recalibration_repository.dart';
import 'package:habit_tracker/core/recalibration/recalibration_service.dart';

/// Provides the [RecalibrationRepository].
final recalibrationRepositoryProvider =
    Provider<RecalibrationRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return RecalibrationRepository(db);
});

/// Provides the [RecalibrationSessionTracker] (singleton per app session).
final recalibrationSessionTrackerProvider =
    Provider<RecalibrationSessionTracker>((ref) {
  return RecalibrationSessionTracker();
});

/// Provides the [RecalibrationService].
final recalibrationServiceProvider = Provider<RecalibrationService>((ref) {
  return RecalibrationService(
    repository: ref.watch(recalibrationRepositoryProvider),
    sessionTracker: ref.watch(recalibrationSessionTrackerProvider),
  );
});
