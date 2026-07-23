# Lightweight External Community Link (Telegram/Discord)

**Category:** Community · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
The app currently has no community presence at all — no place for users to ask questions, share tips, or feel part of anything larger than their own solo streak. Many indie apps solve this cheaply by simply linking out to an external Telegram or Discord channel from Settings. It won't move retention dramatically on its own, but it's close to zero-cost and gives the no-account, no-server app its first taste of "community" without building anything.

## Infrastructure implication
Zero-infra beyond the URL itself. This is a single Settings row that opens an external link via the OS browser/app-link handler — the community platform (Telegram/Discord) is entirely third-party-hosted and moderated outside this app.

## Goals
- Add one Settings entry ("Join our community" or similar) linking out to a real, actively-moderated Telegram or Discord channel.
- Make it trivially discoverable but non-intrusive — a single row, not a nagging prompt or dialog.

## Non-goals / out of scope
- No in-app chat, forum, or comment system — this is purely an outbound link.
- No requirement that this app's team build or host the community infrastructure itself (Telegram/Discord hosting is free and external).
- No moderation tooling, membership tracking, or analytics on click-through in this feature.

## Proposed approach (high-level)
Add a single item to the existing Settings screen that opens the community URL via the platform's standard external-link launcher. No new domain logic, no new data model, no new screen — this is presentation-layer only, sitting alongside the other Settings entries (theme, locale, module toggles, reminders).

## Dependencies & prerequisites
- A real, already-created and actively-moderated Telegram or Discord channel to link to (a non-technical prerequisite — someone has to actually run the community, not just wire up the link).
- `url_launcher` (or whatever mechanism the app already uses for opening external links, if one exists) to open the URL.

## Open questions for the implementation round
- Telegram or Discord (or both, or an in-between choice like a WhatsApp group)? This is more a community-ops decision than an engineering one.
- Who moderates the channel, and is there a plan if it needs to scale past casual size?
- Does the link need a confirmation dialog ("you're leaving the app") or can it just be a direct external-link open?

## Effort & sequencing notes
Small (S), trivially independent of every other Community-category item — this can ship any time, with no dependency ordering. The only real gate is having an actual community channel to link to.
