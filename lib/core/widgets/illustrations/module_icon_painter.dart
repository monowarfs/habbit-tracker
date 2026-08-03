import 'package:flutter/material.dart';

/// A generic `ModuleEmptyState` illustration that paints an [IconData]
/// glyph in [color] — for modules without a bespoke vector illustration
/// (e.g. `WaterDropPainter`). Renders the icon's own glyph via a
/// `TextPainter` since `CustomPainter` has no built-in icon-drawing
/// primitive.
class ModuleIconPainter extends CustomPainter {
  /// Creates a painter for [icon] in [color].
  const ModuleIconPainter(this.color, this.icon);

  /// The color the icon is painted with — always the theme's module
  /// accent at call sites, never scheme-derived.
  final Color color;

  /// The icon glyph to paint.
  final IconData icon;

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size.width * 0.7,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant ModuleIconPainter oldDelegate) =>
      color != oldDelegate.color || icon != oldDelegate.icon;
}
