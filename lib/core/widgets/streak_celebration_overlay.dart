import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Shows a brief (900ms in, 700ms hold, 400ms out; 2000ms total),
/// skippable celebration over the current screen using an
/// [OverlayEntry] — not a route/dialog, so it never blocks input to the
/// screen underneath and never appears in the back-stack. Tapping
/// anywhere on the overlay dismisses it immediately, same as its
/// auto-dismiss (`docs/superpowers/specs/02-delightful/
/// 02-streak-save-celebration-animation-design.md`).
///
/// Respects `MediaQuery.of(context).disableAnimations`
/// (`docs/superpowers/specs/07-accessibility/07-reduce-motion-respect
/// -design.md`'s standing rule): when set, skips straight to a static
/// badge-and-title flash for ~600ms with no motion, rather than the
/// animated version.
Future<void> showStreakCelebration(
  BuildContext context, {
  required String title,
  required Color accentColor,
  required IconData icon,
}) async {
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  final overlayState = Overlay.of(context);
  final completer = Completer<void>();
  Timer? autoDismissTimer;
  void dismiss() {
    if (!completer.isCompleted) {
      autoDismissTimer?.cancel();
      completer.complete();
    }
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _StreakCelebrationOverlay(
      title: title,
      accentColor: accentColor,
      icon: icon,
      reduceMotion: reduceMotion,
      onTapDismiss: dismiss,
    ),
  );
  overlayState.insert(entry);

  final autoDismissAfter = reduceMotion
      ? const Duration(milliseconds: 600)
      : const Duration(milliseconds: 2000);
  autoDismissTimer = Timer(autoDismissAfter, dismiss);

  await completer.future;
  entry.remove();
}

class _StreakCelebrationOverlay extends StatefulWidget {
  const _StreakCelebrationOverlay({
    required this.title,
    required this.accentColor,
    required this.icon,
    required this.reduceMotion,
    required this.onTapDismiss,
  });

  final String title;
  final Color accentColor;
  final IconData icon;
  final bool reduceMotion;
  final VoidCallback onTapDismiss;

  @override
  State<_StreakCelebrationOverlay> createState() =>
      _StreakCelebrationOverlayState();
}

class _StreakCelebrationOverlayState extends State<_StreakCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    // Weights approximate the 900ms-in/700ms-hold/400ms-out timeline
    // over the controller's 2000ms total.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 900,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 700),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0.8),
        weight: 400,
      ),
    ]).animate(_controller);
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 1600),
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 400),
    ]).animate(_controller);
    if (!widget.reduceMotion) {
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTapDismiss,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.35),
          child: Center(
            child: widget.reduceMotion
                ? _badge(opacity: 1, scale: 1)
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) =>
                        _badge(opacity: _fade.value, scale: _scale.value),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _badge({required double opacity, required double scale}) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: 220,
          height: 220,
          child: CustomPaint(
            painter: _ConfettiBurstPainter(color: widget.accentColor),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: widget.accentColor.withValues(
                      alpha: 0.15,
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A cheap confetti-burst approximation: a dozen short colored line
/// segments radiating outward from the center, fixed-seed for
/// deterministic (if unrealistic) rendering — no particle-physics
/// simulation, no images decoded, nothing GPU-heavier than the existing
/// chart widgets already in the app (`period_bar_chart.dart`'s
/// `fl_chart` usage).
class _ConfettiBurstPainter extends CustomPainter {
  _ConfettiBurstPainter({required this.color});

  final Color color;
  static final _random = Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * pi + _random.nextDouble() * 0.2;
      final innerRadius = size.shortestSide * 0.32;
      final outerRadius = size.shortestSide * 0.48;
      final direction = Offset(cos(angle), sin(angle));
      canvas.drawLine(
        center + direction * innerRadius,
        center + direction * outerRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiBurstPainter oldDelegate) =>
      oldDelegate.color != color;
}
