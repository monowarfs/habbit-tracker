import 'package:flutter/material.dart';

/// Helper for checking if animations should be reduced/disabled.
///
/// This establishes a standing rule per
/// `docs/superpowers/specs/07-accessibility/07-reduce-motion-respect-design.md`:
/// all animations in the app must respect the OS reduce-motion setting.
///
/// Usage:
/// ```dart
/// final reduceMotion = ReduceMotionHelper.shouldReduceMotion(context);
/// if (reduceMotion) {
///   // Show instant state change
/// } else {
///   // Show animated transition
/// }
/// ```
class ReduceMotionHelper {
  /// Returns true if the user has enabled reduce-motion in OS settings.
  ///
  /// When true, all animations should be replaced with instant state changes.
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Returns an animation duration that respects reduce-motion settings.
  ///
  /// Returns [Duration.zero] when reduce-motion is enabled, otherwise
  /// returns the provided [duration].
  static Duration animationDuration(
    BuildContext context, {
    required Duration duration,
  }) {
    return shouldReduceMotion(context) ? Duration.zero : duration;
  }
}
