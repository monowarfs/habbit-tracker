# Implementation Plan: Badge Rarity Tiers

**Spec:** 05-badge-rarity-tiers-design.md
**Complexity:** S | **Estimated effort:** 0.5 day
**Dependencies:** Achievement definitions (`AchievementDefinition` class), badge gallery UI

---

## Overview

Add a `BadgeRarity` enum to `AchievementDefinition` and render tier-appropriate visuals in the badge gallery. Purely additive metadata — no DB migration, no engine changes.

---

## Implementation Tasks

### Task 1: BadgeRarity Enum

**Files to create/modify:**
- `lib/core/achievements/achievement_kind.dart` (modify)

**Add to existing file:**
```dart
enum BadgeRarity { common, rare, legendary }
```

---

### Task 2: Extend AchievementDefinition

**Files to modify:**
- `lib/core/modules/habit_module.dart`

**Changes to `AchievementDefinition`:**
```dart
class AchievementDefinition {
  const AchievementDefinition({
    required this.key,
    required this.moduleId,
    required this.titleKey,
    required this.descriptionKey,
    required this.target,
    required this.currentProgress,
    this.rarity = BadgeRarity.common, // NEW — default common
  });

  // ... existing fields ...
  final BadgeRarity rarity;
}
```

---

### Task 3: Assign Rarity to All Existing Achievements

**Files to modify (per module):**
- `lib/features/water/water_module.dart` — Water's `achievementDefinitions` getter
- `lib/features/medicine/medicine_module.dart` — Medicine's `achievementDefinitions` getter
- `lib/features/prayer/prayer_module.dart` — Prayer's `achievementDefinitions` getter

**Rarity assignment rules:**
| Tier | Criteria | Example |
|---|---|---|
| Common | Target <= 7 | 7-day streak, first entry |
| Rare | Target 8-30 | 14-day streak, 30-day streak |
| Legendary | Target > 30 or special condition | 100-day streak, 365-day streak, 2-year tenure |

**Each module's `achievementDefinitions`** adds `rarity:` parameter to each `AchievementDefinition()` constructor call.

---

### Task 4: Badge Gallery Rarity Visual Treatment

**Files to modify:**
- `lib/features/achievements/presentation/` (badge gallery screen/widget)

**New widget file:**
- `lib/features/achievements/presentation/widgets/badge_rarity_indicator.dart`

```dart
class BadgeRarityIndicator extends StatelessWidget {
  const BadgeRarityIndicator({required this.rarity});
  final BadgeRarity rarity;

  @override
  Widget build(BuildContext context) {
    return switch (rarity) {
      BadgeRarity.common => const SizedBox.shrink(),
      BadgeRarity.rare => Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        // Silver border/glow
      ),
      BadgeRarity.legendary => Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.amber, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 8)],
        ),
        // Gold border/glow + subtle particle effect
      ),
    };
  }
}
```

**Gallery card integration:** Wrap each badge card with `BadgeRarityIndicator` based on the definition's `rarity` field.

---

### Task 5: Screen Reader Support

**Files to modify:**
- Badge gallery card widget

**Changes:**
```dart
Semantics(
  label: '${definition.titleKey} — ${rarity.name} badge',
  child: BadgeCard(definition: definition),
)
```

---

### Task 6: Localization

**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**ARB keys:**
```
"badgeRarityCommon": "Common",
"badgeRarityRare": "Rare",
"badgeRarityLegendary": "Legendary",
"badgeRarityLabel": "Rarity: {tier}"
```

---

## Performance Considerations

- **Caching:** Rarity is a code-level constant on the definition object — no DB query, no computation.
- **Lazy loading:** Badge gallery already lazy-loads; rarity visual is just a wrapper.

---

## Testing

**Files to create:**
- `test/core/achievements/badge_rarity_test.dart`
- `test/features/achievements/presentation/widgets/badge_rarity_indicator_test.dart`

**Coverage:**
| Test | Covers |
|---|---|
| `badge_rarity_test.dart` | Enum default value, all three tiers exist |
| `badge_rarity_indicator_test.dart` | Common shows nothing, rare shows silver border, legendary shows gold glow |

---

## Edge Cases

- **Backward compatibility:** Existing achievements default to `common` rarity. No migration needed.
- **Visual treatment:** Common = default style, Rare = silver border, Legendary = gold glow + particle.
- **Screen reader:** Rarity announced as part of badge's semantic label.
