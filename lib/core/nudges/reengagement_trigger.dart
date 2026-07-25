/// The action to take when checking the re-engagement trigger.
enum ReEngagementAction {
  /// No nudge due.
  none,

  /// Send a system-level notification.
  showNotification,

  /// Show a dashboard banner (fallback when notifications are disabled).
  showDashboardBanner,
}

/// Result of checking the re-engagement trigger.
class ReEngagementResult {
  /// Creates a result.
  const ReEngagementResult({
    required this.action,
    this.daysSinceActivity,
  });

  /// The action to take.
  final ReEngagementAction action;

  /// How many days since the user's last activity (for display).
  final int? daysSinceActivity;
}

/// Pure logic: checks whether a re-engagement nudge should be sent.
///
/// Fires when:
/// - User has been inactive for >= 7 days
/// - User has had the app for >= 7 days (grace period)
/// - No nudge has already been sent for this lapse
ReEngagementResult checkReEngagement({
  required DateTime? lastActivityAt,
  required DateTime? installDate,
  required DateTime? nudgeSentAfter,
  required bool notificationsEnabled,
  required DateTime now,
}) {
  if (lastActivityAt == null || installDate == null) {
    return const ReEngagementResult(action: ReEngagementAction.none);
  }

  final daysSinceInstall = now.difference(installDate).inDays;
  if (daysSinceInstall < 7) {
    return const ReEngagementResult(action: ReEngagementAction.none);
  }

  final daysSinceActivity = now.difference(lastActivityAt).inDays;
  if (daysSinceActivity < 7) {
    return const ReEngagementResult(action: ReEngagementAction.none);
  }

  // If a nudge was already sent after this activity, don't re-nudge
  // until the user becomes active again (which resets lastActivityAt).
  if (nudgeSentAfter != null) {
    final daysSinceNudge = now.difference(nudgeSentAfter).inDays;
    if (daysSinceActivity < daysSinceNudge) {
      return const ReEngagementResult(action: ReEngagementAction.none);
    }
  }

  if (!notificationsEnabled) {
    return ReEngagementResult(
      action: ReEngagementAction.showDashboardBanner,
      daysSinceActivity: daysSinceActivity,
    );
  }

  return ReEngagementResult(
    action: ReEngagementAction.showNotification,
    daysSinceActivity: daysSinceActivity,
  );
}
