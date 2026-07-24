import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/seasonal_occasion.dart';

/// The app-wide Material 3 seed color (teal), per `strategies/theme.md`.
///
/// Deliberately neutral/health-brand rather than a literal "water blue" so
/// it doesn't visually pre-empt the Water module's own accent color.
const Color _seedColor = Color(0xFF006874);

/// Per-module accent colors (`strategies/theme.md`), used only for a
/// module's icon/dashboard tile/nav highlight — never as `ColorScheme` roles.
class ModuleAccents {
  const ModuleAccents._();

  /// Water module accent.
  static const Color water = Color(0xFF1565C0);

  /// Medicine module accent.
  static const Color medicine = Color(0xFF5E35B1);

  /// Prayer module accent.
  static const Color prayer = Color(0xFFB8860B);
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
  static const poholaBoishakh = SeasonalAccent(
    occasion: SeasonalOccasion.poholaBoishakh,
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

  /// Light theme, seeded from [_seedColor] unless [seasonalSeed]
  /// overrides it (a curated seasonal accent, `core/theme/
  /// seasonal_accent_provider.dart` — `null` when no occasion is active
  /// or the user opted out).
  static ThemeData light({required bool isBangla, Color? seasonalSeed}) =>
      _build(
        brightness: Brightness.light,
        semanticColors: AppSemanticColors.light,
        isBangla: isBangla,
        seedColor: seasonalSeed ?? _seedColor,
      );

  /// Dark theme, seeded from [_seedColor] unless [seasonalSeed] overrides
  /// it.
  static ThemeData dark({required bool isBangla, Color? seasonalSeed}) =>
      _build(
        brightness: Brightness.dark,
        semanticColors: AppSemanticColors.dark,
        isBangla: isBangla,
        seedColor: seasonalSeed ?? _seedColor,
      );

  static ThemeData _build({
    required Brightness brightness,
    required AppSemanticColors semanticColors,
    required bool isBangla,
    required Color seedColor,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme(isBangla: isBangla),
      extensions: [semanticColors],
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
