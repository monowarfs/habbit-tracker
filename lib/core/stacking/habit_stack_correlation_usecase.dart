import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:meta/meta.dart';

/// One correlation candidate: a source module's (Medicine/Prayer)
/// completed-action time reliably precedes a Water log by a short,
/// consistent gap (`docs/superpowers/specs/02-delightful/
/// 04-habit-stacking-suggestions-design.md`).
@immutable
class StackCorrelationResult {
  /// Creates a correlation result.
  const StackCorrelationResult({
    required this.qualifyingDays,
    required this.totalDaysWithSource,
    required this.medianGapMinutes,
    required this.typicalSourceTime,
  });

  /// Days (within the trailing window) where a Water log followed the
  /// source action within `maxGap`.
  final int qualifyingDays;

  /// Days (within the trailing window) the source module had any
  /// completed action at all — the correlation's denominator.
  final int totalDaysWithSource;

  /// Median gap, source-action -> water-log, across qualifying days.
  final int medianGapMinutes;

  /// Median source-action wall-clock time, e.g. `08:15` — the anchor
  /// time an accepted suggestion nudges Water's reminder window to.
  final LocalTime typicalSourceTime;

  @override
  bool operator ==(Object other) =>
      other is StackCorrelationResult &&
      qualifyingDays == other.qualifyingDays &&
      totalDaysWithSource == other.totalDaysWithSource &&
      medianGapMinutes == other.medianGapMinutes &&
      typicalSourceTime == other.typicalSourceTime;

  @override
  int get hashCode => Object.hash(
    qualifyingDays,
    totalDaysWithSource,
    medianGapMinutes,
    typicalSourceTime,
  );

  @override
  String toString() =>
      'StackCorrelationResult(qualifyingDays: $qualifyingDays, '
      'totalDaysWithSource: $totalDaysWithSource, '
      'medianGapMinutes: $medianGapMinutes, '
      'typicalSourceTime: $typicalSourceTime)';
}

/// Pure heuristic — explainable, not a model. [sourceByDay] is one
/// timestamp per day (the source module's first `done`/`prayed` action
/// that day); [targetByDay] is every Water `loggedAt` that day. Only the
/// trailing [windowDays] days (relative to the latest day present in
/// [sourceByDay]) are considered. A day "qualifies" if any target
/// timestamp falls in `(source, source + maxGap]`. Returns `null` below
/// [minQualifyingDays] or below a 70% qualifying-day rate — both guard
/// against "coincidence, not a pattern."
StackCorrelationResult? findStackCorrelation({
  required Map<LocalDate, DateTime> sourceByDay,
  required Map<LocalDate, List<DateTime>> targetByDay,
  int windowDays = 14,
  int minQualifyingDays = 5,
  Duration maxGap = const Duration(minutes: 90),
}) {
  if (sourceByDay.isEmpty) return null;

  final latestDay = sourceByDay.keys.reduce(
    (a, b) => a.compareTo(b) >= 0 ? a : b,
  );
  final earliestInWindow = latestDay.addDays(-(windowDays - 1));
  final windowedSource = {
    for (final entry in sourceByDay.entries)
      if (entry.key.compareTo(earliestInWindow) >= 0) entry.key: entry.value,
  };
  final totalDaysWithSource = windowedSource.length;

  final gapsMinutes = <int>[];
  final sourceMinutesOfDay = <int>[];
  for (final entry in windowedSource.entries) {
    final sourceTime = entry.value;
    final targets = targetByDay[entry.key] ?? const [];
    int? bestGapMinutes;
    for (final target in targets) {
      final gap = target.difference(sourceTime);
      if (gap > Duration.zero && gap <= maxGap) {
        final gapMinutes = gap.inMinutes;
        if (bestGapMinutes == null || gapMinutes < bestGapMinutes) {
          bestGapMinutes = gapMinutes;
        }
      }
    }
    if (bestGapMinutes != null) {
      gapsMinutes.add(bestGapMinutes);
      sourceMinutesOfDay.add(sourceTime.hour * 60 + sourceTime.minute);
    }
  }

  final qualifyingDays = gapsMinutes.length;
  if (qualifyingDays < minQualifyingDays) return null;
  if (qualifyingDays / totalDaysWithSource < 0.7) return null;

  final medianGap = _median(gapsMinutes);
  final medianMinuteOfDay = _median(sourceMinutesOfDay);
  return StackCorrelationResult(
    qualifyingDays: qualifyingDays,
    totalDaysWithSource: totalDaysWithSource,
    medianGapMinutes: medianGap,
    typicalSourceTime: LocalTime(
      medianMinuteOfDay ~/ 60,
      medianMinuteOfDay % 60,
    ),
  );
}

int _median(List<int> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : ((sorted[mid - 1] + sorted[mid]) / 2).round();
}
