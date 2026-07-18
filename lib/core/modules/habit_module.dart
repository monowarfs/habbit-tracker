import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Display metadata for a module, used by the dashboard tile and nav bar.
@immutable
class ModuleMetadata {
  /// Creates module display metadata.
  const ModuleMetadata({
    required this.displayName,
    required this.icon,
    required this.accentColor,
  });

  /// The module's human-readable name (e.g. "Water").
  final String displayName;

  /// The icon shown in the nav bar and dashboard tile.
  final IconData icon;

  /// The module's identity color (`strategies/theme.md`) — used only for
  /// this module's own icon/tile/nav highlight, never as a `ColorScheme` role.
  final Color accentColor;
}

/// A notification a module wants scheduled, read by `core/notifications`'
/// planner (FR-C-08) from the shared `notification_ledger` table
/// (`technical/architecture.md`).
///
/// **Correction (Run 08 implementation):** `sourceType`/`deepLinkRoute` were
/// added — `notification_ledger`'s schema (`technical/database-design.md`)
/// always carried these columns, but nothing on this contract could supply
/// them until the notification engine that consumes this list existed.
@immutable
class PendingNotification {
  /// Creates a pending notification descriptor.
  const PendingNotification({
    required this.id,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.sourceType,
    required this.deepLinkRoute,
  });

  /// Stable id for this notification instance — doubles as the
  /// `notification_ledger` row id and `source_id`.
  final String id;

  /// When this notification should fire.
  final DateTime scheduledAt;

  /// Notification title.
  final String title;

  /// Notification body.
  final String body;

  /// `notification_ledger.source_type` (e.g. `'water_reminder'`).
  final String sourceType;

  /// Route to open when this notification is tapped (FR-C-09).
  final String deepLinkRoute;
}

/// Done/Snooze/Skip, as reported to the owning module via
/// [HabitModule.onNotificationAction] (`strategies/notifications.md`).
enum NotificationActionType {
  /// The user marked the reminder done.
  done,

  /// The user snoozed the reminder (never mutates module data — see
  /// `strategies/notifications.md`'s "streak effect: none" note).
  snooze,

  /// The user dismissed the reminder without acting on it.
  skip,
}

/// A module's exported data payload (`strategies/backup-import-export.md`
/// groundwork — full export/import ships in v1.1).
@immutable
class ModuleExport {
  /// Creates a module export payload.
  const ModuleExport(this.payload);

  /// The module-defined, JSON-serializable export payload.
  final Map<String, Object?> payload;
}

/// The plugin contract every habit module (Water, Medicine, Prayer, and any
/// future module) implements to register itself, per
/// `technical/architecture.md`. This is the one shared touchpoint between
/// modules — `core/` code (router, dashboard, settings, notification
/// engine) iterates `module_registry.dart`'s list uniformly and never
/// branches on which module it's looking at.
abstract class HabitModule {
  /// Stable module id (e.g. `'water'`, `'medicine'`, `'prayer'`).
  String get id;

  /// Display metadata for the dashboard tile and nav bar.
  ModuleMetadata get metadata;

  /// This module's `GoRouter` routes.
  List<RouteBase> get routes;

  /// The dashboard tile summarizing this module's current state (FR-C-03).
  Widget dashboardSummary(WidgetRef ref);

  /// This module's section in Settings, or `null` if it has none.
  Widget? settingsEntry(WidgetRef ref);

  /// Notifications this module wants scheduled within the near-term
  /// scheduling window (`strategies/notifications.md`'s "Window 2"), for
  /// `core/notifications`'s planner to materialize as real OS notifications.
  Future<List<PendingNotification>> pendingNotifications();

  /// **Added (Run 08 implementation):** reacts to a Done/Snooze/Skip action
  /// on one of this module's own notifications. `sourceId` is whatever `id`
  /// that notification was given in [pendingNotifications]. Runs from the
  /// notification background isolate
  /// (`core/notifications/notification_action_handler.dart`) as well as
  /// the foreground — implementations must not assume a `Ref`.
  Future<void> onNotificationAction(
    String sourceId,
    NotificationActionType action,
  );

  /// Exports this module's data (backup groundwork, v1.1).
  Future<ModuleExport> exportData();

  /// Imports previously-exported data for this module (v1.1).
  Future<void> importData(ModuleExport data);
}
