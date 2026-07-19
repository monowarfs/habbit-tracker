/// A prayer-time calculation location, resolved from either a one-shot
/// GPS fix or the user's manual entry (FR-P-06/D-09) — the shared input
/// both `calculatePrayerTimes` and `planPrayerMaterialization` take, so
/// neither needs to know *how* it was resolved.
typedef ResolvedLocation = ({
  double latitude,
  double longitude,
  String ianaTimezone,
});
