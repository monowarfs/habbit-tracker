import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';
import 'package:habit_tracker/core/nudges/last_activity_repository.dart';
import 'package:habit_tracker/core/nudges/reengagement_nudge.dart';
import 'package:habit_tracker/core/nudges/reengagement_trigger.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/settings/presentation/providers/locale_controller.dart';

/// Checks whether a re-engagement nudge should be sent and sends it
/// if needed. Called from the app lifecycle on foreground resume.
Future<void> checkReEngagementNudge(WidgetRef ref) async {
  final settings = await ref.read(appSettingsProvider.future);
  final db = ref.read(databaseProvider);
  final lastActivityRepo = LastActivityRepository(db);
  final ledgerRepo = NotificationLedgerRepository(db);

  if (!settings.reengagementNudgeEnabled) return;

  final lastActivity = await lastActivityRepo.mostRecentActivity();

  // Read nudgeSentAfter from the DB row.
  final row =
      await (db.select(db.appSettingsTable)
            ..where((t) => t.id.equals('singleton'))
            ..limit(1))
          .getSingleOrNull();
  final nudgeSentAfter = row?.nudgeSentAfter == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(
          row!.nudgeSentAfter!,
          isUtc: true,
        );

  final result = checkReEngagement(
    lastActivityAt: lastActivity,
    installDate: settings.installDate,
    nudgeSentAfter: nudgeSentAfter,
    notificationsEnabled: settings.soundEnabled,
    now: clock.now(),
  );

  if (result.action == ReEngagementAction.showNotification) {
    // Load localization for notification content.
    final locale = ref.read(localeControllerProvider);
    final l10n = await AppLocalizations.delegate.load(locale);

    final nudge = buildReEngagementNudge(
      lastActivityAt: lastActivity!,
      l10n: l10n,
    );
    if (nudge == null) return;

    await NotificationService.instance.schedule(
      nudge,
      moduleId: 'system',
      snoozeCount: 0,
    );

    await ledgerRepo.insertScheduled(
      id: nudge.id,
      moduleId: 'system',
      sourceType: nudge.sourceType,
      sourceId: nudge.id,
      title: nudge.title,
      body: nudge.body,
      scheduledFor: nudge.scheduledAt,
      deepLinkRoute: nudge.deepLinkRoute,
      originalScheduledFor: nudge.scheduledAt,
    );

    // Record nudge timestamp to prevent re-nudging.
    await ref
        .read(settingsRepositoryProvider)
        .updateNudgeSentAfter(clock.now());
  }
}
