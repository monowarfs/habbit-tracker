import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;

/// Captures an arbitrary widget as a PNG image, off-screen — the
/// reusable form of `features/reports/presentation/widgets/
/// recap_card_capture.dart`'s one-off `RecapCardCapture`
/// (`docs/superpowers/specs/06-gamification/
/// 07-milestone-certificate-image-design.md`'s "Reusable for Spec
/// 04-premium/05 (PDF reports)" note). Same technique: `RepaintBoundary`
/// + `RenderRepaintBoundary.toImage()` + `dart:ui`'s own PNG encoder
/// (`ui.ImageByteFormat.png`) — no extra image-encoding package needed.
///
/// `context` is only used to reach the app's real `Overlay` (same
/// off-screen-`Positioned` trick `ReportsScreen._shareMonth` uses) so
/// the captured widget renders under a real `Directionality`/
/// `MediaQuery`/`Localizations` ancestor without ever being shown to
/// the user.
class ImageRenderer {
  const ImageRenderer._();

  /// Captures [widget] as PNG bytes at [size], rendered off-screen.
  static Future<Uint8List> captureWidget(
    BuildContext context,
    Widget widget, {
    required Size size,
    double pixelRatio = 2.0,
  }) async {
    final boundaryKey = GlobalKey();
    final overlayState = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: -size.width - 9999,
        top: 0,
        child: Material(
          child: SizedBox.fromSize(
            size: size,
            child: RepaintBoundary(key: boundaryKey, child: widget),
          ),
        ),
      ),
    );
    overlayState.insert(entry);
    try {
      final frameDrawn = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => frameDrawn.complete(),
      );
      await frameDrawn.future;
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }

  /// Renders [widget] to a PNG file named [fileName] in the app's
  /// documents directory, returning the file path. [getDirectory] is a
  /// test-only seam — same precedent as `recap_share_usecase.dart`'s
  /// `getTemporaryDirectory` param — the real `path_provider` plugin
  /// channel isn't exercised under `flutter test`.
  static Future<String> renderToFile(
    BuildContext context,
    Widget widget, {
    required String fileName,
    required Size size,
    double pixelRatio = 2.0,
    Future<Directory> Function() getDirectory =
        path_provider.getApplicationDocumentsDirectory,
  }) async {
    final bytes = await captureWidget(
      context,
      widget,
      size: size,
      pixelRatio: pixelRatio,
    );
    final dir = await getDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
