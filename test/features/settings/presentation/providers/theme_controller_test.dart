import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/settings/presentation/providers/theme_controller.dart';

void main() {
  test('defaults to system theme mode and updates on set', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeControllerProvider), ThemeMode.system);

    container.read(themeControllerProvider.notifier).themeMode = ThemeMode.dark;

    expect(container.read(themeControllerProvider), ThemeMode.dark);
  });
}
