import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/gamification/shop/shop_catalog.dart';
import 'package:habit_tracker/core/gamification/shop/shop_providers.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/shop/presentation/widgets/shop_item_card.dart';

/// Full-screen shop catalog with the current XP balance displayed.
class ShopScreen extends ConsumerWidget {
  /// Creates the shop screen.
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final balance = ref.watch(currentXpBalanceProvider);
    final unlocked = ref.watch(unlockedShopItemsProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shopTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Text(l10n.shopCurrentBalance(balance))),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: shopCatalog.length,
        itemBuilder: (context, index) {
          final item = shopCatalog[index];
          return ShopItemCard(item: item, owned: unlocked.contains(item.id));
        },
      ),
    );
  }
}
