import 'package:flutter/material.dart';

/// Shared empty-state widget for a module's primary screen — an
/// icon-sized vector illustration in [accentColor] above a message line.
/// Replaces the bare `Center(child: Text(...))` each module's first-run
/// empty state rendered before this
/// (`docs/superpowers/specs/02-delightful/
/// 09-adaptive-empty-state-illustrations-design.md`).
class ModuleEmptyState extends StatelessWidget {
  /// Creates a module empty state painting [painter] (applied to
  /// [accentColor]) above [message].
  const ModuleEmptyState({
    required this.painter,
    required this.message,
    required this.accentColor,
    super.key,
  });

  /// Module-specific illustration constructor, e.g.
  /// `WaterDropPainter.new`.
  final CustomPainter Function(Color color) painter;

  /// The existing l10n empty-state string for this module — reused
  /// verbatim, not a new key.
  final String message;

  /// The module's `ModuleAccents` color the illustration is painted with.
  final Color accentColor;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(painter: painter(accentColor)),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
