import 'package:flutter/material.dart';

/// A crescent above a small prayer mat, painted in [color] — Prayer's
/// empty-state illustration (`docs/superpowers/specs/02-delightful/
/// 09-adaptive-empty-state-illustrations-design.md`).
class CrescentMatPainter extends CustomPainter {
  /// Creates a crescent-and-mat painter using [color].
  const CrescentMatPainter(this.color);

  /// The color every shape is painted with.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;

    // Crescent: a full circle minus an offset circle (even-odd path
    // difference) — a plain Canvas-primitive way to draw an arc-shaped
    // crescent without manual trigonometry.
    final outer = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(w * 0.5, h * 0.36), radius: w * 0.26),
      );
    final inner = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(w * 0.61, h * 0.3), radius: w * 0.22),
      );
    final crescent = Path.combine(PathOperation.difference, outer, inner);
    canvas
      ..drawPath(crescent, fill)
      // Prayer mat: a small rounded rectangle beneath the crescent.
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.2, h * 0.72, w * 0.6, h * 0.16),
          Radius.circular(w * 0.04),
        ),
        fill,
      );
  }

  @override
  bool shouldRepaint(covariant CrescentMatPainter oldDelegate) =>
      oldDelegate.color != color;
}
