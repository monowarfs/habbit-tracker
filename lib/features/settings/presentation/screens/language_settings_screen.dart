import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/presentation/providers/locale_controller.dart';

/// Language picker, extracted from the old flat Settings home screen.
class LanguageSettingsScreen extends ConsumerWidget {
  /// Creates the language settings screen.
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsLanguage)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SegmentedButton<Locale>(
          segments: const [
            ButtonSegment(value: Locale('en'), label: Text('English')),
            ButtonSegment(value: Locale('bn'), label: Text('বাংলা')),
          ],
          selected: {locale},
          onSelectionChanged: (selection) => ref
              .read(localeControllerProvider.notifier)
              .updateLocale(selection.first),
        ),
      ),
    );
  }
}
