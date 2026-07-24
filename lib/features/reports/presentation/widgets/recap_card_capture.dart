import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Wraps [child] in a `RepaintBoundary` keyed by [_boundaryKey] and
/// exposes [capturePng] to rasterize it. `pixelRatio: 3` for
/// share-quality output regardless of the rendering device's actual
/// density (`docs/superpowers/specs/02-delightful/
/// 05-shareable-monthly-recap-card-design.md`). No existing capability
/// in this app does this job — `grep -rn "RenderRepaintBoundary\|
/// toImage(" lib/` returns nothing prior to this widget.
class RecapCardCapture extends StatelessWidget {
  /// Wraps [child] for capture — typically a `MonthlyRecapCard`.
  const RecapCardCapture({required this.child, super.key});

  /// The widget to capture.
  final Widget child;

  static final GlobalKey<State> _boundaryKey = GlobalKey();

  /// Renders the wrapped widget to PNG bytes. Must be called after the
  /// first frame the boundary is part of (post-`WidgetsBinding.instance
  /// .addPostFrameCallback`, or from a button's `onPressed`, which
  /// always runs after layout).
  static Future<Uint8List> capturePng({double pixelRatio = 3}) async {
    final boundary = _boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: _boundaryKey, child: child);
}
