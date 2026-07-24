import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/effective_prayer_status.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';

/// A preview of the Android prayer widget, shown in-app.
/// Shows the next pending prayer with a live countdown that ticks every minute.
class PrayerWidgetPreview extends ConsumerStatefulWidget {
  /// Creates the widget preview.
  const PrayerWidgetPreview({super.key});

  @override
  ConsumerState<PrayerWidgetPreview> createState() =>
      _PrayerWidgetPreviewState();
}

class _PrayerWidgetPreviewState extends ConsumerState<PrayerWidgetPreview> {
  late Timer _timer;
  DateTime? _nextPrayerTime;
  String? _headline;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _update());
    _update();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _update() async {
    final repository = ref.read(prayerRepositoryProvider);
    final settings = await ref.read(prayerSettingsProvider.future);
    final location = await ref.read(resolvedPrayerLocationProvider.future);
    if (location == null) return;
    final now = DateTime.now();
    final today = localDayKey(now);
    final records = await repository.recordsInRange(today, today);
    records.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    PrayerRecord? firstPending;
    for (final record in records) {
      final cutoff = cutoffForPrayer(
        record: record,
        sameDayRecordsSorted: records,
        ishaDayRolloverTime: settings.ishaDayRolloverTime,
        ianaTimezone: location.ianaTimezone,
      );
      final status = effectivePrayerStatus(
        storedStatus: record.storedStatus,
        scheduledFor: record.scheduledFor,
        cutoff: cutoff,
        now: now,
      );
      if (status == PrayerStatus.due || status == PrayerStatus.upcoming) {
        firstPending ??= record;
      }
    }
    // Midnight rollover: if none pending today, look at tomorrow.
    if (firstPending == null) {
      final tomorrow = today.addDays(1);
      final recordsTomorrow = await repository.recordsInRange(today, tomorrow);
      recordsTomorrow.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
      for (final record in recordsTomorrow) {
        final cutoff = cutoffForPrayer(
          record: record,
          sameDayRecordsSorted: recordsTomorrow,
          ishaDayRolloverTime: settings.ishaDayRolloverTime,
          ianaTimezone: location.ianaTimezone,
        );
        final status = effectivePrayerStatus(
          storedStatus: record.storedStatus,
          scheduledFor: record.scheduledFor,
          cutoff: cutoff,
          now: now,
        );
        if (status == PrayerStatus.due || status == PrayerStatus.upcoming) {
          firstPending ??= record;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _nextPrayerTime = firstPending?.scheduledFor;
      if (firstPending != null) {
        final label = _titleCase(firstPending.prayerName.name);
        final timeStr =
            '${firstPending.scheduledFor.hour.toString().padLeft(2, '0')}:'
            '${firstPending.scheduledFor.minute.toString().padLeft(2, '0')}';
        _headline = '$label · $timeStr';
      } else {
        _headline = null;
      }
    });
  }

  String _titleCase(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_headline == null) {
      return const SizedBox.shrink();
    }
    final remaining = _nextPrayerTime?.difference(DateTime.now());
    final countdownText = remaining != null && remaining.isNegative
        ? ''
        : _formatCountdown(remaining ?? Duration.zero);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.prayerCountdownWidgetPreview,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _headline!,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (countdownText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                countdownText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCountdown(Duration remaining) {
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes} min';
  }
}