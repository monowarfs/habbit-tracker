import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/main.dart';

void main() {
  testWidgets('app boots to the dashboard empty state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: HabitTrackerApp()),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Enable a module in Settings to get started'),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
