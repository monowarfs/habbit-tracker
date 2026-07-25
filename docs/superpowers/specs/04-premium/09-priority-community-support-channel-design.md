# Priority / Community Support Channel

**Category:** Premium · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23 · **Revised:** 2026-07-25
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
As a small-team, offline-first app with no account system, there's no
built-in support relationship with users at all today — no in-app
contact channel, no way to distinguish a paying supporter's request from
general feedback. A recognized-purchaser support lane (a dedicated
email address or Telegram/community channel for premium users) is a
low-cost trust signal that's an indie-app norm: it costs the team almost
nothing beyond attention, but tells a paying user their support matters
more than a cold inbox.

## What stays free vs. what's paywalled
General support (bug reports, feedback, a community channel open to all
users) stays free and available to everyone — this doesn't restrict
existing help channels. What's paywalled is a *priority* lane: a
recognized-purchaser path (e.g. a purchase-receipt-gated email address or
private Telegram group/channel) that gets faster attention or direct
access to the team, distinct from the general-purpose channel.

## Goals
- Give premium purchasers a clearly faster or more direct way to reach
  the team than the general support channel.
- Verify premium status via purchase receipt before granting access to
  the priority channel, so it isn't trivially spoofable.
- Keep operational cost minimal — this should not require new
  infrastructure beyond a support inbox or an existing chat platform.

## Non-goals / out of scope
- Not building an in-app ticketing/helpdesk system — this is a contact
  channel, not a support-ticket product.
- Not building automated receipt validation infrastructure beyond
  whatever the platform (App Store/Play) already provides for purchase
  verification — reuse existing receipt-check mechanisms, don't invent
  new ones.
- Not committing to specific SLAs (e.g. "24-hour response") in this
  planning pass — an operational decision for the team, not an
  architecture one.

## Proposed approach (high-level)
Surface a "Priority Support" entry point somewhere in Settings, visible
to (or unlocked for) premium purchasers, that reveals a dedicated contact
method — likely a specific email address or an invite link to a private
Telegram group/channel — gated behind the same purchase-state check
other premium features use. Verification can be as light as checking the
existing purchase-state flag client-side and optionally asking the user
to include their purchase receipt/order ID in their message for the team
to manually confirm, rather than building automated server-side receipt
validation from scratch.

### Settings screen integration

A new "Priority Support" entry appears in the Settings screen's premium
section (alongside other premium feature entries):

```
┌─────────────────────────────────────────┐
│  Settings                               │
│  ...                                    │
├─────────────────────────────────────────┤
│  Premium                                │
│  ┌─────────────────────────────────┐    │
│  │  🎨 Themes & Icons     [Unlocked]│   │
│  │  📊 Extended Stats     [Unlocked]│   │
│  │  📄 PDF/CSV Export    [Unlocked] │   │
│  │  💬 Priority Support  [→]       │   │
│  └─────────────────────────────────┘    │
├─────────────────────────────────────────┤
│  ...                                    │
└─────────────────────────────────────────┘
```

Tapping "Priority Support" navigates to a dedicated screen:

```
┌─────────────────────────────────────────┐
│  Priority Support          [← Back]     │
├─────────────────────────────────────────┤
│                                         │
│  Thank you for supporting Habit         │
│  Tracker! As a premium supporter,       │
│  you get priority access to our team.   │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  📧 Email Us                   │    │
│  │  support-premium@shurjomoy.dev │    │
│  │  [Copy Email] [Open Mail App]  │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  💬 Telegram Group             │    │
│  │  Habit Tracker Premium         │    │
│  │  [Join Group]                  │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  When contacting us, please include:    │
│  • Your purchase receipt/order ID       │
│  • Device model and OS version          │
│  • App version                          │
│  • Description of your issue            │
│                                         │
│  Your receipt can be found in your      │
│  email from the App Store / Play Store. │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  General support & feedback:            │
│  support@shurjomoy.dev                  │
│  (open to all users)                    │
│                                         │
└─────────────────────────────────────────┘
```

### Support channel options

The implementation round decides between (or combines):

1. **Dedicated email address** (`support-premium@shurjomoy.dev`):
   - Lowest operational cost.
   - The team manually filters premium vs. general based on receipt
     inclusion.
   - Can use email forwarding rules to prioritize.

2. **Private Telegram group/channel:**
   - Better for community building among premium users.
   - Allows premium users to help each other.
   - Requires moderation effort.

3. **Both:** email for direct support, Telegram for community. The
   premium support screen surfaces both.

### Non-premium user behavior

If a non-premium user somehow reaches the Priority Support screen (e.g.
via deep link or direct navigation), they see:
- A description of the priority support benefit.
- A "Unlock Premium" CTA that navigates to the purchase screen.

This doubles as a subtle conversion point.

## Database changes
- No new tables — this feature reads from the existing
  `premium_entitlements` table (or equivalent) to check premium status.
- The support channel details (email address, Telegram link) are
  hardcoded constants, not database-stored — changing them requires an
  app update, which is acceptable for an operational detail.

## Dependencies & prerequisites
- Entitlement/IAP infrastructure (spec 07) — this feature reads from
  the `premium_entitlements` table to check premium status. It reuses
  the same `core/premium/entitlement_service.dart` as all other premium
  features.
- A support inbox or community channel (Telegram, Discord, or similar)
  the team is willing to operate — an operational commitment, not a
  code dependency.

## Localization
- The Priority Support screen text needs en/bn localization.
- Email address and Telegram link are locale-agnostic.
- "General support" text needs localization.
- "Include your receipt" guidance needs localization.

## Edge cases & error handling
- **No email app installed:** the "Open Mail App" button gracefully
  degrades to "Copy Email" only — show a snackbar confirming the copy.
- **Telegram not installed:** the "Join Group" link opens in the device's
  browser, which handles the Telegram deep link or web fallback.
- **Receipt not available:** guide the user to find it in their email
  or in the platform's purchase history.

## Open questions for the implementation round
- Email-based priority support, a private community channel, or both?
- Does the team want lightweight self-reported receipt verification, or
  is client-side purchase-state good enough given the low stakes of
  someone spoofing "I'm premium" to get into a support channel?
- Should this be bundled automatically with every premium purchase/tier,
  or sold as its own small add-on? (Recommendation: bundled — it's a
  trust signal, not a revenue stream.)

## Effort & sequencing notes
S complexity — the lightest item in this batch; almost entirely
operational (standing up a channel) rather than engineering. No hard
technical dependency on other items beyond needing a purchase-state
check to exist somewhere first.
