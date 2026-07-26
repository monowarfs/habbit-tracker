import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/reports/pdf_report_generator.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

void main() {
  const range = DateRange(
    start: LocalDate(2026, 6, 1),
    end: LocalDate(2026, 6, 30),
  );

  test('generates a valid PDF with no modules', () async {
    final bytes = await const PdfReportGenerator().generate(
      reports: const [],
      range: range,
      periodLabel: 'Month',
      generatedAt: DateTime.utc(2026, 6, 30),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test(
    'generates a valid PDF with a module report and no chart image',
    () async {
      final bytes = await const PdfReportGenerator().generate(
        reports: [
          (
            moduleId: 'water',
            displayName: 'Water',
            accentColor: Colors.blue,
            points: const [],
            longestStreak: 5,
          ),
        ],
        range: range,
        periodLabel: 'Month',
        generatedAt: DateTime.utc(2026, 6, 30),
        profileName: 'Nadia',
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    },
  );
}
