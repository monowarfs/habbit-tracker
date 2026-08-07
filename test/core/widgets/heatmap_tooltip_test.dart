import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/heatmap_tooltip.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('formats a completed day', () {
    expect(
      heatmapTooltipMessage(
        l10n,
        const LocalDate(2026, 7, 25),
        const ModuleDayStatus(kind: ModuleDayStatusKind.complete, value: 4),
      ),
      '25 Jul 2026 — Completed',
    );
  });

  test('formats a partially-completed day', () {
    expect(
      heatmapTooltipMessage(
        l10n,
        const LocalDate(2026, 7, 24),
        const ModuleDayStatus(kind: ModuleDayStatusKind.partial, value: 2),
      ),
      '24 Jul 2026 — Partially completed',
    );
  });

  test('formats a day with no data (null status)', () {
    expect(
      heatmapTooltipMessage(l10n, const LocalDate(2026, 7, 1), null),
      '1 Jul 2026 — No data',
    );
  });

  test('formats a missed day', () {
    expect(
      heatmapTooltipMessage(
        l10n,
        const LocalDate(2026, 7, 2),
        const ModuleDayStatus(kind: ModuleDayStatusKind.missed, value: 0),
      ),
      '2 Jul 2026 — Missed',
    );
  });
}
