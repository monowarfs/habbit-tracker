import 'package:drift/drift.dart';

/// The singleton app-settings row (`database-design.md`) — app code always
/// upserts the fixed id `'singleton'`; Drift has no native
/// "exactly one row" constraint short of a trigger, which is unjustified
/// complexity for an app-code-enforced invariant.
@DataClassName('AppSettingsRow')
class AppSettingsTable extends Table {
  @override
  String get tableName => 'app_settings';

  /// Always `'singleton'`.
  TextColumn get id => text()();

  /// `'en'` | `'bn'`.
  TextColumn get locale => text()();

  /// `'system'` | `'light'` | `'dark'`.
  TextColumn get themeMode => text()();

  /// `'ml'` | `'fl_oz'` (D-01).
  TextColumn get waterUnit => text()();

  /// PIN lock enabled (D-15) — the hash itself lives in
  /// `flutter_secure_storage`, never in this table.
  BoolColumn get pinEnabled => boolean().withDefault(const Constant(false))();

  /// 0 = immediate.
  IntColumn get pinLockTimeoutSeconds =>
      integer().withDefault(const Constant(0))();

  /// Whether biometric unlock is offered on `/lock`, when the device
  /// supports it (D-15/`strategies/security.md`) — default `true`
  /// because that's the pre-existing always-on behavior this column
  /// makes visible and opt-out-able, not a new default.
  BoolColumn get biometricEnabled =>
      boolean().withDefault(const Constant(true))();

  /// `FLAG_SECURE` (Android) / app-switcher blur (iOS) toggle
  /// (`strategies/security.md`) — default `false`, opt-in.
  BoolColumn get screenPrivacyEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Whether the in-app dose-done completion chime is played
  /// (`docs/superpowers/specs/02-delightful/
  /// 10-optional-sound-design-pass-design.md`) — default `false`, opt-in.
  BoolColumn get soundEnabled => boolean().withDefault(const Constant(false))();

  /// Manual override: `true`/`false` pins Ramadan mode; `null` (default)
  /// means "follow `isRamadan(today)` automatically"
  /// (`docs/superpowers/specs/02-delightful/01-ramadan-mode-design.md`).
  BoolColumn get ramadanModeManualOverride => boolean().nullable()();

  /// Whether Ramadan-mode auto-detection is enabled at all. Default
  /// `true`; a user who turns it off never sees the mode unless they
  /// also pin [ramadanModeManualOverride].
  BoolColumn get ramadanAutoDetectEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Whether reminder times auto-shift based on historical `done`-action
  /// response offsets (`docs/superpowers/plans/ai-powered/
  /// 01-adaptive-reminder-timing-impl-plan.md`) — default `false`, opt-in.
  BoolColumn get adaptiveReminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Whether quiet-hours notification suppression is active.
  BoolColumn get quietHoursEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Quiet-hours window start, `"HH:mm"` wall-clock format.
  TextColumn get quietHoursStart =>
      text().withDefault(const Constant('22:00'))();

  /// Quiet-hours window end, `"HH:mm"` wall-clock format.
  TextColumn get quietHoursEnd => text().withDefault(const Constant('07:00'))();

  /// UTC epoch millis; null = onboarding not yet completed.
  IntColumn get onboardingCompletedAt => integer().nullable()();

  /// The app version the user last saw the changelog for; null means
  /// the feature hasn't recorded a version yet (fresh install or
  /// upgrade from a pre-changelog build).
  TextColumn get lastSeenAppVersion => text().nullable()();

  /// Optional user-set display name for the dashboard greeting; null =
  /// no name set, greeting degrades to a name-less form
  /// (`docs/superpowers/specs/02-delightful/
  /// 11-personalized-dashboard-greeting-design.md`).
  TextColumn get displayName => text().nullable()();

  /// Opt-out for the seasonal palette shift (Pohela Boishakh; Eid is not
  /// yet detectable, `core/theme/seasonal_occasion.dart`) — default
  /// `true` (opt-in by default, matching the feature's own "festive but
  /// tasteful" framing), flip off for users who never want the app's
  /// look to change (`docs/superpowers/specs/02-delightful/
  /// 12-seasonal-theme-accents-design.md`).
  BoolColumn get seasonalAccentsEnabled =>
      boolean().withDefault(const Constant(true))();

  /// UTC epoch millis; null = the Water hydration-science "why this
  /// matters" card hasn't been shown yet (`docs/superpowers/specs/
  /// 02-delightful/06-why-this-matters-micro-education-cards-design.md`).
  IntColumn get waterHydrationHintSeenAt => integer().nullable()();

  /// UTC epoch millis; null = the Prayer Qadha-context "why this
  /// matters" card hasn't been shown yet.
  IntColumn get prayerQadhaHintSeenAt => integer().nullable()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
