import 'package:flutter/material.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';

/// Stock level + refill action (FR-M-04).
class StockCard extends StatelessWidget {
  /// Creates a stock card for [medicine].
  const StockCard({required this.medicine, required this.onRefill, super.key});

  /// The medicine whose stock this card shows.
  final Medicine medicine;

  /// Called with the amount to add when the user confirms a refill.
  final ValueChanged<int> onRefill;

  @override
  Widget build(BuildContext context) {
    if (!medicine.stockEnabled) return const SizedBox.shrink();
    final low =
        medicine.stockThreshold != null &&
        (medicine.stockCount ?? 0) <= medicine.stockThreshold!;
    return Card(
      color: low ? Theme.of(context).colorScheme.errorContainer : null,
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text('${medicine.stockCount ?? 0} remaining'),
        subtitle: low ? const Text('Low stock — refill soon') : null,
        trailing: TextButton(
          onPressed: () => _showRefillDialog(context),
          child: const Text('Refill'),
        ),
      ),
    );
  }

  Future<void> _showRefillDialog(BuildContext context) async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add stock'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (amount != null && amount > 0) onRefill(amount);
  }
}
