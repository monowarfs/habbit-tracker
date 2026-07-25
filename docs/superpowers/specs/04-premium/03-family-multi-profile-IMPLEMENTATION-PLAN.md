# Implementation Plan: Family / Multi-Profile

**Spec:** `03-family-multi-profile-design.md`
**Complexity:** L · **Estimated effort:** 8-10 days
**Depends on:** Spec 02 (sync), spec 07 (entitlements)

---

## Task 1: Add `profiles` Drift table

**File:** `lib/core/database/app_database.dart`

Create `lib/core/profiles/profile_table.dart`:

```dart
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get avatarColor => text()();
  @override
  Set<Column> get primaryKey => {id};
}
```

Add to `AppDatabase`'s table list.

---

## Task 2: Add `profile_id` column to all existing tables

Run a Drift migration to add `profile_id TEXT NOT NULL DEFAULT 'system'`
to every module table:
- `water_goals`, `water_logs`, `water_settings`
- `medicines`, `medicine_schedules`, `medicine_doses`, `medicine_stock_events`
- `prayer_settings`, `prayer_records`, `prayer_qadha_counters`
- `achievements`, `habit_stack_suggestions`, `notification_ledger`
- `app_settings` (add `active_profile_id TEXT`)

The default value `'system'` preserves all existing data.

---

## Task 3: Create `ProfileRepository`

**File:** `lib/core/profiles/profile_repository.dart`

- `createProfile(String name, String color)` → `Profile`
- `updateProfile(String id, {String? name, String? color})`
- `deleteProfile(String id)` — soft-deletes all rows for this profile.
- `listProfiles()` → `List<Profile>`
- `getActiveProfile()` → `Profile`
- `setActiveProfile(String id)`

---

## Task 4: Create profile-aware query pattern

For every repository method, add `profileId` parameter:
```dart
Future<List<WaterLog>> getLogs(DateRange range, {required String profileId});
```

Update all callers to pass the active profile ID.

**Files:** All repository files in `water/`, `medicine/`, `prayer/`.

---

## Task 5: Create active profile provider

**File:** `lib/core/profiles/active_profile_provider.dart`

A Riverpod provider that exposes the currently active profile:
```dart
@Riverpod(keepAlive: true)
Future<Profile> activeProfile(Ref ref) async { ... }
```

All profile-aware code reads from this provider.

---

## Task 6: Create profile switcher UI

**File:** `lib/core/profiles/profile_switcher.dart`

A widget shown in the app bar (next to display name) that:
- Shows the active profile's name and avatar color.
- Opens a dropdown/modal with all profiles.
- Switches the active profile on selection.

---

## Task 7: Create "Manage Profiles" screen

**File:** `lib/features/settings/presentation/screens/manage_profiles_screen.dart`

- List of profiles with edit/delete actions.
- "Add Profile" button.
- Profile limit enforcement (max 5).
- Storage usage per profile.

---

## Task 8: Update notification planning for multi-profile

Modify `notification_planner.dart` to plan notifications only for the
active profile. Store `profile_id` in `notification_ledger` rows.

---

## Task 9: Update widget refresh for multi-profile

Modify `widget_refresh_helper.dart` to save widget data for the active
profile only.

---

## Task 10: Add entitlement gate

Wire spec 07's entitlement check. Multi-profile is premium.

---

## Task 11: Add localization strings

en/bn ARB keys for profile management UI.

---

## Review checklist

- [ ] Profile switching works without data loss.
- [ ] Each profile has independent data.
- [ ] Notifications fire for the active profile only.
- [ ] Widget data reflects the active profile.
- [ ] Profile deletion preserves other profiles' data.
- [ ] Max profile limit enforced.
- [ ] Entitlement gate works.
