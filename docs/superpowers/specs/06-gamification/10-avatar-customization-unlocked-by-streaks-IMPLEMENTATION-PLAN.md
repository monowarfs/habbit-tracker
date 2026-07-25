# Implementation Plan: Avatar Customization Unlocked by Streaks

**Spec:** 10-avatar-customization-unlocked-by-streaks-design.md
**Complexity:** M | **Estimated effort:** 3 days (+ art asset production)
**Dependencies:** Achievements engine (streak milestone events), dashboard

---

## Overview

Unlock cosmetic avatar pieces (head, body, background, frame) at streak-length milestones. Display the equipped avatar on the dashboard. Trigger detection hooks into the achievements engine's event stream. Requires an art asset pipeline.

---

## Implementation Tasks

### Task 1: Avatar Unlock Drift Table

**Files to create/modify:**
- `lib/core/database/tables/avatar_unlocks_table.dart` (create)
- `lib/core/database/tables/avatar_equipped_table.dart` (create)
- `lib/core/database/app_database.dart` (modify)

**Drift tables:**
```dart
@DataClassName('AvatarUnlockRow')
class AvatarUnlocksTable extends Table {
  @override
  String get tableName => 'avatar_unlocks';

  TextColumn get id => text()();
  TextColumn get pieceId => text()();
  TextColumn get slot => text()(); // 'head' | 'body' | 'background' | 'frame'
  IntColumn get unlockedAt => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {pieceId},
  ];
}

@DataClassName('AvatarEquippedRow')
class AvatarEquippedTable extends Table {
  @override
  String get tableName => 'avatar_equipped';

  TextColumn get id => text()();
  TextColumn get headPieceId => text().nullable()();
  TextColumn get bodyPieceId => text().nullable()();
  TextColumn get backgroundPieceId => text().nullable()();
  TextColumn get framePieceId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Migration:** `if (from < N)` creates both tables. Seeds singleton row in `avatar_equipped` with all null pieces (base avatar).

---

### Task 2: Avatar Piece Catalog

**Files to create:**
- `lib/core/gamification/avatar/avatar_piece_catalog.dart`

```dart
enum AvatarSlot { head, body, background, frame }

class AvatarPiece {
  const AvatarPiece({
    required this.id,
    required this.slot,
    required this.nameKey,
    required this.unlockRequirement, // streak achievement key
    required this.assetPath,
  });

  final String id;
  final AvatarSlot slot;
  final String nameKey;
  final String unlockRequirement; // e.g. 'water_30_day_streak'
  final String assetPath;
}

const avatarPieceCatalog = [
  // Head pieces
  AvatarPiece(id: 'head_bandana', slot: AvatarSlot.head, nameKey: 'avatarHeadBandana', unlockRequirement: 'water_7_day_streak', assetPath: 'assets/avatar/head/bandana.png'),
  AvatarPiece(id: 'head_crown', slot: AvatarSlot.head, nameKey: 'avatarHeadCrown', unlockRequirement: 'water_100_day_streak', assetPath: 'assets/avatar/head/crown.png'),
  // Body pieces
  AvatarPiece(id: 'body_robe', slot: AvatarSlot.body, nameKey: 'avatarBodyRobe', unlockRequirement: 'prayer_30_day_streak', assetPath: 'assets/avatar/body/robe.png'),
  // Background pieces
  AvatarPiece(id: 'bg_sunset', slot: AvatarSlot.background, nameKey: 'avatarBgSunset', unlockRequirement: 'medicine_14_day_streak', assetPath: 'assets/avatar/bg/sunset.png'),
  // Frame pieces
  AvatarPiece(id: 'frame_gold', slot: AvatarSlot.frame, nameKey: 'avatarFrameGold', unlockRequirement: 'tenure_1_year', assetPath: 'assets/avatar/frame/gold.png'),
];
```

---

### Task 3: Avatar Repository

**Files to create:**
- `lib/core/gamification/avatar/avatar_repository.dart`

```dart
class AvatarRepository {
  AvatarRepository(this._db);
  final AppDatabase _db;

  /// Returns all unlocked piece IDs.
  Future<Set<String>> unlockedPieceIds();

  /// Stream of unlocked pieces for reactive UI.
  Stream<Set<String>> watchUnlockedPieces();

  /// Records an unlock.
  Future<void> unlockPiece({
    required String pieceId,
    required AvatarSlot slot,
    required DateTime now,
  });

  /// Returns current equipped pieces.
  Future<AvatarEquippedRow> currentEquipped();

  /// Stream of current equipped pieces.
  Stream<AvatarEquippedRow> watchEquipped();

  /// Equips a piece in a slot.
  Future<void> equipPiece({
    required AvatarSlot slot,
    required String? pieceId,
    required DateTime now,
  });
}
```

---

### Task 4: Avatar Unlock Listener

**Files to create:**
- `lib/core/gamification/avatar/avatar_unlock_listener.dart`

```dart
class AvatarUnlockListener {
  AvatarUnlockListener({
    required this.achievementEngine,
    required this.avatarRepository,
  });

  final AchievementEngine achievementEngine;
  final AvatarRepository avatarRepository;

  /// Subscribes to achievement events and unlocks avatar pieces
  /// when a qualifying streak milestone is achieved.
  StreamSubscription<AchievementEvent> listen() {
    return achievementEngine.events.listen((event) async {
      if (!event.justUnlocked) return;

      // Check if this achievement maps to an avatar piece unlock
      for (final piece in avatarPieceCatalog) {
        if (piece.unlockRequirement == event.key) {
          await avatarRepository.unlockPiece(
            pieceId: piece.id,
            slot: piece.slot,
            now: clock.now(),
          );
          // Show unlock toast
        }
      }
    });
  }
}
```

---

### Task 5: Avatar Display Widget

**Files to create:**
- `lib/features/dashboard/presentation/widgets/avatar_display.dart`

```dart
class AvatarDisplay extends ConsumerWidget {
  /// Renders the equipped avatar on the dashboard.
  /// Layers: background → body → head → frame (bottom to top).
  /// Base avatar always visible; equipped pieces overlay.
}

class _AvatarLayer extends StatelessWidget {
  /// Renders a single avatar layer (background, body, head, or frame).
  /// Falls back to base layer if no piece equipped in slot.
}
```

**Dashboard integration:** Insert `AvatarDisplay` in `DashboardScreen` near the greeting area.

---

### Task 6: Avatar Customize Screen

**Files to create:**
- `lib/features/avatar/presentation/screens/avatar_customize_screen.dart`
- `lib/features/avatar/presentation/widgets/piece_selector.dart`
- `lib/features/avatar/presentation/widgets/slot_picker.dart`

```dart
class AvatarCustomizeScreen extends ConsumerWidget {
  /// Full-screen avatar customization.
  /// Shows avatar preview + slot selectors.
}

class SlotPicker extends ConsumerWidget {
  /// Shows available pieces for a given slot.
  /// Locked pieces show lock icon + unlock requirement.
  /// Equipped piece shows checkmark.
}
```

**Router integration:** Add `/avatar/customize` route.

---

### Task 7: Avatar Unlock Toast

**Files to create:**
- `lib/core/gamification/avatar/avatar_unlock_toast.dart`

```dart
void showAvatarUnlockToast(BuildContext context, {required AvatarPiece piece});
```

**Integration:** Called from `AvatarUnlockListener` when a piece is unlocked.

---

### Task 8: Localization

**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**ARB keys:**
```
"avatarCustomizeTitle": "Customize Avatar",
"avatarUnlockToast": "New piece unlocked: {name}!",
"avatarSlotHead": "Head",
"avatarSlotBody": "Body",
"avatarSlotBackground": "Background",
"avatarSlotFrame": "Frame",
"avatarLocked": "Locked — {requirement}",
"avatarEquipButton": "Equip",
"avatarUnequipButton": "Remove",
"avatarHeadBandana": "Bandana",
"avatarHeadCrown": "Crown",
"avatarBodyRobe": "Robe",
"avatarBgSunset": "Sunset Background",
"avatarFrameGold": "Gold Frame"
```

---

## Performance Considerations

- **Caching:** Unlocked pieces set is small (max ~20 items). Cache in Riverpod `StreamProvider`.
- **Lazy loading:** Avatar image assets loaded on demand when the customize screen opens.
- **Memory:** Dashboard avatar is a static composite — no animation overhead.

---

## Testing

**Files to create:**
- `test/core/gamification/avatar/avatar_repository_test.dart`
- `test/core/gamification/avatar/avatar_unlock_listener_test.dart`
- `test/features/dashboard/presentation/widgets/avatar_display_test.dart`
- `test/features/avatar/presentation/screens/avatar_customize_screen_test.dart`

**Coverage:**
| Test | Covers |
|---|---|
| `avatar_repository_test.dart` | Unlock recording, equip/unequip, dedup, stream reactivity |
| `avatar_unlock_listener_test.dart` | Streak milestone triggers correct piece unlock, non-matching events ignored |
| `avatar_display_test.dart` | Base avatar renders, equipped pieces layer correctly |
| `avatar_customize_screen_test.dart` | Locked pieces show requirement, equip works, slot switching |

---

## Edge Cases

- **Overlap with Spec 03 (companion):** Avatar is user-customized self-portrait; companion is autonomous. Both coexist on dashboard.
- **Default avatar:** Every user starts with base avatar (no pieces equipped). Base always available.
- **Unlock detection:** Hooks into achievement engine's event stream. Maps achievement keys to avatar pieces.
- **Art assets:** PNG files for base avatar + each unlockable piece. Must be produced externally.
