# Opt-In Cloud "Weekly Coach" Summary

**Category:** AI-Powered · **Atlas complexity:** L · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Fitbit/Whoop-style AI-written weekly recaps ("here's how your week went,
in plain language") are a proven engagement pattern — a short, readable
narrative summary is more digestible and more likely to be read than a
chart. This app's Reports module already computes the structured data
such a summary would draw from (streak records, adherence rates,
week-over-week comparisons), so the gap is purely the "write it in plain
language" step, which is genuinely better done by an LLM than by
hand-authored templated copy for every possible data shape. **This is
the one deliberately-cloud item in this category** — everything else in
this atlas section is scoped to on-device heuristics specifically
because this app's entire trust story is offline-first and
account-free. This feature is the single exception, and it must be
built as an isolated, clearly-bounded opt-in layer, not a precedent that
quietly normalizes future network calls elsewhere in the app.

## Goals
- Offer users who explicitly opt in a short, LLM-generated plain-language
  weekly recap summarizing their own already-locally-computed stats
  (streaks, adherence, notable changes week-over-week).
- Keep the feature fully inert (no network calls, no data leaves the
  device) for every user who has not explicitly opted in — which should
  be the overwhelming majority given the app's positioning.
- Treat every item in the consent checklist below as a hard, sequential
  prerequisite gate — not a parallel workstream, not a footnote, not
  something to revisit "after" the feature ships.

## Non-goals / out of scope
- Not a general-purpose chat/assistant feature — a single, scheduled,
  bounded weekly summary generation, not open-ended conversation.
- Not a default-on or opt-out feature under any circumstances — off by
  default, and staying off is the only acceptable state absent explicit,
  affirmative user action.
- Does not send raw per-entry data (specific medicine names, dosages,
  specific prayer times, specific dates) off-device if it can be avoided
  — the goal is to send the same kind of coarse, aggregated figures the
  existing `AnalyticsEvent` design already treats as the redaction
  boundary (counts, rates, streak lengths), not granular health records.
  The exact data-minimization boundary is itself part of the health-data
  sensitivity review below, not a decision to make casually in code.
- Not scoped to build in this pass at all unless/until the consent
  checklist gate is explicitly cleared by a product/legal decision — this
  spec documents the shape of the feature so it isn't designed from
  scratch under time pressure later, not a green light to start building.

## Proposed approach (high-level)
**This is the sole feature in this atlas category that leaves the
device.** Where every other item in "AI-Powered" is on-device arithmetic
or a rule-based parser, this one calls a real LLM API over the network,
and that difference has to be architecturally visible, not buried: the
network call, the request/response payload shape, and the opt-in gate
should live in a clearly separate, clearly named module (distinct from
`core/notifications`, `core/achievements`, and `core/reports`, though it
reads from Reports' aggregated output as its input), so it's easy for
any future contributor to see at a glance which single feature in the
whole app talks to the network and why. The Reports module's existing
`aggregate_report_usecase` output (week/month summaries, streak records)
is the only data source — no new per-entry data collection is
introduced for this feature. That aggregated payload is sent to an LLM
API, which returns a short plain-language recap displayed to the user
(e.g. on the Reports screen or dashboard, clearly labeled as
AI-generated and requiring an active opt-in toggle in Settings to be
visible at all). Network reachability failures degrade silently to "no
summary this week" — never a jarring error state — since this is a
nice-to-have narrative layer on top of data the user can already see in
structured form regardless.

## The consent checklist gate (from `docs/strategies/analytics-future.md`)
This feature must clear every one of the six prerequisites
`analytics-future.md` lays out for *any* feature sending data off-device,
before a single line of network-calling code ships — restated here in
full because this spec is exactly the situation that checklist exists
for:

1. **Affirmative, off-by-default opt-in** — a separate, explicit consent
   action, not a pre-checked toggle or an implied consent from enabling
   a module. The app's current "no data collected" promise is a real
   commitment to existing users; this feature cannot retroactively break
   it for anyone who hasn't explicitly opted in.
2. **Store listing updates** — both Play Console's Data Safety form and
   App Store Connect's App Privacy details currently state no data is
   collected; both must be updated accurately before this ships, as a
   compliance requirement, not a courtesy.
3. **Health-data sensitivity review** — even aggregated adherence/streak
   figures are an inference about a user's health situation (medicine
   adherence, prayer consistency), which several jurisdictions'
   regulations treat as sensitive/special-category data. "It's just
   aggregated numbers, not names" is not sufficient justification on its
   own to skip this review.
4. **A vendor decision made deliberately** — which LLM API provider,
   under what data-retention/training-use terms, and whether region-
   hosted or self-hosted alternatives were genuinely evaluated rather
   than defaulting to whichever SDK is most convenient.
5. **A durable off switch** — a visible, working Settings toggle that
   turns this back off at any time, with an immediate effective stop to
   further network calls — a one-time consent that can't be revoked
   isn't real consent.
6. **A deletion story** — if a user who opted in later requests deletion
   of any data the LLM vendor might have retained (prompts, logs), there
   must be an actual path to reach that data, independent of this app's
   own on-device soft-delete mechanism, which only ever governed data
   that stayed on-device.

None of these six are negotiable or reorderable — clearing five and
treating the sixth as a fast-follow is the exact failure mode this
checklist exists to prevent.

## Dependencies & prerequisites
- All six consent-checklist items above, cleared as a genuine
  product/legal decision before implementation begins.
- The Reports module's aggregated output as the sole data source.
- An LLM API vendor selection and integration (network client, API key
  management, error/timeout handling).
- Network reachability handling that fails silently/gracefully, given
  the rest of the app has no expectation of connectivity.
- Settings UI for the opt-in toggle and its durable off switch.

## Open questions for the implementation round
- Which LLM vendor, and under what data-retention/training-opt-out
  contractual terms — this is a decision requiring input beyond
  engineering alone.
- What exact aggregated fields are safe to send given the health-data
  sensitivity review's findings — the data-minimization boundary needs
  to be explicit and reviewed, not inferred from "seems coarse enough."
- Does the recap generation happen client-side calling the LLM API
  directly, or via a thin backend proxy this app doesn't otherwise have
  — the latter is a bigger architectural addition (this app currently
  has zero backend) worth weighing against direct-from-client calls.
- What does the UI look like for a user who opts in but has no network
  connectivity that week, or whose API call fails/times out — the
  silent-degradation approach above needs concrete UX.
- How is cost (LLM API usage cost per user per week) accounted for,
  given this app has no account/subscription/payment layer today?

## Effort & sequencing notes
Complexity L, and that's before counting the non-engineering effort
(legal review, store listing updates, vendor evaluation) the checklist
above requires — the consent-gate work alone likely dwarfs the
engineering effort of the summary feature itself. This should be
sequenced last among all "AI-Powered" items, and only taken up at all
once the product/legal decision to clear the checklist has actually been
made — not scheduled as ordinary engineering backlog work in the
meantime.

---

## Implementation Plan (Low-Level)

### Consent checklist gate — prerequisite tasks

Every task below is a hard prerequisite before any network-calling code
ships. These are tracked as separate tasks, not footnotes.

| # | Consent item | Owner | Blocking? |
|---|---|---|---|
| C1 | Affirmative opt-in toggle + consent flow UI | Engineering | Yes — code gate |
| C2 | Play Console Data Safety + App Store Privacy update | Product/Legal | Yes — store gate |
| C3 | Health-data sensitivity review (aggregated figures) | Legal/Privacy | Yes — legal gate |
| C4 | LLM vendor selection + data-retention terms | Product/Eng | Yes — vendor gate |
| C5 | Durable off-switch (instant stop on toggle-off) | Engineering | Yes — code gate |
| C6 | Deletion path for vendor-retained data | Product/Legal | Yes — legal gate |

**None of the implementation tasks below may be merged to main until
all six C1-C6 items are marked complete in the spec's tracking.**

### Schema changes

No new Drift tables. Coach summaries are ephemeral — generated on-demand,
cached in memory during the session, not persisted to the database. If
optional offline caching is desired later, a `coach_summaries` table
can be added then, but v1 has no persistence.

A new column on `AppSettingsTable` stores the opt-in state:

```sql
-- Migration: schemaVersion 8
ALTER TABLE app_settings ADD COLUMN coach_opt_in INTEGER NOT NULL DEFAULT 0;
```

**Modify:** `lib/core/database/app_database.dart`

```dart
@override
int get schemaVersion => 8;  // was 7

// In migration:
if (from < 8) {
  await m.addColumn(appSettingsTable, appSettingsTable.coachOptIn);
}
```

**Modify:** `lib/core/database/tables/app_settings_table.dart`

```dart
BoolColumn get coachOptIn => boolean().withDefault(const Constant(false))();
```

### Domain entities

**New file:** `lib/core/coach/domain/entities/coach_summary.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'coach_summary.freezed.dart';

/// Status of a coach summary generation attempt.
enum CoachSummaryStatus {
  /// Successfully generated.
  generated,

  /// Network failure or API error — silent degradation.
  failed,

  /// Opted in but generation not yet attempted this week.
  pending,
}

/// An LLM-generated weekly recap. Ephemeral — not persisted to DB.
@freezed
sealed class CoachSummary with _$CoachSummary {
  const factory CoachSummary({
    required DateTime weekStart,
    required DateTime weekEnd,
    required String generatedText,
    required DateTime generatedAt,
    required CoachSummaryStatus status,
  }) = _CoachSummary;
}
```

**New file:** `lib/core/coach/domain/entities/coach_consent_payload.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'coach_consent_payload.freezed.dart';

/// The aggregated stats payload sent to the LLM. Deliberately coarse —
/// counts, rates, streak lengths only. No per-entry data, no names,
/// no dates beyond the week range.
@freezed
sealed class CoachConsentPayload with _$CoachConsentPayload {
  const factory CoachConsentPayload({
    required String weekLabel,       // e.g. "Jul 14 – Jul 20, 2026"
    required List<ModuleStats> modules,
  }) = _CoachConsentPayload;
}

/// One module's aggregated stats for the week.
@freezed
sealed class ModuleStats with _$ModuleStats {
  const factory ModuleStats({
    required String moduleId,
    required String displayName,
    required int daysWithActivity,
    required int totalDaysInWeek,
    required int longestStreak,
    required num totalValue,         // ml logged, doses taken, prayers done
    required num dailyAverage,
  }) = _ModuleStats;
}
```

**Modify:** `lib/features/settings/domain/entities/app_settings.dart`

Add `coachOptIn` field:

```dart
const factory AppSettings({
  // ... existing fields ...
  required bool coachOptIn,  // NEW — off by default, consent-gated
}) = _AppSettings;
```

### Use case signatures

**New file:** `lib/core/coach/domain/usecases/generate_weekly_coach_summary.dart`

```dart
import 'package:habit_tracker/core/coach/domain/entities/coach_consent_payload.dart';
import 'package:habit_tracker/core/coach/domain/entities/coach_summary.dart';
import 'package:habit_tracker/core/coach/domain/services/coach_api_service.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';

/// Generates a weekly coach summary from aggregated stats.
/// The sole data source is [AggregateReportUseCase] output — no new
/// per-entry data collection.
class GenerateWeeklyCoachSummaryUseCase {
  const GenerateWeeklyCoachSummaryUseCase(this._apiService);

  final CoachApiService _apiService;

  /// Builds a [CoachConsentPayload] from [moduleReports], sends it to
  /// the LLM API, and returns a [CoachSummary].
  ///
  /// On network failure, returns a [CoachSummary] with
  /// [CoachSummaryStatus.failed] — never throws.
  Future<CoachSummary> execute({
    required List<ModuleReport> moduleReports,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    final payload = _buildPayload(moduleReports, weekStart, weekEnd);
    try {
      final text = await _apiService.generateRecap(payload);
      return CoachSummary(
        weekStart: weekStart,
        weekEnd: weekEnd,
        generatedText: text,
        generatedAt: DateTime.now(),
        status: CoachSummaryStatus.generated,
      );
    } on Object catch (_) {
      return CoachSummary(
        weekStart: weekStart,
        weekEnd: weekEnd,
        generatedText: '',
        generatedAt: DateTime.now(),
        status: CoachSummaryStatus.failed,
      );
    }
  }

  CoachConsentPayload _buildPayload(
    List<ModuleReport> reports,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    // Map ModuleReport → ModuleStats (coarse aggregation only)
    // ...
  }
}
```

**New file:** `lib/core/coach/domain/usecases/build_coach_prompt.dart`

```dart
import 'package:habit_tracker/core/coach/domain/entities/coach_consent_payload.dart';

/// Pure function that builds the LLM prompt from the aggregated payload.
/// Separated for unit testing prompt construction without API calls.
String buildCoachPrompt(CoachConsentPayload payload) {
  // System prompt: "You are a supportive habit coach. Write a brief
  // weekly recap based on the user's aggregated habit data. Be
  // encouraging but honest. 3-5 sentences max. Do not fabricate data."
  // User message: JSON of payload
  // ...
}
```

### API service interface

**New file:** `lib/core/coach/domain/services/coach_api_service.dart`

```dart
import 'package:habit_tracker/core/coach/domain/entities/coach_consent_payload.dart';

/// Interface for the LLM API call. Abstracted so the implementation
/// can be swapped (different vendor, mock for tests).
abstract class CoachApiService {
  /// Sends [payload] to the LLM and returns the generated text.
  /// Must timeout within 30 seconds and never throw — callers handle
  /// the degraded case.
  Future<String> generateRecap(CoachConsentPayload payload);
}
```

**New file:** `lib/core/coach/data/services/coach_api_service_impl.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:habit_tracker/core/coach/domain/entities/coach_consent_payload.dart';
import 'package:habit_tracker/core/coach/domain/services/coach_api_service.dart';

/// HTTP implementation of [CoachApiService]. Vendor-specific — the API
/// key, endpoint, and request shape are configured here.
class CoachApiServiceImpl implements CoachApiService {
  CoachApiServiceImpl({required this.httpClient, required this.apiKey});

  final http.Client httpClient;
  final String apiKey;

  @override
  Future<String> generateRecap(CoachConsentPayload payload) async {
    final response = await httpClient
        .post(
          Uri.parse('https://api.example.com/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': 'gpt-4o-mini', // or chosen model
            'messages': [
              {'role': 'system', 'content': _systemPrompt},
              {'role': 'user', 'content': jsonEncode(payload.toJson())},
            ],
            'max_tokens': 300,
            'temperature': 0.7,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw CoachApiException(response.statusCode, response.body);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['choices'][0]['message']['content'] as String;
  }

  static const _systemPrompt = '''
You are a supportive habit coach. Write a brief weekly recap based on
the user's aggregated habit data. Be encouraging but honest. Keep it
to 3-5 sentences. Do not fabricate specific numbers — only reference
the data provided. Use a warm, motivating tone.
''';
}
```

### Network client setup

**New file:** `lib/core/coach/data/coach_http_client_provider.dart`

Riverpod provider that creates a `http.Client` instance, scoped to the
coach module. The API key is read from a secure storage location
(not hardcoded) — `flutter_secure_storage` or environment-configured.

```dart
@Riverpod(keepAlive: true)
http.Client coachHttpClient(Ref ref) {
  return http.Client();
}

@Riverpod(keepAlive: true)
String coachApiKey(Ref ref) {
  // Read from secure storage or config
  // This must be non-empty for the feature to work
}
```

### Opt-in gate

**New file:** `lib/core/coach/presentation/providers/coach_providers.dart`

```dart
@riverpod
bool coachOptedIn(Ref ref) {
  return ref.watch(appSettingsProvider).value?.coachOptIn ?? false;
}

@riverpod
Future<CoachSummary?> weeklyCoachSummary(Ref ref) async {
  final optedIn = ref.watch(coachOptedInProvider);
  if (!optedIn) return null;

  // Compute current week range
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 6));

  // Get aggregated reports (sole data source)
  final modules = ref.read(habitModulesProvider);
  final reports = await AggregateReportUseCase().execute(
    modules: modules,
    period: ReportPeriod.week,
    periodAnchor: localDayKey(now),
  );

  // Generate summary via LLM
  final useCase = ref.read(generateWeeklyCoachSummaryProvider);
  return useCase.execute(
    moduleReports: reports,
    weekStart: weekStart,
    weekEnd: weekEnd,
  );
}
```

**Modify:** `lib/features/settings/presentation/screens/settings_screen.dart`

Add a "Weekly Coach" section below existing settings, visible only when
the consent checklist gate is cleared:

```dart
// Coach opt-in section
if (consentGateCleared) ...[
  SwitchListTile(
    title: Text(l10n.coachOptInTitle),
    subtitle: Text(l10n.coachOptInSubtitle),
    value: settings.coachOptIn,
    onChanged: (value) => controller.updateCoachOptIn(value),
  ),
  if (settings.coachOptIn)
    TextButton(
      onPressed: () => _showConsentDialog(context),
      child: Text(l10n.coachReviewConsent),
    ),
],
```

**New file:** `lib/core/coach/presentation/screens/coach_consent_dialog.dart`

Full consent dialog shown when user first opts in, listing:
- What data is sent (aggregated stats only, no per-entry data)
- Where it goes (LLM API provider, name disclosed)
- That it can be turned off instantly
- That vendor deletion is available on request
- Requires explicit "I understand and agree" tap

**Modify:** `lib/core/l10n/app_en.arb` and `lib/core/l10n/app_bn.arb`

Keys:
- `coachOptInTitle` — "Weekly Coach Summary"
- `coachOptInSubtitle` — "Get an AI-generated weekly recap of your habits"
- `coachConsentDialogTitle` — "About Weekly Coach"
- `coachConsentDialogContent` — (multi-line, explains data flow)
- `coachConsentAgree` — "I understand and agree"
- `coachConsentDecline` — "Not now"
- `coachReviewConsent` — "Review consent"
- `coachSummaryTitle` — "Your Weekly Recap"
- `coachSummaryFailed` — "Summary unavailable this week"
- `coachSummaryGenerating` — "Generating your recap..."
- `coachSummaryDisclaimer` — "AI-generated summary based on your aggregated data"

### Error handling

- Network timeout: 30s hard limit. On timeout → `CoachSummaryStatus.failed`
- HTTP non-200: → `CoachSummaryStatus.failed`
- JSON parse error: → `CoachSummaryStatus.failed`
- No network at all: http client throws `SocketException` → caught → `failed`
- All failures degrade silently: the Reports screen simply doesn't show
  the summary card when status is `failed`. No error snackbar, no dialog.
- Toggle-off mid-generation: in-flight request is cancelled via
  `CancelableOperation` or simply ignored (response arrives, provider
  reads `coachOptIn == false`, discards result).

### Presentation layer

**Modify:** `lib/features/reports/presentation/screens/reports_screen.dart`

Add a coach summary card at the top of the `ListView` (before module
report cards), visible only when opted in and summary is available:

```dart
// In the ListView children:
if (coachOptedIn) ...[
  coachSummaryAsync.when(
    data: (summary) => summary != null
      ? CoachSummaryCard(summary: summary)
      : const SizedBox.shrink(),
    loading: () => const CoachSummaryLoadingCard(),
    error: (_, __) => const SizedBox.shrink(),
  ),
  const SizedBox(height: 16),
],
```

**New file:** `lib/core/coach/presentation/widgets/coach_summary_card.dart`

Card widget displaying:
- "Your Weekly Recap" header with a small "AI-generated" badge
- The `generatedText` in a readable `Text` widget
- Generated timestamp in small text
- If status is `failed`: shows "Summary unavailable this week" in
  muted text, not an error state

**New file:** `lib/core/coach/presentation/widgets/coach_summary_loading_card.dart`

Shimmer/skeleton placeholder shown while the LLM API call is in flight.

### Data flow diagram

```
User toggles opt-in (Settings)
  → AppSettings.coachOptIn = true
  → Consent dialog shown → user confirms

Reports screen loads (weekly view)
  → coachOptedInProvider reads true
  → weeklyCoachSummaryProvider triggers:
    1. AggregateReportUseCase.execute() — reads from existing modules
    2. CoachConsentPayload built (coarse stats only)
    3. CoachApiService.generateRecap(payload) — HTTP POST to LLM
    4. CoachSummary returned (generated or failed)
  → CoachSummaryCard renders (or nothing on failure)
```

### Testing strategy

| Test file | What it covers |
|---|---|
| `test/core/coach/domain/usecases/build_coach_prompt_test.dart` | Unit: prompt construction from various payload shapes, edge cases (empty modules, single module). Pure, no mocks. |
| `test/core/coach/domain/usecases/generate_weekly_coach_summary_test.dart` | Unit: mock `CoachApiService`, verify `CoachSummary` construction, verify failed-status on API error. |
| `test/core/coach/domain/entities/coach_consent_payload_test.dart` | Freezed entity construction, equality. |
| `test/core/coach/data/services/coach_api_service_impl_test.dart` | Integration: mock HTTP client, verify request shape, response parsing, timeout handling, non-200 handling. |
| `test/core/coach/presentation/providers/coach_providers_test.dart` | Provider tests: opted-in/off gates summary generation, failed status produces null/empty. |
| `test/core/coach/presentation/widgets/coach_summary_card_test.dart` | Widget: renders text when generated, shows muted message when failed, hidden when null. |
| `test/features/settings/domain/entities/app_settings_test.dart` | Add `coachOptIn` field to existing test matrix. |

### File paths

**Files to create:**
- `lib/core/coach/domain/entities/coach_summary.dart`
- `lib/core/coach/domain/entities/coach_consent_payload.dart`
- `lib/core/coach/domain/services/coach_api_service.dart`
- `lib/core/coach/domain/usecases/generate_weekly_coach_summary.dart`
- `lib/core/coach/domain/usecases/build_coach_prompt.dart`
- `lib/core/coach/data/services/coach_api_service_impl.dart`
- `lib/core/coach/data/coach_http_client_provider.dart`
- `lib/core/coach/presentation/providers/coach_providers.dart`
- `lib/core/coach/presentation/screens/coach_consent_dialog.dart`
- `lib/core/coach/presentation/widgets/coach_summary_card.dart`
- `lib/core/coach/presentation/widgets/coach_summary_loading_card.dart`

**Files to modify:**
- `lib/core/database/app_database.dart` — schema version 8, add `coachOptIn` column
- `lib/core/database/tables/app_settings_table.dart` — add `coachOptIn` column
- `lib/features/settings/domain/entities/app_settings.dart` — add `coachOptIn` field
- `lib/features/settings/data/repositories/settings_repository_impl.dart` — read/write `coachOptIn`
- `lib/features/settings/presentation/screens/settings_screen.dart` — add coach toggle section
- `lib/features/reports/presentation/screens/reports_screen.dart` — add summary card
- `lib/core/l10n/app_en.arb` — add coach localization keys
- `lib/core/l10n/app_bn.arb` — add coach localization keys
- `pubspec.yaml` — add `http` package dependency

### Sequencing

| # | Task | Depends on | Effort |
|---|---|---|---|
| C1 | Consent flow UI (toggle + dialog) + `coachOptIn` schema/entity | — | M |
| C2-C6 | Non-engineering consent items (store listings, legal, vendor, deletion) | — | L (non-eng) |
| T1 | `CoachConsentPayload` + `ModuleStats` entities | — | S |
| T2 | `CoachSummary` entity | — | S |
| T3 | `buildCoachPrompt` pure function + unit tests | T1 | S |
| T4 | `CoachApiService` interface + `CoachApiServiceImpl` (HTTP) + tests | T1 | M |
| T5 | `GenerateWeeklyCoachSummaryUseCase` + tests | T2, T3, T4 | M |
| T6 | `coach_providers.dart` (opt-in gate + summary provider) | T5, C1 | S |
| T7 | `CoachSummaryCard` + `CoachSummaryLoadingCard` widgets | T2 | S |
| T8 | Integrate into `ReportsScreen` + consent dialog | T6, T7, C1 | S |
| T9 | Localization keys (en + bn) | — | S |
| T10 | Integration tests + manual network-failure verification | T8, T9 | M |

**Total estimated effort:** L (matching atlas complexity) — the dominant
cost is the non-engineering consent gate (C2-C6) and the HTTP API
integration (T4). The engineering itself is moderate once the gate is
cleared. The `core/coach/` module is intentionally isolated from all
other core modules — it reads from Reports' output but has zero write
dependencies on any other module.

### Key architectural invariants

1. **Isolation:** `core/coach/` is the ONLY module that imports an HTTP
   client. No other core or feature module has a network dependency.
2. **Off by default:** `coachOptIn` defaults to `false`. The entire
   `core/coach/` module is inert when the toggle is off — no providers
   trigger, no network calls happen.
3. **Data minimization:** The `CoachConsentPayload` contains only coarse
   aggregates (counts, rates, streaks). No medicine names, no specific
   prayer times, no individual entry timestamps.
4. **Silent degradation:** Every failure path returns
   `CoachSummaryStatus.failed` — the UI simply doesn't render the card.
   No error states, no retry prompts, no snackbar.
5. **Instant revocation:** Toggling the switch off immediately stops
   all network activity. In-flight requests are abandoned, not awaited.
