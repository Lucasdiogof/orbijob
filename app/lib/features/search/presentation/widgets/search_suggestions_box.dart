import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/search_suggestions.dart';

/// "Try instead": a broader search of the same profession or a similarly spelled one, shown when nothing was found (search_suggestions.dart).
class SearchSuggestionsBox extends StatelessWidget {
  const SearchSuggestionsBox({
    super.key,
    required this.query,
    required this.onSearch,
  });

  final String query;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final suggestions = searchSuggestions(query);
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.searchSuggestTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpace.s2),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: [
              for (final s in suggestions)
                ActionChip(
                  avatar: const Icon(Icons.search, size: 18),
                  label: Text(s),
                  onPressed: () => onSearch(s),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            l.searchSuggestHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
