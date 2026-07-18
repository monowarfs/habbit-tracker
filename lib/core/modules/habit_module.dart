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

/// A notification a module wants scheduled, read by the boot receiver
/// (FR-C-08) from the shared `notification_ledger` table
/// (`technical/architecture.md`).
@immutable
class PendingNotification {
  /// Creates a pending notification descriptor.
  const PendingNotification({
    required this.id,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });

  /// Ledger row id.
  final String id;

  /// When this notification should fire.
  final DateTime scheduledAt;

  /// Notification title.
  final String title;

  /// Notification body.
  final String body;
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
/// modules — `core/` code (router, dashboard, settings, boot receiver)
/// iterates `module_registry.dart`'s list uniformly and never branches on
/// which module it's looking at.
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

  /// Notifications this module wants scheduled, for the boot receiver
  /// (FR-C-08) to re-register after a device reboot.
  Future<List<PendingNotification>> pendingNotifications();

  /// Exports this module's data (backup groundwork, v1.1).
  Future<ModuleExport> exportData();

  /// Imports previously-exported data for this module (v1.1).
  Future<void> importData(ModuleExport data);
}
