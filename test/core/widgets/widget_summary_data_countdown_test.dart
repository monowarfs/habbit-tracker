import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/widgets/widget_summary_data.dart';

void main() {
  group('WidgetSummaryData countdownTargetAt', () {
    test('round-trips non-null countdownTargetAt', () {
      final now = DateTime.utc(2026, 7, 23, 12, 30);
      final data = WidgetSummaryData(
        moduleId: 'prayer',
        headline: 'Fajr · 5:30 AM',
        deepLinkRoute: '/prayer',
        countdownTargetAt: now,
      );

      final json = data.toJson();
      final deserialized = WidgetSummaryData.fromJson(json);

      expect(deserialized.countdownTargetAt, equals(now));
    });

    test('round-trips null countdownTargetAt', () {
      const data = WidgetSummaryData(
        moduleId: 'water',
        headline: '1250 / 2000 ml',
        deepLinkRoute: '/water',
      );

      final json = data.toJson();
      final deserialized = WidgetSummaryData.fromJson(json);

      expect(deserialized.countdownTargetAt, isNull);
    });

    test('round-trips near-midnight countdownTargetAt correctly', () {
      final nearMidnight = DateTime.utc(2026, 7, 23, 23, 59, 59);
      final data = WidgetSummaryData(
        moduleId: 'prayer',
        headline: 'Isha · 9:00 PM',
        deepLinkRoute: '/prayer',
        countdownTargetAt: nearMidnight,
      );

      final json = data.toJson();
      final deserialized = WidgetSummaryData.fromJson(json);

      expect(deserialized.countdownTargetAt, equals(nearMidnight));
    });

    test('serialization preserves UTC', () {
      final local = DateTime(2026, 7, 23, 12, 30);
      final data = WidgetSummaryData(
        moduleId: 'prayer',
        headline: 'Fajr · 5:30 AM',
        deepLinkRoute: '/prayer',
        countdownTargetAt: local,
      );

      final json = data.toJson();
      // JSON stores epoch millis, which is timezone-agnostic
      expect(json['countdownTargetAt'], isA<int>());

      final deserialized = WidgetSummaryData.fromJson(json);
      expect(deserialized.countdownTargetAt!.isUtc, isTrue);
    });
  });
}
