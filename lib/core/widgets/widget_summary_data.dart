import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Plain, JSON-able data a module surfaces for its home-screen widget.
/// Ref-free — built from the same background isolate as
/// `onNotificationAction`, not from a mounted Flutter widget tree.
@immutable
class WidgetSummaryData {
  /// Creates a widget summary.
  const WidgetSummaryData({
    required this.moduleId,
    required this.headline,
    this.progressFraction,
    this.primaryActionLabel,
    this.primaryActionSourceId,
    required this.deepLinkRoute,
  });

  /// Stable module id (e.g. `'water'`, `'medicine'`, `'prayer'`).
  final String moduleId;

  /// One-line headline shown on the widget tile
  /// (e.g. `"1250 / 2000 ml"`, `"Vitamin D · due 9:00 AM"`).
  final String headline;

  /// 0.0–1.0 progress fraction, or `null` if not applicable (e.g. PRN
  /// dose, or Water before any goal is set).
  final double? progressFraction;

  /// Action button label (e.g. `"+250 ml"`, `"Mark done"`), or `null`
  /// when there's nothing actionable right now (all doses done, goal met).
  final String? primaryActionLabel;

  /// Opaque id passed back into `onNotificationAction` as `sourceId`.
  /// `null` when [primaryActionLabel] is `null`.
  final String? primaryActionSourceId;

  /// Deep-link route to open when the widget tile itself is tapped (as
  /// opposed to the action button). Always present.
  final String deepLinkRoute;

  /// Serializes to a JSON map suitable for `HomeWidget.saveWidgetData`.
  Map<String, Object?> toJson() => {
    'moduleId': moduleId,
    'headline': headline,
    'progressFraction': progressFraction,
    'primaryActionLabel': primaryActionLabel,
    'primaryActionSourceId': primaryActionSourceId,
    'deepLinkRoute': deepLinkRoute,
  };

  /// Deserializes from a JSON map produced by [toJson].
  factory WidgetSummaryData.fromJson(Map<String, Object?> json) =>
      WidgetSummaryData(
        moduleId: json['moduleId'] as String,
        headline: json['headline'] as String,
        progressFraction: (json['progressFraction'] as num?)?.toDouble(),
        primaryActionLabel: json['primaryActionLabel'] as String?,
        primaryActionSourceId: json['primaryActionSourceId'] as String?,
        deepLinkRoute: json['deepLinkRoute'] as String,
      );

  /// JSON string for passing through `HomeWidget.saveWidgetData` which
  /// only accepts `String` values.
  String toRawJson() => jsonEncode(toJson());
}
