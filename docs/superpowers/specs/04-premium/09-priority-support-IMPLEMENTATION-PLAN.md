# Implementation Plan: Priority Support Channel

**Spec:** `09-priority-community-support-channel-design.md`
**Complexity:** S · **Estimated effort:** 1 day
**Depends on:** Spec 07 (entitlements)

---

## Task 1: Create Priority Support screen

**File:** `lib/features/settings/presentation/screens/priority_support_screen.dart`

A simple screen with:
- "Thank you" message for premium supporters.
- Email contact section with copy/open actions.
- Telegram group link with join action.
- "Include your receipt" guidance text.
- General support email for comparison.

---

## Task 2: Add route to app_router.dart

**File:** `lib/core/router/app_router.dart`

Add `/settings/priority-support` route.

---

## Task 3: Add entry to Settings screen

**File:** `lib/features/settings/presentation/screens/settings_home_screen.dart`

Add "Priority Support" tile in the premium section, gated behind
entitlement check.

---

## Task 4: Add entitlement gate

Non-premium users see a "Unlock Premium" CTA instead of the support
channel details.

---

## Task 5: Add localization strings

en/bn ARB keys for support screen text, "Copy Email", "Join Group",
"Open Mail App" labels.

---

## Review checklist

- [ ] Screen shows correct contact information.
- [ ] "Copy Email" copies to clipboard.
- [ ] "Open Mail App" launches email client.
- [ ] "Join Group" opens Telegram.
- [ ] Entitlement gate works for non-premium users.
- [ ] en/bn text renders correctly.
