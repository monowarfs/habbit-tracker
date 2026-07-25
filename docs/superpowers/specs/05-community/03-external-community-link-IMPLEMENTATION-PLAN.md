# Implementation Plan: External Community Link

**Spec:** `03-external-community-link-design.md`
**Complexity:** S · **Estimated effort:** 0.25 day
**Depends on:** `url_launcher` (or equivalent), actual community channel

---

## Task 1: Add `url_launcher` dependency (if not present)

**File:** `pubspec.yaml`

```yaml
dependencies:
  url_launcher: ^6.2.0
```

Run `flutter pub get`.

---

## Task 2: Define community URL constant

**File:** `lib/features/community/data/community_links.dart`

```dart
class CommunityLinks {
  /// Telegram/Discord community channel URL.
  /// Update this constant when the channel URL changes.
  static const communityUrl = 'https://t.me/habittracker_community';

  /// Fallback: raw URL to display if launch fails.
  static const communityUrlRaw = 't.me/habittracker_community';
}
```

---

## Task 3: Add Settings entry

**File:** `lib/features/settings/presentation/screens/settings_home_screen.dart`

Add a "Community" section after the existing sections:

```dart
const Divider(),
_ListSectionHeader(l10n.settingsCommunity),
ListTile(
  leading: const Icon(Icons.forum_outlined),
  title: Text(l10n.communityJoinTitle),
  subtitle: Text(l10n.communityJoinDescription),
  trailing: const Icon(Icons.chevron_right),
  onTap: () async {
    final uri = Uri.parse(CommunityLinks.communityUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CommunityLinks.communityUrlRaw)),
      );
    }
  },
),
```

---

## Task 4: Add localization strings

**Files:** `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`

```json
"settingsCommunity": "Community",
"communityJoinTitle": "Join Our Community",
"communityJoinDescription": "Connect with other users",
"communityJoinAction": "Open",
"communityLeaveAppWarning": "You're leaving the app"
```

Run `flutter gen-l10n`.

---

## Performance considerations

- **No performance concerns.** This is a single `ListTile` that opens
  an external URL. No state, no computation, no memory impact.

## Testing

- `test/features/settings/community_link_test.dart` — widget test
  verifying the Settings row renders and navigates correctly.

## Localization

ARB keys listed in Task 4. The URL itself is locale-agnostic.
