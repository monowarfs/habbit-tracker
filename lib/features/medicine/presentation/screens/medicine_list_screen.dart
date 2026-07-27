import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/widgets/illustrations/pill_calendar_painter.dart';
import 'package:habit_tracker/core/widgets/module_empty_state.dart';
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
          _MedicineListView(includeArchived: false),
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
      return ModuleEmptyState(
        painter: PillCalendarPainter.new,
        message: archivedOnly
            ? l10n.medicineListArchivedEmpty
            : l10n.medicineListEmpty,
        accentColor: Theme.of(context).moduleAccents.medicine,
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
