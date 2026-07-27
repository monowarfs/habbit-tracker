import 'package:flutter/material.dart';

/// A single water-drop glyph, painted in [color] — Water's empty-state
/// illustration (`docs/superpowers/specs/02-delightful/
/// 09-adaptive-empty-state-illustrations-design.md`).
class WaterDropPainter extends CustomPainter {
  /// Creates a water-drop painter using [color].
  const WaterDropPainter(this.color);

  /// The color the drop (and its highlight) is painted with — always the
  /// theme's module accent at call sites, never scheme-derived.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Teardrop: a pointed top narrowing into a rounded bulb, drawn as one
    // closed path (two cubic beziers for the sides, an arc for the
    // rounded bottom).
    final path = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..cubicTo(w * 0.82, h * 0.42, w * 0.82, h * 0.55, w * 0.82, h * 0.60)
      ..arcToPoint(
        Offset(w * 0.18, h * 0.60),
        radius: Radius.circular(w * 0.34),
      )
      ..cubicTo(w * 0.18, h * 0.55, w * 0.18, h * 0.42, w * 0.5, h * 0.08)
      ..close();
    canvas.drawPath(path, fill);

    // Highlight: a small lighter circle near the top-left of the bulb —
    // reads on both light/dark backgrounds since it's relative to [color],
    // not the theme.
    final highlight = Paint()..color = color.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(w * 0.38, h * 0.5), w * 0.08, highlight);
  }

  @override
  bool shouldRepaint(covariant WaterDropPainter oldDelegate) =>
      oldDelegate.color != color;
}
