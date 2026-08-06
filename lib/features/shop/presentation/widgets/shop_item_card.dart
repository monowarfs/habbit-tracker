import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/gamification/shop/shop_catalog.dart';
import 'package:habit_tracker/core/gamification/shop/shop_providers.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Shows an item's name, cost, and Buy/Owned button state.
class ShopItemCard extends ConsumerWidget {
  /// Creates a card for [item]; [owned] reflects whether it's unlocked.
  const ShopItemCard({required this.item, required this.owned, super.key});

  /// The catalog item this card represents.
  final ShopItem item;

  /// Whether this item has already been purchased.
  final bool owned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final balance = ref.watch(currentXpBalanceProvider);
    final affordable = balance >= item.costXp;
    final itemName = _itemName(l10n, item.nameKey);

    final buyButton = FilledButton(
      onPressed: affordable ? () => _purchase(context, ref, itemName) : null,
      child: Text(l10n.shopBuyButton(item.costXp)),
    );

    return Card(
      child: ListTile(
        title: Text(itemName),
        subtitle: Text(_itemDescription(l10n, item.descriptionKey)),
        trailing: owned
            ? Text(l10n.shopOwnedLabel)
            : affordable
            ? buyButton
            : Tooltip(
                message: l10n.shopInsufficientXp(balance, item.costXp),
                child: buyButton,
              ),
      ),
    );
  }

  Future<void> _purchase(
    BuildContext context,
    WidgetRef ref,
    String itemName,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.shopConfirmPurchase(itemName, item.costXp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.shopCancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.shopConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(shopRepositoryProvider)
        .purchaseItem(item: item, now: clock.now());
  }

  String _itemName(AppLocalizations l10n, String key) => switch (key) {
    'shopItemOceanPalette' => l10n.shopItemOceanPalette,
    'shopItemForestPalette' => l10n.shopItemForestPalette,
    'shopItemSunsetPalette' => l10n.shopItemSunsetPalette,
    'shopItemMinimalIcon' => l10n.shopItemMinimalIcon,
    _ => key,
  };

  String _itemDescription(AppLocalizations l10n, String key) => switch (key) {
    'shopItemOceanPaletteDesc' => l10n.shopItemOceanPaletteDesc,
    'shopItemForestPaletteDesc' => l10n.shopItemForestPaletteDesc,
    'shopItemSunsetPaletteDesc' => l10n.shopItemSunsetPaletteDesc,
    'shopItemMinimalIconDesc' => l10n.shopItemMinimalIconDesc,
    _ => '',
  };
}
