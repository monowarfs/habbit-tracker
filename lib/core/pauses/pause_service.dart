import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';
import 'package:habit_tracker/core/pauses/pause_repository.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:uuid/uuid.dart';

/// Business logic for creating, cancelling, and querying pauses.
class PauseService {
  /// Creates a service.
  const PauseService({
    required this.pauseRepository,
    required this.notificationLedger,
  });

  /// Repository for pause CRUD.
  final PauseRepository pauseRepository;

  /// Ledger for notification suppression.
  final NotificationLedgerRepository notificationLedger;

  /// Creates a pause, validates no overlaps, suppresses notifications.
  Future<void> createPause({
    required String moduleId,
    required LocalDate startDate,
    required LocalDate endDate,
    required String profileId,
  }) async {
    // Validate no overlaps.
    final overlaps = await pauseRepository.overlapping(
      moduleId: moduleId,
      start: startDate,
      end: endDate,
      profileId: profileId,
    );
    if (overlaps.isNotEmpty) {
      throw StateError('Pause overlaps with existing pause');
    }

    final now = clock.now().toUtc().millisecondsSinceEpoch;
    final id = const Uuid().v4();

    await pauseRepository.create(
      PauseRangeRow(
        id: id,
        moduleId: moduleId,
        startDate: startDate.toIso(),
        endDate: endDate.toIso(),
        createdAt: now,
        profileId: profileId,
      ),
    );

    // Suppress pending notifications for this module during the pause.
    final pending = await notificationLedger.pendingRows(profileId: profileId);
    final modulePending = pending.where(
      (row) => row.moduleId == moduleId,
    );
    for (final row in modulePending) {
      final scheduledDate = LocalDate.fromDateTime(
        DateTime.fromMillisecondsSinceEpoch(row.scheduledFor, isUtc: true),
      );
      if (scheduledDate.compareTo(startDate) >= 0 &&
          scheduledDate.compareTo(endDate) <= 0) {
        await NotificationService.instance.cancel(row.id);
        await notificationLedger.cancel(row.id, profileId: profileId);
      }
    }
  }

  /// Cancels a pause, re-enables notifications (re-planner handles
  /// re-scheduling on next app resume).
  Future<void> cancelPause(String pauseId, {required String profileId}) async {
    await pauseRepository.cancel(pauseId, profileId: profileId);
  }

  /// Returns the set of paused days for [moduleId] within [range].
  Future<Set<LocalDate>> pausedDaysInRange({
    required String moduleId,
    required DateRange range,
    required String profileId,
  }) async {
    final pauses = await pauseRepository.activeForModule(
      moduleId,
      profileId: profileId,
    );
    final pausedDays = <LocalDate>{};
    for (final pause in pauses) {
      final pauseStart = LocalDate.parse(pause.startDate);
      final pauseEnd = LocalDate.parse(pause.endDate);
      // Clamp to the requested range.
      final effectiveStart = pauseStart.compareTo(range.start) < 0
          ? range.start
          : pauseStart;
      final effectiveEnd = pauseEnd.compareTo(range.end) > 0
          ? range.end
          : pauseEnd;
      var day = effectiveStart;
      while (day.compareTo(effectiveEnd) <= 0) {
        pausedDays.add(day);
        day = day.addDays(1);
      }
    }
    return pausedDays;
  }

  /// All active pause ranges for [moduleId].
  Future<List<PauseRangeRow>> activePauses(
    String moduleId, {
    required String profileId,
  }) {
    return pauseRepository.activeForModule(moduleId, profileId: profileId);
  }
}
