# Decisions Log

Record of every open product AND technical decision, the options considered,
and the final call. Referenced from `functional-requirements.md` and from
`../technical/*.md` by ID. Single running log for the whole project — the
technical blueprint (run 02) appends here rather than starting a second file.

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

**Superseded by D-11.**

---

## D-11: Database engine — Isar vs. Drift vs. ObjectBox (final, technical blueprint)

**Decision: Drift.** Supersedes D-10.

**Reasoning (full comparison in `../technical/database-decision.md`):** live
pub.dev data checked 2026-07-17 shows the original `isar` package has not
released since 2023-04-25 (dead); the ecosystem moved to a community fork,
`isar_community`, which is active but smaller and less mature. `drift`
released 3 days before this check, holds a perfect pub score and Flutter
Favorite badge, and has ~1M monthly downloads — by far the healthiest of the
options. More decisively: Drift is SQL/SQLite, which (a) gives real
`GROUP BY`/date-range queries needed for streak and adherence stats without
hand-rolled Dart aggregation, and (b) transfers the developer's existing
Laravel/Eloquent SQL fluency directly, where Isar/ObjectBox would require
learning a new NoSQL query paradigm from scratch. Multi-isolate access
(required for notification-action callbacks writing to the DB from a
background isolate) is a first-class, well-documented Drift pattern
(`NativeDatabase.createInBackground`).

**Affects:** all of `database-design.md`, `data-models.md`, `erd.md`,
`state-management.md`, `folder-structure.md`; supersedes the `Isar*` line in
`00-project-context.md`'s tech stack per that document's own footnote.

---

## D-12: Row identifiers — UUID v4 vs. UUID v7

**Options:** A. UUID v4 (fully random). B. UUID v7 (time-ordered, random
suffix).

**Decision: B — UUID v7** for every table's primary key.

**Reasoning:** The product requirement ("stable UUIDs on every exportable
row — auto-increment IDs break import/merge") only requires stability and
non-collision, which either UUID version satisfies. UUID v7 additionally
sorts approximately chronologically, which keeps SQLite b-tree index
locality good for insert-heavy tables (`water_logs`, `medicine_doses`,
`prayer_records`) — a free performance property with no downside versus v4
for this app's access patterns. Generated client-side (no DB round-trip),
so it costs nothing architecturally.

**Affects:** `database-design.md`, `data-models.md`.

---

## D-13: Dose/prayer-record materialization — pre-generated rows vs. computed on the fly

**Options:** A. Compute due dates on the fly from the repeat-rule/schedule
whenever the UI or notification scheduler needs them. B. Materialize
concrete rows (`medicine_doses`, `prayer_records`) ahead of time for a
rolling window, topped up by a background/foreground refresh job.

**Decision: B**, rolling window of 30 days ahead, topped up on app foreground
and via a daily background refresh.

**Reasoning:** `flutter_local_notifications` (and the underlying OS alarm
APIs on both platforms) can only schedule a notification against a concrete
future `DateTime` + stable id — there is no OS mechanism to say "figure out
the next occurrence from this repeat rule at fire time." On-the-fly
computation works fine for read-only display (e.g. rendering "next dose in
3h" in the UI) but cannot by itself register the actual OS-level alarm that
FR-C-07/FR-M-07/FR-P-08 depend on. Materializing rows ahead of time is
therefore not optional convenience, it's the only way to hand the
notification plugin what it requires. A 30-day rolling window bounds
storage growth (NFR-04) while comfortably covering the app-foreground/daily
refresh cadence that tops it up, so the window never visibly runs out for a
user who opens the app at least monthly (and the daily background refresh
covers users who don't).

**Affects:** `database-design.md` (`medicine_doses`, `prayer_records`
schemas), `architecture.md` (background refresh job ownership).

---

## D-14: Schedule/prayer wall-clock times vs. the "store everything in UTC" rule

**Decision:** Two different kinds of time get two different storage rules,
both under the umbrella of "all *timestamps* are UTC":
- **Event instants** (when something happened or is concretely scheduled to
  fire: `logged_at`, `scheduled_for`, `status_changed_at`, `created_at`,
  `updated_at`, `deleted_at`) — stored as UTC, always.
- **Recurring wall-clock definitions** (a medicine schedule's "8:00 AM and
  8:00 PM," or a day's local calendar-date bucket) — stored as local
  time-of-day / local calendar date, not converted to UTC, because the
  *meaning* of "8am dose" is "8am wherever the user's phone currently is,"
  not a fixed UTC instant that would silently drift wall-clock meaning
  across a DST transition or timezone travel.

**Reasoning:** Storing schedule times as UTC instants would make "8:00 AM"
silently become "7:00 AM" or "9:00 AM" local time across a DST change or
travel, which is wrong — a prescription taken "at 8am" means 8am local,
always. The materialization job (D-13) resolves a schedule's local
time-of-day against the *current* device timezone at generation time to
produce the concrete UTC instant that actually gets stored on the generated
`medicine_doses`/`prayer_records` row and handed to the notification
scheduler. This keeps the UTC-storage rule intact for every concrete,
already-resolved instant, while not corrupting the recurring definition
itself.

**Affects:** `database-design.md`.

---

## D-15: PIN hash storage — app database vs. OS secure storage

**Options:** A. Store the salted PIN hash in `app_settings` alongside other
settings (as originally sketched in the first pass of `database-design.md`).
B. Store it in `flutter_secure_storage` (iOS Keychain / Android Keystore-
backed), separate from the SQLite database entirely.

**Decision: B.**

**Reasoning (full detail in `../strategies/security.md`):** the app's own
database is explicitly not encrypted in v1.0 (see that document's threat-
model section) — putting a credential hash in the one plaintext store this
app has, when an OS-provided encrypted store already exists and costs
nothing extra to use, is a needless downgrade. `app_settings` keeps only
`pin_enabled` and the lock timeout; the hash, its salt, and the lockout
failed-attempt counter live in `flutter_secure_storage` instead.

**Affects:** `database-design.md` (`app_settings` table), `security.md`.
