import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/backup/drive_backup_repository.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/settings/presentation/providers/locale_controller.dart';

/// Builds a system-level [PendingNotification] nudging the user to back up
/// to Google Drive, or `null` if no reminder is due
/// (`docs/superpowers/specs/04-premium/01-google-drive-backup-restore-
/// design.md`). Same "checked on app resume, fires at most once per
/// eligible day" shape as `core/nudges/reengagement_nudge.dart` — a local
/// reminder, not tied to any module's `pendingNotifications()`, so it
/// intentionally bypasses that whole pipeline.
PendingNotification? buildBackupReminder({
  required bool enabled,
  required DateTime? lastBackupAt,
  required DateTime now,
  required AppLocalizations l10n,
}) {
  if (!enabled) return null;
  if (lastBackupAt != null && now.difference(lastBackupAt).inHours < 24) {
    return null;
  }
  final dayKey = now.toUtc().toIso8601String().substring(0, 10);
  return PendingNotification(
    id: 'drive_backup_reminder_$dayKey',
    scheduledAt: now.add(const Duration(minutes: 1)),
    title: l10n.driveBackupReminderTitle,
    body: l10n.driveBackupReminderBody,
    sourceType: 'drive_backup_reminder',
    deepLinkRoute: '/settings/backup',
    quietHoursSuppressible: true,
  );
}

/// Checks whether a Drive backup reminder is due and schedules it if so.
/// Called from the app lifecycle on foreground resume, same trigger as
/// [core/nudges/reengagement_check.dart]'s `checkReEngagementNudge`.
Future<void> checkBackupReminder(WidgetRef ref) async {
  final settings = await ref.read(appSettingsProvider.future);
  if (!settings.driveBackupReminderEnabled) return;

  final db = ref.read(databaseProvider);
  final latest = await DriveBackupRepository(db).latestBackup();
  final lastBackupAt = latest == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(latest.backedUpAt, isUtc: true);

  final locale = ref.read(localeControllerProvider);
  final l10n = await AppLocalizations.delegate.load(locale);
  final reminder = buildBackupReminder(
    enabled: settings.driveBackupReminderEnabled,
    lastBackupAt: lastBackupAt,
    now: clock.now(),
    l10n: l10n,
  );
  if (reminder == null) return;

  await NotificationService.instance.schedule(
    reminder,
    moduleId: 'system',
    snoozeCount: 0,
  );
  await NotificationLedgerRepository(db).insertScheduled(
    id: reminder.id,
    moduleId: 'system',
    sourceType: reminder.sourceType,
    sourceId: reminder.id,
    title: reminder.title,
    body: reminder.body,
    scheduledFor: reminder.scheduledAt,
    deepLinkRoute: reminder.deepLinkRoute,
    originalScheduledFor: reminder.scheduledAt,
  );
}
