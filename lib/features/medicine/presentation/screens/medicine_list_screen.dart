import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_controller.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';

/// Lists every medicine, active and archived, in two tabs (FR-M-10).
class MedicineListScreen extends ConsumerStatefulWidget {
  /// Creates the medicine list screen.
  const MedicineListScreen({super.key});

  @override
  ConsumerState<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends ConsumerState<MedicineListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.medicineListTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.medicineListActiveTab),
            Tab(text: l10n.medicineListArchivedTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ActiveMedicineListView(),
          _MedicineListView(includeArchived: true, archivedOnly: true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/medicine/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// The active-tab list — drag-to-reorder (FR-M-… Atlas item: manual
/// priority order for medicines). Keeps a local id-order copy so a drag
/// reflects instantly; the underlying `Medicine` objects always come
/// fresh from [medicinesProvider] each rebuild (so a concurrent edit to
/// e.g. `dosageNote` is never masked by a stale cached copy), only their
/// *order* is locally overridden until the next add/archive/delete
/// changes the id set.
class _ActiveMedicineListView extends ConsumerStatefulWidget {
  const _ActiveMedicineListView();

  @override
  ConsumerState<_ActiveMedicineListView> createState() =>
      _ActiveMedicineListViewState();
}

class _ActiveMedicineListViewState
    extends ConsumerState<_ActiveMedicineListView> {
  List<String>? _localOrderIds;

  @override
  Widget build(BuildContext context) {
    final medicines = ref
        .watch(medicinesProvider(includeArchived: false))
        .value;
    if (medicines == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final currentIds = medicines.map((m) => m.id).toSet();
    if (_localOrderIds == null ||
        _localOrderIds!.toSet().length != currentIds.length ||
        !_localOrderIds!.toSet().containsAll(currentIds)) {
      _localOrderIds = medicines.map((m) => m.id).toList();
    }
    final byId = {for (final m in medicines) m.id: m};
    final ordered = _localOrderIds!.map((id) => byId[id]!).toList();

    if (ordered.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(child: Text(l10n.medicineListEmpty));
    }

    return ReorderableListView.builder(
      itemCount: ordered.length,
      // `onReorderItem` (not the deprecated `onReorder`) already adjusts
      // `newIndex` for the removed item at `oldIndex`.
      onReorderItem: (oldIndex, newIndex) {
        final reordered = [...ordered.map((m) => m.id)];
        final moved = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, moved);
        setState(() => _localOrderIds = reordered);
        unawaited(
          ref
              .read(medicineControllerProvider.notifier)
              .reorderMedicines(reordered),
        );
      },
      itemBuilder: (context, index) {
        final medicine = ordered[index];
        return ListTile(
          key: ValueKey(medicine.id),
          leading: const Icon(Icons.medication),
          title: Text(medicine.name),
          subtitle: medicine.dosageNote == null
              ? null
              : Text(medicine.dosageNote!),
          onTap: () => context.push('/medicine/${medicine.id}'),
        );
      },
    );
  }
}

class _MedicineListView extends ConsumerWidget {
  const _MedicineListView({
    required this.includeArchived,
    this.archivedOnly = false,
  });

  final bool includeArchived;
  final bool archivedOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicines = ref
        .watch(medicinesProvider(includeArchived: includeArchived))
        .value;
    if (medicines == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = archivedOnly
        ? medicines.where((m) => m.archivedAt != null).toList()
        : medicines;
    if (filtered.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Text(
          archivedOnly
              ? l10n.medicineListArchivedEmpty
              : l10n.medicineListEmpty,
        ),
      );
    }
    return ListView(
      children: [
        for (final medicine in filtered)
          ListTile(
            leading: const Icon(Icons.medication),
            title: Text(medicine.name),
            subtitle: medicine.dosageNote == null
                ? null
                : Text(medicine.dosageNote!),
            onTap: () => context.push('/medicine/${medicine.id}'),
          ),
      ],
    );
  }
}
