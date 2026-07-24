import 'package:flutter/material.dart';

/// A rounded-rect calendar outline with a capsule overlapping its corner,
/// painted in [color] — Medicine's empty-state illustration
/// (`docs/superpowers/specs/02-delightful/
/// 09-adaptive-empty-state-illustrations-design.md`).
class PillCalendarPainter extends CustomPainter {
  /// Creates a pill-and-calendar painter using [color].
  const PillCalendarPainter(this.color);

  /// The color every shape is painted with.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05;
    final fill = Paint()..color = color;

    // Calendar body: a rounded rectangle outline.
    final calendarRect = Rect.fromLTWH(w * 0.1, h * 0.22, w * 0.8, h * 0.68);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(calendarRect, Radius.circular(w * 0.08)),
        stroke,
      )
      // Two "binding" tabs at the top.
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.25, h * 0.1, w * 0.08, h * 0.18),
          Radius.circular(w * 0.04),
        ),
        fill,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.67, h * 0.1, w * 0.08, h * 0.18),
          Radius.circular(w * 0.04),
        ),
        fill,
      );

    // Capsule glyph, rotated and overlapping the bottom-right corner.
    final capsule = Rect.fromCenter(
      center: Offset(w * 0.66, h * 0.66),
      width: w * 0.4,
      height: h * 0.2,
    );
    canvas
      ..save()
      ..translate(capsule.center.dx, capsule.center.dy)
      ..rotate(-0.5)
      ..translate(-capsule.center.dx, -capsule.center.dy)
      ..drawRRect(
        RRect.fromRectAndRadius(capsule, Radius.circular(h * 0.1)),
        fill,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(covariant PillCalendarPainter oldDelegate) =>
      oldDelegate.color != color;
}
