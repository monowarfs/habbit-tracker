# Offline Strategy

## Single source of truth = local DB

Every screen reads from and writes to the local Drift database
(`database-design.md`). There is no cache-vs-server-truth distinction to
reason about, because there is no server — this is what makes "100% offline,
no feature degrades without a network" (`prd.md` Constraints) trivially true
by construction rather than something to special-case per feature.

## Future-sync readiness now, cheaply

Two columns on every table, decided once and applied uniformly
(`database-design.md`'s global rules):

- **`updated_at`** (UTC epoch millis, bumped on every write).
- **`deleted_at`** (UTC epoch millis, null = not deleted). No row is ever
  `DELETE`d by application code — deletion is `UPDATE ... SET deleted_at = ?`,
  and all normal queries filter `WHERE deleted_at IS NULL`.

**Why this is the minimum viable groundwork for later sync, and why it
costs almost nothing today:**

- A future sync engine's core job is answering "what changed since I last
  synced, on either side, so I can reconcile it." Without `updated_at`,
  that question is unanswerable without a separate change-log
  infrastructure built after the fact, against years of existing data that
  was never stamped. Adding the column later means backfilling a value that
  was never true ("when did this actually last change?") — adding it now
  means the column is simply always correct.
- Hard deletes are the specific thing that breaks a future two-device
  sync: if device A deletes a row and device B never sees a "this was
  deleted" signal, B either resurrects it on next sync or the two devices
  silently diverge forever. `deleted_at` is a tombstone — the cheapest
  possible signal that survives a sync round-trip.
- **Cost today:** one extra nullable integer column per table, one `WHERE
  deleted_at IS NULL` clause added to queries (Drift's generated query
  builder makes this a one-line default filter, not per-query boilerplate),
  and application code calling "soft delete" instead of "delete" — a
  smaller diff than the hard-delete version, not a larger one.

## What is explicitly NOT built yet

Per `00-project-context.md` ("design for it, do not build it") and
`prd.md`'s Non-Goals:

- **No sync queue.** No table tracking "operations pending upload," no
  outbox pattern, no retry/backoff logic for a remote endpoint that doesn't
  exist yet.
- **No conflict resolution.** No last-write-wins logic, no vector clocks,
  no merge UI. `updated_at`/`deleted_at` are the raw material a future
  conflict-resolution strategy would need — they are not themselves a
  conflict-resolution strategy, and building one now against zero real
  multi-device usage would be solving a problem this app doesn't have yet.
- **No remote endpoint, no auth, no Google Drive API integration.** These
  are `roadmap.md` v1.1+ candidates (local export/import first, then Drive
  backup, then real sync) — sequenced deliberately so each step is built
  against evidence the previous step was used, not speculatively bundled
  into v1.0.

## Local export/import (the one adjacent, near-term consumer of this groundwork)

Not a committed v1.0 feature (`feature-breakdown.md` lists it as deferred),
but worth noting here because it's the first thing that reads
`updated_at`/`deleted_at`: an export is "dump every table's rows, including
soft-deleted ones, as JSON" (per `data-models.md`'s export shapes); an
import is "upsert every row by its stable UUID, preferring the row with the
later `updated_at`." That entire feature is describable in one sentence
specifically because the groundwork above already exists — which is the
concrete payoff of paying this small cost now.
