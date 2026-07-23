# [REQUIRES ACCOUNT] Global City-Level Prayer Participation Stat

**Category:** Community · **Atlas complexity:** L · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
An ambient-belonging number — "12,000 people in Dhaka praying Asr today" — is the kind of feature Muslim Pro uses to make a solitary act (praying alone, on your own device) feel collectively shared. It's a nice-to-have for the Prayer persona but the atlas rates it Low retention impact, which matters a lot here because the infrastructure cost to build it is not small: it requires an aggregation backend, exactly like item 06. Unlike item 06, though, no group membership or per-user identity is needed — only an anonymous, aggregated count. That makes it a smaller *slice* of the account/backend problem, but it still crosses the same fundamental line this app has avoided so far: something leaves the device and reaches a server.

## Infrastructure implication
**REQUIRES ACCOUNT-ADJACENT BACKEND** (aggregation service, not necessarily individual user accounts). Even without per-user identity, this needs a server that receives a ping ("someone in Dhaka completed Asr just now"), aggregates it, and serves a count back to all clients. That is still a durable architectural change from "nothing leaves the device," and per the framing carried over from `docs/strategies/analytics-future.md`, it needs the exact same consent checklist that document lays out for analytics: affirmative opt-in (not opt-out), updated store data-safety disclosures, a privacy/anonymization design review, a durable off switch, and a deletion story — even though the payload here is coarser (a city name and a prayer-completion tick) than typical analytics events.

## Goals (if the backend decision is made)
- Show an approximate, anonymized count of nearby-city users who completed a given prayer in a recent window, sourced from Prayer's existing per-prayer completion tracking (`prayer_records`) and location resolution.
- Keep participation in the count fully opt-in, off by default, and easily revocable.
- Design the aggregation so no individual user's specific prayer times or location are ever recoverable from the published number.

## Non-goals / out of scope
- Not building any per-user account or identity — this is aggregate-only, no login, no profile.
- No leaderboard or comparison between cities/countries (that would shift this from "ambient belonging" into competitive territory, a different feature).
- No real-time precision — an approximate, delayed, or rounded count is acceptable and arguably preferable for anonymization.
- Not deciding whether the backend/consent trade-off is worth it for a Low-retention-impact feature — that judgment call belongs to whoever schedules this.

## Proposed approach (high-level)
Contingent on the backend/consent decision: on prayer completion (already tracked via Prayer's existing status derivation and `prayer_records`), an opted-in user's device sends a minimal anonymized ping (city-level location bucket + which prayer + timestamp bucket, no user identifier at all) to an aggregation service. The service maintains rolling counts per city per prayer and serves them back to any client that requests them, opted in or not (viewing the count doesn't require participating in it). Location bucketing reuses Prayer's existing GPS/manual location resolver, coarsened to city granularity to avoid any risk of re-identifying an individual from a small-population area.

## Dependencies & prerequisites
- An aggregation backend (does not need to be the same system as item 06's group backend, but could plausibly share infrastructure if both are ever built).
- The full consent checklist from `docs/strategies/analytics-future.md`, applied here rather than assumed as automatically satisfied: affirmative off-by-default opt-in, Play Console/App Store Connect data-safety disclosure updates, a privacy/anonymization review (city-level location + religious-observance timing is sensitive data in multiple jurisdictions' frameworks), a durable off switch, and a deletion story for the aggregate pings already sent (recognizing aggregated data may not be individually deletable once merged — this needs explicit design, not an assumption).
- Prayer's existing GPS/manual location resolver and `prayer_records` completion tracking as the data source.

## Open questions for the implementation round
- What city-population floor avoids small-town re-identification risk (e.g. suppress the count entirely below some threshold)?
- Is the aggregation service justified for a Low-retention-impact feature, or does it make more sense to bundle this into item 06's backend build if that's ever greenlit, rather than standing up a second backend independently?
- What time-bucketing (real-time vs. hourly vs. daily) balances "feels alive" against anonymization safety?
- Does published participation data need a "how this works" disclosure in-app, given the sensitivity of religious-observance data specifically?

## Effort & sequencing notes
Large (L) complexity for Low retention impact — a candidate for deprioritization or bundling with item 06 rather than standing up independently, if the account/backend decision is ever made at all. Should not be scheduled ahead of resolving whether any backend gets built in the first place.
