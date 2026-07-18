import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_controller.g.dart';

/// The app's supported locales, per `strategies/localization.md`.
const List<Locale> supportedLocales = [Locale('en'), Locale('bn')];

/// Exposes and mutates the app's active locale.
///
/// Language is an explicit in-app setting (FR-C-06), independent of the OS
/// locale — the device locale only picks the initial default. In-memory
/// only for now — this is the seam `app_settings.locale`
/// (`strategies/localization.md`) plugs into once the settings table
/// exists (Run 06); the provider shape itself won't need to change.
@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  @override
  Locale build() {
    final deviceLocale = PlatformDispatcher.instance.locale;
    final matches = supportedLocales.any(
      (locale) => locale.languageCode == deviceLocale.languageCode,
    );
    return matches ? Locale(deviceLocale.languageCode) : supportedLocales.first;
  }

  /// The active locale.
  Locale get locale => state;

  /// Updates the active locale.
  set locale(Locale value) => state = value;
}
