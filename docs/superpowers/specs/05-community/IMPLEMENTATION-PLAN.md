# Implementation Plan: Community Features (05-community)

**Specs:** 11 files | **Total estimated effort:** 15-20 days
**Created:** 2026-07-25

---

## Recommended Implementation Order

### Wave 1: Zero-infrastructure features (3-4 days)
These require no backend, no accounts, and can ship immediately.

| Spec | Effort | Dependencies |
|---|---|---|
| 01 Share-a-Streak Image | 1 day | `share_plus`, streak use cases |
| 02 Invite-a-Friend Deep Link | 0.5 day | `share_plus`, `app_links` |
| 03 External Community Link | 0.5 day | `url_launcher`, actual channel |
| 10 In-App Feedback Board | 0.5 day | Third-party vendor account |

### Wave 2: Multi-profile-gated features (4-5 days)
Blocked on Spec 04-premium/03 (multi-profile) shipping first.

| Spec | Effort | Dependencies |
|---|---|---|
| 04 Household Leaderboard | 2 days | Multi-profile (Premium) |
| 05 Mosque-Finder / Jamaah Times | 2 days | Curated mosque dataset, Prayer module |
| 08 Community Habit Templates | 1 day | Module creation forms |

### Wave 3: Backend-required features (8-10 days)
Blocked on explicit backend/account architecture decision.

| Spec | Effort | Dependencies |
|---|---|---|
| 06 Cloud Accountability Groups | 4 days | Account system, backend |
| 07 Global Prayer Participation | 3 days | Aggregation backend |
| 09 Ramadan Community Challenge | 2 days | Spec 06 (hard), Ramadan mode |
| 11 Caregiver Read-Only Link | 3 days | Token relay backend |

---

## Per-Spec Task Breakdown

### 01 Share-a-Streak Image
1. Add `share_plus` dependency to `pubspec.yaml`
2. Create `lib/core/widgets/image_renderer.dart` — RepaintBoundary-to-image utility
3. Create `lib/features/community/share_streak_image.dart` — card widget
4. Wire streak data from each module's use cases
5. Add en/bn ARB keys
6. Tests

### 02 Invite-a-Friend Deep Link
1. Add `app_links` dependency
2. Create referral link generator (embed tag in store URL)
3. Add first-launch deep-link parser
4. Store referral flag (SharedPreferences or Drift)
5. Add en/bn ARB keys
6. Tests

### 03 External Community Link
1. Add `url_launcher` if not already present
2. Add Settings entry pointing to Telegram/Discord URL
3. Add "leaving app" confirmation dialog (optional)
4. Add en/bn ARB keys
5. Tests

### 04 Household Leaderboard
1. Wait for multi-profile (Spec 04-premium/03)
2. Create leaderboard aggregation (cross-profile query)
3. Build leaderboard UI (ranked list with metrics)
4. Add privacy opt-out per profile
5. Add en/bn ARB keys
6. Tests

### 05 Mosque-Finder / Jamaah Times
1. Curate mosque dataset (content work)
2. Bundle as JSON asset (same pattern as Prayer's 65-city dataset)
3. Create mosque-finder screen with proximity search
4. Add jamaah time display alongside Adhan times
5. Add en/bn ARB keys
6. Tests

### 06 Cloud Accountability Groups
1. **BLOCKED:** Requires explicit backend/account decision
2. Design backend schema (coarse signals only)
3. Implement account creation/authentication
4. Build group creation/invite flow
5. Build group dashboard (read-only completion signals)
6. Privacy/consent review
7. Tests

### 07 Global Prayer Participation
1. **BLOCKED:** Requires aggregation backend
2. Design anonymous ping endpoint
3. Implement city-level aggregation service
4. Build participation stat display in Prayer module
5. Add opt-in consent flow
6. Tests

### 08 Community Habit Templates
1. Define preset data format (JSON or Dart constants)
2. Create preset catalog (3-5 per module)
3. Build template browser UI
4. Wire preset values into module creation forms
5. Add en/bn ARB keys
6. Tests

### 09 Ramadan Community Challenge
1. **BLOCKED:** Requires Spec 06 (accountability groups)
2. Define challenge lifecycle (create, run, archive)
3. Build challenge progress display
4. Integrate with Ramadan mode schedule
5. Add en/bn ARB keys
6. Tests

### 10 In-App Feedback Board
1. Choose vendor (Canny or alternative)
2. Add Settings entry with link/webview
3. Handle no-internet fallback
4. Update store data-safety if needed
5. Add en/bn ARB keys
6. Tests

### 11 Caregiver Read-Only Link
1. **BLOCKED:** Requires backend/token relay decision
2. Design token security model
3. Implement token issuance/validation
4. Build caregiver view (web page)
5. Build link management screen (revoke, expiry)
6. Privacy/consension review
7. Tests
