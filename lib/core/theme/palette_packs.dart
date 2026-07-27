import 'package:flutter/material.dart';

/// Defines a theme color palette.
class PalettePack {
  final String id;
  final String displayNameKey;
  final Color seedColor;
  final bool isPremium;

  const PalettePack({
    required this.id,
    required this.displayNameKey,
    required this.seedColor,
    this.isPremium = false,
  });
}

/// The set of available theme palettes.
const palettePacks = [
  PalettePack(
    id: 'teal',
    displayNameKey: 'palettePackTeal',
    seedColor: Color(0xFF006874), // Original default
    isPremium: false,
  ),
  PalettePack(
    id: 'ocean',
    displayNameKey: 'palettePackOcean',
    seedColor: Color(0xFF1565C0),
    isPremium: true,
  ),
  PalettePack(
    id: 'sunset',
    displayNameKey: 'palettePackSunset',
    seedColor: Color(0xFFD84315),
    isPremium: true,
  ),
  PalettePack(
    id: 'lavender',
    displayNameKey: 'palettePackLavender',
    seedColor: Color(0xFF673AB7),
    isPremium: true,
  ),
  PalettePack(
    id: 'midnight',
    displayNameKey: 'palettePackMidnight',
    seedColor: Color(0xFF263238),
    isPremium: true,
  ),
];
