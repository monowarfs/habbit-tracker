# Implementation Plan: Caregiver Read-Only View Link

**Spec:** `11-caregiver-read-only-view-link-design.md`
**Complexity:** L · **Estimated effort:** 3 days
**Depends on:** Token relay backend — BLOCKED

---

## BLOCKED

This spec requires a backend token relay for issuing, validating,
and expiring read-only view tokens. The backend decision must be made
before implementation.

---

## Task 1: Backend token relay design

**Endpoints:**
- `POST /api/v1/caregiver/link` — issue a new token
- `GET /api/v1/caregiver/view/:token` — serve read-only view
- `DELETE /api/v1/caregiver/link/:token` — revoke token

Token format: opaque UUID, 32-byte entropy, 7-day expiry.

---

## Task 2: Create caregiver link service

**File:** `lib/features/community/data/caregiver_link_service.dart`

```dart
class CaregiverLinkService {
  /// Generates a time-limited read-only link for a caregiver.
  Future<CaregiverLink> generateLink({
    required List<String> modulesInScope,
    required Duration expiry,
  });

  /// Revokes an active link.
  Future<void> revokeLink(String tokenId);

  /// Lists all active links.
  Future<List<CaregiverLink>> getActiveLinks();
}
```

---

## Task 3: Create link management screen

**File:** `lib/features/community/presentation/screens/caregiver_links_screen.dart`

Shows:
- List of active links with expiry countdown
- "Revoke" button per link
- "Generate New Link" button

---

## Task 4: Create caregiver view (web page)

**File:** A simple static HTML page hosted by the relay backend.

Shows:
- Dependent's name (or anonymous)
- Medicine adherence status (taken/missed per dose)
- Streak information
- No raw data, no personal details

---

## Task 5: Wire to share sheet

Use `share_plus` to distribute the generated link.

---

## Task 6: Add localization strings

ARB keys for link management, expiry, revocation, caregiver view.

---

## Performance considerations

- **Token validation:** O(1) lookup on the relay.
- **Caching:** the caregiver view can cache data for 1 hour to avoid
  repeated backend calls.

## Testing

- Unit test: token generation and expiry logic.
- Unit test: revocation flow.
- Widget test: link management screen.
- Integration test: end-to-end relay communication (mocked).

## Localization

ARB keys listed in Task 6.
