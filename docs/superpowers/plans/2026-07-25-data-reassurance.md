# "Your Data Never Left This Device" Reassurance — Implementation Plan

**Spec:** `docs/superpowers/specs/09-retention/08-data-never-left-device-reassurance-design.md`
**Date:** 2026-07-25
**Status:** Ready for implementation

---

## Architecture overview

This is a copy-only addition to an existing screen. No new tables, no new logic, no new routes.

```
┌──────────────────────────────────────────────────────────┐
│  Data settings screen (existing)                         │
│  → DataPrivacyReassuranceCard widget (new, permanent)    │
│  shield icon + 2-3 sentences about offline/local-only    │
│  placed below existing export/import/share actions       │
└──────────────────────────────────────────────────────────┘
```

---

## Implementation tasks

### T1: Add reassurance card widget to Data settings

**Files:**
- `lib/features/settings/presentation/widgets/data_privacy_reassurance_card.dart` — **new file**
- `lib/features/settings/presentation/screens/data_settings_screen.dart` — add widget at bottom of `ListView`

**Widget design:**
```dart
class DataPrivacyReassuranceCard extends StatelessWidget {
  const DataPrivacyReassuranceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: Theme.of(context).extension<AppSemanticColors>()?.success
          .withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield, color: /* success green */),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.dataPrivacyReassuranceTitle,
                    style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(l10n.dataPrivacyReassuranceBody),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Placement:** Append as the last child in the `DataSettingsScreen`'s `ListView.children`, after the existing export/import/share section.

**Tests:** Widget test — card renders, icon visible, text content present.

---

### T2: Audit near-duplicate privacy copy

**Files:**
- `lib/features/settings/presentation/screens/about_screen.dart` — check existing `aboutPrivacyPolicy` / `aboutPrivacyPolicyBody` strings
- `lib/core/l10n/app_en.arb` — audit existing privacy-related strings for overlap

**Action:**
1. Read existing `aboutPrivacyPolicyBody` content.
2. If it already states the offline promise, add a cross-reference: "See Settings > Data for more details about how your data is stored."
3. If it doesn't, leave it as-is (About screen covers legal/privacy policy, Data settings covers technical storage details).

**No code changes needed** — just a localization string update if overlap is found.

---

### T3: Localization

**Files:**
- `lib/core/l10n/app_en.arb` — ~3 new keys
- `lib/core/l10n/app_bn.arb` — Bangla translations

**Keys:**
- `dataPrivacyReassuranceTitle` — "Your data stays on this device"
- `dataPrivacyReassuranceBody` — "All your habits, logs, and history are stored locally on your device. Nothing is uploaded to the cloud, and no account is required."
- `dataPrivacyReassuranceBodyWithCaveat` — (if Medicine dose window caveat needed) "Your habit history is always saved. Short-term forecasts (like upcoming medicine doses) are regenerated as needed — these are not your history."

**Note:** The Medicine caveat is only needed if the Data settings screen discusses dose projections. For v1, keep it simple — the reassurance card covers the general offline/local-only promise.

---

## Task sequencing

```
T2 (audit) ──→ T1 (widget) ──→ T3 (i18n)
```

---

## Commit plan

| Commit | Tasks | Message |
|--------|-------|---------|
| 1 | T1 | `feat(settings): add data privacy reassurance card to Data settings` |
| 2 | T2 | `feat(i18n): audit and consolidate near-duplicate privacy copy` |
| 3 | T3 | `feat(i18n): add en/bn strings for data privacy reassurance` |
