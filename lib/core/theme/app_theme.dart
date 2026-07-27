import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/seasonal_occasion.dart';

/// The app-wide Material 3 seed color (teal), per `strategies/theme.md`.
///
/// Deliberately neutral/health-brand rather than a literal "water blue" so
/// it doesn't visually pre-empt the Water module's own accent color.
const Color _seedColor = Color(0xFF006874);

/// Per-module accent colors (`strategies/theme.md`), used only for a
/// module's icon/dashboard tile/nav highlight — never as `ColorScheme` roles.
/// Per-module accent colors.
@immutable
class ModuleThemeAccents extends ThemeExtension<ModuleThemeAccents> {
  /// Creates a set of per-module accent colors.
  const ModuleThemeAccents({
    required this.water,
    required this.medicine,
    required this.prayer,
  });

  /// The Water module's accent color.
  final Color water;

  /// The Medicine module's accent color.
  final Color medicine;

  /// The Prayer module's accent color.
  final Color prayer;

  /// Default accents.
  static const ModuleThemeAccents defaults = ModuleThemeAccents(
    water: Color(0xFF1565C0),
    medicine: Color(0xFF5E35B1),
    prayer: Color(0xFFB8860B),
  );

  @override
  ModuleThemeAccents copyWith({Color? water, Color? medicine, Color? prayer}) {
    return ModuleThemeAccents(
      water: water ?? this.water,
      medicine: medicine ?? this.medicine,
      prayer: prayer ?? this.prayer,
    );
  }

  @override
  ModuleThemeAccents lerp(ThemeExtension<ModuleThemeAccents>? other, double t) {
    if (other is! ModuleThemeAccents) return this;
    return ModuleThemeAccents(
      water: Color.lerp(water, other.water, t) ?? water,
      medicine: Color.lerp(medicine, other.medicine, t) ?? medicine,
      prayer: Color.lerp(prayer, other.prayer, t) ?? prayer,
    );
  }
}

/// A curated seasonal occasion this app acknowledges cosmetically
/// (`core/theme/seasonal_occasion.dart`) — a substitute `ColorScheme`
/// seed, applied only when Settings' opt-out isn't set and today falls
/// in the active window.
class SeasonalAccent {
  /// Creates a seasonal accent pairing an [occasion] with its
  /// [seedColor].
  const SeasonalAccent({required this.occasion, required this.seedColor});

  /// The occasion this accent represents.
  final SeasonalOccasion occasion;

  /// The substitute `ColorScheme.fromSeed` seed color for this occasion.
  final Color seedColor;

  /// Pohela Boishakh — traditional red-and-white motif.
  static const pohelaBoishakh = SeasonalAccent(
    occasion: SeasonalOccasion.pohelaBoishakh,
    seedColor: Color(0xFFC62828),
  );

  /// Both Eid occasions share one accent (traditional Eid green) — a
  /// curated design decision, not a per-Eid distinction. Unreachable
  /// today: `activeSeasonalOccasion` never returns
  /// [SeasonalOccasion.eid] until a Hijri date source exists
  /// (`core/theme/seasonal_occasion.dart`).
  static const eid = SeasonalAccent(
    occasion: SeasonalOccasion.eid,
    seedColor: Color(0xFF2E7D32),
  );
}

/// App-specific semantic colors beyond the standard M3 `ColorScheme` roles.
///
/// M3 has no built-in "success" role; every module needs one consistent
/// "done/on-time" green, so it's added via Flutter's own `ThemeExtension`
/// mechanism rather than overloading an existing role.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  /// Creates a set of app-specific semantic colors.
  const AppSemanticColors({required this.success});

  /// "Done" / "Prayed" / "on-time" state color, shared across all modules.
  final Color success;

  /// Semantic colors tuned for the light theme.
  static const AppSemanticColors light = AppSemanticColors(
    success: Color(0xFF2E7D32),
  );

  /// Semantic colors tuned for the dark theme.
  static const AppSemanticColors dark = AppSemanticColors(
    success: Color(0xFF81C784),
  );

  @override
  AppSemanticColors copyWith({Color? success}) {
    return AppSemanticColors(success: success ?? this.success);
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t) ?? success,
    );
  }
}

/// Builds the light/dark [ThemeData] pair used by `MaterialApp.theme`/
/// `.darkTheme`, plus the locale-aware text theme adjustment.
class AppTheme {
  const AppTheme._();

  /// Light theme, seeded from [_seedColor] unless [seasonalSeed] or
  /// [paletteSeed] overrides it.
  static ThemeData light({
    required bool isBangla,
    Color? seasonalSeed,
    Color? paletteSeed,
    ModuleThemeAccents? moduleAccents,
  }) => _build(
    brightness: Brightness.light,
    semanticColors: AppSemanticColors.light,
    isBangla: isBangla,
    seedColor: seasonalSeed ?? paletteSeed ?? _seedColor,
    moduleAccents: moduleAccents ?? ModuleThemeAccents.defaults,
  );

  /// Dark theme.
  static ThemeData dark({
    required bool isBangla,
    Color? seasonalSeed,
    Color? paletteSeed,
    ModuleThemeAccents? moduleAccents,
  }) => _build(
    brightness: Brightness.dark,
    semanticColors: AppSemanticColors.dark,
    isBangla: isBangla,
    seedColor: seasonalSeed ?? paletteSeed ?? _seedColor,
    moduleAccents: moduleAccents ?? ModuleThemeAccents.defaults,
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppSemanticColors semanticColors,
    required bool isBangla,
    required Color seedColor,
    required ModuleThemeAccents moduleAccents,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme(isBangla: isBangla),
      extensions: [semanticColors, moduleAccents],
    );
  }

  /// Bangla script reads cramped at Latin-tuned line-heights (taller
  /// ascenders/descenders, stacking conjuncts) — apply a taller line-height
  /// multiplier once here rather than per-widget (`strategies/theme.md`).
  static TextTheme _textTheme({required bool isBangla}) {
    if (!isBangla) return Typography.material2021().black;
    const heightMultiplier = 1.45;
    return Typography.material2021().black.apply(
      heightFactor: heightMultiplier,
    );
  }
}

/// Helper extension to access module accents from the theme.
extension ModuleAccentsTheme on ThemeData {
  /// The app's per-module accent colors.
  ModuleThemeAccents get moduleAccents => extension<ModuleThemeAccents>()!;
}
