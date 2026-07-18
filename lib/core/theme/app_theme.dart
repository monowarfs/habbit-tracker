import 'package:flutter/material.dart';

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

  /// Light theme, seeded from [_seedColor].
  static ThemeData light({required bool isBangla}) => _build(
    brightness: Brightness.light,
    semanticColors: AppSemanticColors.light,
    isBangla: isBangla,
  );

  /// Dark theme, seeded from [_seedColor].
  static ThemeData dark({required bool isBangla}) => _build(
    brightness: Brightness.dark,
    semanticColors: AppSemanticColors.dark,
    isBangla: isBangla,
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppSemanticColors semanticColors,
    required bool isBangla,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
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
