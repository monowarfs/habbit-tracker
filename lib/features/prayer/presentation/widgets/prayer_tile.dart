import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:intl/intl.dart';

/// One row of the checklist (FR-P-07) — a prayer's display label,
/// scheduled time, live status, and a tap-to-mark-prayed toggle (only
/// while not yet `missed` — the toggle is a one-tap "Prayed" action,
/// never a manual "missed" tap target).
class PrayerTile extends StatelessWidget {
  /// Creates a prayer tile.
  const PrayerTile({
    required this.view,
    required this.onToggle,
    this.highlighted = false,
    super.key,
  });

  /// The record view to render.
  final PrayerRecordView view;

  /// Called when the user taps the "Prayed" toggle.
  final VoidCallback onToggle;

  /// Whether this tile should be visually highlighted (notification
  /// deep-link target).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = theme.extension<AppSemanticColors>()!.success;
    final label =
        view.showAsJumuah ? "Jumu'ah" : _labelFor(view.record.prayerName);
    final canToggle = view.effectiveStatus != PrayerStatus.missed;
    return Card(
      color: highlighted ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        title: Text(label),
        subtitle: Text(
          '${DateFormat.jm().format(view.record.scheduledFor.toLocal())} · '
          '${_statusLabel(view.effectiveStatus)}',
        ),
        trailing: canToggle
            ? IconButton(
                icon: Icon(
                  view.effectiveStatus == PrayerStatus.prayed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: view.effectiveStatus == PrayerStatus.prayed
                      ? success
                      : null,
                ),
                onPressed: onToggle,
              )
            : const Icon(Icons.cancel_outlined),
      ),
    );
  }

  String _labelFor(PrayerName name) => switch (name) {
    PrayerName.fajr => 'Fajr',
    PrayerName.dhuhr => 'Dhuhr',
    PrayerName.asr => 'Asr',
    PrayerName.maghrib => 'Maghrib',
    PrayerName.isha => 'Isha',
  };

  String _statusLabel(PrayerStatus status) => switch (status) {
    PrayerStatus.upcoming => 'Upcoming',
    PrayerStatus.due => 'Due',
    PrayerStatus.prayed => 'Prayed',
    PrayerStatus.missed => 'Missed',
  };
}
