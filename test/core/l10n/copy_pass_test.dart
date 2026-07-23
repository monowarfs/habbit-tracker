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
}
