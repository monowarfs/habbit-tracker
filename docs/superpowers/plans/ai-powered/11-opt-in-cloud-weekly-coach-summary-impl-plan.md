# Opt-In Cloud Weekly Coach Summary — Implementation Plan

**Spec:** [11-opt-in-cloud-weekly-coach-summary-design.md](./11-opt-in-cloud-weekly-coach-summary-design.md)
**Run:** TBD
**Estimated effort:** L
**Dependencies:** Reports module (`AggregateReportUseCase`), Settings module (`AppSettings` entity + repository), all six consent checklist items (C1-C6) cleared before any network-calling code ships.

## Pre-requisites

- **All six consent checklist items (C1-C6) must be complete:**
  - C1: Affirmative opt-in toggle + consent flow UI (Engineering)
  - C2: Play Console Data Safety + App Store Privacy updates (Product/Legal)
  - C3: Health-data sensitivity review for aggregated figures (Legal/Privacy)
  - C4: LLM vendor selection + data-retention terms (Product/Eng)
  - C5: Durable off-switch (instant stop on toggle-off) (Engineering)
  - C6: Deletion path for vendor-retained data (Product/Legal)
- Reports module fully functional with `AggregateReportUseCase` producing week/month summaries.
- Settings module functional with `AppSettings` entity and `SettingsRepositoryImpl`.
- LLM API vendor selected, API key available, data-retention terms documented.
- `http` package added to `pubspec.yaml`.

## Tasks

### Task 1 (C1): Consent flow UI + `coachOptIn` schema + entity
**Effort:** M
**Files to create:**
- `lib/core/coach/presentation/screens/coach_consent_dialog.dart`

**Files to modify:**
- `lib/core/database/app_database.dart` — schema version 8, add migration
- `lib/core/database/tables/app_settings_table.dart` — add `coachOptIn` column
- `lib/features/settings/domain/entities/app_settings.dart` — add `coachOptIn` field
- `lib/features/settings/data/repositories/settings_repository_impl.dart` — read/write `coachOptIn`
- `lib/features/settings/presentation/screens/settings_screen.dart` — add coach toggle section

**Description:** Add `coachOptIn` boolean column (default `false`) to `app_settings_table.dart`. Update `AppSettings` Freezed entity with `coachOptIn` field. Update `SettingsRepositoryImpl` to read/write the field. Bump schema version to 8 with a migration that adds the column. Build the consent dialog listing: what data is sent, where it goes, instant revocation, vendor deletion available. Add a `SwitchListTile` section in Settings visible only when the consent gate is cleared.

**Acceptance criteria:**
- Schema version is 8; migration adds `coach_opt_in` column with default `false`.
- `AppSettings.coachOptIn` exists and defaults to `false`.
- Settings screen shows "Weekly Coach Summary" toggle (off by default).
- Toggling on shows the consent dialog; user must tap "I understand and agree" to proceed.
- Toggling off immediately stops all network activity.

**Test:** `test/features/settings/domain/entities/app_settings_test.dart` — add `coachOptIn` to existing test matrix.

---

### Task 2: `CoachConsentPayload` + `ModuleStats` entities
**Effort:** S
**Files to create:**
- `lib/core/coach/domain/entities/coach_consent_payload.dart`

**Files to modify:** (none)

**Description:** Create `CoachConsentPayload` Freezed entity with `weekLabel` (String) and `modules` (List of `ModuleStats`). Create `ModuleStats` Freezed entity with `moduleId`, `displayName`, `daysWithActivity`, `totalDaysInWeek`, `longestStreak`, `totalValue`, `dailyAverage`. These represent the coarse, aggregated data sent to the LLM — no per-entry data, no names, no specific dates.

**Acceptance criteria:**
- Both entities compile with generated `.freezed.dart`.
- `CoachConsentPayload` serializes to JSON (for LLM prompt construction).
- `ModuleStats` fields are all numeric/string — no sensitive data types.

**Test:** `test/core/coach/domain/entities/coach_consent_payload_test.dart` — Freezed construction, equality, JSON serialization.

---

### Task 3: `CoachSummary` entity
**Effort:** S
**Files to create:**
- `lib/core/coach/domain/entities/coach_summary.dart`

**Files to modify:** (none)

**Description:** Create `CoachSummary` Freezed entity with `weekStart`, `weekEnd`, `generatedText`, `generatedAt`, and `status` (a `CoachSummaryStatus` enum: `generated`, `failed`, `pending`). This is ephemeral — not persisted to the database.

**Acceptance criteria:**
- Entity compiles with generated `.freezed.dart`.
- `CoachSummaryStatus` has all three values.
- `generatedText` is empty string when status is `failed`.

**Test:** Freezed entity construction, equality, copyWith.

---

### Task 4: `buildCoachPrompt` pure function + unit tests
**Effort:** S
**Files to create:**
- `lib/core/coach/domain/usecases/build_coach_prompt.dart`

**Files to modify:** (none)

**Description:** Pure function that takes a `CoachConsentPayload` and returns a string prompt for the LLM. The system prompt instructs the model to be a supportive habit coach, write a 3–5 sentence weekly recap, be encouraging but honest, and not fabricate data. The user message is the JSON-serialized payload.

**Acceptance criteria:**
- Function is pure — no I/O, no dependencies beyond the payload entity.
- System prompt is embedded in the function.
- Handles edge cases: empty modules list, single module, all-zero stats.

**Test:** `test/core/coach/domain/usecases/build_coach_prompt_test.dart` — verify prompt construction with various payload shapes, edge cases.

---

### Task 5: `CoachApiService` interface + `CoachApiServiceImpl` (HTTP) + tests
**Effort:** M
**Files to create:**
- `lib/core/coach/domain/services/coach_api_service.dart`
- `lib/core/coach/data/services/coach_api_service_impl.dart`
- `lib/core/coach/data/coach_http_client_provider.dart`

**Files to modify:** (none)

**Description:** Create the abstract `CoachApiService` interface with `generateRecap(CoachConsentPayload)` method. Implement `CoachApiServiceImpl` using `http.Client`: POST to the LLM vendor's API endpoint with the system prompt + payload JSON, 30-second timeout, parse response. Handle HTTP non-200, timeout, JSON parse errors — all throw `CoachApiException` which the use case catches. Create a Riverpod provider for the `http.Client` instance and API key (from secure storage or config).

**Acceptance criteria:**
- `CoachApiService` is abstract — can be swapped for different vendors or mocks.
- `CoachApiServiceImpl` sends correct request shape (system prompt + user payload).
- 30-second timeout enforced.
- Non-200 responses throw `CoachApiException`.
- API key is not hardcoded — read from secure storage or config.
- `http` package is the sole network dependency.

**Test:** `test/core/coach/data/services/coach_api_service_impl_test.dart` — mock HTTP client, verify request shape, response parsing, timeout handling, non-200 handling.

---

### Task 6: `GenerateWeeklyCoachSummaryUseCase` + tests
**Effort:** M
**Files to create:**
- `lib/core/coach/domain/usecases/generate_weekly_coach_summary.dart`

**Files to modify:** (none)

**Description:** Implement the use case that orchestrates: (1) build `CoachConsentPayload` from `ModuleReport` list, (2) build prompt via `buildCoachPrompt`, (3) call `CoachApiService.generateRecap`, (4) return `CoachSummary` with status `generated` or `failed`. On any exception, return `CoachSummary` with status `failed` — never throws.

**Acceptance criteria:**
- `execute()` never throws — always returns a `CoachSummary`.
- On API success: returns `CoachSummaryStatus.generated` with text.
- On API failure/timeout: returns `CoachSummaryStatus.failed` with empty text.
- Payload is built from `ModuleReport` list with coarse aggregates only.

**Test:** `test/core/coach/domain/usecases/generate_weekly_coach_summary_test.dart` — mock `CoachApiService`, verify `CoachSummary` construction, verify failed status on API error.

---

### Task 7: `coach_providers.dart` (opt-in gate + summary provider)
**Effort:** S
**Files to create:**
- `lib/core/coach/presentation/providers/coach_providers.dart`

**Files to modify:** (none)

**Description:** Create `coachOptedInProvider` (reads `appSettingsProvider.coachOptIn`, defaults to `false`). Create `weeklyCoachSummaryProvider` that: checks opt-in first (returns `null` if not opted in), computes current week range, reads aggregated reports via `AggregateReportUseCase`, calls `GenerateWeeklyCoachSummaryUseCase`, returns `CoachSummary?`. Toggle-off mid-generation discards in-flight result.

**Acceptance criteria:**
- `coachOptedInProvider` returns `false` by default.
- `weeklyCoachSummaryProvider` returns `null` when not opted in.
- When opted in, triggers aggregation + LLM call.
- Toggle-off immediately stops further calls (provider re-evaluates on next watch).

**Test:** `test/core/coach/presentation/providers/coach_providers_test.dart` — opted-in/off gates summary generation, failed status produces null/empty.

---

### Task 8: `CoachSummaryCard` + `CoachSummaryLoadingCard` widgets
**Effort:** S
**Files to create:**
- `lib/core/coach/presentation/widgets/coach_summary_card.dart`
- `lib/core/coach/presentation/widgets/coach_summary_loading_card.dart`

**Files to modify:** (none)

**Description:** `CoachSummaryCard` renders: "Your Weekly Recap" header with "AI-generated" badge, the `generatedText` in a readable `Text` widget, generated timestamp in small text. When status is `failed`, shows "Summary unavailable this week" in muted text (not an error state). `CoachSummaryLoadingCard` is a shimmer/skeleton placeholder while the LLM API call is in flight.

**Acceptance criteria:**
- Card renders text when summary is generated.
- Card shows muted message when summary failed.
- Card is hidden (returns `SizedBox.shrink()`) when summary is null.
- Loading card shows skeleton/shimmer.

**Test:** `test/core/coach/presentation/widgets/coach_summary_card_test.dart` — renders text when generated, shows muted message when failed, hidden when null.

---

### Task 9: Integrate into `ReportsScreen`
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/reports/presentation/screens/reports_screen.dart`

**Description:** Add a coach summary card at the top of the `ListView` (before module report cards), visible only when opted in and summary is available. Use `coachSummaryAsync.when()` to handle loading/data/error states. The card renders conditionally based on `coachOptedInProvider`.

**Acceptance criteria:**
- Summary card appears at top of Reports screen when opted in.
- Loading state shows shimmer card.
- Error/no-summary state shows nothing (silent degradation).
- No card rendered when not opted in.

**Test:** Manual device verification — toggle opt-in, verify card appears on Reports screen.

---

### Task 10: Localization keys (en + bn)
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**Description:** Add all new localization keys for the coach feature in both English and Bangla.

**Acceptance criteria:**
- All keys present in both ARB files.
- `flutter gen-l10n` succeeds without errors.

**Test:** `flutter gen-l10n` compiles cleanly; verify keys in `AppLocalizations`.

---

### Task 11: Integration tests + manual network-failure verification
**Effort:** M
**Files to create:** (none)
**Files to modify:** (none)

**Description:** Run all unit/widget tests from prior tasks. Manual verification: toggle opt-in on, verify consent dialog appears, confirm consent, navigate to Reports screen, verify summary card loads (or shows muted failure if offline). Toggle off, verify no network calls. Test with airplane mode to verify silent degradation.

**Acceptance criteria:**
- All prior test files pass.
- End-to-end opt-in → consent → summary flow works on device.
- Airplane mode produces silent "summary unavailable" (no error dialog).
- Toggle-off mid-generation stops activity.

**Test:** Run `flutter test` for all new test files; manual device verification checklist.

## Schema Migration

```sql
-- Migration: schemaVersion 8 (from 7)
ALTER TABLE app_settings ADD COLUMN coach_opt_in INTEGER NOT NULL DEFAULT 0;
```

In `app_database.dart`:
```dart
@override
int get schemaVersion => 8;

@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from < 8) {
      await m.addColumn(appSettingsTable, appSettingsTable.coachOptIn);
    }
  },
);
```

## Localization Keys

| Key | English | Bangla |
|-----|---------|--------|
| `coachOptInTitle` | Weekly Coach Summary | সাপ্তাহিক কোচ সারসংক্ষেপ |
| `coachOptInSubtitle` | Get an AI-generated weekly recap of your habits | আপনার অভ্যাসের AI-জেনারেটেড সাপ্তাহিক সারসংক্ষেপ পান |
| `coachConsentDialogTitle` | About Weekly Coach | সাপ্তাহিক কোচ সম্পর্কে |
| `coachConsentDialogContent` | (multi-line — explains data flow, vendor, deletion) | (multi-line — ডেটা প্রবাহ, বিক্রেতা, মুছে ফেলার বিবরণ) |
| `coachConsentAgree` | I understand and agree | আমি বুঝেছি এবং সম্মত |
| `coachConsentDecline` | Not now | এখন নয় |
| `coachReviewConsent` | Review consent | সম্মতি পর্যালোচনা করুন |
| `coachSummaryTitle` | Your Weekly Recap | আপনার সাপ্তাহিক সারসংক্ষেপ |
| `coachSummaryFailed` | Summary unavailable this week | এই সপ্তাহে সারসংক্ষেপ পাওয়া যায়নি |
| `coachSummaryGenerating` | Generating your recap... | আপনার সারসংক্ষেপ তৈরি হচ্ছে... |
| `coachSummaryDisclaimer` | AI-generated summary based on your aggregated data | আপনার সমষ্টিগত ডেটার উপর ভিত্তি করে AI-জেনারেটেড সারসংক্ষেপ |

## Risk Notes

1. **Consent gate is a hard blocker** — no network-calling code may ship until all six C1-C6 items are marked complete. This includes store listing updates and legal review, which are non-engineering work.
2. **Data minimization boundary** — the `CoachConsentPayload` must contain only coarse aggregates (counts, rates, streaks). No medicine names, no specific prayer times, no individual entry timestamps. This boundary is a legal/privacy requirement, not an engineering choice.
3. **Vendor lock-in** — the `CoachApiService` interface abstracts the vendor, but the system prompt and response parsing are vendor-specific. Keep vendor logic isolated in `CoachApiServiceImpl` for future swaps.
4. **Cost accounting** — LLM API usage cost per user per week has no billing infrastructure in the app today. This must be addressed before production deployment.
5. **Silent degradation is intentional** — network failures produce no error UI. The Reports screen simply doesn't show the summary card. This is by design, not a bug.
6. **Instant revocation** — toggle-off must immediately stop all network activity. In-flight requests are abandoned, not awaited. The provider re-evaluates on next watch cycle.
7. **`core/coach/` isolation** — this is the ONLY module that imports an HTTP client. No other core or feature module should have a network dependency. Enforce this architecturally.
