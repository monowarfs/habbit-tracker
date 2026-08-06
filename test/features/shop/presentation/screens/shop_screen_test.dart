import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/gamification/shop/shop_catalog.dart';
import 'package:habit_tracker/core/gamification/xp_repository.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/shop/presentation/screens/shop_screen.dart';
import 'package:habit_tracker/features/shop/presentation/widgets/shop_item_card.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ShopScreen(),
      ),
    ),
  );

  // Unmounts the widget tree before `tearDown`'s `db.close()` runs, so
  // every card's live Drift `watch()` subscription (currentXpBalance +
  // unlockedShopItems, per card) cancels cleanly first — mirrors
  // `dashboard_screen_test.dart`'s `disposeTree`, needed here for the
  // same reason (multiple concurrent stream-watching widgets in one
  // tree) and skipped by simpler single-stream screen tests elsewhere.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('renders one card per catalog item', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ShopItemCard), findsNWidgets(shopCatalog.length));
    await disposeTree(tester);
  });

  testWidgets('buy button is disabled when XP balance is insufficient', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();

    final buyButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byType(ShopItemCard).first,
        matching: find.byType(FilledButton),
      ),
    );
    expect(buyButton.onPressed, isNull);
    await disposeTree(tester);
  });

  testWidgets('shows Owned instead of a Buy button for a purchased item', (
    tester,
  ) async {
    final item = shopCatalog.first;
    await XpRepository(db).awardXp(
      moduleId: 'water',
      eventType: 'action',
      amount: item.costXp,
      now: DateTime.utc(2026, 8, 6),
    );
    await db
        .into(db.shopUnlocksTable)
        .insert(
          ShopUnlocksTableCompanion.insert(
            id: 'test-unlock',
            itemId: item.id,
            itemType: item.type.name,
            unlockedAt: 0,
            createdAt: 0,
          ),
        );

    await pump(tester);
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.shopOwnedLabel), findsOneWidget);
    await disposeTree(tester);
  });
}
