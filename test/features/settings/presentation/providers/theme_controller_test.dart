import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/features/settings/presentation/providers/theme_controller.dart';

import '../../../../support/test_database.dart';

void main() {
  test('defaults to system theme mode and persists an update', () async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(testDatabase())],
    );
    addTearDown(container.dispose);

    expect(container.read(themeControllerProvider), ThemeMode.system);

    final changedToDark = Completer<void>();
    container.listen(themeControllerProvider, (previous, next) {
      if (next == ThemeMode.dark) changedToDark.complete();
    });

    await container
        .read(themeControllerProvider.notifier)
        .updateThemeMode(ThemeMode.dark);
    await changedToDark.future.timeout(const Duration(seconds: 2));

    expect(container.read(themeControllerProvider), ThemeMode.dark);
  });
}
