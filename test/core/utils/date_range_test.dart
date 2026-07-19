import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

void main() {
  test('DateRange holds its start/end and supports equality', () {
    const a = DateRange(
      start: LocalDate(2026, 6, 1),
      end: LocalDate(2026, 6, 7),
    );
    const b = DateRange(
      start: LocalDate(2026, 6, 1),
      end: LocalDate(2026, 6, 7),
    );
    expect(a, b);
    expect(a.start, const LocalDate(2026, 6, 1));
    expect(a.end, const LocalDate(2026, 6, 7));
  });
}
