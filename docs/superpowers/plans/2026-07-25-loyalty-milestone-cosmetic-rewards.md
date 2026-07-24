# Loyalty Milestone Cosmetic Rewards — Implementation Plan

**Spec:** `docs/superpowers/specs/09-retention/10-loyalty-milestone-cosmetic-rewards-design.md`
**Date:** 2026-07-25
**Status:** Ready for implementation

---

## Architecture overview

This spec extends the anniversary-badge mechanism (Spec 06) with a cosmetic unlock. The tenure evaluator awards an achievement; the cosmetic unlock system makes a theme accent selectable in Settings.

```
┌──────────────────────────────────────────────────────────┐
│  Tenure evaluator (Spec 06) awards 2-year achievement    │
│  → cosmetic_unlock_engine detects new unlock              │
│  → writes to cosmetic_unlocks table                       │
│  → Settings "Unlocks" section shows theme accent          │
└──────────────────────────────────────────────────────────┘
```

---

## Resolved dependencies

| Dep | Source |
|-----|--------|
| `installDate` on `AppSettings` | Spec 01 T1-T2 |
| Tenure evaluator + achievements | Spec 06 T1-T4 |
| Schema migration v15 (achievements) | Spec 06 T1 |
| Achievement engine `Stream<AchievementEvent>` | New in this spec |

---

## Implementation tasks

### T1: Schema migration — `cosmetic_unlocks` table + achievement stream

**Files:**
- `lib/core/database/tables/cosmetic_unlocks_table.dart` — **new file**
- `lib/core/database/app_database.dart` — add table, bump `schemaVersion` to 18

**Table definition:**
```dart
@DataClassName('CosmeticUnlockRow')
class CosmeticUnlocksTable extends Table {
  @override
  String get tableName => 'cosmetic_unlocks';

  TextColumn get id => text()();
  TextColumn get achievementKey => text()();   // 'tenure_2_year'
  TextColumn get cosmeticKey => text()();      // 'theme_accent_midnight'
  IntColumn get unlockedAt => integer()();     // UTC epoch millis

  @override
  Set<Column> get primaryKey => {id};
}
```

**Migration (from < 18):**
```dart
if (from < 18) {
  await m.createTable(cosmeticUnlocksTable);
}
```

---

### T2: Achievement engine — emit unlock events

**Files:**
- `lib/core/achievements/achievement_engine.dart` — add `StreamController<AchievementEvent>` and emit events on unlock

```dart
class AchievementEvent {
  const AchievementEvent({
    required this.moduleId,
    required this.key,
    required this.justUnlocked,
  });
  final String moduleId;
  final String key;
  final bool justUnlocked;
}
```

**Change:** `evaluate()` already knows when `justUnlocked` is true (from `upsertProgress`). Add a stream that emits `AchievementEvent` when this happens.

**Tests:** Verify stream emits on unlock, doesn't emit on progress update without unlock.

---

### T3: `CosmeticUnlockEngine` — map achievements to cosmetics

**Files:**
- `lib/core/cosmetics/cosmetic_unlock_engine.dart` — **new file**

```dart
/// Maps achievement keys to cosmetic option keys.
const achievementToCosmetic = {
  'tenure_2_year': 'theme_accent_midnight',
};

class CosmeticUnlockEngine {
  const CosmeticUnlockEngine({
    required this.cosmeticRepository,
    required this.achievementEngine,
  });

  final CosmeticRepository cosmeticRepository;
  final AchievementEngine achievementEngine;

  /// Checks if [achievementKey] maps to a cosmetic unlock.
  /// If so, records it in the cosmetic_unlocks table.
  Future<void> onAchievementUnlocked(String achievementKey);

  /// All unlocked cosmetic keys.
  Future<Set<String>> unlockedCosmetics();
}
```

**Tests:** `test/core/cosmetics/cosmetic_unlock_engine_test.dart`

---

### T4: `CosmeticRepository` — CRUD for cosmetic unlocks

**Files:**
- `lib/core/cosmetics/cosmetic_repository.dart` — **new file**

```dart
class CosmeticRepository {
  const CosmeticRepository(this._db);
  final AppDatabase _db;

  /// All unlocked cosmetic keys.
  Future<Set<String>> unlockedKeys();

  /// Whether [cosmeticKey] is unlocked.
  Future<bool> isUnlocked(String cosmeticKey);

  /// Records a cosmetic unlock (append-only, idempotent).
  Future<void> unlock({
    required String achievementKey,
    required String cosmeticKey,
  });

  /// Stream of unlock state changes.
  Stream<Set<String>> watchUnlocked();
}
```

**Tests:** `test/core/cosmetics/cosmetic_unlock_repository_test.dart`

---

### T5: Theme accent — "Midnight" variant

**Files:**
- `lib/core/theme/app_theme.dart` — add `midnightAccent` to `ModuleAccents` or as a standalone accent
- `lib/core/theme/cosmetic_accent_provider.dart` — **new file**, Riverpod provider that reads cosmetic unlocks and provides available accents

**Approach:** The existing `ModuleAccents` system already supports per-module accent colors. The cosmetic unlock adds a new accent option (e.g., a deep blue-purple "Midnight" accent) that becomes selectable when the 2-year achievement is unlocked.

**Tests:** Verify accent provider reads from cosmetic unlocks.

---

### T6: Settings "Unlocks" section

**Files:**
- `lib/features/settings/presentation/screens/unlocks_screen.dart` — **new file**
- `lib/features/settings/presentation/screens/settings_home_screen.dart` — add "Unlocks" tile

**Unlocks screen:**
- Lists available cosmetic options.
- Locked options: show with lock icon, grayed out, "Unlock by using the app for 2 years."
- Unlocked options: selectable, apply immediately.
- "Since you installed the app on this device" copy (handles reinstalls).

**Tests:** Widget test — locked state, unlocked state, selection.

---

### T7: Wire cosmetic evaluation into app lifecycle

**Files:**
- `lib/main.dart` — subscribe to achievement engine events, trigger `CosmeticUnlockEngine.onAchievementUnlocked`

**Tests:** Integration test — 2-year achievement triggers cosmetic unlock.

---

### T8: Localization

**Files:**
- `lib/core/l10n/app_en.arb` — ~8 new keys
- `lib/core/l10n/app_bn.arb` — Bangla translations

**Keys:**
- `unlocksTitle` — "Unlocks"
- `unlocksEmptyState` — "No unlocks yet. Keep using the app to earn cosmetic rewards."
- `unlockThemeAccentMidnight` — "Midnight Accent"
- `unlockThemeAccentMidnightDescription` — "A deep blue-purple theme accent, unlocked after 2 years."
- `unlockLockedLabel` — "Locked"
- `unlockLockedDescription` — "Unlock by using the app for 2 years."
- `unlockSinceInstall` — "Since you installed the app on this device"
- `unlockApply` — "Apply"

---

## Task sequencing

```
T1 (schema) ──→ T4 (repository) ──→ T3 (engine)
T2 (achievement stream) ──→ T3 ──→ T7 (wiring)
T3 ──→ T5 (theme accent)
T4 + T5 ──→ T6 (settings UI)
T6 ──→ T8 (i18n)
```

---

## Commit plan

| Commit | Tasks | Message |
|--------|-------|---------|
| 1 | T1 | `feat(db): add cosmetic_unlocks table (migration 18)` |
| 2 | T2 | `feat(achievements): emit stream events on achievement unlock` |
| 3 | T3 | `feat(cosmetics): add CosmeticUnlockEngine for achievement-to-cosmetic mapping` |
| 4 | T4 | `feat(cosmetics): add CosmeticRepository` |
| 5 | T5 | `feat(theme): add Midnight accent cosmetic option` |
| 6 | T6 | `feat(settings): add Unlocks section for cosmetic rewards` |
| 7 | T7 | `feat: wire cosmetic evaluation into app lifecycle` |
| 8 | T8 | `feat(i18n): add en/bn strings for cosmetic unlocks` |
