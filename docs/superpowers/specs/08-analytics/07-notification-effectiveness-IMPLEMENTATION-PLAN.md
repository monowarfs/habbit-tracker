# Implementation Plan: Notification-Effectiveness Self-Metric

**Spec:** `07-notification-effectiveness-design.md`
**Complexity:** S · **Estimated effort:** 0.5 day
**Depends on:** `notification_ledger` table

---

## Task 1: Create effectiveness calculator

**File:** `lib/core/analytics/notification_effectiveness_use_case.dart`

```dart
class NotificationEffectivenessUseCase {
  /// Calculates effectiveness rate from notification ledger.
  EffectivenessResult calculate({
    required List<NotificationLedgerEntry> entries,
    Duration attributionWindow = const Duration(hours: 4),
  }) {
    final fired = entries.where((e) => e.firedAt != null).toList();
    final acted = fired.where((e) =>
      e.action == 'done' &&
      e.actionAt != null &&
      e.actionAt!.difference(e.firedAt!) <= attributionWindow
    ).length;

    return EffectivenessResult(
      total: fired.length,
      acted: acted,
      rate: fired.isEmpty ? 0 : acted / fired.length,
    );
  }
}
```

---

## Task 2: Create provider

**File:** `lib/features/analytics/presentation/providers/effectiveness_provider.dart`

Query `notification_ledger` for last 90 days, group by module, calculate
per-module effectiveness.

---

## Task 3: Add to Settings notification screen

**File:** `lib/features/settings/presentation/screens/notification_settings_screen.dart`

Add "Reminder Effectiveness" section showing per-module rates.

---

## Task 4: Add localization strings

```json
"notificationEffectivenessTitle": "Reminder Effectiveness",
"notificationEffectivenessRate": "{percent}% effective",
"notificationEffectivenessDescription": "Reminders led to action {acted} out of {total} times in the last 90 days.",
"notificationEffectivenessEmpty": "No reminder data yet"
```

---

## Performance considerations

- **90-day window:** the ledger has a 90-day eviction policy. Query is
  bounded and fast.
- **Caching:** cache effectiveness calculation for 1 hour.

## Testing

- Unit test: effectiveness calculation with various action patterns.
- Unit test: time-window scoping (4-hour cutoff).
- Widget test: effectiveness display.

## Localization

ARB keys listed in Task 4.
