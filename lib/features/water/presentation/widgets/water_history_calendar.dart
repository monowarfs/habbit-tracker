import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// A month grid coloring each day green when its goal was met (FR-W-08).
class WaterHistoryCalendar extends StatelessWidget {
  /// Creates a calendar for [month] (any [LocalDate] within that month).
  const WaterHistoryCalendar({
    required this.month,
    required this.goalMetByDay,
    required this.onDayTap,
    super.key,
  });

  /// Any day within the month to render.
  final LocalDate month;

  /// Whether each day (present in the map) met its goal. A day absent
  /// from the map is rendered neutrally (no data / in the future).
  final Map<LocalDate, bool> goalMetByDay;

  /// Called when a day cell is tapped.
  final void Function(LocalDate day) onDayTap;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = LocalDate(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.toDateTimeUtc().weekday - 1; // Mon=0
    final semanticColors = Theme.of(context).extension<AppSemanticColors>();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: leadingBlanks + daysInMonth,
      itemBuilder: (context, index) {
        if (index < leadingBlanks) return const SizedBox.shrink();
        final day = LocalDate(
          month.year,
          month.month,
          index - leadingBlanks + 1,
        );
        final met = goalMetByDay[day];
        final color = met == null
            ? null
            : (met
                  ? semanticColors?.success
                  : ModuleAccents.water.withValues(alpha: 0.2));
        return InkWell(
          onTap: () => onDayTap(day),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        );
      },
    );
  }
}
