# Decisions Log

Record of every open product decision, the options considered, and the final call.
Referenced from `functional-requirements.md` by ID.

---

## D-01: Water unit — ml only, or ml + oz?

**Options:**
- A. Metric only (ml) in v1.
- B. ml + fl oz as a per-user display setting, canonical storage in ml.
- C. ml + fl oz, user picks unit per-log-entry.

**Decision: B** — canonical storage in ml, user picks a display unit (ml or fl oz)
in Settings, applied globally to the Water module.

**Reasoning:** Primary launch personas (Dhaka office worker, Bangla locale) are
metric-native, so ml-only would be the lazy-safe default. But the app also
targets English-speaking users on iOS in markets (US) where fl oz is the
mental model, and a global toggle is one stored enum + one conversion function —
not worth gating out for a top-3-market use case. Option C (per-entry unit) is
rejected: it adds a unit field to every log row and a conversion-on-read cost
for zero user benefit — nobody logs the same habit in two units on the same day.

**Affects:** FR-W-02, FR-W-03.

---

## D-02: Medicine — overlapping schedules

**Options:**
- A. One active schedule per medicine at a time (editing replaces the old one).
- B. Multiple independent schedules per medicine, merged into one daily timeline.

**Decision: B.**

**Reasoning:** Real-world dosing changes mid-course (e.g., taper schedules,
"twice daily for 5 days then once daily for 5 days") are common enough that
forcing edit-in-place would lose history and misrepresent adherence stats.
Each schedule is its own record with its own start/end; the presentation layer
flattens all active schedules for a medicine into a single ordered list of
dose instances per day. Schedules for the same medicine cannot generate two
doses in the same time slot on the same day — the second one is deduped by
schedule priority (most recently created wins) and this is a documented edge
case, not a silent bug.

**Affects:** FR-M-01, FR-M-02.

---

## D-03: Medicine — "every other day" anchoring

**Decision:** Anchored to the schedule's `startDate`, computed as
`daysSinceStart % 2 == 0` in the user's local calendar day (not UTC, not a
rolling 48h window). Editing `startDate` re-anchors the whole pattern.

**Reasoning:** Anchoring to start date (not e.g. "even calendar days") is the
only interpretation that matches what a prescription label means by "every
other day" — day 1 dose, day 2 skip, day 3 dose. Using local calendar days
(not a 48h timer) avoids drift across DST changes and matches user mental
model of "today is a dose day."

**Affects:** FR-M-03.

---

## D-04: Medicine — end date vs. stock exhaustion

**Options:**
- A. Whichever comes first (end date OR stock = 0) silently ends the schedule.
- B. Stock reaching 0 only triggers a low-stock/out-of-stock notification;
  the schedule keeps generating doses (which the user can't mark taken from
  stock, but can still log) until its explicit end date or manual stop.

**Decision: B, with an opt-in toggle** `stopWhenStockDepleted` (default off).

**Reasoning:** Defaulting to auto-stop on stock=0 is dangerous for a health
app — a user who forgets to refill should not have their tracker silently
declare "schedule complete." Default behavior is: keep the schedule alive,
surface an "out of stock" banner and a refill reminder notification. Users
who explicitly want the schedule to pause when supply runs out (e.g. PRN
courses) can enable the toggle per-medicine.

**Affects:** FR-M-04, FR-M-05.

---

## D-05: Medicine — missed-dose grace window

**Decision:** Default grace window = 30 minutes after scheduled time, during
which a dose is "due" (not yet late). After the grace window and until the
next scheduled dose (or end of day for the last dose), an unmarked dose is
"missed." Grace window is editable per-medicine, range 0–180 min.

**Reasoning:** A fixed global constant would be wrong for both a
twice-a-day medicine (wide tolerance is fine) and an insulin-timed medicine
(tight tolerance matters). Per-medicine override with a sane default avoids
building a settings screen most users never touch, while not hard-coding
away a real clinical need.

**Affects:** FR-M-06.

---

## D-06: Prayer — calculation method

**Decision:** User-selectable calculation method (Muslim World League, ISNA,
Egyptian General Authority, Umm al-Qura Makkah, University of Islamic
Sciences Karachi, Tehran, Dubai, Kuwait, Qatar, Singapore, custom
angle-based). Default is chosen by device locale/region at first launch
(Bangladesh → Karachi), user can change any time in Settings.

**Also decided:** Asr juristic method (Standard/Shafi'i vs. Hanafi) is a
separate user setting, default Hanafi for Bangladesh locale, Standard
otherwise — because the Hanafi Asr calculation is common in the primary
launch region and silently defaulting to Standard would make Asr times
visibly wrong for a large share of users.

**Reasoning:** Prayer time calculation methods are a matter of regional/
scholarly convention, not something the app should assume. Locale-based
default minimizes first-run friction while the explicit setting avoids
ever being "wrong" for a user in a different tradition.

**Affects:** FR-P-01, FR-P-02.

---

## D-07: Prayer — Jumu'ah replacing Friday Dhuhr

**Decision:** Explicit boolean setting, `observesJumuah`, default **off**.
When on, Friday's Dhuhr checklist item is relabeled "Jumu'ah" and its window
follows the same Dhuhr time (no separate calculation), and it counts toward
the same streak/Qadha bucket as Dhuhr.

**Reasoning:** The requirement explicitly says not to assume — this is not
inferred from a gender field or any other proxy. It's a direct, named
toggle in Settings under Prayer preferences, off by default so v1 behavior
is the same as before the user configures anything.

**Affects:** FR-P-03.

---

## D-08: Prayer — Qadha accounting rules

**Decision:**
- Users can enter a **starting Qadha balance** per prayer (5 counters) during
  onboarding or later, to account for missed prayers before using the app.
- Going forward, a prayer not marked complete by the cutoff (start of the
  next prayer's window, or user-configured "day rollover" time for Isha)
  auto-increments that prayer's Qadha counter by 1.
- A dedicated Qadha screen lets the user decrement counters as they make up
  missed prayers (tap "−1" per prayer), independent of today's checklist.
- Qadha counters never go negative and are not included in streak
  calculations (streaks are about on-time completion; Qadha is a separate
  ledger).

**Reasoning:** Keeping Qadha as an explicit, user-adjustable counter (not an
automatically-inferred history reconstruction) matches how Qadha is actually
tracked mentally — as a running balance you pay down — and avoids the app
making theological assumptions about make-up ordering or timing rules.

**Affects:** FR-P-04, FR-P-05.

---

## D-09: Prayer — travel / timezone change

**Decision:** Prayer times recompute from device location + timezone
automatically on: app foreground, and a background refresh at local
midnight. If location permission is denied, the user sets a fixed city
manually in Settings and times are computed for that fixed location until
changed. A one-time in-app banner explains why location is requested
(accurate prayer times), shown before the OS permission prompt.

**Reasoning:** Automatic recompute handles the common case (flying, DST)
without user action; the manual-city fallback keeps the feature fully
functional (offline-appropriate) for users who deny location, which is
common and must not brick the module.

**Affects:** FR-P-06.

---

## D-10: Database engine — Isar vs. Drift

**Decision:** Follow the tech stack default (Isar) unless a later technical
blueprint run (02) supersedes it. Not re-litigated in this product-only run.

**Affects:** all data-model-adjacent FRs (noted for traceability only; schema
is out of scope for this document).
