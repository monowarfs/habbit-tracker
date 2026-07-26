import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Wraps a chart widget in a `RepaintBoundary` and captures it to PNG
/// bytes — the same `RenderRepaintBoundary`/`toImage()` technique
/// `RecapCardCapture` already uses for the monthly recap card, but with
/// an instance-scoped key (not a static one) so the PDF export flow can
/// render and capture one `PeriodBarChart` per module in sequence
/// without their boundary keys colliding
/// (`docs/superpowers/specs/04-premium/05-exportable-pdf-csv-reports-
/// IMPLEMENTATION-PLAN.md`).
class ChartImageRenderer {
  final GlobalKey _boundaryKey = GlobalKey();

  /// Wraps [chart] for capture. Must be laid out (e.g. rendered
  /// off-screen in an `Overlay`, same as `ReportsScreen._shareMonth`)
  /// before [capture] is called.
  Widget wrap(Widget chart) => RepaintBoundary(key: _boundaryKey, child: chart);

  /// Rasterizes the wrapped chart to PNG bytes. `pixelRatio: 3` for
  /// print-quality output regardless of the rendering device's density.
  Future<Uint8List> capture({double pixelRatio = 3}) async {
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}
