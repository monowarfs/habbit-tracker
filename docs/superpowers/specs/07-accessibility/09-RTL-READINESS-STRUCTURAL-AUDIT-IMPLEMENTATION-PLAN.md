# Implementation Plan: 09 RTL-Readiness Structural Audit

## Overview

- **Spec:** RTL-Readiness Structural Audit
- **Complexity:** S
- **Estimated effort:** 0.5 day
- **Dependencies:** Standalone. Should run before spec 06 (Simple Mode adds new layouts).
- **Prerequisites:** No new locale or translation work needed — purely a structural code audit.

---

## Implementation Tasks

### Task 1: Force app into pseudo-RTL locale for testing

**Files to create/modify:**
- None (testing setup only)

**Detailed changes:**
- In test harness or debug build, set `locale: Locale('ar')` in `MaterialApp` to force RTL layout mirroring.
- No real Arabic translation needed — the layout mirroring is what's being tested.
- Alternatively, use Flutter's `Directionality(textDirection: TextDirection.rtl, child: ...)` wrapper for per-widget RTL testing.

**Integration:** Uses Flutter's built-in RTL testing support.

### Task 2: Audit all screens for hardcoded directions

**Files to create/modify:**
- Grep `lib/` for: `left`, `right`, `Alignment.centerLeft`, `Alignment.centerRight`, `EdgeInsets.only(left:`, `EdgeInsets.only(right:`, `EdgeInsets.fromLTRB(`

**Detailed changes:**
- Search the entire `lib/` directory for hardcoded directional properties.
- For each finding, determine if it should be replaced with a directional-agnostic equivalent:
  - `left` → `start`
  - `right` → `end`
  - `Alignment.centerLeft` → `Alignment.centerStart`
  - `Alignment.centerRight` → `Alignment.centerEnd`
  - `EdgeInsets.only(left: x)` → `EdgeInsetsDirectional.only(start: x)`
  - `EdgeInsets.fromLTRB(l, t, r, b)` → `EdgeInsetsDirectional.only(start: l, end: r) + EdgeInsets.only(top: t, bottom: b)`
- Exceptions: some `left`/`right` usages are correct (e.g. a literal left-side indicator that shouldn't mirror).

**Integration:** One-line property swaps in each affected file.

### Task 3: Fix identified hardcoded directions

**Files to create/modify:**
- Per audit findings (typical files: screen layouts, custom widgets)

**Detailed changes:**
- Apply the directional-agnostic replacements identified in Task 2.
- Common locations to check:
  - `Padding` with `left`/`right` in `EdgeInsets.only()`.
  - `Align` or `Positioned` with `Alignment.centerLeft`/`centerRight`.
  - Custom `Row`/`Stack` layouts with hardcoded `Positioned(left: ...)`.
  - `ListTile` leading/trailing — these already use `start`/`end` by default.

**Integration:** Each fix is a one-line property change.

### Task 4: Check icons for unwanted mirroring

**Files to create/modify:**
- Per audit findings

**Detailed changes:**
- Icons that should NOT mirror in RTL: play buttons, checkmarks, arrows pointing in a meaningful direction.
- For these, either:
  - Use `Directionality(textDirection: TextDirection.ltr, child: Icon(...))` to force LTR rendering.
  - Or add a separate RTL variant icon if the icon meaning is direction-dependent.
- Icons that SHOULD mirror: navigation arrows (back/forward), chevrons, progress indicators with directional meaning.

**Integration:** Per-icon fixes wrapped in `Directionality` widget.

### Task 5: Verify fl_chart RTL behavior

**Files to create/modify:**
- `lib/core/widgets/charts/period_bar_chart.dart` (verify, likely no changes)

**Detailed changes:**
- `fl_chart` handles RTL internally — verify that the chart renders correctly when the app is in RTL mode.
- Check that bar chart x-axis labels don't get misaligned or reversed.
- If issues are found, they may need to be reported upstream to `fl_chart` rather than worked around.

**Integration:** Verification only — `fl_chart` is a third-party library.

### Task 6: Verify Prayer module direction-sensitive content

**Files to create/modify:**
- `lib/features/prayer/presentation/` screens (verify)

**Detailed changes:**
- Check if any Prayer module screen has direction-sensitive content (e.g. Qibla-related iconography, directional indicators).
- If found, apply appropriate `Directionality` overrides or RTL-aware layouts.

**Integration:** Verification and per-finding fixes.

### Task 7: Document findings

**Files to create/modify:**
- `docs/superpowers/specs/07-accessibility/09-rtl-audit-results.md` (new)

**Detailed changes:**
- Record all hardcoded-direction findings and their fixes.
- Note any icons that need special RTL handling.
- Note any `fl_chart` RTL issues.

**Integration:** Repository artifact for traceability.

---

## Performance Considerations

- **Caching strategy:** N/A — layout property changes are static.
- **Lazy loading:** N/A.
- **Memory efficiency:** No impact — property swaps only.

---

## Testing

- Widget tests verifying key screens render correctly under RTL `Directionality` widget.
- CI check that runs key widget tests with RTL directionality enabled.
- Manual audit walking every screen under pseudo-RTL locale.

---

## Localization

No new ARB keys needed — the audit verifies existing layout code uses directional-agnostic properties.

---

## Edge Cases

1. **Pseudo-RTL testing** — force RTL via `locale: Locale('ar')` in `MaterialApp`.
2. **Icons that shouldn't mirror** — play buttons, checkmarks, directional arrows need `Directionality` override.
3. **fl_chart RTL** — the chart library handles RTL internally; verify but don't modify its internals.
4. **New layouts from spec 06** — Simple Mode layouts must also be RTL-checked.
