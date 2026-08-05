import 'package:habit_tracker/core/utils/local_date.dart';

/// A detected combo day — every active module completed on [date].
class ComboEvent {
  /// Creates a combo event.
  const ComboEvent({
    required this.date,
    required this.modulesCompleted,
    required this.totalActiveModules,
  });

  /// The day the combo happened on.
  final LocalDate date;

  /// How many modules were complete (equals [totalActiveModules] by
  /// definition of a combo — kept as its own field since it's also the
  /// number the celebration copy shows).
  final int modulesCompleted;

  /// How many modules were active that day.
  final int totalActiveModules;
}
