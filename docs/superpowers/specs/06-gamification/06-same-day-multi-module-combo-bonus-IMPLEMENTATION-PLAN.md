# Implementation Plan: Same-Day Multi-Module Combo Bonus

**Spec:** 06-same-day-multi-module-combo-bonus-design.md
**Complexity:** S | **Estimated effort:** 1 day
**Dependencies:** Dashboard day-completion indicator, module enable/disable registry

---

## Overview

Detect when all active modules are completed for the same day and fire a one-time combo bonus event. Detection runs at read time from existing `dayStatus()` data — no new tracking infrastructure.

---

## Implementation Tasks

### Task 1: Combo Detection Logic

**Files to create:**
- `lib/core/gamification/combo/combo_detector.dart`

```dart
class ComboDetector {
  /// Checks if all active modules are complete for [date].
  /// Returns true only when every enabled module's status is 'complete'.
  /// Requires 2+ active modules to fire.
  Future<bool> isComboDay({
    required LocalDate date,
    required List<HabitModule> modules,
  });

  /// Returns the number of active modules that are complete for [date].
  Future<int> completedModuleCount({
    required LocalDate date,
    required List<HabitModule> modules,
  });
}
```

**Integration:** Uses `HabitModule.dayStatus()` for each module — no new data source.

---

### Task 2: Combo Event Emitter

**Files to create:**
- `lib/core/gamification/combo/combo_event.dart`
- `lib/core/gamification/combo/combo_event_emitter.dart`

```dart
class ComboEvent {
  const ComboEvent({
    required this.date,
    required this.modulesCompleted,
    required this.totalActiveModules,
  });

  final LocalDate date;
  final int modulesCompleted;
  final int totalActiveModules;
}

class ComboEventEmitter {
  ComboEventEmitter({
    required this.comboDetector,
    required this.modules,
  });

  final ComboDetector comboDetector;
  final List<HabitModule> modules;

  /// Checks today's combo status and fires event if all modules complete.
  /// Called from dashboard or on app resume.
  Future<ComboEvent?> checkAndEmit({required DateTime now});
}
```

**Integration:** `ComboEventEmitter` is called from the dashboard's `_DayCompletionIndicator` or on app resume (same place as `WeeklyQuestResetHandler`).

---

### Task 3: Combo XP Award

**Files to modify:**
- `lib/core/gamification/xp_values.dart` (already has `comboBonus = 30`)

**Integration:**
When `ComboEventEmitter` detects a combo, award `XpValues.comboBonus` via `XpRepository.awardXp()`:
```dart
await xpRepository.awardXp(
  moduleId: 'core',
  eventType: 'combo_bonus',
  amount: XpValues.comboBonus,
  sourceId: 'combo_${date.toIso()}',
  now: now,
);
```

---

### Task 4: Combo Celebration UI

**Files to create:**
- `lib/core/gamification/combo/combo_celebration.dart`

```dart
Future<void> showComboCelebration(BuildContext context, {
  required int modulesCompleted,
  required int xpBonus,
});
```

**Widget:** Animated overlay with confetti/sparkle effect + "All modules done today!" text.

**Integration:** Triggered by `ComboEventEmitter.checkAndEmit()` when a combo is detected for the first time today.

---

### Task 5: Dashboard Combo Indicator

**Files to modify:**
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

**Changes:**
- In `_DayCompletionIndicator`, when all modules complete, show a subtle combo indicator (e.g. a small star icon next to the progress bar).
- The combo celebration fires once per day (tracked by checking if the combo event was already emitted for today).

---

### Task 6: Single-Module User Handling

**Files to modify:**
- `lib/core/gamification/combo/combo_detector.dart`

**Logic:**
```dart
Future<bool> isComboDay({...}) async {
  if (modules.length < 2) return false; // Single-module users see no combo
  // ... check all modules complete ...
}
```

**UI:** `WeeklyQuestList` and combo indicator are hidden when only 1 module is enabled.

---

### Task 7: Localization

**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**ARB keys:**
```
"comboCelebrationTitle": "Combo Complete!",
"comboCelebrationBody": "All modules done today!",
"comboXpBonus": "+{amount} XP combo bonus",
"comboIndicatorLabel": "All modules complete today",
"comboMinModules": "Enable 2+ modules for combo bonuses"
```

---

## Performance Considerations

- **Caching:** Combo status is checked once per app session (on resume or dashboard load). No periodic polling.
- **Lazy loading:** `dayStatus()` is already called by `_DayCompletionIndicator` — combo detection piggybacks on the same call.

---

## Testing

**Files to create:**
- `test/core/gamification/combo/combo_detector_test.dart`
- `test/core/gamification/combo/combo_event_emitter_test.dart`

**Coverage:**
| Test | Covers |
|---|---|
| `combo_detector_test.dart` | 2+ modules all complete → true, single module → false, partial completion → false |
| `combo_event_emitter_test.dart` | Combo event fires once per day, XP awarded, duplicate prevention |

---

## Edge Cases

- **Single-module users:** Combo hidden when only 1 module enabled. Requires 2+ active modules.
- **Timing:** Combo fires at end-of-day (23:59 local), not the moment the last module completes.
- **"Active modules" definition:** Uses `modules` table's `enabled` column via `module_registry.dart`.
- **Partial day:** Module with partial completion does NOT count as "complete" for combo.
- **Retroactive:** No combo detection for past days before feature ships.
