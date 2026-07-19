# 12 — IMPLEMENTATION: SETTINGS, PIN LOCK, EXPORT/IMPORT

**Inputs:** `00-project-context.md`, `docs/strategies/security.md`,
`docs/strategies/backup-import-export.md`

## Scope

1. **Settings tab (final form)**: sections for appearance (theme), language,
   notifications (global toggles, per-module links, troubleshooting screen
   with full OEM battery-killer guidance from the strategy doc), security,
   data, about (version, licenses via LicenseRegistry, privacy policy text)
2. **PIN lock**: setup/change/disable flows; salted-hash storage per security
   doc; lock on app launch and on resume after a configurable timeout;
   GoRouter redirect integration (the seam left in run 05); failed-attempt
   backoff; optional biometric unlock (local_auth) layered over PIN;
   "forgot PIN" behaves exactly as decided in the security doc
3. **JSON export**: versioned envelope per strategy doc, each module
   contributing via its contract handler; share/save via the platform share
   sheet; human-readable pretty-print option
4. **JSON import**: file picker → schema validation with clear error
   messages → summary preview (counts per module) → explicit
   replace-with-confirmation → progress → success report. A failed import
   must leave existing data untouched (import into a transaction / staging
   and swap — per DB capability).
5. **Share logs** UI hooked to run 06's ring buffer (with redaction)
6. Localize everything (en + bn)

## Definition of Done
- Round-trip test (automated): seed data in all modules → export → wipe →
  import → assert equality (this test doubles as the module-contract
  export/import compliance check)
- Import rejects: malformed JSON, wrong schemaVersion, truncated file —
  each with a helpful message, data untouched
- PIN tests: hash never stores plaintext, backoff timing, resume-timeout
  behavior; manual biometric check on real device
- Analyze clean, tests pass, commit:
  `feat(settings): settings, pin lock, export/import`
