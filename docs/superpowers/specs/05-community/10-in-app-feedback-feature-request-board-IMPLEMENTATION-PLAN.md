# Implementation Plan: In-App Feedback / Feature-Request Board

**Spec:** `10-in-app-feedback-feature-request-board-design.md`
**Complexity:** S · **Estimated effort:** 0.25 day
**Depends on:** Third-party vendor account (Canny or equivalent)

---

## Task 1: Choose vendor

**Decision required:** Canny vs. alternative (UserVoice, Nolt, or
a simple Google Form).

**Recommendation:** Canny free tier (up to 1 admin, unlimited posts)
for v1. Zero engineering — just a link.

---

## Task 2: Define feedback URL

**File:** `lib/features/community/data/community_links.dart`

```dart
class CommunityLinks {
  static const feedbackUrl = 'https://habittracker.canny.io/feature-requests';
}
```

---

## Task 3: Add Settings entry

**File:** `lib/features/settings/presentation/screens/settings_home_screen.dart`

Add "Feedback & Feature Requests" `ListTile` in the Community section:

```dart
ListTile(
  leading: const Icon(Icons.feedback_outlined),
  title: Text(l10n.feedbackTitle),
  subtitle: Text(l10n.feedbackDescription),
  trailing: const Icon(Icons.chevron_right),
  onTap: () async {
    final uri = Uri.parse(CommunityLinks.feedbackUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  },
),
```

---

## Task 4: Add localization strings

```json
"feedbackTitle": "Feedback & Feature Requests",
"feedbackDescription": "Tell us what you'd like to see next",
"feedbackOpenButton": "Open Feedback Board",
"feedbackLoadingError": "Could not open feedback board"
```

---

## Performance considerations

- **No performance concerns.** Single `ListTile` opening an external URL.

## Testing

- Widget test: Settings entry renders and navigates correctly.

## Localization

ARB keys listed in Task 4.
