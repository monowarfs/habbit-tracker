# Implementation Plan: Cloud Accountability Groups

**Spec:** `06-cloud-accountability-groups-design.md`
**Complexity:** L · **Estimated effort:** 4 days
**Depends on:** Explicit backend/account architecture decision — BLOCKED

---

## BLOCKED

This spec requires a backend and user accounts. The backend decision
must be made explicitly and separately before implementation. The plan
below assumes the decision is made and outlines the implementation.

---

## Task 1: Backend technology decision

**Decision required:**
- Self-hosted vs. BaaS (Firebase, Supabase)?
- Authentication method (email, phone, anonymous)?
- Hosting region and data residency?

**Recommendation:** Firebase Auth (anonymous → optional email) +
Firestore for coarse signals. Lowest operational cost for a small team.

---

## Task 2: Design backend schema

**Firestore collections:**

```
groups/{groupId}:
  name: string
  createdBy: userId
  createdAt: timestamp
  maxMembers: 10
  inviteCode: string (time-limited)
  inviteCodeExpiresAt: timestamp

groups/{groupId}/members/{userId}:
  displayName: string
  joinedAt: timestamp
  isActive: boolean

groups/{groupId}/signals/{userId}_{date}:
  userId: string
  date: string (YYYY-MM-DD)
  modules: map<moduleId, completionPercentage>
  sharedAt: timestamp
```

---

## Task 3: Create backend service

**File:** `lib/core/community/backend/group_service.dart`

```dart
class GroupService {
  Future<Group> createGroup(String name);
  Future<Group> joinGroup(String inviteCode);
  Future<void> leaveGroup(String groupId);
  Future<void> shareSignal(String groupId, CoarseSignal signal);
  Future<List<GroupMember>> getMembers(String groupId);
  Future<List<CoarseSignal>> getSignals(String groupId, DateRange range);
}
```

---

## Task 4: Create coarse signal extractor

**File:** `lib/core/community/data/coarse_signal_extractor.dart`

Extracts ONLY coarse completion data — never raw health data:

```dart
class CoarseSignalExtractor {
  /// Extracts per-module completion percentage for a day.
  /// Never includes medicine names, dosages, or prayer specifics.
  static CoarseSignal extract({
    required String moduleId,
    required Map<LocalDate, ModuleDayStatus> dayStatus,
  }) {
    // Return: {moduleId: completionPercentage}
  }
}
```

---

## Task 5: Create group screens

**Files:**
- `lib/features/community/presentation/screens/group_list_screen.dart`
- `lib/features/community/presentation/screens/group_detail_screen.dart`
- `lib/features/community/presentation/screens/create_group_screen.dart`
- `lib/features/community/presentation/screens/join_group_screen.dart`

---

## Task 6: Add authentication

**File:** `lib/core/community/auth/auth_service.dart`

```dart
class AuthService {
  Future<User> signInAnonymously();
  Future<User> linkWithEmail(String email);
  Future<void> signOut();
  Future<User?> get currentUser;
}
```

---

## Task 7: Privacy/consent review

Complete the consent checklist from `docs/strategies/analytics-future.md`:
1. Affirmative opt-in consent
2. Store listing updates
3. Health-data sensitivity review
4. Durable off switch
5. Deletion story

---

## Task 8: Add localization strings

ARB keys for group management UI, invite codes, error messages.

---

## Performance considerations

- **Offline-first:** queue sync operations, retry on connectivity.
- **Signal granularity:** daily completion percentages, not real-time.
- **Caching:** cache group data locally for offline viewing.

## Testing

- Unit tests: group business logic, invite code validation.
- Widget tests: group screens with mock data.
- Integration tests: full sync cycle (create → join → share → view).

## Localization

All group management UI needs en/bn ARB keys.
