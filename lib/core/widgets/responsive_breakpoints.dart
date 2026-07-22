import 'package:flutter/material.dart';

/// Material 3's compact/medium width boundary — below this, phone-style
/// bottom nav; at or above it, side nav.
const double kTabletBreakpointWidth = 600;

/// True once [context]'s width reaches the medium size class.
bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kTabletBreakpointWidth;

/// Caps content at a comfortable reading/card width on wide screens,
/// centered; a no-op below the cap.
class MaxContentWidth extends StatelessWidget {
  /// Creates a [MaxContentWidth] wrapper.
  const MaxContentWidth({
    required this.child,
    this.maxWidth = 840,
    super.key,
  });

  /// The child widget to constrain.
  final Widget child;

  /// The maximum width the child can occupy.
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
