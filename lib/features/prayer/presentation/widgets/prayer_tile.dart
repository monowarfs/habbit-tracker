import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
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
    required this.onNoteTap,
    this.highlighted = false,
    super.key,
  });

  /// The record view to render.
  final PrayerRecordView view;

  /// Called when the user taps the "Prayed" toggle.
  final VoidCallback onToggle;

  /// Called when the user taps the note icon to add/edit this record's
  /// note.
  final VoidCallback onNoteTap;

  /// Whether this tile should be visually highlighted (notification
  /// deep-link target).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final success = theme.extension<AppSemanticColors>()!.success;
    final label = view.showAsJumuah
        ? l10n.prayerNameJumuah
        : _labelFor(l10n, view.record.prayerName);
    final canToggle = view.effectiveStatus != PrayerStatus.missed;
    return Card(
      color: highlighted ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(label)),
            IconButton(
              icon: Icon(
                view.record.notes != null
                    ? Icons.sticky_note_2
                    : Icons.sticky_note_2_outlined,
              ),
              tooltip: l10n.logNotesSheetTitle,
              onPressed: onNoteTap,
            ),
          ],
        ),
        subtitle: Text(
          '${DateFormat.jm().format(view.record.scheduledFor.toLocal())} · '
          '${_statusLabel(l10n, view.effectiveStatus)}',
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

  String _labelFor(AppLocalizations l10n, PrayerName name) => switch (name) {
    PrayerName.fajr => l10n.prayerNameFajr,
    PrayerName.dhuhr => l10n.prayerNameDhuhr,
    PrayerName.asr => l10n.prayerNameAsr,
    PrayerName.maghrib => l10n.prayerNameMaghrib,
    PrayerName.isha => l10n.prayerNameIsha,
  };

  String _statusLabel(AppLocalizations l10n, PrayerStatus status) =>
      switch (status) {
        PrayerStatus.upcoming => l10n.prayerStatusUpcoming,
        PrayerStatus.due => l10n.prayerStatusDue,
        PrayerStatus.prayed => l10n.prayerStatusPrayed,
        PrayerStatus.missed => l10n.prayerStatusMissed,
      };
}
