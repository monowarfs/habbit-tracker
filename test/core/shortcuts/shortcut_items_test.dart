import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/shortcuts/shortcut_items.dart';

void main() {
  test(
    'buildShortcutItems returns exactly 3 items keyed by module id, no '
    'icon set',
    () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      final items = buildShortcutItems(l10n);

      expect(
        items.map((i) => i.type).toList(),
        ['water', 'medicine', 'prayer'],
      );
      expect(items.every((i) => i.icon == null), isTrue);
      expect(items.first.localizedTitle, l10n.waterQuickAddAction);
    },
  );

  test('buildShortcutItems resolves titles in the requested locale', () {
    final en = buildShortcutItems(lookupAppLocalizations(const Locale('en')));
    final bn = buildShortcutItems(lookupAppLocalizations(const Locale('bn')));

    expect(en.first.localizedTitle, isNot(bn.first.localizedTitle));
  });
}
