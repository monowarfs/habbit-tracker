import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/gamification/shop/shop_catalog.dart';
import 'package:habit_tracker/core/gamification/shop/shop_providers.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Shows an item's name, cost, and Buy/Owned button state.
class ShopItemCard extends ConsumerStatefulWidget {
  /// Creates a card for [item]; [owned] reflects whether it's unlocked.
  const ShopItemCard({required this.item, required this.owned, super.key});

  /// The catalog item this card represents.
  final ShopItem item;

  /// Whether this item has already been purchased.
  final bool owned;

  @override
  ConsumerState<ShopItemCard> createState() => _ShopItemCardState();
}

class _ShopItemCardState extends ConsumerState<ShopItemCard> {
  bool _purchasing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final balance = ref.watch(currentXpBalanceProvider);
    final item = widget.item;
    final affordable = balance >= item.costXp;
    final itemName = _itemName(l10n, item.nameKey);

    final buyButton = FilledButton(
      onPressed: affordable && !_purchasing ? _purchase : null,
      child: Text(l10n.shopBuyButton(item.costXp)),
    );

    return Card(
      child: ListTile(
        title: Text(itemName),
        subtitle: Text(_itemDescription(l10n, item.descriptionKey)),
        trailing: widget.owned
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

  Future<void> _purchase() async {
    if (_purchasing) return;
    final item = widget.item;
    final l10n = AppLocalizations.of(context)!;
    final itemName = _itemName(l10n, item.nameKey);
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
    if (!mounted || confirmed != true) return;

    setState(() => _purchasing = true);
    await ref
        .read(shopRepositoryProvider)
        .purchaseItem(item: item, now: clock.now());
    // Deliberately not resetting `_purchasing` back to false: the
    // stream-driven `owned` rebuild that hides the Buy button entirely
    // lags a beat behind this write completing (same reasoning as
    // `_QuestTile._claim`'s own doc comment) — re-enabling in between
    // reopens the exact double-tap window this guard exists to close.
    // `purchaseItem` is a no-op past this point either way (already
    // owned).
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
