import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

void main() {
  test(
    'prayerStatusMissedDue reframes English away from a bare "Missed" '
    'verdict, matching the already-neutral Bangla framing '
    '(docs/superpowers/specs/02-delightful/'
    '03-gentle-no-guilt-missed-dose-copy-pass-design.md, row 6)',
    () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(en.prayerStatusMissedDue, 'Due for Qadha');

      final bn = await AppLocalizations.delegate.load(const Locale('bn'));
      // Bangla is unchanged — it already read "became Qadha"/"due as
      // make-up", not a literal "Missed".
      expect(bn.prayerStatusMissedDue, 'কাজা হয়েছে');
    },
  );

  test(
    'prayerQadhaCountLabel drops the "owed"/debt framing in English, '
    'matching Bangla\'s already-neutral "remaining" framing (row 7)',
    () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(en.prayerQadhaCountLabel(3), '3 remaining');

      final bn = await AppLocalizations.delegate.load(const Locale('bn'));
      expect(bn.prayerQadhaCountLabel(3), '3টি বাকি');
    },
  );

  test(
    'medicineDetailStatsSummary/medicineDetailNoHistory are localized and '
    'say "not taken" instead of "missed" — matching row 1\'s finding that '
    '"missed"-adjacent-but-red-badged wording should read neutrally '
    '(row 8, the one hardcoded-string gap the ARB grep itself missed)',
    () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        en.medicineDetailStatsSummary(80, 1, 1),
        'Last 30 days: 80% taken (1 not taken, 1 skipped)',
      );
      expect(en.medicineDetailNoHistory, 'No dose history yet');

      final bn = await AppLocalizations.delegate.load(const Locale('bn'));
      // Just needs to exist and be non-empty — exact Bangla wording is
      // this task's own translation, not pinned to a specific string in
      // this English-authored test.
      expect(bn.medicineDetailStatsSummary(80, 1, 1), isNotEmpty);
      expect(bn.medicineDetailNoHistory, isNotEmpty);
    },
  );
}
