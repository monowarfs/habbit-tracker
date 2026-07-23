# Natural-Language Quick-Add

**Category:** AI-Powered · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Water's quick-add today is a grid of preset-amount buttons plus a custom
amount form — fast for the common case, but a power user who wants to log
"2 glasses just now" or "500ml at 3pm" still has to tap through a button
and, for anything not on the grid or not "now", a separate time picker.
TickTick's free-text quick-add parsing is the benchmark: typing a sentence
and having the app extract the structured fields is meaningfully faster
than multi-step form entry once a user trusts it. This is a convenience
upgrade for an existing flow, not a new capability.

## Goals
- Let a user type (or, later, speak) a short phrase like "2 glasses just
  now" or "300ml 20 minutes ago" and have Water parse an amount and a
  timestamp from it.
- Fall back gracefully (and visibly) to the existing manual custom-amount
  form when the parser can't confidently extract both fields.
- Keep the existing button-grid quick-add as the default/primary path —
  this is an additional entry point, not a replacement.

## Non-goals / out of scope
- No natural-language understanding model, no cloud NLU API — this is
  explicitly a small rule-based/regex-style parser.
- No support for arbitrary free-form logging across all three modules in
  this pass; Water is the natural first target since its log entries are
  a single number, unlike Medicine's schedule complexity or Prayer's fixed
  checklist.
- No voice input in this spec (see the separate voice-logging feature).
- Not attempting to parse every phrasing users might try — a bounded
  vocabulary (numbers + units + a handful of relative-time phrases) with
  a clear "couldn't understand that" fallback is the target, not 100%
  coverage.

## Proposed approach (high-level)
A small on-device parser (a handful of regex/token-matching rules, not a
model) extracts two things from a typed string: a quantity+unit token
(numbers, "glass"/"glasses", "ml", "cup", respecting the existing
Water unit setting) and an optional relative-time phrase ("just now",
"an hour ago", "at 3pm"). The parsed result maps onto the same inputs
`LogWaterEntryUseCase` already validates (amount > 0, no future
timestamp), so the parser's only job is producing those two values —
all the existing validation and persistence logic downstream is reused
unchanged. The UI surface is a text field alongside (or replacing, on
user preference) the quick-add button row, with a preview of the parsed
amount/time shown before confirming, so a misparse is caught before it's
logged rather than silently logging the wrong thing.

## Dependencies & prerequisites
- No new packages required if the parser stays regex/rule-based; if a
  more capable tokenizer is wanted later, that's a deliberate call to
  make in the implementation round, not assumed here.
- Localization: the parser needs bn-language number words/units handled
  too, or an explicit decision to ship en-only first and treat bn as a
  follow-up given the existing en/bn localization commitment.

## Open questions for the implementation round
- Does the parser need to handle Bangla phrasing at launch, or is an
  English-only v1 acceptable given the effort/localization tradeoff?
- What's the exact fallback UX when parsing fails partially (e.g. amount
  found, time not) — assume "now" for a missing time, or force the user
  to clarify?
- Should this live as a Water-only feature permanently, or is the parser
  designed generically enough that Medicine's "log as taken" flow could
  reuse it later?
- Where does the preview/confirm step live — inline in the text field's
  own widget, or a lightweight bottom sheet?

## Effort & sequencing notes
Complexity M — the parsing logic itself is small, but building a
trustworthy preview/confirm UX (so a misparse doesn't silently log wrong
data) is the part that takes real design and testing effort. Fine to
sequence independently of other AI-powered items; no shared dependencies.
