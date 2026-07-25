import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';

/// Builds a system-level [PendingNotification] for the re-engagement nudge,
/// or null if no nudge is due.
PendingNotification? buildReEngagementNudge({
  required DateTime lastActivityAt,
  required AppLocalizations l10n,
}) {
  final id = 'reengagement_nudge_${lastActivityAt.millisecondsSinceEpoch}';

  return PendingNotification(
    id: id,
    scheduledAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
    title: l10n.reengagementNudgeTitle,
    body: l10n.reengagementNudgeBody,
    sourceType: 'reengagement_nudge',
    deepLinkRoute: '/',
    quietHoursSuppressible: true,
  );
}
