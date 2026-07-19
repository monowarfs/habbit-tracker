import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:meta/meta.dart';

/// An inclusive local-day range (`[start, end]`) — the shared parameter
/// type for `HabitModule.dayStatus`, Reports' period bucketing, and the
/// global calendar's month window (D-17,
/// `../../../docs/superpowers/specs/2026-07-19-dashboard-reports-achievements-design.md`).
@immutable
class DateRange {
  /// Creates an inclusive date range from [start] to [end].
  const DateRange({required this.start, required this.end});

  /// The first day in the range, inclusive.
  final LocalDate start;

  /// The last day in the range, inclusive.
  final LocalDate end;

  @override
  bool operator ==(Object other) =>
      other is DateRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '${start.toIso()}..${end.toIso()}';
}
