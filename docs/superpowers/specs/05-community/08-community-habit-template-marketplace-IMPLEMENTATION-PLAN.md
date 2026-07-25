# Implementation Plan: Community Habit-Template Marketplace

**Spec:** `08-community-habit-template-marketplace-design.md`
**Complexity:** M · **Estimated effort:** 1 day
**Depends on:** Module creation forms (Water/Medicine/Prayer)

---

## Task 1: Define preset data format

**File:** `assets/data/habit_templates.json`

```json
[
  {
    "id": "water_standard",
    "moduleId": "water",
    "name": "Standard Water Tracking",
    "nameBn": "স্ট্যান্ডার্ড পানি ট্র্যাকিং",
    "description": "Track 2L daily with hourly reminders",
    "descriptionBn": "ঘণ্টায় একবার রিমাইন্ডার সহ দৈনিক 2L ট্র্যাক করুন",
    "config": {
      "goalMl": 2000,
      "quickAddAmountsMl": [250, 500, 750],
      "reminderEnabled": true,
      "reminderIntervalMinutes": 60
    }
  },
  {
    "id": "medicine_twice_daily",
    "moduleId": "medicine",
    "name": "Twice-Daily Medicine",
    "nameBn": "দৈনিক দুইবার ওষুধ",
    "description": "Morning and evening doses with food",
    "descriptionBn": "খাবারের সাথে সকাল ও সন্ধ্যার ডোজ",
    "config": {
      "frequencyType": "fixed_daily",
      "timesOfDay": ["08:00", "20:00"],
      "graceWindowMinutes": 30
    }
  }
]
```

---

## Task 2: Create template parser

**File:** `lib/core/templates/habit_template_parser.dart`

```dart
class HabitTemplateParser {
  static Future<List<HabitTemplate>> parse() async {
    final json = await rootBundle.loadString('assets/data/habit_templates.json');
    return (jsonDecode(json) as List)
        .map((e) => HabitTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
```

---

## Task 3: Create template browser screen

**File:** `lib/features/community/presentation/screens/template_browser_screen.dart`

Shows available templates filtered by module, with a "Use Template"
button that prefills the module creation form.

---

## Task 4: Wire template to creation forms

**File:** `lib/features/water/presentation/screens/water_settings_screen.dart`
(and Medicine/Prayer equivalents)

When a template is selected, prefill the form fields with the
template's config values. The user can still edit before saving.

---

## Task 5: Add entry point

Add "Habit Templates" entry to Settings or Dashboard for quick access.

---

## Task 6: Add localization strings

ARB keys for template names, descriptions, "Use Template" button.

---

## Performance considerations

- **Asset loading:** JSON is <100KB — load once, cache in memory.
- **No network:** everything is bundled offline.

## Testing

- Unit test: template parsing.
- Widget test: template browser renders correctly.
- Widget test: template prefills creation form correctly.

## Localization

ARB keys listed in Task 6. Template names/descriptions need en/bn.
