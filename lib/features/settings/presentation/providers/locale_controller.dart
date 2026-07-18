import 'dart:ui';

import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_controller.g.dart';

/// The app's supported locales, per `../../../../strategies/localization.md`.
const List<Locale> supportedLocales = [Locale('en'), Locale('bn')];

/// Exposes the app's active [Locale], derived from the DB-backed
/// [appSettingsProvider] — language is an explicit in-app setting
/// (FR-C-06), independent of the OS locale.
@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  @override
  Locale build() {
    final settings = ref.watch(appSettingsProvider);
    return settings.value?.locale.toFlutterLocale() ?? const Locale('en');
  }

  /// Persists a new locale; [build] picks up the change automatically once
  /// the write lands (the DB stream re-emits).
  Future<void> updateLocale(Locale locale) async {
    final result = await ref
        .read(settingsRepositoryProvider)
        .updateLocale(locale.toAppLocale());
    if (result case Failure(:final error)) logException(error);
  }
}

/// Domain <-> Flutter mapping, kept at the presentation boundary since
/// `domain/` has zero Flutter imports (`../../../../technical/architecture.md`).
extension AppLocaleFlutter on AppLocale {
  /// Maps to a Flutter [Locale].
  Locale toFlutterLocale() => switch (this) {
    AppLocale.en => const Locale('en'),
    AppLocale.bn => const Locale('bn'),
  };
}

/// The inverse of [AppLocaleFlutter].
extension LocaleApp on Locale {
  /// Maps to the domain's [AppLocale].
  AppLocale toAppLocale() => switch (languageCode) {
    'bn' => AppLocale.bn,
    _ => AppLocale.en,
  };
}
