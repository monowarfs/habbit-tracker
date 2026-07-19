import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';

/// Cross-module search (FR-C-15) — queries every module's own
/// [HabitModule.search] in parallel and merges the results, sorted
/// title-prefix matches first.
class AppSearchDelegate extends SearchDelegate<void> {
  /// Creates a search delegate over [_modules].
  AppSearchDelegate(this._modules);

  final List<HabitModule> _modules;

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (query.trim().isEmpty) {
      return Center(child: Text(l10n.searchPrompt));
    }
    return FutureBuilder<List<SearchResult>>(
      future: _search(query),
      builder: (context, snapshot) {
        final results = snapshot.data ?? const [];
        if (snapshot.connectionState == ConnectionState.done &&
            results.isEmpty) {
          return Center(child: Text(l10n.searchNoResults));
        }
        return ListView(
          children: [
            for (final result in results)
              ListTile(
                title: Text(result.title),
                subtitle: Text(result.subtitle),
                onTap: () {
                  close(context, null);
                  context.go(result.deepLinkRoute);
                },
              ),
          ],
        );
      },
    );
  }

  Future<List<SearchResult>> _search(String rawQuery) async {
    final lowerQuery = rawQuery.toLowerCase();
    final perModule = await Future.wait(
      _modules.map((m) => m.search(rawQuery)),
    );
    final all = perModule.expand((results) => results).toList();
    all.sort((a, b) {
      final aPrefix = a.title.toLowerCase().startsWith(lowerQuery);
      final bPrefix = b.title.toLowerCase().startsWith(lowerQuery);
      if (aPrefix != bPrefix) return aPrefix ? -1 : 1;
      return a.title.compareTo(b.title);
    });
    return all;
  }
}
