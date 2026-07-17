# Security

## PIN lock — hashing, storage, and lockout

**Algorithm: PBKDF2-HMAC-SHA256**, via `pointycastle` (verified active on
pub.dev 2026-07-17: v4.0.0, published 2025-02-19, `bouncycastle.org`
publisher, 2.68M downloads/30 days — a foundational, widely-depended-on
Dart crypto library). **Explicitly not Argon2** via `dargon2_flutter` —
checked and rejected: that package's latest release is from 2023-06-18,
over 3 years stale, and Argon2's extra resistance to GPU-parallelized
attacks is a marginal benefit here specifically, since the actual defense
against a 4-digit PIN's inherently small keyspace (10,000 possibilities) is
the lockout backoff below, not the hash algorithm's cost factor. PBKDF2
with a high iteration count (≥ 100,000, tuned against the reference device
class in `non-functional-requirements.md` so verification stays under
~100ms) is more than sufficient for a secret whose real protection is
rate-limiting, not hash-cracking resistance.

**Where the salt and hash live: `flutter_secure_storage`, not the app
database.** Verified active on pub.dev 2026-07-17: v10.3.1, published
2026-05-27, 3.23M downloads/30 days. This wraps iOS Keychain and Android
Keystore-backed `EncryptedSharedPreferences` — both OS-level encrypted
stores, independent of whether the app's own SQLite file is encrypted (see
the DB-encryption honesty section below). **This supersedes
`database-design.md`'s original `app_settings.pin_hash TEXT` column** — a
sensitive credential hash has no reason to sit in the same plaintext
SQLite file as habit-tracking data; it's cheap to keep it in the
OS-provided secure store instead, and the two systems are already both in
play (Drift for data, `flutter_secure_storage` for this one secret). Logged
as **D-15** in `../product/decisions.md`; `database-design.md`'s
`app_settings` table description is corrected to drop that column and note
the relocation.

**Lockout backoff** (client-side only — there is no server to rate-limit
against, so this is enforced by a failed-attempt counter + last-attempt
timestamp, itself stored in `flutter_secure_storage` alongside the
hash/salt):

| Consecutive failed attempts | Delay before next attempt is accepted |
|---|---|
| 1-3 | none (immediate retry, just an error shake) |
| 4 | 5 seconds |
| 5 | 30 seconds |
| 6+ | doubles each additional attempt, capped at 5 minutes |

**Honest limit, stated plainly:** because this is a purely local,
account-free app, this backoff is enforced by app code the user's own
device runs — it is not a substitute for server-side rate-limiting and
cannot be, since there is no server. A determined attacker with the
patience to wait through backoff delays, or who uninstalls/reinstalls the
app to reset the counter (which also wipes all data per the Forgot-PIN
policy below), is not fully stopped by this mechanism. This is an accepted
trade-off for a 4-digit convenience PIN protecting habit-tracking data, not
a claim of bank-grade security — the PIN's job is to stop a casual
someone-picked-up-my-phone look, which it does well, not to resist a
targeted attack.

## Biometric unlock — optional convenience layer over PIN, never a replacement

`local_auth` (verified active: v3.0.2, published 2026-07-09 — 8 days before
this document — `flutter.dev` publisher, 1.14M downloads/30 days, perfect
pub score). Biometric unlock is strictly additive: **a PIN must already be
set** before biometric unlock can be offered as an option, and `local_auth`'s
`authenticate()` call is a pure OS-level yes/no gate — no secret material
(PIN, hash, salt) passes through it or is derived from it. A successful
biometric check is treated exactly like a correct PIN entry (unlocks the
app, resets the failed-attempt counter); a failed or unavailable biometric
check falls back to the normal PIN entry screen, never to a degraded/no-
lock state.

## Screen privacy — `FLAG_SECURE` (Android) and app-switcher hiding (iOS)

**Default: off, opt-in from Settings, only offered when PIN lock is also
enabled** (a user who hasn't opted into PIN lock at all is unlikely to want
the stricter screenshot/recording block, and this avoids surprising a
caregiver persona like Farida who might reasonably want to screenshot her
father's adherence stats to share with his doctor).

- **Android:** `FLAG_SECURE` on the main activity's window — blocks
  screenshots, screen recording, and replaces the app's thumbnail in the
  recent-apps switcher with a blank/branded placeholder.
- **iOS:** no direct `FLAG_SECURE` equivalent exists. Standard technique:
  show a blurred/branded overlay when the app resigns active
  (`applicationWillResignActive`), removed on `applicationDidBecomeActive`
  — this hides sensitive content from the OS's app-switcher snapshot,
  which is the iOS analogue of the Android recent-apps thumbnail leak this
  feature is meant to prevent. iOS has no equivalent to blocking
  screenshots/screen-recording outright at the OS level for third-party
  apps, and that gap is not something this app can close — noted here as
  an honest platform asymmetry, not an oversight.

## Threat model honesty: the local database is not encrypted in v1

**Stated plainly:** the Drift/SQLite database file is stored as plain,
unencrypted data in the app's private storage sandbox. On a device with
physical access, root/jailbreak, or a filesystem-level backup extraction
(e.g. `adb backup` on an unlocked, debuggable device), habit-tracking data
— medicine names, dosages, prayer records — is readable directly from the
database file. This is an accepted v1.0 trade-off, not an oversight:
encrypting the full database (via SQLCipher) adds real, ongoing complexity
— key management, a harder migration story (schema changes now interact
with an encryption layer), and measurable query performance overhead — for
a threat model whose realistic exploitation already requires the device
itself to be compromised at a level (root, physical unlocked access) far
beyond what this app's own encryption could meaningfully defend against on
its own. The one exception already carved out is the PIN hash/salt above,
which costs nothing extra to keep in the OS-provided secure store instead
of the database.

**Future option, explicitly not committed:** DB-level encryption via
`sqlcipher_flutter_libs` (the SQLCipher build used alongside `sqlite3`/
Drift). **Checked on pub.dev 2026-07-17: its most recent release,
`0.7.0+eol`, is tagged `eol`** — an ambiguous signal (it may indicate this
specific packaging approach is being wound down in favor of a different
encrypted-SQLite integration within the same ecosystem, rather than that
encrypted SQLite for Drift is abandoned outright). Per this run's "verify,
don't guess" rule: this is reported as-is, not resolved further here — if
DB encryption is ever prioritized (a natural v1.1+ candidate alongside
`../product/roadmap.md`'s backup/sync candidates, since an encrypted local
DB also matters more once a backup file might leave the device), the
current recommended encrypted-SQLite path for Drift should be re-verified
at that time rather than committing to a specific package today against a
release tagged in a way this document can't fully interpret.

## Forgot PIN — full data reset, not a soft recovery

Reiterating and giving technical shape to the product decision already
made in `../product/functional-requirements.md` FR-C-04: recovering from a
forgotten PIN means a **full local data reset** — deleting/recreating the
Drift database file and clearing the `flutter_secure_storage` PIN entry —
not a "soft" recovery flow (security questions, email reset link, etc.).
**Justification, restated at the technical level:** there is no account
and no backend, so there is no independent identity to verify a "forgot
PIN" request against — any soft-recovery mechanism this app could build
(a security question, a recovery code shown once at setup) is either
theater (doesn't actually verify anything beyond "did you write this down
somewhere") or itself a second secret the user must protect exactly as
carefully as the PIN, at which point it hasn't reduced risk, only added a
second forgettable thing. A full, clearly-explained reset is the more
honest option, and per FR-C-04, the user is warned about this trade-off
up front, at PIN-enable time, not discovered as a surprise at the moment
they actually forget it.
