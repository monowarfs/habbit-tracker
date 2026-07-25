import 'package:habit_tracker/core/database/app_database.dart';

/// Cross-module query for the most recent user activity across all
/// tracking modules. Used by the re-engagement nudge to detect inactivity.
class LastActivityRepository {
  /// Creates a repository backed by the given database.
  const LastActivityRepository(this._db);

  final AppDatabase _db;

  /// Returns the most recent write timestamp across water_logs,
  /// medicine_doses, and prayer_records, or null if all tables are empty.
  Future<DateTime?> mostRecentActivity() async {
    final waterResult = await _db.customSelect(
      'SELECT MAX(created_at) AS latest FROM water_logs '
      'WHERE created_at IS NOT NULL',
    ).getSingleOrNull();
    final waterLatest = waterResult?.data['latest'] as int?;

    final medicineResult = await _db.customSelect(
      'SELECT MAX(created_at) AS latest FROM medicine_doses '
      'WHERE created_at IS NOT NULL',
    ).getSingleOrNull();
    final medicineLatest = medicineResult?.data['latest'] as int?;

    final prayerResult = await _db.customSelect(
      'SELECT MAX(created_at) AS latest FROM prayer_records '
      'WHERE created_at IS NOT NULL',
    ).getSingleOrNull();
    final prayerLatest = prayerResult?.data['latest'] as int?;

    final candidates = <int>[
      ?waterLatest,
      ?medicineLatest,
      ?prayerLatest,
    ];

    if (candidates.isEmpty) return null;
    final latest = candidates.reduce((a, b) => a > b ? a : b);
    return DateTime.fromMillisecondsSinceEpoch(latest, isUtc: true);
  }
}
