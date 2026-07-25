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

## Localization

New user-facing strings requiring en/bn ARB keys:

- `communityJoinTitle` — "Join Our Community" / "আমাদের কমিউনিটিতে যোগ দিন"
- `communityJoinDescription` — "Connect with other users" / "অন্যান্য ব্যবহারকারীদের সাথে সংযুক্ত হন"
- `communityJoinAction` — "Open" / "খুলুন"
- `communityLeaveAppWarning` — "You're leaving the app" / "আপনি অ্যাপটি ছাড়ছেন"

Add these to `lib/core/l10n/app_en.arb` and `lib/core/l10n/app_bn.arb`.

## Edge cases & error handling

1. **External URL fails to open** — If `url_launcher` cannot handle the URL (no browser, no Telegram/Discord installed), surface a SnackBar with the raw URL so the user can copy it. Use `AppException.unexpected` internally.
2. **Community channel URL becomes stale** — The hardcoded URL may change over time. Consider making it a remote-configurable value (or at least easily updatable via a new app release). For v1, a hardcoded constant is acceptable.
3. **Confirmation dialog dismissed** — If a "leaving the app" confirmation is added, a dismiss should simply return to Settings with no action. No error state needed.
4. **Deep-link opens the community platform app instead of browser** — This is expected behavior (Telegram app opens the channel directly). No special handling needed.
5. **Accessibility: link not announced** — Ensure the Settings row has a proper `Semantics` label so screen readers announce it as a link. Reference `docs/superpowers/specs/07-accessibility/01-talkback-voiceover-navigation-audit-design.md`.

## Cross-references

- `docs/superpowers/specs/05-community/10-in-app-feedback-feature-request-board-design.md` — similar external-link Settings entry pattern.
- `docs/superpowers/specs/07-accessibility/01-talkback-voiceover-navigation-audit-design.md` — screen reader considerations for Settings links.
- `lib/features/settings/` — existing Settings presentation layer where this row is added.
- `lib/core/l10n/app_en.arb` / `app_bn.arb` — localization source files.

## Test strategy

- **Unit tests**: Verify the community URL constant is valid (non-empty, well-formed).
- **Widget tests**: Settings row renders with correct label and opens the URL on tap. Verify the row appears in the Settings screen at the expected position.
- **Test files to create**:
  - `test/features/settings/community_link_test.dart`
