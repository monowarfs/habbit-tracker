# Implementation Plan: Invite-a-Friend Deep Link

**Spec:** `02-invite-a-friend-deep-link-design.md`
**Complexity:** S · **Estimated effort:** 0.5 day
**Depends on:** `share_plus` (shared with spec 01), `app_links`

---

## Task 1: Add `app_links` dependency

**File:** `pubspec.yaml`

```yaml
dependencies:
  app_links: ^3.5.0
```

Run `flutter pub get`.

---

## Task 2: Generate and store referral ID

**File:** `lib/features/community/data/referral_service.dart`

```dart
class ReferralService {
  static const _referralIdKey = 'referral_id';

  /// Returns the stable referral ID for this install.
  /// Generated once on first call, stored in SharedPreferences.
  static Future<String> getReferralId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_referralIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_referralIdKey, id);
    }
    return id;
  }
}
```

Key: the ID is generated once and stored — stable across shares.

---

## Task 3: Build invite link

**File:** `lib/features/community/data/invite_link_builder.dart`

```dart
class InviteLinkBuilder {
  /// Builds a store URL with referral tag.
  /// Android: Play Store URL with ?referrer= param
  /// iOS: App Store URL with referral tag in path
  static Future<String> buildInviteLink() async {
    final referralId = await ReferralService.getReferralId();
    if (Platform.isAndroid) {
      return 'https://play.google.com/store/apps/details?id=dev.shurjomoy.habit_tracker&referrer=ref%3D$referralId';
    } else {
      return 'https://apps.apple.com/app/id$appleAppId?ref=$referralId';
    }
  }
}
```

---

## Task 4: Create invite controller

**File:** `lib/features/community/presentation/providers/invite_friend_provider.dart`

```dart
@riverpod
class InviteFriendController extends _$InviteFriendController {
  @override
  Future<void> build() async {}

  Future<void> inviteFriend() async {
    final link = await InviteLinkBuilder.buildInviteLink();
    await Share.share(
      link,
      subject: 'Check out Habit Tracker!',
    );
  }
}
```

---

## Task 5: Add invite entry point

**File:** `lib/features/settings/presentation/screens/settings_home_screen.dart`

Add an "Invite a Friend" `ListTile` in the Community section:

```dart
ListTile(
  leading: const Icon(Icons.person_add_outlined),
  title: Text(l10n.inviteFriendTitle),
  subtitle: Text(l10n.inviteFriendDescription),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => ref.read(inviteFriendControllerProvider.notifier).inviteFriend(),
),
```

---

## Task 6: Create deep-link parser

**File:** `lib/features/community/data/referral_parser.dart`

```dart
class ReferralParser {
  /// Extracts referral ID from a deep link URL.
  /// Returns null if no valid referral tag found.
  static String? parseReferralTag(Uri uri) {
    // Android: ?referrer=ref%3D<id>
    // iOS: ?ref=<id>
    return uri.queryParameters['referrer']?.replaceFirst('ref=', '')
        ?? uri.queryParameters['ref'];
  }
}
```

---

## Task 7: Wire deep-link handler on first launch

**File:** `lib/main.dart` or `lib/app.dart`

On cold start, check if the app was opened via a deep link with a
referral tag. If so, store the referral source locally:

```dart
final appLinks = AppLinks();
final initialLink = await appLinks.getInitialAppLink();
if (initialLink != null) {
  final referralId = ReferralParser.parseReferralTag(initialLink);
  if (referralId != null) {
    await prefs.setString('referred_by', referralId);
  }
}
```

---

## Task 8: Add localization strings

**Files:** `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`

```json
"inviteFriendTitle": "Invite a Friend",
"inviteFriendDescription": "Share the app with someone you care about",
"inviteFriendShareAction": "Share Link",
"inviteFriendCopiedMessage": "Link copied!",
"inviteFriendReferralNote": "Your friend will know you invited them"
```

Run `flutter gen-l10n`.

---

## Performance considerations

- **Referral ID:** generated once, stored in SharedPreferences — no
  performance concern.
- **Deep-link parsing:** runs once on cold start — negligible cost.
- **Share sheet:** native OS component — no performance concern.

## Testing

- `test/features/community/invite_friend_test.dart` — unit tests for
  link building and referral ID stability.
- `test/core/referral_parser_test.dart` — unit tests for URL parsing
  with various URL formats.
- Widget test: invite button triggers share with correct URL.

## Localization

ARB keys listed in Task 8. The referral note is informational only —
no localization needed for the referral ID itself (it's opaque).
