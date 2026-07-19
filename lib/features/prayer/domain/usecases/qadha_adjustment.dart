import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';

/// New Qadha balance after applying [counter]'s make-up "−1" control
/// (FR-P-05), clamped at 0.
int applyQadhaMakeup(PrayerQadhaCounter counter) =>
    counter.count > 0 ? counter.count - 1 : 0;
