import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/recaps/year_summary.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/widget_summary_data.dart';

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
    required this.quietHoursSuppressible,
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

  /// Whether this notification may be suppressed during quiet hours.
  /// `false` for anything time-sensitive enough that suppressing it
  /// would defeat its purpose.
  final bool quietHoursSuppressible;
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

/// How a module's day went, for the global calendar / Reports / the
/// dashboard's day-completion indicator (D-17).
enum ModuleDayStatusKind {
  /// Every relevant item for the day was completed.
  complete,

  /// Some but not all relevant items were completed.
  partial,

  /// Nothing was completed and the day is fully resolved (not still in
  /// progress).
  missed,

  /// The module was paused on this day (e.g. life-event pause or all
  /// items archived). Paused days are excluded from streak calculations
  /// — they neither count nor break streaks.
  paused,

  /// No data for this day (before the module's first use, or a day still
  /// in progress with nothing logged yet).
  none,
}

/// One day's status for a module, plus its natural numeric value (ml
/// logged, doses taken, prayers completed) for report charts.
@immutable
class ModuleDayStatus {
  /// Creates a day status.
  const ModuleDayStatus({required this.kind, required this.value});

  /// This day's completion category.
  final ModuleDayStatusKind kind;

  /// This day's value in the module's own natural unit.
  final num value;
}

/// One cross-module search hit (D-18).
@immutable
class SearchResult {
  /// Creates a search result.
  const SearchResult({
    required this.title,
    required this.subtitle,
    required this.deepLinkRoute,
  });

  /// The matched record's display title (e.g. a medicine's name).
  final String title;

  /// Secondary detail shown under the title.
  final String subtitle;

  /// Route to open on tap (FR-C-09-style deep link).
  final String deepLinkRoute;
}

/// Badge rarity tier for achievements.
enum BadgeRarity {
  /// Common achievements (easy to unlock).
  common,

  /// Rare achievements (moderate difficulty).
  rare,

  /// Legendary achievements (very hard to unlock).
  legendary,
}

/// One achievement a module contributes to the shared engine
/// (`core/achievements/achievement_engine.dart`, D-16). [currentProgress]
/// is a closure over the module's own repository/use cases — the engine
/// never queries a module's data directly.
@immutable
class AchievementDefinition {
  /// Creates an achievement definition.
  const AchievementDefinition({
    required this.key,
    required this.moduleId,
    required this.titleKey,
    required this.descriptionKey,
    required this.target,
    required this.currentProgress,
    this.rarity = BadgeRarity.common,
  });

  /// Stable key (e.g. `'water_7_day_streak'`), the `achievements.key`
  /// column and this achievement's identity across re-evaluations.
  final String key;

  /// Which module this achievement belongs to.
  final String moduleId;

  /// `AppLocalizations` key naming this achievement's title.
  final String titleKey;

  /// `AppLocalizations` key naming this achievement's description.
  final String descriptionKey;

  /// Progress needed to unlock.
  final int target;

  /// Computes current progress toward [target] from live data.
  final Future<int> Function() currentProgress;

  /// Badge rarity tier for visual treatment.
  final BadgeRarity rarity;
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

  /// Performs this module's one fixed, unconditional quick action — the
  /// headless equivalent of what [quickActions]'s single chip does when
  /// visible, triggered by an OS home-screen/app shortcut tap
  /// (`core/shortcuts/quick_action_handler.dart`). Runs with no `Ref` and no
  /// `BuildContext`, same constraint as [onNotificationAction]. Modules with
  /// nothing due no-op rather than throwing.
  Future<void> onQuickAction();

  /// Per-day status for [range] — used by the global calendar (as-is),
  /// Reports (bucketed by period), and the dashboard's day-completion
  /// indicator (today's entry only). D-17.
  ///
  /// [profileId] defaults to each implementation's own fixed profile id
  /// when omitted (every other `HabitModule` method still only operates
  /// on that fixed profile — see e.g. `WaterModule._fixedProfileId`'s doc
  /// comment). It exists so the household leaderboard (`docs/superpowers/
  /// specs/06-gamification/12-household-leaderboard-IMPLEMENTATION-PLAN
  /// .md`) can read another profile's day status without a `Ref`, without
  /// widening any other method's profile scoping.
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(
    DateRange range, {
    String? profileId,
  });

  /// The next actionable item this module wants surfaced on the
  /// dashboard's upcoming strip, or `null` if there's nothing upcoming.
  /// D-19.
  Widget? nextUpcoming(WidgetRef ref);

  /// One-tap actions this module wants exposed on the dashboard's
  /// quick-actions row. Empty list if none. D-19.
  List<Widget> quickActions(WidgetRef ref);

  /// Free-text search over this module's own named user data. Modules
  /// with nothing free-text-searchable return `[]`. D-18.
  Future<List<SearchResult>> search(String query);

  /// Achievement definitions this module contributes, evaluated by
  /// `core/achievements/achievement_engine.dart`. D-16.
  List<AchievementDefinition> get achievementDefinitions;

  /// Exports this module's data (backup groundwork, v1.1).
  Future<ModuleExport> exportData();

  /// Imports previously-exported data for this module (v1.1).
  Future<void> importData(ModuleExport data);

  /// This module's home-screen-widget summary, or `null` if it has
  /// nothing worth surfacing (e.g. Water before any goal is set, or all
  /// Medicine doses already done). Ref-free — called from the same
  /// background isolate as [onNotificationAction].
  Future<WidgetSummaryData?> widgetSummary();

  /// Deletes every row this module owns. The wipe half of import's
  /// replace semantics (`core/backup/wipe_all_data.dart`) — never called
  /// standalone outside that orchestrator.
  Future<void> wipeData();

  /// Aggregates this module's stats for the given [yearRange] into a
  /// [ModuleYearStats] for the yearly recap. Returns `null` if the module
  /// has no data in the range.
  Future<ModuleYearStats?> yearAggregation(DateRange yearRange);
}
