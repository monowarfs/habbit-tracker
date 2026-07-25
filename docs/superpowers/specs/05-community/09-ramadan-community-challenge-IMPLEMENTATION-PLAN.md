# Implementation Plan: Ramadan Community Challenge

**Spec:** `09-ramadan-community-challenge-design.md`
**Complexity:** M · **Estimated effort:** 2 days
**Depends on:** Spec 06 (accountability groups) — HARD PREREQUISITE

---

## BLOCKED

This spec requires accountability groups (spec 06) to exist first.
The challenge is a group-scoped feature.

---

## Task 1: Define challenge data model

**File:** `lib/features/community/domain/entities/ramadan_challenge.dart`

```dart
@freezed
class RamadanChallenge with _$RamadanChallenge {
  const factory RamadanChallenge({
    required String id,
    required String groupId,
    required int year,
    required LocalDate startDate,
    required LocalDate endDate,
    required ChallengeStatus status,
  }) = _RamadanChallenge;
}

enum ChallengeStatus { upcoming, active, completed }
```

---

## Task 2: Create challenge service

**File:** `lib/features/community/data/challenge_service.dart`

```dart
class ChallengeService {
  /// Creates or retrieves the annual Ramadan challenge for a group.
  Future<RamadanChallenge> getOrCreateChallenge(String groupId, int year);

  /// Logs a day's completion for a user in the challenge.
  Future<void> logCompletion(String challengeId, String userId, LocalDate date);

  /// Gets leaderboard for the challenge.
  Future<List<ChallengeEntry>> getLeaderboard(String challengeId);
}
```

---

## Task 3: Create challenge screen

**File:** `lib/features/community/presentation/screens/ramadan_challenge_screen.dart`

Shows:
- Challenge progress (days completed / total days)
- Group leaderboard
- Personal stats

---

## Task 4: Wire to Ramadan mode

**File:** `lib/features/settings/presentation/screens/ramadan_settings_screen.dart`

Add "Join Ramadan Challenge" button when Ramadan mode is enabled.

---

## Task 5: Add notifications

Schedule daily challenge reminders using `NotificationService`.

---

## Task 6: Add localization strings

ARB keys for challenge UI, leaderboard, completion tracking.

---

## Performance considerations

- **Challenge data:** cached locally, synced via group backend.
- **Leaderboard:** computed server-side for group challenges.

## Testing

- Unit test: challenge lifecycle (create → active → completed).
- Unit test: completion logging and leaderboard computation.
- Widget test: challenge screen with mock data.

## Localization

ARB keys listed in Task 6.
