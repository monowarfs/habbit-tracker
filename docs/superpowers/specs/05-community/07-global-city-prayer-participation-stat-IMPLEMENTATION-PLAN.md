# Implementation Plan: Global City-Level Prayer Participation Stat

**Spec:** `07-global-city-prayer-participation-stat-design.md`
**Complexity:** L · **Estimated effort:** 3 days
**Depends on:** Aggregation backend — BLOCKED (can share infra with spec 06)

---

## BLOCKED

This spec requires an aggregation backend for anonymous prayer pings.
The backend decision must be made before implementation. Can share
infrastructure with spec 06 (accountability groups).

---

## Task 1: Backend aggregation endpoint

**Endpoint:** `POST /api/v1/participation/ping`

Request body:
```json
{
  "city": "Dhaka",
  "prayer": "fajr",
  "timestamp_bucket": "2026-07-25T05:00:00Z"
}
```

No user ID, no device ID — fully anonymous. The backend increments a
city+prayer+bucket counter.

**Response:** `204 No Content`

---

## Task 2: Backend aggregation query

**Endpoint:** `GET /api/v1/participation/count?city=Dhaka&date=2026-07-25`

Response:
```json
{
  "city": "Dhaka",
  "date": "2026-07-25",
  "counts": {
    "fajr": 12400,
    "dhuhr": 15600,
    "asr": 14200,
    "maghrib": 16800,
    "isha": 11900
  }
}
```

Minimum population threshold: suppress counts below 10 users.

---

## Task 3: Create participation service

**File:** `lib/core/community/participation/participation_service.dart`

```dart
class ParticipationService {
  /// Sends an anonymous ping when a prayer is completed.
  Future<void> sendPing({
    required String city,
    required String prayer,
  });

  /// Fetches participation counts for a city/date.
  Future<ParticipationCounts?> getCounts({
    required String city,
    required String date,
  });
}
```

---

## Task 4: Create opt-in/opt-out setting

**File:** `lib/features/settings/domain/entities/app_settings.dart`

Add `prayerParticipationEnabled` boolean (default: false — off by default).

---

## Task 5: Wire ping to prayer completion

**File:** `lib/features/prayer/domain/usecases/effective_prayer_status.dart`

After a prayer is marked as `prayed`, if participation is enabled,
send an anonymous ping in the background (don't block the UI).

---

## Task 6: Create participation display

**File:** `lib/features/prayer/presentation/widgets/participation_stat.dart`

Show "X people praying {prayer} in {city} today" on the Prayer
checklist screen. Only visible when participation is enabled.

---

## Task 7: Add consent flow

**File:** `lib/features/prayer/presentation/screens/prayer_settings_screen.dart`

Add opt-in toggle with privacy explanation:
- "Share anonymous prayer completion data"
- "No personal information is shared"
- "You can turn this off anytime"

---

## Task 8: Add localization strings

ARB keys for participation display, opt-in flow, privacy text.

---

## Performance considerations

- **Ping frequency:** one ping per prayer completion (max 5/day).
  Trivial network cost.
- **Caching:** cache participation counts for 1 hour to avoid
  repeated API calls.
- **Background send:** use `compute()` or background isolate for
  the network call to avoid UI jank.

## Testing

- Unit test: ping payload construction (verify no user ID).
- Unit test: city name normalization.
- Unit test: population threshold enforcement.
- Widget test: participation stat display.
- Integration test: opt-in → complete prayer → ping sent.

## Localization

All participation UI needs en/bn ARB keys.
