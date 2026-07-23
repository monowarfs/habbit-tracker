# Priority / Community Support Channel

**Category:** Premium · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
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

## Dependencies & prerequisites
- Whatever purchase-state/entitlement check other premium features
  establish (this rides on that same mechanism).
- A support inbox or community channel (Telegram, Discord, or similar)
  the team is willing to operate — an operational commitment, not a
  code dependency.

## Open questions for the implementation round
- Email-based priority support, a private community channel, or both?
- Does the team want lightweight self-reported receipt verification, or
  is client-side purchase-state good enough given the low stakes of
  someone spoofing "I'm premium" to get into a support channel?
- Should this be bundled automatically with every premium purchase/tier,
  or sold as its own small add-on?

## Effort & sequencing notes
S complexity — the lightest item in this batch; almost entirely
operational (standing up a channel) rather than engineering. No hard
technical dependency on other items beyond needing a purchase-state
check to exist somewhere first.
