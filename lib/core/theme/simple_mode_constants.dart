/// Sizing constants for the Simple Mode large-button layout
/// (`docs/superpowers/specs/07-accessibility/
/// 06-SIMPLE-MODE-LARGE-BUTTON-LAYOUT-IMPLEMENTATION-PLAN.md`), consumed
/// by each module's Simple Mode layout branch.
library;

import 'package:flutter/widgets.dart';

/// Minimum touch target size (WCAG 2.5.5).
const double simpleModeMinTouchTarget = 48;

/// Height of a Simple Mode primary action button.
const double simpleModeButtonHeight = 64;

/// Icon size used inside Simple Mode buttons.
const double simpleModeIconSize = 32;

/// Multiplier applied to the ambient text scale while Simple Mode is on.
const double simpleModeTextScaleMultiplier = 1.2;

/// Standard content padding for Simple Mode screens/cards.
const EdgeInsets simpleModePadding = EdgeInsets.all(24);
