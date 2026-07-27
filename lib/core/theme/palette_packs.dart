import 'package:flutter/material.dart';

/// Defines a theme color palette.
class PalettePack {
  /// Creates a palette pack definition.
  const PalettePack({
    required this.id,
    required this.displayNameKey,
    required this.seedColor,
    this.isPremium = false,
    this.moduleAccents,
  });

  /// Stable identifier stored in settings.
  final String id;

  /// l10n key for the pack's display name.
  final String displayNameKey;

  /// The `ColorScheme.fromSeed` seed color for this palette.
  final Color seedColor;

  /// Whether selecting this palette requires premium.
  final bool isPremium;

  /// Optional per-module accent color overrides, keyed by module id.
  final Map<String, Color>? moduleAccents;
}

/// The set of available theme palettes.
const palettePacks = [
  PalettePack(
    id: 'teal',
    displayNameKey: 'palettePackTeal',
    seedColor: Color(0xFF006874), // Original default
  ),
  PalettePack(
    id: 'ocean',
    displayNameKey: 'palettePackOcean',
    seedColor: Color(0xFF1565C0),
    isPremium: true,
    moduleAccents: {
      'water': Color(0xFF0D47A1),
      'medicine': Color(0xFF311B92),
      'prayer': Color(0xFF006064),
    },
  ),
  PalettePack(
    id: 'sunset',
    displayNameKey: 'palettePackSunset',
    seedColor: Color(0xFFD84315),
    isPremium: true,
    moduleAccents: {
      'water': Color(0xFFBF360C),
      'medicine': Color(0xFF4E342E),
      'prayer': Color(0xFFE65100),
    },
  ),
  PalettePack(
    id: 'lavender',
    displayNameKey: 'palettePackLavender',
    seedColor: Color(0xFF673AB7),
    isPremium: true,
    moduleAccents: {
      'water': Color(0xFF4527A0),
      'medicine': Color(0xFF283593),
      'prayer': Color(0xFF6A1B9A),
    },
  ),
  PalettePack(
    id: 'midnight',
    displayNameKey: 'palettePackMidnight',
    seedColor: Color(0xFF263238),
    isPremium: true,
    moduleAccents: {
      'water': Color(0xFF212121),
      'medicine': Color(0xFF000000),
      'prayer': Color(0xFF37474F),
    },
  ),
];
